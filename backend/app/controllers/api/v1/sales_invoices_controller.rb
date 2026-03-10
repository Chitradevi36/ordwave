module Api
  module V1
    class SalesInvoicesController < BaseController
      before_action :require_organization!
      before_action :set_invoice, only: %i[show issue void_invoice pdf einvoice ewaybill cancel_ewaybill]

      INVOICE_INCLUDES = [
        :branch, :customer, :sales_order, :created_by,
        { lines: :product }
      ].freeze

      # ── GET /api/v1/sales_invoices ─────────────────────────────────────────
      def index
        base  = policy_scope(SalesInvoice).includes(:branch, :customer, :sales_order)
        base  = apply_filters(base)
        items = paginate(base.recent)

        counts = policy_scope(SalesInvoice).group(:status).count

        render_success(
          items.map { |inv| serialize_invoice(inv) },
          meta: pagination_meta(items).merge(counts: counts)
        )
      end

      # ── GET /api/v1/sales_invoices/:id ─────────────────────────────────────
      def show
        authorize @invoice
        render_success(serialize_invoice(@invoice, detailed: true))
      end

      # ── POST /api/v1/sales_invoices ────────────────────────────────────────
      # Creates a draft or issues immediately from posted params.
      # Body: { customer_id, branch_id, sales_order_id?, invoice_date?,
      #         generation_source?, notes?, delivered_lines: [{...}] }
      def create
        authorize SalesInvoice.new(organization: current_organization), :create?

        branch   = current_organization.branches.find(invoice_params[:branch_id])
        customer = current_organization.customers.find(invoice_params[:customer_id])

        order = if invoice_params[:sales_order_id].present?
                  current_organization.sales_orders.find(invoice_params[:sales_order_id])
                end

        result = Invoice::GenerateFromDeliveryService.call(
          actor:             current_user,
          branch:            branch,
          customer:          customer,
          sales_order:       order,
          invoice_date:      invoice_params[:invoice_date].presence || Date.current,
          generation_source: invoice_params[:generation_source].presence || 'manual_direct',
          notes:             invoice_params[:notes],
          delivered_lines:   Array(invoice_params[:delivered_lines])
        )

        if result.success?
          render_created(serialize_invoice(result.invoice, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # ── POST /api/v1/sales_invoices/generate_from_order/:sales_order_id ───
      def generate_from_order
        order  = current_organization.sales_orders.find(params[:sales_order_id])
        branch = order.branch

        authorize SalesInvoice.new(organization: current_organization, branch: branch),
                  :generate_from_order?

        # Build invoiceable lines from delivered - already-invoiced qty
        delivered_lines = order.lines.map do |sol|
          invoiceable_qty = sol.delivered_qty.to_d - sol.invoiced_qty.to_d
          next if invoiceable_qty <= 0

          # Allow caller to pass explicit quantities (partial re-invoice)
          override = Array(params[:delivered_lines]).find { |dl| dl[:sales_order_line_id].to_i == sol.id }
          qty = override ? [override[:qty].to_d, invoiceable_qty].min : invoiceable_qty

          {
            product_id:          sol.product_id,
            qty:                 qty,
            sales_order_line_id: sol.id,
            unit_price:          sol.unit_price,
            discount_pct:        sol.discount_pct,
            hsn_code:            sol.hsn_code,
            gst_rate:            sol.gst_rate
          }
        end.compact

        if delivered_lines.empty?
          return render_errors(['No invoiceable delivered quantities found on this order'])
        end

        result = Invoice::GenerateFromDeliveryService.call(
          actor:             current_user,
          branch:            branch,
          customer:          order.customer,
          sales_order:       order,
          invoice_date:      params[:invoice_date].presence || Date.current,
          generation_source: 'manual_from_order',
          notes:             params[:notes],
          delivered_lines:   delivered_lines
        )

        if result.success?
          render_created(serialize_invoice(result.invoice, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # ── POST /api/v1/sales_invoices/generate_from_delivery_stop/:stop_id ──
      # Synchronous version (for manual trigger from UI). Job handles async.
      def generate_from_delivery_stop
        stop  = TripStop.find(params[:stop_id])
        order = stop.sales_order

        authorize SalesInvoice.new(organization: current_organization, branch: order.branch),
                  :generate_from_stop?

        unless stop.delivery_trip.organization_id == current_organization.id
          return render_errors(['Stop does not belong to your organization'], status: :forbidden)
        end

        delivered_lines = order.lines.map do |sol|
          invoiceable_qty = sol.delivered_qty.to_d - sol.invoiced_qty.to_d
          next if invoiceable_qty <= 0

          {
            product_id:          sol.product_id,
            qty:                 invoiceable_qty,
            sales_order_line_id: sol.id,
            unit_price:          sol.unit_price,
            discount_pct:        sol.discount_pct,
            hsn_code:            sol.hsn_code,
            gst_rate:            sol.gst_rate
          }
        end.compact

        if delivered_lines.empty?
          return render_errors(['No invoiceable delivered quantities for this stop'])
        end

        result = Invoice::GenerateFromDeliveryService.call(
          actor:             current_user,
          branch:            order.branch,
          customer:          order.customer,
          sales_order:       order,
          trip_stop:         stop,
          invoice_date:      stop.delivered_at&.to_date || Date.current,
          generation_source: 'auto_on_delivery',
          delivered_lines:   delivered_lines
        )

        if result.success?
          render_created(serialize_invoice(result.invoice, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # ── POST /api/v1/sales_invoices/bulk_generate ─────────────────────────
      # Body: { order_ids: [1, 2, 3], invoice_date: "2026-03-09" }
      # Returns: { generated: N, skipped: N, errors: [] }
      def bulk_generate
        authorize SalesInvoice.new(organization: current_organization), :bulk_generate?

        order_ids    = Array(params[:order_ids]).map(&:to_i).uniq
        invoice_date = params[:invoice_date].presence&.then { |d| Date.parse(d) rescue Date.current } || Date.current

        generated = 0
        skipped   = 0
        errors    = []

        orders = current_organization.sales_orders
                                     .where(id: order_ids)
                                     .includes(:lines, :customer, :branch)

        orders.each do |order|
          delivered_lines = order.lines.map do |sol|
            invoiceable_qty = sol.delivered_qty.to_d - sol.invoiced_qty.to_d
            next if invoiceable_qty <= 0

            {
              product_id:          sol.product_id,
              qty:                 invoiceable_qty,
              sales_order_line_id: sol.id,
              unit_price:          sol.unit_price,
              discount_pct:        sol.discount_pct,
              hsn_code:            sol.hsn_code,
              gst_rate:            sol.gst_rate
            }
          end.compact

          if delivered_lines.empty?
            skipped += 1
            next
          end

          result = Invoice::GenerateFromDeliveryService.call(
            actor:             current_user,
            branch:            order.branch,
            customer:          order.customer,
            sales_order:       order,
            invoice_date:      invoice_date,
            generation_source: "manual_from_order",
            delivered_lines:   delivered_lines
          )

          if result.success?
            generated += 1
          else
            skipped += 1
            errors << { order_id: order.id, order_number: order.order_number, errors: result.errors }
          end
        rescue => e
          skipped += 1
          errors << { order_id: order.id, errors: [e.message] }
        end

        render_success({ generated: generated, skipped: skipped, errors: errors })
      end

      # ── POST /api/v1/sales_invoices/:id/issue ──────────────────────────────
      def issue
        authorize @invoice, :issue?

        if @invoice.issued?
          return render_errors(['Invoice is already issued'])
        end

        @invoice.update!(status: 'issued', issued_at: Time.current)
        Credit::AuditLogger.log(
          actor:        current_user,
          organization: @invoice.organization,
          auditable:    @invoice,
          action:       'invoice_issued',
          changes:      { issued_at: @invoice.issued_at }
        )
        render_success(serialize_invoice(@invoice, detailed: true))
      end

      # ── POST /api/v1/sales_invoices/:id/void ───────────────────────────────
      def void_invoice
        authorize @invoice, :void?

        result = Invoice::VoidService.call(
          actor:   current_user,
          invoice: @invoice,
          reason:  params[:reason]
        )

        if result.success?
          render_success(serialize_invoice(result.invoice, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # ── POST /api/v1/sales_invoices/:id/einvoice ─────────────────────────────
      # Triggers e-invoice (IRN) generation via the NIC IRP.
      # Runs synchronously and returns the updated invoice payload.
      # For fire-and-forget mode callers may pass ?async=true to enqueue instead.
      def einvoice
        authorize @invoice, :einvoice?

        if @invoice.irn.present?
          return render_errors(['IRN has already been generated for this invoice'])
        end

        unless @invoice.issued?
          return render_errors(['Invoice must be in issued status before generating e-invoice'])
        end

        if params[:async].present?
          EinvoiceJob.perform_later(@invoice.id)
          @invoice.update_columns(einvoice_status: 'pending')
          return render_success(
            serialize_invoice(@invoice, detailed: true),
            meta: { message: 'E-invoice generation queued' }
          )
        end

        result = Gst::EinvoiceService.call(invoice: @invoice)

        if result.success?
          @invoice.reload
          render_success(serialize_invoice(@invoice, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # ── POST /api/v1/sales_invoices/:id/ewaybill ─────────────────────────
      # Generates an e-waybill via the NIC E-Way Bill API.
      def ewaybill
        authorize @invoice, :ewaybill?

        existing = @invoice.ewaybill_requests.order(:created_at).last
        if existing&.status == 'generated'
          return render_errors(['E-waybill has already been generated for this invoice'])
        end

        unless @invoice.issued?
          return render_errors(['Invoice must be in issued status before generating e-waybill'])
        end

        result = Gst::EwaybillService.generate(
          sales_invoice:    @invoice,
          transport_mode:   params[:transport_mode].presence || 'road',
          vehicle_number:   params[:vehicle_number],
          distance_km:      params[:distance_km],
          transporter_id:   params[:transporter_id],
          transporter_name: params[:transporter_name]
        )

        if result.success?
          @invoice.reload
          render_success(serialize_invoice(@invoice, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # ── POST /api/v1/sales_invoices/:id/cancel_ewaybill ───────────────────
      def cancel_ewaybill
        authorize @invoice, :cancel_ewaybill?

        ewb = @invoice.ewaybill_requests.order(:created_at).last
        unless ewb&.status == 'generated'
          return render_errors(['No active e-waybill found for this invoice'])
        end

        result = Gst::EwaybillService.cancel(
          ewaybill_request: ewb,
          reason:           params[:reason].presence || 'Data Entry Mistake'
        )

        if result.success?
          @invoice.reload
          render_success(serialize_invoice(@invoice, detailed: true))
        else
          render_errors(result.errors)
        end
      end

      # ── GET /api/v1/sales_invoices/:id/pdf ────────────────────────────────
      def pdf
        authorize @invoice, :pdf?

        # Re-generate if not yet attached
        unless @invoice.pdf_document.attached?
          result = Invoice::PdfRendererService.call(actor: current_user, invoice: @invoice)
          unless result.success?
            return render_errors(result.errors)
          end
        end

        render_success({ download_url: signed_pdf_url(@invoice) })
      end

      private

      # ── Finder ──────────────────────────────────────────────────────────────

      def set_invoice
        @invoice = SalesInvoice.not_deleted
                               .for_org(current_organization)
                               .find(params[:id])
      end

      # ── Params ───────────────────────────────────────────────────────────────

      def invoice_params
        params.permit(
          :branch_id, :customer_id, :sales_order_id,
          :invoice_date, :generation_source, :notes,
          delivered_lines: [
            :product_id, :qty, :sales_order_line_id,
            :unit_price, :discount_pct, :hsn_code, :gst_rate
          ]
        )
      end

      # ── Filters ──────────────────────────────────────────────────────────────

      def apply_filters(scope)
        scope = scope.by_branch(params[:branch_id])     if params[:branch_id].present?
        scope = scope.by_customer(params[:customer_id]) if params[:customer_id].present?
        scope = scope.by_status(params[:status])        if params[:status].present?
        scope = scope.in_date_range(params[:from_date], params[:to_date])
        scope = scope.search_query(params[:q].strip)    if params[:q].present?
        scope
      end

      # ── Serializers ──────────────────────────────────────────────────────────

      def serialize_invoice(inv, detailed: false)
        data = {
          id:                inv.id,
          invoice_number:    inv.invoice_number,
          invoice_date:      inv.invoice_date,
          due_date:          inv.due_date,
          status:            inv.status,
          subtotal:          inv.subtotal,
          tax_total:         inv.tax_total,
          grand_total:       inv.grand_total,
          round_off:         inv.round_off,
          currency:          inv.currency,
          notes:             inv.notes,
          generation_source: inv.generation_source,
          issued_at:         inv.issued_at,
          voided_at:         inv.voided_at,
          void_reason:       inv.void_reason,
          pdf_generated_at:  inv.pdf_generated_at,
          has_pdf:           inv.pdf_document.attached?,
          einvoice_status:   inv.einvoice_status,
          irn:               inv.irn,
          ack_number:        inv.ack_number,
          ack_datetime:      inv.ack_datetime,
          einvoice_qr_code:  inv.einvoice_qr_code,
          irn_generated_at:  inv.irn_generated_at,
          created_at:        inv.created_at,
          ewaybill_number:      (ewb = inv.association(:ewaybill_requests).loaded? ? inv.ewaybill_requests.max_by(&:created_at) : inv.ewaybill_requests.order(:created_at).last)&.ewaybill_number,
          ewaybill_status:      ewb&.status,
          ewaybill_valid_upto:  ewb&.valid_until,
          ewaybill_generated_at: ewb&.generated_at,
          customer: {
            id:    inv.customer_id,
            name:  inv.customer.name,
            code:  inv.customer.code,
            gstin: inv.customer.gstin
          },
          branch: {
            id:   inv.branch_id,
            name: inv.branch.name,
            code: inv.branch.code
          }
        }

        if inv.association(:sales_order).loaded? && inv.sales_order.present?
          data[:sales_order] = {
            id:           inv.sales_order_id,
            order_number: inv.sales_order.order_number
          }
        end

        if detailed
          data[:lines]       = serialize_lines(inv)
          data[:tax_breakup] = inv.tax_breakup
          data[:audit_trail] = inv.audit_logs.recent.map do |log|
            {
              action:     log.action,
              actor:      { id: log.actor_id, name: "#{log.actor.first_name} #{log.actor.last_name}" },
              changes:    log.changes_data,
              reason:     log.reason,
              created_at: log.created_at
            }
          end

          if inv.pdf_document.attached?
            data[:pdf_url] = signed_pdf_url(inv)
          end
        end

        data
      end

      def serialize_lines(inv)
        inv.lines.map do |l|
          {
            id:            l.id,
            product_id:    l.product_id,
            product_name:  l.product.name,
            product_sku:   l.product.sku,
            hsn_code:      l.hsn_code,
            qty:           l.qty,
            unit_price:    l.unit_price,
            discount_pct:  l.discount_pct,
            taxable_value: l.taxable_value,
            gst_rate:      l.gst_rate,
            cgst_rate:     l.cgst_rate,
            sgst_rate:     l.sgst_rate,
            igst_rate:     l.igst_rate,
            cgst_amount:   l.cgst_amount,
            sgst_amount:   l.sgst_amount,
            igst_amount:   l.igst_amount,
            tax_amount:    l.tax_amount,
            line_total:    l.line_total
          }
        end
      end

      def signed_pdf_url(inv)
        Rails.application.routes.url_helpers
             .rails_blob_url(inv.pdf_document, expires_in: 1.hour, disposition: 'inline')
      rescue
        nil
      end
    end
  end
end
