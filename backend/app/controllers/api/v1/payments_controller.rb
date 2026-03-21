module Api
  module V1
    class PaymentsController < BaseController
      before_action :require_organization!
      before_action :set_payment, only: %i[show confirm reverse retry]

      PAYMENT_INCLUDES = [
        :branch, :customer, :created_by,
        { allocations: :sales_invoice }
      ].freeze

      # ── GET /api/v1/payments ───────────────────────────────────────────────
      def index
        base  = policy_scope(Payment).includes(:branch, :customer, :created_by)
        base  = apply_filters(base)
        items = paginate(base.recent)

        counts = policy_scope(Payment).group(:status).count

        render_success(
          items.map { |p| serialize_payment(p) },
          meta: pagination_meta(items).merge(counts: counts)
        )
      end

      # ── GET /api/v1/payments/:id ───────────────────────────────────────────
      def show
        authorize @payment
        render_success(serialize_payment(@payment, detailed: true))
      end

      # ── POST /api/v1/payments ──────────────────────────────────────────────
      def create
        authorize Payment.new(organization: current_organization), :create?

        branch   = current_organization.branches.find(payment_params[:branch_id])
        customer = current_organization.customers.find(payment_params[:customer_id])

        payment = Payment.new(
          organization:     current_organization,
          branch:           branch,
          customer:         customer,
          created_by:       current_user,
          payment_number:   Payment.generate_payment_number(
                              organization: current_organization,
                              branch:       branch
                            ),
          amount:           payment_params[:amount],
          payment_mode:     payment_params[:payment_mode].presence || 'cash',
          reference_number: payment_params[:reference_number],
          received_date:    payment_params[:received_date].presence || Date.current,
          notes:            payment_params[:notes],
          status:           'draft'
        )

        if payment.save
          Credit::AuditLogger.log(
            actor:        current_user,
            organization: current_organization,
            auditable:    payment,
            action:       'payment_created',
            changes:      { amount: payment.amount, mode: payment.payment_mode }
          )
          render_created(serialize_payment(payment, detailed: true))
        else
          render_errors(payment.errors.full_messages)
        end
      end

      # ── POST /api/v1/payments/:id/confirm ─────────────────────────────────
      def confirm
        authorize @payment, :confirm?

        result = Payments::ConfirmPaymentService.call(
          actor:        current_user,
          payment:      @payment,
          manual_lines: Array(params[:allocations]).presence
        )

        if result.success?
          render_success(serialize_payment(result.payment, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # ── POST /api/v1/payments/:id/reverse ─────────────────────────────────
      def reverse
        authorize @payment, :reverse?

        result = Payments::ReversePaymentService.call(
          actor:   current_user,
          payment: @payment,
          reason:  params[:reason].to_s.strip
        )

        if result.success?
          render_success(serialize_payment(result.payment, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # ── POST /api/v1/payments/:id/retry ────────────────────────────────────
      def retry
        @payment = policy_scope(Payment).find(params[:id])
        authorize @payment, :retry?

        result = Payment::RetryService.new(@payment, 'customer').call

        if result[:success]
          render_success(result)
        else
          render_errors(result[:message])
        end
      end

      private

      # ── Auto-Posting Feature Endpoints ──────────────────────────────────────
      
      def auto_posting_status
        config = ConfidenceAdjustment.latest
        configuration = config&.to_configuration_hash || {
          'auto_post_threshold' => 95,
          'suggestion_threshold' => 85,
          'rejection_window_minutes' => 60,
          'amount_tolerance_pct' => 2.0,
          'date_tolerance_days' => 3,
          'customer_fuzzy_minimum' => 0.80,
          'reference_weight' => 15
        }

        stats = {
          today_auto_posted: AutoPostAudit.auto_posted.where(
            timestamp: Time.current.beginning_of_day..Time.current.end_of_day
          ).count,
          today_suggested: PaymentSuggestion.pending.where(
            created_at: Time.current.beginning_of_day..Time.current.end_of_day
          ).count,
          today_manual_review: ManualPaymentReview.where(
            created_at: Time.current.beginning_of_day..Time.current.end_of_day
          ).count,
          this_week_auto_posted: AutoPostAudit.auto_posted.where(
            timestamp: 1.week.ago..Time.current
          ).count
        }

        render_success({
          auto_posting_enabled: true,
          confidence_threshold_auto: configuration['auto_post_threshold'],
          confidence_threshold_suggest: configuration['suggestion_threshold'],
          rejection_window_minutes: configuration['rejection_window_minutes'],
          stats: stats
        })
      end

      def reject_auto_post
        payment = Payment.find_by(id: params[:id])
        return render_error('Payment not found', status: 404) unless payment

        unless payment.auto_posted?
          return render_error('Payment was not auto-posted', status: 422)
        end

        unless payment.can_reject?
          return render_error('Rejection window has expired (>1 hour)', status: 422)
        end

        rejector = Payments::PaymentRejectionService.new(
          payment: payment,
          rejection_reason: params[:rejection_reason],
          actor: current_user
        )

        result = rejector.call

        if result.success?
          render_success({
            ok: true,
            payment: serialize_payment_auto_post(result.data[:payment]),
            message: 'Payment reversed and routed to manual review'
          })
        else
          render_error(result.errors, status: 422)
        end
      end

      def confidence_breakdown
        payment = Payment.find_by(id: params[:id])
        return render_error('Payment not found', status: 404) unless payment

        unless payment.auto_posted?
          return render_error('Payment was not auto-posted', status: 404)
        end

        breakdown = payment.auto_post_audits.first&.confidence_breakdown || {}

        render_success({
          payment_id: payment.id,
          confidence_score: payment.confidence_score,
          confidence_grade: payment.confidence_grade,
          breakdown: breakdown,
          auto_posted: payment.auto_posted?,
          can_reject_until: payment.rejection_window_expires_at,
          time_until_expires_seconds: payment.time_until_rejection_expires
        })
      end

      def audit_trail
        filters = params.dig(:filters) || {}
        limit = (params[:limit] || 50).to_i
        offset = (params[:offset] || 0).to_i

        query = AutoPostAudit.recent

        # Apply action filter
        if filters[:action].present?
          query = query.where(action: filters[:action])
        end

        # Apply date range filter
        if filters[:date_from].present? && filters[:date_to].present?
          from_date = Date.parse(filters[:date_from])
          to_date = Date.parse(filters[:date_to])
          query = query.for_date_range(from_date, to_date)
        end

        # Apply status filter
        if filters[:status].present?
          case filters[:status]
          when 'auto_posted'
            query = query.auto_posted
          when 'rejected'
            query = query.rejected
          end
        end

        total = query.count
        audits = query.limit(limit).offset(offset)

        render_success({
          audits: serialize_audits(audits),
          total: total,
          page: (offset / limit.to_f).ceil + 1,
          per_page: limit,
          pages: (total / limit.to_f).ceil
        })
      end

      def auto_post_stats
        period = params[:period] || 'today'
        date_range = calculate_date_range(period)

        auto_posted = AutoPostAudit.auto_posted.for_date_range(date_range[0], date_range[1]).count
        rejected = AutoPostAudit.rejected.for_date_range(date_range[0], date_range[1]).count
        total = auto_posted + rejected

        success_rate = total.zero? ? 0 : (auto_posted.to_f / total * 100).round(2)

        rejection_reasons = RejectionFeedback.for_date_range(date_range[0], date_range[1])
          .group(:rejection_reason)
          .count

        render_success({
          period: period,
          date_range: { from: date_range[0], to: date_range[1] },
          total_transactions: total,
          auto_posted: auto_posted,
          rejected: rejected,
          success_rate: success_rate,
          rejection_reasons: rejection_reasons
        })
      end

      # ── Helper Methods ──────────────────────────────────────────────────────

      def serialize_payment_auto_post(payment)
        {
          id: payment.id,
          amount: payment.amount,
          status: payment.status,
          auto_posted: payment.auto_posted?,
          confidence_score: payment.confidence_score,
          reversed_at: payment.reversed_at,
          invoice_id: payment.sales_invoices.first&.id,
          invoice_number: payment.sales_invoices.first&.invoice_number
        }
      end

      def serialize_audits(audits)
        audits.map do |audit|
          {
            id: audit.id,
            payment_id: audit.payment_id,
            action: audit.action,
            timestamp: audit.timestamp,
            actor: audit.actor&.full_name || 'system',
            notes: audit.audit_notes
          }
        end
      end

      def calculate_date_range(period)
        case period
        when 'today'
          [Date.today, Date.today]
        when 'week'
          [1.week.ago.to_date, Date.today]
        when 'month'
          [1.month.ago.to_date, Date.today]
        else
          [Date.today, Date.today]
        end
      end

      # ── Existing Serializers and Helpers ────────────────────────────────────

      private

      def set_payment
        @payment = policy_scope(Payment)
                     .includes(PAYMENT_INCLUDES)
                     .find(params[:id])
      end

      def payment_params
        params.require(:payment).permit(
          :branch_id, :customer_id, :amount, :payment_mode,
          :reference_number, :received_date, :notes
        )
      end

      def apply_filters(scope)
        scope = scope.where(branch_id: params[:branch_id])     if params[:branch_id].present?
        scope = scope.where(customer_id: params[:customer_id]) if params[:customer_id].present?
        scope = scope.by_mode(params[:payment_mode])           if params[:payment_mode].present?
        scope = scope.by_status(params[:status])               if params[:status].present?
        scope = scope.in_date_range(params[:from_date], params[:to_date]) if params[:from_date].present? || params[:to_date].present?
        scope = scope.search_query(params[:q])                 if params[:q].present?
        scope
      end

      def serialize_payment(payment, detailed: false)
        base = {
          id:                 payment.id,
          payment_number:     payment.payment_number,
          customer:           { id: payment.customer_id, name: payment.customer&.name },
          branch:             { id: payment.branch_id,   code: payment.branch&.code },
          amount:             payment.amount,
          payment_mode:       payment.payment_mode,
          reference_number:   payment.reference_number,
          received_date:      payment.received_date,
          status:             payment.status,
          allocated_amount:   payment.allocated_amount,
          unallocated_amount: payment.unallocated_amount,
          notes:              payment.notes,
          confirmed_at:       payment.confirmed_at,
          reversed_at:        payment.reversed_at,
          reversal_reason:    payment.reversal_reason,
          created_by:         payment.created_by&.full_name,
          created_at:         payment.created_at
        }

        return base unless detailed

        base.merge(
          allocations:  serialize_allocations(payment),
          audit_trail:  payment.audit_logs
                               .order(created_at: :desc)
                               .limit(30)
                               .map { |a|
                                 { action: a.action, actor: a.actor&.full_name,
                                   at: a.created_at, changes: a.changes_data,
                                   reason: a.reason }
                               }
        )
      end

      def serialize_allocations(payment)
        payment.allocations.map do |alloc|
          inv = alloc.sales_invoice
          {
            id:               alloc.id,
            status:           alloc.status,
            allocated_amount: alloc.allocated_amount,
            invoice: inv ? {
              id:             inv.id,
              invoice_number: inv.invoice_number,
              invoice_date:   inv.invoice_date,
              grand_total:    inv.grand_total,
              outstanding:    inv.outstanding_amount
            } : nil
          }
        end
      end
    end
  end
end
