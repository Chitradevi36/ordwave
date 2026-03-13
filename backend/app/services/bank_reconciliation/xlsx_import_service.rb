# frozen_string_literal: true

require "roo"

module BankReconciliation
  # Parses an XLSX/XLS bank statement using the Roo gem.
  # Row normalization and deduplication reuse the same RowParser +
  # NarrationNormalizer + BankTransaction.build_idempotency_key logic as
  # CsvImportService, ensuring identical downstream behavior.
  #
  # Usage:
  #   result = BankReconciliation::XlsxImportService.call(
  #     import:    bank_statement_import,
  #     blob_path: "/path/to/file.xlsx"
  #   )
  #   result.success?   # => true
  #   result.summary    # => { total:, new:, duplicates:, failed: }
  class XlsxImportService
    Result = Struct.new(:success, :summary, :errors, keyword_init: true) do
      def success? = success
    end

    def self.call(import:, blob_path:)
      new(import: import, blob_path: blob_path).call
    end

    def initialize(import:, blob_path:)
      @import    = import
      @blob_path = blob_path
      @counters  = { total: 0, new: 0, duplicates: 0, failed: 0 }
      @errors    = []
    end

    def call
      @import.start_processing!

      spreadsheet = open_spreadsheet
      if spreadsheet.nil?
        @import.mark_failed!(@errors.first)
        return failure_result
      end

      headers  = nil
      row_index = 0

      spreadsheet.each_row_streaming do |row|
        row_cells = row.map { |cell| cell&.value.to_s.strip }

        # First non-blank row becomes the header
        if headers.nil?
          headers = row_cells.map { |h| h.downcase.strip.tr(" ", "_") }
          next
        end

        row_index += 1
        next if row_cells.all?(&:empty?)

        row_hash = headers.zip(row_cells).to_h
        process_row(row_hash, row_index)
      end

      @import.mark_completed!(
        total:      @counters[:total],
        new:        @counters[:new],
        duplicates: @counters[:duplicates],
        failed:     @counters[:failed]
      )

      Result.new(success: true, summary: @counters, errors: @errors)
    rescue StandardError => e
      @import.mark_failed!(e.message)
      Result.new(success: false, summary: @counters, errors: [e.message])
    end

    private

    def open_spreadsheet
      ext = File.extname(@blob_path).downcase

      spreadsheet = if ext == ".xls"
        Roo::Excel.new(@blob_path)
      else
        Roo::Excelx.new(@blob_path)
      end

      # Use first sheet
      spreadsheet.default_sheet = spreadsheet.sheets.first
      spreadsheet
    rescue StandardError => e
      @errors << "Could not open spreadsheet: #{e.message}"
      nil
    end

    def process_row(row_hash, line_number)
      @counters[:total] += 1

      parsed = BankReconciliation::RowParser.call(row_hash, bank_account_id: @import.bank_account_id)

      if parsed.nil?
        @counters[:failed] += 1
        @errors << "Row #{line_number}: could not parse — #{row_hash.inspect.truncate(200)}"
        return
      end

      norm = BankReconciliation::NarrationNormalizer.call(parsed.narration)

      idempotency_key = BankTransaction.build_idempotency_key(
        bank_account_id: @import.bank_account_id,
        txn_date:        parsed.txn_date,
        amount:          parsed.amount,
        reference:       parsed.reference_number || parsed.utr_number,
        narration:       parsed.narration
      )

      if BankTransaction.exists?(idempotency_key: idempotency_key)
        @counters[:duplicates] += 1
        return
      end

      BankTransaction.create!(
        organization:          @import.organization,
        bank_account:          @import.bank_account,
        bank_statement_import: @import,
        txn_date:              parsed.txn_date,
        amount:                parsed.amount,
        direction:             parsed.direction,
        utr_number:            parsed.utr_number,
        reference_number:      parsed.reference_number,
        payer_name:            parsed.payer_name,
        narration:             parsed.narration,
        normalized_narration:  norm.normalized,
        raw_row_json:          row_hash,
        match_meta:            {
          tokens:          norm.tokens,
          invoice_numbers: norm.invoice_numbers,
          customer_codes:  norm.customer_codes,
          utr_candidates:  norm.utr_candidates,
          phone_fragments: norm.phone_fragments
        },
        status:          "unmatched",
        idempotency_key: idempotency_key
      )

      @counters[:new] += 1
    rescue ActiveRecord::RecordInvalid => e
      @counters[:failed] += 1
      @errors << "Row #{line_number}: #{e.message}"
    rescue StandardError => e
      @counters[:failed] += 1
      @errors << "Row #{line_number}: unexpected error — #{e.message}"
    end

    def failure_result
      Result.new(success: false, summary: @counters, errors: @errors)
    end
  end
end
