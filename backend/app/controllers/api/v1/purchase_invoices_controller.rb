module Api
  module V1
    class PurchaseInvoicesController < BaseController
      before_action :require_organization!
      before_action :set_invoice, only: %i[show update post_invoice cancel]

      INVOICE_INCLUDES = [{ lines: [:product, :hsn_sac_code] }, :supplier, :branch, :created_by, :stock_movements].freeze

      # GET /api/v1/purchase_invoices
      def index
        scope = policy_scope(PurchaseInvoice)
        scope = scope.by_status(params[:status])             if params[:status].present?
        scope = scope.for_supplier(params[:supplier_id])     if params[:supplier_id].present?
        scope = scope.for_branch(params[:branch_id])         if params[:branch_id].present?
        scope = scope.in_date_range(params[:date_from], params[:date_to])
        scope = scope.search_query(params[:q])               if params[:q].present?

        invoices = paginate(scope.includes(INVOICE_INCLUDES).order(invoice_date: :desc))

        render_success(
          invoices.map { |i| serialize_invoice(i) },
          meta: pagination_meta(invoices)
        )
      end

      # GET /api/v1/purchase_invoices/:id
      def show
        authorize @invoice
        render_success(serialize_invoice(@invoice, detailed: true))
      end

      # POST /api/v1/purchase_invoices
      def create
        authorize PurchaseInvoice.new(organization: current_organization)

        result = PurchaseInvoices::CreateService.new(
          params:       invoice_params,
          organization: current_organization,
          branch:       current_branch,
          actor:        current_user
        ).call

        if result.success?
          render_created(serialize_invoice(result.invoice, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # PATCH /api/v1/purchase_invoices/:id
      def update
        authorize @invoice

        result = PurchaseInvoices::UpdateService.new(
          invoice: @invoice,
          params:  invoice_params,
          actor:   current_user
        ).call

        if result.success?
          render_success(serialize_invoice(result.invoice, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/purchase_invoices/:id/post
      def post_invoice
        authorize @invoice, :post?

        result = PurchaseInvoices::PostService.new(
          invoice: @invoice,
          actor:   current_user
        ).call

        if result.success?
          render_success(serialize_invoice(@invoice.reload, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # POST /api/v1/purchase_invoices/:id/cancel
      def cancel
        authorize @invoice, :cancel?

        result = PurchaseInvoices::CancelService.new(
          invoice: @invoice,
          actor:   current_user,
          reason:  params[:reason]
        ).call

        if result.success?
          render_success(serialize_invoice(@invoice.reload, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      private

      def set_invoice
        @invoice = PurchaseInvoice.not_deleted
                                  .where(organization: current_organization)
                                  .includes(INVOICE_INCLUDES)
                                  .find(params[:id])
      end

      def invoice_params
        params.require(:purchase_invoice).permit(
          :supplier_id, :branch_id, :invoice_number, :invoice_date, :due_date,
          :currency, :notes,
          lines_attributes: %i[
            id product_id qty unit_price discount_pct tax_rate hsn_sac_code_id notes _destroy
          ]
        )
      end

      def serialize_invoice(invoice, detailed: false)
        data = {
          id:                  invoice.id,
          invoice_number:      invoice.invoice_number,
          invoice_date:        invoice.invoice_date,
          due_date:            invoice.due_date,
          status:              invoice.status,
          currency:            invoice.currency,
          total_amount:        invoice.total_amount,
          tax_amount:          invoice.tax_amount,
          grand_total:         invoice.grand_total,
          notes:               invoice.notes,
          posted_at:           invoice.posted_at,
          cancelled_at:        invoice.cancelled_at,
          cancellation_reason: invoice.cancellation_reason,
          created_at:          invoice.created_at,
          updated_at:          invoice.updated_at,
          supplier: invoice.supplier ? {
            id:   invoice.supplier.id,
            name: invoice.supplier.name,
            code: invoice.supplier.code
          } : nil,
          branch: invoice.branch ? {
            id:   invoice.branch.id,
            name: invoice.branch.name
          } : nil,
          created_by: invoice.created_by ? {
            id:   invoice.created_by.id,
            name: invoice.created_by.full_name
          } : nil
        }

        if detailed
          data[:lines] = invoice.lines.map do |line|
            {
              id:           line.id,
              product_id:   line.product_id,
              product_name:      line.product&.name,
              product_sku:       line.product&.sku,
              qty:               line.qty,
              unit_price:        line.unit_price,
              discount_pct:      line.discount_pct,
              tax_rate:          line.tax_rate,
              tax_amount:        line.tax_amount,
              line_total:        line.line_total,
              hsn_sac_code_id:   line.hsn_sac_code_id,
              hsn_sac_code:      line.hsn_sac_code ? {
                id:       line.hsn_sac_code.id,
                code:     line.hsn_sac_code.code,
                gst_rate: line.hsn_sac_code.gst_rate
              } : nil,
              notes:             line.notes
            }
          end

          data[:stock_movements] = invoice.stock_movements.order(created_at: :asc).map do |sm|
            {
              id:            sm.id,
              movement_type: sm.movement_type,
              direction:     sm.direction,
              product_id:    sm.product_id,
              qty:           sm.qty,
              unit_cost:     sm.unit_cost,
              created_at:    sm.created_at
            }
          end
        end

        data
      end
    end
  end
end
