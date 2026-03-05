module PurchaseInvoices
  class CreateService
    Result = Struct.new(:success?, :invoice, :errors)

    def initialize(params:, organization:, branch:, actor:)
      @params       = params.is_a?(ActionController::Parameters) ? params.to_h.deep_symbolize_keys : params
      @organization = organization
      @branch       = branch
      @actor        = actor
    end

    def call
      invoice = PurchaseInvoice.new(
        organization: @organization,
        branch:       @branch,
        created_by:   @actor,
        **invoice_attrs
      )

      build_lines(invoice)

      ActiveRecord::Base.transaction do
        if invoice.save
          invoice.recalculate_totals!
          Credit::AuditLogger.log(
            actor:        @actor,
            organization: @organization,
            auditable:    invoice.supplier,
            action:       'purchase_invoice_created',
            changes:      {
              invoice_number: invoice.invoice_number,
              invoice_date:   invoice.invoice_date,
              grand_total:    invoice.grand_total
            }
          )
          Result.new(true, invoice, [])
        else
          raise ActiveRecord::Rollback
          Result.new(false, nil, invoice.errors.full_messages)
        end
      end || Result.new(false, nil, invoice.errors.full_messages)
    end

    private

    def invoice_attrs
      @params.slice(:supplier_id, :invoice_number, :invoice_date, :due_date,
                    :currency, :notes)
    end

    def build_lines(invoice)
      (@params[:lines] || []).each do |line_attrs|
        invoice.lines.build(line_attrs.slice(
          :product_id, :qty, :unit_price, :discount_pct,
          :tax_rate, :hsn_sac_code_id, :notes
        ))
      end
    end
  end
end
