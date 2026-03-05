module Api
  module V1
    class ReturnRequestsController < BaseController
      before_action :require_organization!
      before_action :set_return_request, only: %i[show update submit start_qc complete_qc cancel]

      # GET /api/v1/return_requests
      def index
        base_scope = policy_scope(ReturnRequest)
        scope      = base_scope.includes(:customer, :branch, :lines, :credit_note)
        scope      = apply_filters(scope)
        records    = paginate(scope.recent)

        counts = base_scope.group(:status).count

        render_success(
          records.map { |r| serialize_return(r) },
          meta: pagination_meta(records).merge(counts: counts)
        )
      end

      # GET /api/v1/return_requests/:id
      def show
        authorize @return_request
        render_success(serialize_return(@return_request, detailed: true))
      end

      # POST /api/v1/return_requests
      def create
        authorize ReturnRequest.new(organization: current_organization), :create?

        branch = current_organization.branches.find(return_params[:branch_id])

        result = Returns::CreateDraft.call(
          actor:        current_user,
          organization: current_organization,
          branch:       branch,
          params:       return_params
        )

        if result.success?
          render_created(serialize_return(result.return_request, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # PATCH /api/v1/return_requests/:id
      def update
        authorize @return_request

        unless @return_request.draft?
          return render_errors(['Only draft returns can be edited'], status: :unprocessable_entity)
        end

        if return_params[:lines].present?
          @return_request.lines.destroy_all
        end

        if @return_request.update(update_return_params)
          if return_params[:lines].present?
            build_lines_from_params(@return_request, return_params[:lines])
          end
          Credit::AuditLogger.log(
            actor:        current_user,
            organization: current_organization,
            auditable:    @return_request,
            action:       'return_updated',
            changes:      { updated_at: Time.current }
          )
          render_success(serialize_return(@return_request.reload, detailed: true))
        else
          render_errors(@return_request.errors.full_messages)
        end
      end

      # POST /api/v1/return_requests/:id/submit
      def submit
        authorize @return_request, :submit?

        result = Returns::Submit.call(
          actor:          current_user,
          return_request: @return_request
        )

        if result.success?
          render_success(serialize_return(result.return_request, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/return_requests/:id/start_qc
      def start_qc
        authorize @return_request, :start_qc?

        result = Returns::StartQc.call(
          actor:          current_user,
          return_request: @return_request
        )

        if result.success?
          render_success(serialize_return(result.return_request, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/return_requests/:id/complete_qc
      def complete_qc
        authorize @return_request, :complete_qc?

        result = Returns::CompleteQc.call(
          actor:          current_user,
          return_request: @return_request,
          qc_lines:       params[:qc_lines]
        )

        if result.success?
          render_success(serialize_return(result.return_request, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/return_requests/:id/cancel
      def cancel
        authorize @return_request, :cancel?

        result = Returns::Cancel.call(
          actor:          current_user,
          return_request: @return_request,
          reason:         params[:reason]
        )

        if result.success?
          render_success(serialize_return(result.return_request, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      private

      def set_return_request
        @return_request = ReturnRequest.not_deleted
                                       .for_org(current_organization)
                                       .find(params[:id])
      end

      def return_params
        params.require(:return_request).permit(
          :branch_id, :customer_id, :source_type, :source_id,
          :return_date, :notes,
          lines: %i[
            product_id sales_order_line_id qty_reported
            condition_reported reason_code
            unit_price_snapshot gst_rate_snapshot hsn_code_snapshot
          ]
        )
      end

      def update_return_params
        return_params.except(:lines, :customer_id, :branch_id)
      end

      def build_lines_from_params(rr, lines_attrs)
        Array(lines_attrs).each do |attrs|
          rr.lines.create!(
            product_id:          attrs[:product_id],
            sales_order_line_id: attrs[:sales_order_line_id],
            qty_reported:        attrs[:qty_reported],
            condition_reported:  attrs[:condition_reported].presence || 'unknown',
            reason_code:         attrs[:reason_code].presence || 'other',
            unit_price_snapshot: attrs[:unit_price_snapshot],
            gst_rate_snapshot:   attrs[:gst_rate_snapshot],
            hsn_code_snapshot:   attrs[:hsn_code_snapshot]
          )
        end
      end

      def apply_filters(scope)
        scope = scope.by_status(params[:status])     if params[:status].present?
        scope = scope.by_customer(params[:customer_id]) if params[:customer_id].present?
        scope = scope.by_branch(params[:branch_id])  if params[:branch_id].present?
        scope = scope.in_date_range(params[:from_date], params[:to_date])
        scope = scope.search_q(params[:q])           if params[:q].present?
        scope
      end

      # ── Serializers ─────────────────────────────────────────────────────────

      def serialize_return(rr, detailed: false)
        data = {
          id:            rr.id,
          return_number: rr.return_number,
          status:        rr.status,
          source_type:   rr.source_type,
          source_id:     rr.source_id,
          return_date:   rr.return_date,
          notes:         rr.notes,
          submitted_at:  rr.submitted_at,
          qc_completed_at: rr.qc_completed_at,
          cancelled_at:  rr.cancelled_at,
          cancellation_reason: rr.cancellation_reason,
          created_at:    rr.created_at,
          item_count:    rr.lines.size,
          customer: {
            id:   rr.customer_id,
            name: rr.customer.name,
            code: rr.customer.try(:code)
          },
          branch: {
            id:   rr.branch_id,
            name: rr.branch.name
          },
          credit_note: rr.credit_note ? {
            id:                 rr.credit_note.id,
            credit_note_number: rr.credit_note.credit_note_number,
            status:             rr.credit_note.status,
            total:              rr.credit_note.total
          } : nil
        }

        if detailed
          data[:lines] = rr.lines.includes(:product, :qc_item, :sales_order_line).map do |line|
            serialize_line(line)
          end

          data[:stock_movements] = rr.stock_movements.order(occurred_at: :asc).map do |m|
            {
              id:            m.id,
              movement_type: m.movement_type,
              direction:     m.direction,
              qty:           m.qty,
              product_id:    m.product_id,
              occurred_at:   m.occurred_at
            }
          end

          data[:timeline] = rr.audit_logs.recent.map do |log|
            {
              id:         log.id,
              action:     log.action,
              actor:      log.actor&.full_name,
              changes:    log.changes_data,
              reason:     log.reason,
              created_at: log.created_at
            }
          end
        end

        data
      end

      def serialize_line(line)
        {
          id:                  line.id,
          product_id:          line.product_id,
          product_sku:         line.product.sku,
          product_name:        line.product.name,
          qty_reported:        line.qty_reported,
          qty_accepted:        line.qty_accepted,
          qty_rejected:        line.qty_rejected,
          condition_reported:  line.condition_reported,
          reason_code:         line.reason_code,
          unit_price_snapshot: line.unit_price_snapshot,
          gst_rate_snapshot:   line.gst_rate_snapshot,
          hsn_code_snapshot:   line.hsn_code_snapshot,
          sales_order_line_id: line.sales_order_line_id,
          qc_item: line.qc_item ? {
            id:              line.qc_item.id,
            qty_resalable:   line.qc_item.qty_resalable,
            qty_damaged:     line.qc_item.qty_damaged,
            qty_expired:     line.qc_item.qty_expired,
            condition_final: line.qc_item.condition_final,
            qc_notes:        line.qc_item.qc_notes,
            qc_at:           line.qc_item.qc_at
          } : nil
        }
      end
    end
  end
end
