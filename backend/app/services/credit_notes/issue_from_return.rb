module CreditNotes
  # Issues a CreditNote from a QC-completed ReturnRequest.
  #
  # - Lines are built from QC resalable quantities only.
  # - Unit price is taken from the price snapshot locked at submission.
  # - GST is calculated via Gst::GstCalculator.
  # - Does NOT mutate any SalesOrder/invoice.
  # - Transitions ReturnRequest → credit_note_issued.
  #
  class IssueFromReturn
    Result = Struct.new(:success?, :credit_note, :errors)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, return_request:, notes: nil)
      @actor          = actor
      @return_request = return_request
      @notes          = notes
    end

    def call
      unless @return_request.qc_completed?
        return Result.new(false, nil, ['Credit note can only be issued after QC is completed'])
      end

      if @return_request.credit_note.present?
        return Result.new(false, @return_request.credit_note, ['Credit note already exists for this return'])
      end

      # Collect lines with resalable QC quantity
      creditable_lines = @return_request.lines.includes(:qc_item, :product, :sales_order_line).select do |l|
        l.qc_item&.qty_resalable.to_d > 0
      end

      if creditable_lines.empty?
        return Result.new(false, nil, ['No resalable items to credit'])
      end

      ActiveRecord::Base.transaction do
        cn = CreditNote.new(
          organization:   @return_request.organization,
          branch:         @return_request.branch,
          customer:       @return_request.customer,
          return_request: @return_request,
          sales_order:    resolve_sales_order,
          created_by:     @actor,
          notes:          @notes,
          status:         'draft'
        )

        creditable_lines.each do |line|
          qty        = line.qc_item.qty_resalable
          unit_price = line.unit_price_snapshot.to_d
          gst_rate   = line.gst_rate_snapshot.to_d
          taxable    = (qty * unit_price).round(2)

          # Use GST calculator for precise split (intra/inter)
          gst_result = Gst::GstCalculator.calculate(
            branch:        @return_request.branch,
            customer:      @return_request.customer,
            gst_rate:      gst_rate,
            taxable_value: taxable
          )

          cn.lines.build(
            product:     line.product,
            return_line: line,
            qty:         qty,
            unit_price:  unit_price,
            gst_rate:    gst_rate,
            tax_amount:  gst_result.total_tax,
            line_total:  (taxable + gst_result.total_tax).round(2),
            hsn_code:    line.hsn_code_snapshot
          )
        end

        cn.save!
        cn.recalculate_totals!

        # Transition credit note to issued immediately
        cn.update!(status: 'issued', issued_at: Time.current)

        # Transition return request
        @return_request.transition_to!('credit_note_issued')

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @return_request.organization,
          auditable:    cn,
          action:       'credit_note_issued',
          changes:      {
            credit_note_number: cn.credit_note_number,
            return_number:      @return_request.return_number,
            total:              cn.total
          }
        )

        Result.new(true, cn, [])
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, nil, [e.message])
    end

    private

    def resolve_sales_order
      return nil unless @return_request.source_type == 'order' && @return_request.source_id.present?

      SalesOrder.find_by(id: @return_request.source_id)
    end
  end
end
