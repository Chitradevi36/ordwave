# frozen_string_literal: true

module BankReconciliation
  # Phase 1 PDF parser: extracts text from PDF using PDF::Reader,
  # then detects tabular bank statement rows via heuristic line analysis.
  #
  # Design philosophy:
  #   - Attempt text extraction first. Do NOT use OCR in Phase 1.
  #   - If text quality is poor (<= MIN_PARSED_ROWS for the page count),
  #     mark the import as failed with a clear human-readable message.
  #   - The heuristic looks for lines containing a date pattern AND a numeric
  #     amount, treating those as potential transaction rows.
  #
  # Usage:
  #   result = BankReconciliation::PdfImportService.call(
  #     import:    bank_statement_import,
  #     blob_path: "/path/to/statement.pdf"
  #   )
  class PdfImportService
    require "pdf-reader"

    # Matches lines like: "12/03/2026  INV/001  UPI/CR/NAME  10,500.00  CR"
    DATE_PATTERN       = /\b\d{2}[\/\-]\d{2}[\/\-]\d{4}\b|\b\d{4}-\d{2}-\d{2}\b/.freeze
    AMOUNT_IN_LINE     = /[\d,]+\.\d{2}/.freeze
    MIN_PARSED_ROWS    = 1   # If we can't find at least 1 parseable row, mark failed

    Result = Struct.new(:success, :summary, :errors, keyword_init: true) do
      def success? = success
    end

    def self.call(import:, blob_path:)
      new(import: import, blob_path: blob_path).call
    end

    def initialize(import:, blob_path:)
      @import   = import
      @blob_path = blob_path
      @counters  = { total: 0, new: 0, duplicates: 0, failed: 0 }
      @errors    = []
    end

    def call
      @import.start_processing!

      lines = extract_text_lines
      if lines.nil?
        @import.mark_failed!(@errors.first)
        return failure_result
      end

      candidate_rows = detect_transaction_lines(lines)

      if candidate_rows.empty?
        msg = "PDF text extraction found no parseable transaction rows. " \
              "Please convert the PDF to CSV/XLSX and re-upload. " \
              "Scanned/image PDFs are not supported in Phase 1."
        @import.mark_failed!(msg)
        return failure_result
      end

      candidate_rows.each_with_index do |row_hash, idx|
        process_row(row_hash, idx + 1)
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

    def extract_text_lines
      reader = PDF::Reader.new(@blob_path)
      lines  = reader.pages.flat_map do |page|
        page.text.to_s.split("\n").map(&:strip).reject(&:empty?)
      end
      lines
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::EncryptedPDFError => e
      @errors << "PDF could not be read: #{e.message}"
      nil
    rescue StandardError => e
      @errors << "Unexpected error reading PDF: #{e.message}"
      nil
    end

    # Convert raw text lines into row hashes the RowParser understands.
    # Heuristic: a line qualifies if it has a date-like pattern AND an amount-like value.
    def detect_transaction_lines(lines)
      rows = []

      lines.each do |line|
        next unless line.match?(DATE_PATTERN) && line.match?(AMOUNT_IN_LINE)

        # Attempt to tokenize the line into fields using common column order:
        # Date | Description/Narration | Debit | Credit | Balance | Ref
        parts = line.split(/\s{2,}|\t/)
        next if parts.size < 3

        date_str      = parts.find { |p| p.match?(DATE_PATTERN) } || parts[0]
        amount_tokens = parts.select { |p| p.match?(/\A[\d,]+\.\d{2}\z/) }
        narration     = parts.reject { |p| p.match?(DATE_PATTERN) || p.match?(/\A[\d,]+\.\d{2}\z/) || p.match?(/\ACR|DR\z/i) }.join(" ").strip

        # Detect CR / DR suffix
        direction = if line.match?(/\bCR\b/i) then "credit"
                    elsif line.match?(/\bDR\b/i) then "debit"
                    else "credit"   # default assumption for bank statement credits
                    end

        rows << {
          "date"      => date_str,
          "amount"    => amount_tokens.first.to_s.gsub(",", ""),
          "narration" => narration.presence || line.truncate(200),
          "dr_cr"     => direction.upcase[0..1]   # "CR" or "DR"
        }
      end

      rows
    end

    def process_row(row_hash, line_number)
      @counters[:total] += 1

      parsed = BankReconciliation::RowParser.call(row_hash, bank_account_id: @import.bank_account_id)

      if parsed.nil?
        @counters[:failed] += 1
        @errors << "PDF row #{line_number}: could not parse row"
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
          phone_fragments: norm.phone_fragments,
          source:          "pdf_text_extraction"
        },
        status:          "unmatched",
        idempotency_key: idempotency_key
      )

      @counters[:new] += 1
    rescue ActiveRecord::RecordInvalid => e
      @counters[:failed] += 1
      @errors << "PDF row #{line_number}: #{e.message}"
    rescue StandardError => e
      @counters[:failed] += 1
      @errors << "PDF row #{line_number}: unexpected error — #{e.message}"
    end

    def failure_result
      Result.new(success: false, summary: @counters, errors: @errors)
    end
  end
end
