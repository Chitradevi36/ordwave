module PurchaseInvoices
  class UpdateService
    Result = Struct.new(:success?, :invoice, :errors)

    def initialize(invoice:, params:, actor:)
      @invoice = invoice
      @params  = params.is_a?(ActionController::Parameters) ? params.to_h.deep_symbolize_keys : params
      @actor   = actor
    end

    def call
      unless @invoice.editable?
        return Result.new(false, @invoice,
                          ["Cannot edit a #{@invoice.status} invoice"])
      end

      ActiveRecord::Base.transaction do
        update_lines
        @invoice.assign_attributes(invoice_attrs)

        if @invoice.save
          @invoice.recalculate_totals!
          Credit::AuditLogger.log(
            actor:        @actor,
            organization: @invoice.organization,
            auditable:    @invoice.supplier,
            action:       'purchase_invoice_updated',
            changes:      @invoice.previous_changes.except('updated_at')
          )
          Result.new(true, @invoice, [])
        else
          raise ActiveRecord::Rollback
        end
      end || Result.new(false, @invoice, @invoice.errors.full_messages)
    end

    private

    def invoice_attrs
      @params.slice(:supplier_id, :invoice_number, :invoice_date, :due_date,
                    :currency, :notes)
    end

    def update_lines
      existing_ids = @invoice.lines.pluck(:id)

      (@params[:lines] || []).each do |line_attrs|
        id = line_attrs[:id]
        if id.present? && existing_ids.include?(id.to_i)
          line = @invoice.lines.find(id)
          line.assign_attributes(line_attrs.except(:id))
          line.save!
        elsif line_attrs[:_destroy].present?
          # handled by accepts_nested_attributes_for if we use that approach;
          # but we manage manually for clarity
          @invoice.lines.find(id)&.destroy! if id.present?
        else
          @invoice.lines.build(line_attrs.slice(
            :product_id, :qty, :unit_price, :discount_pct,
            :tax_rate, :hsn_sac_code_id, :notes
          ))
        end
      end
    end
  end
end
