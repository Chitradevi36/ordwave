module Invoice
  # Generates a SalesInvoice from delivered quantities.
  #
  # Supports three generation modes:
  #   auto_on_delivery   — triggered by delivery stop completion
  #   manual_from_order  — triggered by accounts team from the order detail page
  #   manual_direct      — ad-hoc without an order (wholesale walk-in, etc.)
  #
  # Key guarantees:
  #   - Unit price / discount / HSN / GST rate are FROZEN as snapshots on each line.
  #   - Subsequent changes to product masters or price lists do NOT affect history.
  #   - CGST/SGST (intra-state) vs IGST (inter-state) split is computed and stored per line.
  #   - Partial delivery → partial invoice; remaining delivered_qty can be invoiced later.
  #   - Idempotency: auto generation with the same stop + retailer pair is rejected.
  #   - `sales_order_lines.invoiced_qty` is incremented to prevent double-invoicing.
  #
  # Usage:
  #   result = Invoice::GenerateFromDeliveryService.call(
  #     actor:              current_user,
  #     branch:             branch,
  #     customer:           customer,
  #     sales_order:        order,          # optional
  #     trip_stop:          stop,           # optional; used for auto mode
  #     invoice_date:       Date.today,
  #     generation_source:  'auto_on_delivery',
  #     delivered_lines: [
  #       {
  #         product_id:             1,
  #         qty:                    10,
  #         sales_order_line_id:    5,    # optional
  #         unit_price:             nil,  # nil → resolve from order line snapshot
  #         discount_pct:           nil,  # nil → resolve from order line snapshot
  #         hsn_code:               nil,  # nil → resolve from product
  #         gst_rate:               nil,  # nil → resolve from order line or product
  #       },
  #       ...
  #     ]
  #   )
  #
  #   result.success?     # => true / false
  #   result.invoice      # => SalesInvoice
  #   result.errors       # => ['...']
  #
  class GenerateFromDeliveryService
    Result = Struct.new(:success?, :invoice, :errors, keyword_init: true)

    GENERATION_SOURCES = %w[auto_on_delivery manual_from_order manual_direct].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, branch:, customer:, delivered_lines:,
                   sales_order: nil, trip_stop: nil, invoice_date: nil,
                   generation_source: 'manual_direct', notes: nil)
      @actor             = actor
      @branch            = branch
      @customer          = customer
      @sales_order       = sales_order
      @trip_stop         = trip_stop
      @delivered_lines   = Array(delivered_lines)
      @invoice_date      = (invoice_date || Date.current).to_date
      @generation_source = generation_source.to_s
      @notes             = notes
    end

    def call
      errors = validate
      return Result.new(success?: false, invoice: nil, errors: errors) if errors.any?

      ActiveRecord::Base.transaction do
        invoice = build_invoice
        build_lines(invoice)
        invoice.save!
        invoice.recalculate_totals!
        mark_invoiced_qtys!(invoice)
        write_audit!(invoice)

        Result.new(success?: true, invoice: invoice.reload, errors: [])
      end.tap do |result|
        if result.success?
          # Enqueue email notification asynchronously
          SendInvoiceEmailJob.perform_later(result.invoice.id)
          
          # Enqueue SMS notification asynchronously (if enabled)
          SendInvoiceSmsJob.perform_later(result.invoice.id) if FEATURES.invoice_sms_notifications_enabled?(@branch.organization)
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, invoice: nil, errors: [e.message])
    end

    private

    # ── Validation ──────────────────────────────────────────────────────────

    def validate
      errs = []

      errs << 'Branch is required'   if @branch.blank?
      errs << 'Customer is required' if @customer.blank?
      errs << 'Delivered lines cannot be empty' if @delivered_lines.empty?

      unless GENERATION_SOURCES.include?(@generation_source)
        errs << "Invalid generation_source '#{@generation_source}'"
      end

      @delivered_lines.each_with_index do |dl, i|
        errs << "Line #{i + 1}: product_id is required" if dl[:product_id].blank?
        qty = dl[:qty].to_d
        errs << "Line #{i + 1}: qty must be > 0"        if qty <= 0
      end

      # Idempotency guard for auto delivery trigger
      if @generation_source == 'auto_on_delivery' && @trip_stop.present?
        existing = SalesInvoice.not_deleted.where(
          "metadata->>'source_trip_stop_id' = ?",
          @trip_stop.id.to_s
        ).where(customer: @customer).exists?

        errs << "Invoice already auto-generated for this delivery stop" if existing
      end

      # Feature 9: Warn if creating invoice for dunning-suspended customer
      # Allow creation but flag for manual review
      if @customer&.dunning_suspended_at.present?
        log_suspended_customer_invoice
      end

      errs
    end

    # ── Invoice header ───────────────────────────────────────────────────────

    def build_invoice
      org        = @branch.organization
      number     = SalesInvoice.generate_invoice_number(organization: org, branch: @branch)
      due_date   = compute_due_date

      invoice = SalesInvoice.new(
        organization:      org,
        branch:            @branch,
        customer:          @customer,
        sales_order:       @sales_order,
        created_by:        @actor,
        invoice_number:    number,
        invoice_date:      @invoice_date,
        due_date:          due_date,
        status:            'issued',
        issued_at:         Time.current,
        currency:          org.currency || 'INR',
        generation_source: @generation_source,
        notes:             @notes,
        metadata: {
          source_trip_stop_id: @trip_stop&.id,
          sales_order_id:      @sales_order&.id,
          generated_by:        @actor.id
        }
      )
      invoice
    end

    def compute_due_date
      credit_days = @customer.credit_days.to_i
      credit_days > 0 ? @invoice_date + credit_days.days : nil
    end

    # ── Line building ────────────────────────────────────────────────────────

    def build_lines(invoice)
      @delivered_lines.each do |dl|
        product = Product.find(dl[:product_id])
        qty     = dl[:qty].to_d

        # Resolve price snapshot (order line preferred, then runtime)
        sol = resolve_order_line(dl)

        unit_price   = dl[:unit_price].present?   ? dl[:unit_price].to_d   : (sol&.unit_price.to_d   || 0)
        discount_pct = dl[:discount_pct].present? ? dl[:discount_pct].to_d : (sol&.discount_pct.to_d || 0)

        # Resolve HSN/GST snapshot
        hsn_code = dl[:hsn_code].presence || sol&.hsn_code.presence || product.hsn_code.presence
        gst_rate = dl[:gst_rate].present? ? dl[:gst_rate].to_d : (sol&.gst_rate.to_d || product_gst_rate(product))

        # Compute taxable base
        base_price   = (qty * unit_price).round(2)
        taxable_value = (base_price * (1 - discount_pct / 100)).round(2)

        # Split GST
        gst_result = Gst::GstCalculator.calculate(
          branch:        @branch,
          customer:      @customer,
          gst_rate:      gst_rate,
          taxable_value: taxable_value
        )

        invoice.lines.build(
          product:                   product,
          qty:                       qty,
          unit_price:                unit_price,
          discount_pct:              discount_pct,
          taxable_value:             taxable_value,
          hsn_code:                  hsn_code,
          gst_rate:                  gst_rate,
          cgst_rate:                 gst_result.cgst_rate,
          sgst_rate:                 gst_result.sgst_rate,
          igst_rate:                 gst_result.igst_rate,
          cgst_amount:               gst_result.cgst_amount,
          sgst_amount:               gst_result.sgst_amount,
          igst_amount:               gst_result.igst_amount,
          tax_amount:                gst_result.total_tax,
          line_total:                (taxable_value + gst_result.total_tax).round(2),
          source_sales_order_line_id: sol&.id,
          source_trip_stop_id:        @trip_stop&.id,
          metadata: {
            price_source: sol&.price_source,
            order_line_id: sol&.id
          }
        )
      end
    end

    def resolve_order_line(dl)
      return nil unless dl[:sales_order_line_id].present? || @sales_order.present?

      if dl[:sales_order_line_id].present?
        SalesOrderLine.find_by(id: dl[:sales_order_line_id])
      elsif @sales_order.present? && dl[:product_id].present?
        @sales_order.lines.find_by(product_id: dl[:product_id])
      end
    end

    def product_gst_rate(product)
      # Fall back to 0 if product has no HSN linked; prevents nil GST
      product.respond_to?(:gst_rate) ? product.gst_rate.to_d : BigDecimal('0')
    end

    # ── Post-save: stamp invoiced_qty on order lines ─────────────────────────

    def mark_invoiced_qtys!(invoice)
      invoice.lines.each do |inv_line|
        next unless inv_line.source_sales_order_line_id.present?

        sol = SalesOrderLine.find_by(id: inv_line.source_sales_order_line_id)
        next unless sol

        already_invoiced = sol.invoiced_qty.to_d
        max_invoiceable  = sol.delivered_qty.to_d - already_invoiced

        if inv_line.qty.to_d > max_invoiceable && max_invoiceable > 0
          # Cap to what's available (defensive)
          inv_line.update_column(:qty, max_invoiceable)
        end

        sol.update_column(:invoiced_qty, already_invoiced + inv_line.qty.to_d)
      end
    end

    def write_audit!(invoice)
      Credit::AuditLogger.log(
        actor:        @actor,
        organization: invoice.organization,
        auditable:    invoice,
        action:       'invoice_created',
        changes: {
          invoice_number:    invoice.invoice_number,
          grand_total:       invoice.grand_total,
          generation_source: invoice.generation_source,
          customer_id:       invoice.customer_id,
          sales_order_id:    invoice.sales_order_id
        }
      )

      Credit::AuditLogger.log(
        actor:        @actor,
        organization: invoice.organization,
        auditable:    invoice,
        action:       'invoice_issued',
        changes: { issued_at: invoice.issued_at }
      )

      WebhookEvents.fire(
        organization: invoice.organization,
        event:        'invoice.generated',
        payload:      WebhookEvents.invoice_payload(invoice)
      )
    end

    def log_suspended_customer_invoice
      # Feature 9: Notify finance that invoice is being created for suspended account
      Credit::AuditLogger.log(
        actor:        @actor,
        organization: @branch.organization,
        auditable:    @customer,
        action:       'invoice_generated_for_suspended_customer',
        changes: {
          customer_id:               @customer.id,
          suspended_since:           @customer.dunning_suspended_at,
          suspension_reason:         @customer.dunning_suspension_reason,
          suspension_invoice_id:     @customer.dunning_suspension_invoice_id,
          generation_source:         @generation_source,
          manual_review_recommended: true
        }
      )

      # Create notification for finance team
      finance_users = User.joins(:memberships)
                          .where(memberships: {
                            organization_id: @branch.organization_id,
                            deleted_at:      nil,
                            active:          true
                          })
                          .joins(memberships: :role)
                          .where(roles: { name: %w[finance admin] })
                          .distinct

      Notifications::CreateService.call(
        organization: @branch.organization,
        recipients:   finance_users,
        actor:        @actor,
        notifiable:   @customer,
        type:         'invoice_generated_for_suspended_customer',
        title:        "Invoice generated for suspended account",
        body:         "An invoice is being created for #{@customer.name} (suspended since #{@customer.dunning_suspended_at.to_date}). " \
                      "Review income recognition and dunning status.",
        deep_link:    "/customers/#{@customer.id}/invoices",
        severity:     'medium'
      )
    rescue StandardError => e
      Rails.logger.warn("[GenerateFromDeliveryService] Suspended customer notification failed: #{e.message}")
    end
  end
end
