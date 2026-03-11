# frozen_string_literal: true

require "csv"

module BankReconciliation
  # Orchestrates the full CSV import flow:
  #   1. Parse CSV into rows
  #   2. Validate headers
  #   3. Normalise each row
  #   4. Deduplicate using idempotency key
  #   5. Persist BankTransaction records
  #   6. Update BankStatementImport counters
  #
  # Usage:
  #   result = BankReconciliation::CsvImportService.call(
  #     import:   bank_statement_import,
  #     csv_data: file.read,
  #     current_user: user
  #   )
  #   result.success?   # => true
  #   result.summary    # => { total: 50, new: 45, duplicates: 4, failed: 1 }
  class CsvImportService
    REQUIRED_COLUMNS = %w[date amount narration].freeze

    Result = Struct.new(:success, :summary, :errors, keyword_init: true) do
      def success? = success
    end

    def self.call(import:, csv_data:, current_user: nil)
      new(import: import, csv_data: csv_data, current_user: current_user).call
    end

    def initialize(import:, csv_data:, current_user: nil)
      @import       = import
      @csv_data     = csv_data
      @current_user = current_user
      @counters     = { total: 0, new: 0, duplicates: 0, failed: 0 }
      @errors       = []
    end

    def call
      @import.start_processing!

      rows = parse_csv
      if rows.nil?
        @import.mark_failed!(@errors.first)
        return failure_result
      end

      validate_headers!(rows.first&.headers || [])
      rows.each_with_index { |row, idx| process_row(row, idx + 2) }  # +2: 1 header + 1-indexed

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

    def parse_csv
      CSV.parse(@csv_data, headers: true, skip_blanks: true)
    rescue CSV::MalformedCSVError => e
      @errors << "CSV parse error: #{e.message}"
      nil
    end

    def validate_headers!(headers)
      normalised = headers.map { |h| h.to_s.downcase.strip.tr(" ", "_") }
      missing = REQUIRED_COLUMNS.reject do |req|
        normalised.any? { |h| h.include?(req) }
      end
      raise ArgumentError, "Missing required columns: #{missing.join(', ')}" if missing.any?
    end

    def process_row(row, line_number)
      @counters[:total] += 1
      row_hash = row.to_h

      parsed = BankReconciliation::RowParser.call(row_hash, bank_account_id: @import.bank_account_id)

      if parsed.nil?
        @counters[:failed] += 1
        @errors << "Line #{line_number}: could not parse row — #{row_hash.inspect}"
        return
      end

      # Normalize narration
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
        status:                "unmatched",
        idempotency_key:       idempotency_key
      )

      @counters[:new] += 1
    rescue ActiveRecord::RecordInvalid => e
      @counters[:failed] += 1
      @errors << "Line #{line_number}: #{e.message}"
    rescue StandardError => e
      @counters[:failed] += 1
      @errors << "Line #{line_number}: unexpected error — #{e.message}"
    end

    def failure_result
      Result.new(success: false, summary: @counters, errors: @errors)
    end
  end
end
