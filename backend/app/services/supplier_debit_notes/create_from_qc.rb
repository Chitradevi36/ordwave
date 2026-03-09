# frozen_string_literal: true

module SupplierDebitNotes
  # Creates a SupplierDebitNote from QC results for items marked return-to-supplier.
  #
  # Scans the ReturnRequest's QC items for qty_return_to_supplier > 0,
  # groups by supplier (via product's supplier association), and produces
  # one debit note per supplier.
  #
  # Usage:
  #   result = SupplierDebitNotes::CreateFromQc.call(
  #     actor:          current_user,
  #     return_request: rr
  #   )
  #   result.debit_notes  # => [SupplierDebitNote, ...]
  #
  class CreateFromQc
    Result = Struct.new(:success?, :debit_notes, :errors)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, return_request:)
      @actor          = actor
      @return_request = return_request
    end

    def call
      unless @return_request.status.in?(%w[qc_completed processing])
        return Result.new(false, [], ['Return must be in qc_completed or processing status'])
      end

      supplier_lines = collect_return_to_supplier_lines
      if supplier_lines.empty?
        return Result.new(false, [], ['No lines marked for return-to-supplier'])
      end

      debit_notes = []
      errors      = []

      ActiveRecord::Base.transaction do
        supplier_lines.each do |supplier, lines|
          sdn = SupplierDebitNote.create!(
            organization:   @return_request.organization,
            branch:         @return_request.branch,
            supplier:       supplier,
            return_request: @return_request,
            date:           Date.current,
            status:         'draft',
            reason:         derive_reason(lines),
            created_by:     @actor
          )

          lines.each do |line_data|
            line        = line_data[:return_line]
            qc_item     = line_data[:qc_item]
            product     = line.product
            qty         = qc_item.qty_return_to_supplier.to_d
            unit_price  = line.unit_price_snapshot.to_d
            gst_rate    = product.try(:gst_rate).to_d
            hsn         = product.try(:hsn_code) || product.try(:hsn_sac_code)&.code

            sdn.lines.create!(
              product:       product,
              return_line:   line,
              qty:           qty,
              unit_price:    unit_price,
              gst_rate:      gst_rate,
              hsn_code:      hsn.to_s,
              batch_number:  line.try(:batch_number),
              expiry_date:   line.try(:expiry_date)
            )
          end

          sdn.recalculate_totals!
          debit_notes << sdn
        end

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @return_request.organization,
          auditable:    @return_request,
          action:       'supplier_debit_notes_created',
          changes:      {
            debit_note_count: debit_notes.size,
            debit_note_ids:   debit_notes.map(&:id)
          }
        )
      end

      Result.new(true, debit_notes, [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, [], [e.message])
    end

    private

    # Collects QC items with qty_return_to_supplier > 0, grouped by supplier.
    def collect_return_to_supplier_lines
      grouped = Hash.new { |h, k| h[k] = [] }

      @return_request.lines.includes(:qc_item, product: :supplier).find_each do |line|
        qc_item = line.qc_item
        next unless qc_item
        next unless qc_item.respond_to?(:qty_return_to_supplier)
        next unless qc_item.qty_return_to_supplier.to_d.positive?

        supplier = line.product.try(:supplier)
        next unless supplier

        grouped[supplier] << { return_line: line, qc_item: qc_item }
      end

      grouped
    end

    def derive_reason(lines)
      reasons = lines.map { |ld| ld[:qc_item].try(:supplier_return_reason) }.compact.uniq
      return reasons.first if reasons.size == 1

      # If mixed reasons or no reason recorded, pick most common or default
      return 'quality_issue' if reasons.empty?

      reasons.tally.max_by { |_, count| count }.first
    end
  end
end
