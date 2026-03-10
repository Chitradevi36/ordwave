module Api
  module V1
    class CreditNotesController < BaseController
      before_action :require_organization!
      before_action :set_credit_note, only: %i[show void_note apply]

      # GET /api/v1/credit_notes
      def index
        base_scope = policy_scope(CreditNote)
        scope      = base_scope.includes(:customer, :branch, :return_request, :lines)
        scope      = apply_filters(scope)
        records    = paginate(scope.recent)

        counts = base_scope.group(:status).count

        render_success(
          records.map { |cn| serialize_credit_note(cn) },
          meta: pagination_meta(records).merge(counts: counts)
        )
      end

      # GET /api/v1/credit_notes/:id
      def show
        authorize @credit_note
        render_success(serialize_credit_note(@credit_note, detailed: true))
      end

      # POST /api/v1/credit_notes/from_return/:return_request_id/issue
      def issue
        return_request = ReturnRequest.not_deleted
                                      .for_org(current_organization)
                                      .find(params[:return_request_id])

        authorize CreditNote.new(
          organization:   current_organization,
          return_request: return_request
        ), :issue?

        result = CreditNotes::IssueFromReturn.call(
          actor:          current_user,
          return_request: return_request,
          notes:          params[:notes]
        )

        if result.success?
          render_created(serialize_credit_note(result.credit_note, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/credit_notes/:id/apply
      # Body: { applications: [{ sales_invoice_id: 123, amount: 500.00 }, ...] }
      def apply
        authorize @credit_note, :apply?

        result = CreditNotes::ApplyToInvoice.call(
          actor:        current_user,
          credit_note:  @credit_note,
          applications: params[:applications]
        )

        if result.success?
          @credit_note.reload
          render_success(serialize_credit_note(@credit_note, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/credit_notes/:id/void
      def void_note
        authorize @credit_note, :void?

        result = CreditNotes::Void.call(
          actor:       current_user,
          credit_note: @credit_note,
          reason:      params[:reason]
        )

        if result.success?
          render_success(serialize_credit_note(result.credit_note, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      private

      def set_credit_note
        @credit_note = CreditNote.not_deleted
                                 .for_org(current_organization)
                                 .find(params[:id])
      end

      def apply_filters(scope)
        scope = scope.by_status(params[:status])     if params[:status].present?
        scope = scope.by_customer(params[:customer_id]) if params[:customer_id].present?
        scope
      end

      # ── Serializers ─────────────────────────────────────────────────────────

      def serialize_credit_note(cn, detailed: false)
        data = {
          id:                 cn.id,
          credit_note_number: cn.credit_note_number,
          status:             cn.status,
          subtotal:           cn.subtotal,
          tax_total:          cn.tax_total,
          total:              cn.total,
          applied_amount:     cn.applied_amount.to_f,
          unapplied_amount:   cn.unapplied_amount.to_f,
          notes:              cn.notes,
          issued_at:          cn.issued_at,
          voided_at:          cn.voided_at,
          void_reason:        cn.void_reason,
          created_at:         cn.created_at,
          customer: {
            id:   cn.customer_id,
            name: cn.customer.name
          },
          branch: {
            id:   cn.branch_id,
            name: cn.branch.name
          },
          return_request: {
            id:            cn.return_request_id,
            return_number: cn.return_request&.return_number
          }
        }

        if detailed
          data[:lines] = cn.lines.includes(:product).map do |line|
            {
              id:           line.id,
              product_id:   line.product_id,
              product_sku:  line.product.sku,
              product_name: line.product.name,
              qty:          line.qty,
              unit_price:   line.unit_price,
              gst_rate:     line.gst_rate,
              tax_amount:   line.tax_amount,
              line_total:   line.line_total,
              hsn_code:     line.hsn_code
            }
          end

          data[:applications] = cn.applications.includes(:sales_invoice, :applied_by).order(created_at: :desc).map do |app|
            {
              id:             app.id,
              amount:         app.amount.to_f,
              status:         app.status,
              reversed_at:    app.reversed_at,
              reversal_reason: app.reversal_reason,
              created_at:     app.created_at,
              sales_invoice: {
                id:             app.sales_invoice_id,
                invoice_number: app.sales_invoice.invoice_number,
                grand_total:    app.sales_invoice.grand_total.to_f
              },
              applied_by: app.applied_by ? {
                id:   app.applied_by_id,
                name: app.applied_by.full_name
              } : nil
            }
          end

          data[:audit_trail] = cn.audit_logs.recent.map do |log|
            {
              action:     log.action,
              actor:      log.actor&.full_name,
              changes:    log.changes_data,
              created_at: log.created_at
            }
          end
        end

        data
      end
    end
  end
end
