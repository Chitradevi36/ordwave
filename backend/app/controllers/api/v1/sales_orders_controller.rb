module Api
  module V1
    class SalesOrdersController < BaseController
      before_action :require_organization!
      before_action :set_order, only: %i[show update submit approve hold cancel refresh_price lifecycle pick confirm_pick]

      # recent_for_customer uses policy_scope (not authorize) — skip the
      # verify_authorized after_action that BaseController enforces on all
      # non-index actions, otherwise we get a DoubleRenderError.
      skip_after_action :verify_authorized, only: :recent_for_customer

      # GET /api/v1/sales_orders
      def index
        base_scope = policy_scope(SalesOrder)

        # Status counts across the entire accessible scope (unfiltered, for tab badges)
        counts = base_scope.group(:status).count

        # Today's summary metrics
        today_start = Time.current.beginning_of_day
        today_scope = base_scope.where("sales_orders.created_at >= ?", today_start)
        metrics = {
          today_orders:      today_scope.count,
          pending_approvals: base_scope.where(status: %w[submitted on_hold]).count,
          on_hold:           base_scope.where(status: "on_hold").count,
          today_value:       today_scope.sum(:total_amount).to_f.round(0)
        }

        scope  = base_scope.includes(:customer, :branch, :created_by, :lines)
        scope  = apply_filters(scope)
        orders = paginate(apply_sort(scope))

        render_success(
          orders.map { |o| serialize_order(o) },
          meta: pagination_meta(orders).merge(counts: counts, metrics: metrics)
        )
      end

      # GET /api/v1/sales_orders/:id
      def show
        authorize @order
        render_success(serialize_order(@order, detailed: true))
      end

      # GET /api/v1/sales_orders/:id/lifecycle
      # Returns a merged chronological timeline of every event across
      # order → delivery → invoice → payment for one order.
      def lifecycle
        authorize @order, :show?

        events = []

        # ── 1. Order audit logs ────────────────────────────────────────────
        @order.audit_logs.order(:created_at).each do |log|
          events << {
            stage:  'order',
            event:  log.action,
            label:  lifecycle_order_label(log.action),
            at:     log.created_at,
            actor:  log.actor&.full_name,
            reason: log.reason,
            meta:   log.changes_data || {}
          }
        end

        # ── 2. Delivery trip / stop ────────────────────────────────────────
        stop = @order.trip_stop
        if stop.present?
          trip = stop.delivery_trip

          if trip.dispatched_at.present?
            events << {
              stage: 'delivery',
              event: 'trip_dispatched',
              label: 'Dispatched for Delivery',
              at:    trip.dispatched_at,
              actor: trip.driver&.full_name,
              meta:  {
                trip_number: trip.trip_number,
                vehicle:     trip.vehicle&.registration_number,
                driver:      trip.driver&.full_name
              }
            }
          end

          if stop.completed?
            events << {
              stage: 'delivery',
              event: "stop_#{stop.status}",
              label: lifecycle_stop_label(stop.status),
              at:    stop.delivered_at,
              meta:  {
                outcome:        stop.status,
                delivery_notes: stop.delivery_notes,
                exception_code: stop.exception_code
              }.compact
            }
          end
        end

        # ── 3. Invoices ────────────────────────────────────────────────────
        @order.sales_invoices.not_deleted.order(:created_at).each do |inv|
          events << {
            stage: 'invoice',
            event: 'invoice_created',
            label: 'Invoice Generated',
            at:    inv.created_at,
            meta:  {
              invoice_id:        inv.id,
              invoice_number:    inv.invoice_number,
              grand_total:       inv.grand_total,
              status:            inv.status,
              generation_source: inv.generation_source
            }
          }
          if inv.issued_at.present?
            events << {
              stage: 'invoice',
              event: 'invoice_issued',
              label: 'Invoice Issued',
              at:    inv.issued_at,
              meta:  { invoice_id: inv.id, invoice_number: inv.invoice_number }
            }
          end
        end

        # ── 4. Payments (via invoice allocations) ─────────────────────────
        invoice_ids = @order.sales_invoices.not_deleted.pluck(:id)
        if invoice_ids.any?
          PaymentAllocation
            .includes(:payment, :sales_invoice)
            .where(sales_invoice_id: invoice_ids)
            .each do |alloc|
              pmt = alloc.payment
              next unless pmt&.confirmed?

              events << {
                stage: 'payment',
                event: 'payment_collected',
                label: 'Payment Collected',
                at:    pmt.updated_at,
                meta:  {
                  payment_id:     pmt.id,
                  payment_number: pmt.payment_number,
                  amount:         alloc.amount_applied,
                  mode:           pmt.payment_mode,
                  invoice_number: alloc.sales_invoice&.invoice_number
                }
              }
            end
        end

        # ── Sort chronologically, nil timestamps last ─────────────────────
        events.sort_by! { |e| e[:at] || Time.at(9_999_999_999) }

        render_success({ steps: events, order_number: @order.order_number })
      end

      # GET /api/v1/sales_orders/:id/trip_assignment_suggestions
      # Returns suggested trip assignments for an approved order
      def trip_assignment_suggestions
        authorize @order, :show?
        
        return render_errors(['Order must be in approved status']) unless @order.approved?
        return render_errors(['Order already assigned to a trip']) if @order.trip_stop.present?

        suggester = Delivery::TripAssignmentSuggester.new(
          sales_order: @order,
          organization: Current.organization,
          trip_date: params[:trip_date].present? ? Date.parse(params[:trip_date]) : Date.today
        )

        suggestions = suggester.get_suggestions

        render json: {
          data: suggestions
        }
      end

      # POST /api/v1/sales_orders/:id/assign_to_trip
      # Assigns order to a trip (existing or new)
      # Body: { trip_id: X } OR { driver_id: Y, trip_date: 'YYYY-MM-DD' }
      def assign_to_trip
        authorize @order, :approve?

        trip_date = params[:trip_date].present? ? Date.parse(params[:trip_date]) : Date.today

        result = Delivery::AssignToTripService.call(
          order: @order,
          trip_id: params[:trip_id],
          driver_id: params[:driver_id],
          user: Current.user,
          trip_date: trip_date
        )

        if result.success?
          render_success({
            data: serialize_order(result.trip_stop.sales_order, detailed: true),
            trip: {
              id: result.trip.id,
              trip_number: result.trip.trip_number,
              status: result.trip.status,
              driver_name: result.trip.driver&.name
            },
            message: result.message
          })
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/sales_orders
      def create
        authorize SalesOrder.new(organization: current_organization), :create?

        customer = Customer.not_deleted.where(organization: current_organization).find(order_params[:customer_id])
        branch   = current_organization.branches.find(order_params[:branch_id])

        result = Orders::DraftUpsertService.call(
          actor:        current_user,
          organization: current_organization,
          branch:       branch,
          customer:     customer,
          params:       order_params,
          order:        nil
        )

        if result[:ok]
          render_created(serialize_order(result[:order], detailed: true))
        else
          render_errors(result[:errors])
        end
      end

      # PATCH /api/v1/sales_orders/:id
      def update
        authorize @order

        # Submitted / on_hold orders: only delivery_date + notes are editable (managers only)
        if @order.limited_editable?
          result = Orders::LimitedUpdateService.call(
            actor:  current_user,
            order:  @order,
            params: order_params
          )
          if result[:ok]
            render_success(serialize_order(result[:order], detailed: true))
          else
            render_errors(result[:errors])
          end
          return
        end

        result = Orders::DraftUpsertService.call(
          actor:        current_user,
          organization: current_organization,
          branch:       @order.branch,
          customer:     @order.customer,
          params:       order_params,
          order:        @order
        )

        if result[:ok]
          render_success(serialize_order(result[:order], detailed: true))
        else
          render_errors(result[:errors])
        end
      end

      # POST /api/v1/sales_orders/:id/submit
      def submit
        authorize @order, :submit?

        result = Orders::SubmitOrderService.call(
          actor:           current_user,
          order:           @order,
          idempotency_key: params[:idempotency_key]
        )

        if result[:ok]
          render json: {
            data:   serialize_order(result[:order], detailed: true),
            credit: serialize_credit(result[:credit])
          }, status: :ok
        elsif result[:credit]&.dig(:decision) == 'blocked'
          render json: {
            errors: result[:errors],
            code:   'credit_blocked',
            credit: serialize_credit(result[:credit])
          }, status: :unprocessable_entity
        else
          render_errors(result[:errors])
        end
      end

      # POST /api/v1/sales_orders/:id/approve
      def approve
        authorize @order, :approve?

        result = Orders::ApproveOrderService.call(
          actor:    current_user,
          order:    @order,
          decision: params[:decision],
          reason:   params[:reason]
        )

        if result[:ok]
          data = serialize_order(result[:order], detailed: true)
          if (tr = result[:trip_result])
            data[:auto_trip] = {
              action:      tr[:action],
              trip_number: tr[:trip]&.trip_number,
              trip_id:     tr[:trip]&.id,
              ok:          tr[:ok],
              errors:      tr[:errors]
            }
          end
          render_success(data)
        else
          render_errors(result[:errors])
        end
      end

      # POST /api/v1/sales_orders/:id/hold
      def hold
        authorize @order, :hold?

        result = Orders::HoldOrderService.call(
          actor:  current_user,
          order:  @order,
          reason: params[:reason]
        )

        if result[:ok]
          render_success(serialize_order(result[:order], detailed: true))
        else
          render_errors(result[:errors])
        end
      end

      # POST /api/v1/sales_orders/:id/cancel
      def cancel
        authorize @order, :cancel?

        result = Orders::CancelOrderService.call(
          actor:  current_user,
          order:  @order,
          reason: params[:reason]
        )

        if result[:ok]
          render_success(serialize_order(result[:order], detailed: true))
        else
          render_errors(result[:errors])
        end
      end

      # POST /api/v1/sales_orders/:id/refresh_price
      def refresh_price
        authorize @order, :refresh_price?

        result = Orders::PriceRefreshService.call(
          actor:  current_user,
          order:  @order
        )

        if result[:ok]
          render_success(serialize_order(result[:order], detailed: true))
        else
          render_errors(result[:errors])
        end
      end

      # POST /api/v1/sales_orders/:id/pick
      def pick
        authorize @order, :pick?

        unless @order.pending_pick?
          return render json: { errors: ['Order must be in pending_pick status to mark as picked'] }, status: :unprocessable_entity
        end

        @order.update!(
          pick_status:     :picked,
          picked_by:       current_user,
          picked_at:       Time.current
        )
        @order.audit_logs.create!(
          action:       'order_picked',
          actor:        current_user,
          organization: current_organization
        )
        render_success(serialize_order(@order, detailed: true))
      end

      # POST /api/v1/sales_orders/:id/confirm_pick
      def confirm_pick
        authorize @order, :confirm_pick?

        unless @order.picked?
          return render json: { errors: ['Order must be in picked status to confirm pick'] }, status: :unprocessable_entity
        end

        @order.update!(
          pick_status:          :pick_confirmed,
          pick_confirmed_by:    current_user,
          pick_confirmed_at:    Time.current
        )
        @order.audit_logs.create!(
          action:       'order_pick_confirmed',
          actor:        current_user,
          organization: current_organization
        )
        render_success(serialize_order(@order, detailed: true))
      end

      # GET /api/v1/sales_orders/recent_for_customer?customer_id=X
      def recent_for_customer
        return render_errors(["customer_id is required"]) if params[:customer_id].blank?

        orders = policy_scope(SalesOrder)
          .includes(lines: :product)
          .where(customer_id: params[:customer_id])
          .where.not(status: %w[draft cancelled])
          .recent
          .limit(2)

        render_success(orders.map { |o| serialize_order(o, detailed: true) })
      end

      # POST /api/v1/sales_orders/from_mobile
      # Create + submit in one atomic call (mobile field reps)
      def from_mobile
        authorize SalesOrder.new(organization: current_organization), :from_mobile?

        # Idempotency guard at outer level
        idempotency_key = params[:idempotency_key]
        if idempotency_key.present?
          existing = SalesOrder
                       .not_deleted
                       .where(organization_id: current_organization.id, idempotency_key: idempotency_key)
                       .where.not(status: 'draft')
                       .first
          return render_success(serialize_order(existing, detailed: true)) if existing
        end

        customer = Customer.not_deleted.where(organization: current_organization).find(order_params[:customer_id])
        branch   = current_organization.branches.find(order_params[:branch_id])

        ActiveRecord::Base.transaction do
          draft_result = Orders::DraftUpsertService.call(
            actor:        current_user,
            organization: current_organization,
            branch:       branch,
            customer:     customer,
            params:       order_params,
            order:        nil
          )

          unless draft_result[:ok]
            render_errors(draft_result[:errors])
            raise ActiveRecord::Rollback
          end

          submit_result = Orders::SubmitOrderService.call(
            actor:           current_user,
            order:           draft_result[:order],
            idempotency_key: idempotency_key
          )

          if submit_result[:ok]
            order  = submit_result[:order]
            serial = serialize_order(order, detailed: true)

            # B3.6 — Expose credit decision and scheme details explicitly for mobile
            serial[:credit_check] = {
              decision:         order.credit_decision,
              reasons:          Array(order.credit_reasons),
              metrics:          (order.credit_snapshot || {}).slice('outstanding', 'overdue_amount', 'overdue_days', 'available_credit', 'credit_limit').transform_keys(&:to_s),
              actions_required: (order.credit_snapshot || {}).fetch('actions_required', {})
            }
            serial[:schemes_applied] = (order.scheme_snapshot || []).map do |snap|
              {
                scheme_id:    snap['scheme_id'],
                scheme_name:  snap['scheme_name'],
                scheme_type:  snap['scheme_type'],
                discount_pct: snap['discount_pct'],
                freebies:     snap['freebies'] || []
              }
            end

            render_created(serial)
          else
            render_errors(submit_result[:errors])
            raise ActiveRecord::Rollback
          end
        end
      end

      private

      def set_order
        @order = policy_scope(SalesOrder).find(params[:id])
      end

      def order_params
        params.require(:order).permit(
          :customer_id,
          :branch_id,
          :delivery_date,
          :notes,
          lines: %i[product_id qty unit_price discount_pct]
        )
      end

      def apply_filters(scope)
        scope = scope.by_status(params[:status])            if params[:status].present?
        scope = scope.by_branch(params[:branch_id])         if params[:branch_id].present?
        scope = scope.by_customer(params[:customer_id])     if params[:customer_id].present?
        scope = scope.by_created_by(params[:created_by_id]) if params[:created_by_id].present?
        scope = scope.search_q(params[:q])                  if params[:q].present?
        scope = scope.by_date_range(params[:date_from], params[:date_to]) if params[:date_from].present? || params[:date_to].present?
        scope = scope.where("sales_orders.total_amount >= ?", params[:min_value].to_f) if params[:min_value].present?
        scope = scope.where("sales_orders.total_amount <= ?", params[:max_value].to_f) if params[:max_value].present?
        if params[:delivery_overdue] == "1"
          scope = scope.where("sales_orders.delivery_date < ?", Date.current)
                       .where(status: %w[submitted on_hold approved dispatched])
        end
        scope
      end

      def apply_sort(scope)
        allowed = %w[created_at total_amount order_number delivery_date submitted_at]
        col = allowed.include?(params[:sort_by]) ? params[:sort_by] : 'created_at'
        dir = params[:sort_dir]&.downcase == 'asc' ? :asc : :desc
        scope.reorder(col => dir)
      end

      def serialize_order(order, detailed: false)
        data = {
          id:              order.id,
          order_number:    order.order_number,
          status:          order.status,
          credit_decision: order.credit_decision,
          credit_reasons:  order.credit_reasons,
          credit_snapshot: order.credit_snapshot || {},
          delivery_date:   order.delivery_date,
          notes:           order.notes,
          total_amount:    order.total_amount,
          discount_amount: order.discount_amount,
          submitted_at:    order.submitted_at,
          approved_at:     order.approved_at,
          dispatched_at:   order.dispatched_at,
          delivered_at:    order.delivered_at,
          invoiced_at:     order_invoiced_at(order),
          paid_at:         order_paid_at(order),
          cancelled_at:    order.cancelled_at,
          cancellation_reason: order.cancellation_reason,
          pick_status:         order.pick_status,
          picked_by_id:        order.picked_by_id,
          picked_at:           order.picked_at,
          pick_confirmed_by_id: order.pick_confirmed_by_id,
          pick_confirmed_at:   order.pick_confirmed_at,
          created_at:      order.created_at,
          updated_at:      order.updated_at,
          customer: {
            id:   order.customer_id,
            name: order.customer&.name,
            code: order.customer&.code
          },
          branch: {
            id:   order.branch_id,
            name: order.branch&.name
          },
          created_by: {
            id:   order.created_by_id,
            name: order.created_by&.full_name
          }
        }

        if detailed
          data[:lines] = order.lines.map { |l| serialize_line(l) }
          data[:timeline] = order.audit_logs.recent.map { |log| serialize_audit_log(log) }
          data[:freebies]        = order.freebies.includes(:product).map { |f| { id: f.id, product_id: f.product_id, product_name: f.product&.name, qty_free: f.qty_free, scheme_id: f.scheme_id, notes: f.notes } }
          data[:scheme_snapshot] = order.scheme_snapshot
        end

        data
      end

      # Returns the earliest timestamp an invoice was generated for this order.
      def order_invoiced_at(order)
        order.sales_invoices.not_deleted
             .where.not(status: 'draft')
             .minimum(:created_at)
      end

      # Returns the timestamp when ALL non-void invoices on the order became fully paid.
      # Nil if any invoice is still outstanding.
      def order_paid_at(order)
        invoices = order.sales_invoices.not_deleted.where.not(status: 'void')
        return nil if invoices.empty?
        return nil unless invoices.all? { |inv| inv.paid? }
        invoices.map(&:updated_at).max
      end

      def serialize_credit(credit)
        return nil if credit.nil?
        {
          decision:         credit[:decision],
          reasons:          Array(credit[:reasons]),
          metrics:          credit[:metrics] || {},
          actions_required: credit[:actions_required] || {}
        }
      end

      def serialize_line(line)
        {
          id:            line.id,
          product_id:    line.product_id,
          product_name:  line.product&.name,
          product_sku:   line.product&.sku,
          qty:           line.qty,
          unit_price:    line.unit_price,
          discount_pct:  line.discount_pct,
          gst_rate:      line.gst_rate,
          line_total:    line.line_total,
          price_source:  line.price_source,
          hsn_code:      line.hsn_code,
          scheme_discount_pct: line.scheme_discount_pct,
          scheme_tags:         line.scheme_tags
        }
      end

      def serialize_audit_log(log)
        {
          id:         log.id,
          action:     log.action,
          changes:    log.changes_data,
          reason:     log.reason,
          actor_name: log.actor&.full_name,
          created_at: log.created_at
        }
      end

      LIFECYCLE_ORDER_LABELS = {
        'order_created'          => 'Order Created',
        'order_updated'          => 'Order Updated',
        'order_submitted'        => 'Order Submitted',
        'order_credit_checked'   => 'Credit Checked',
        'order_on_hold'          => 'Placed On Hold',
        'order_approved'         => 'Order Approved',
        'order_rejected'         => 'Order Rejected',
        'order_cancelled'        => 'Order Cancelled',
        'order_dispatched'       => 'Dispatched',
        'order_delivered'        => 'Delivered',
        'order_partial_delivery' => 'Partially Delivered',
        'order_price_refreshed'  => 'Prices Refreshed'
      }.freeze

      def lifecycle_order_label(action)
        LIFECYCLE_ORDER_LABELS.fetch(action, action.humanize)
      end

      def lifecycle_stop_label(status)
        {
          'delivered'        => 'Delivered',
          'partial_delivery' => 'Partially Delivered',
          'failed'           => 'Delivery Failed',
          'skipped'          => 'Stop Skipped'
        }.fetch(status, status.humanize)
      end
    end
  end
end
