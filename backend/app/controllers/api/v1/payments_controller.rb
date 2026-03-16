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
