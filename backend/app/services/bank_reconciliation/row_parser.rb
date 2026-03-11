# frozen_string_literal: true

module BankReconciliation
  # Parses a single CSV row hash (keyed by column header) into a normalized
  # attributes hash suitable for BankTransaction.new.
  #
  # Supports common Indian bank CSV export column names.
  # Returns nil for rows that should be skipped (headers, totals, debit rows
  # when import is credit-only, etc.).
  class RowParser
    # Canonical column aliases keyed by intent → array of acceptable header names
    COLUMN_MAP = {
      txn_date:   %w[date value_date transaction_date txn_date posting_date],
      amount:     %w[amount credit_amount withdrawal_amount debit_amount cr_amount dr_amount],
      narration:  %w[narration description particulars remarks transaction_remarks],
      reference:  %w[reference ref_no reference_number chq_ref_number cheque_ref_number],
      utr:        %w[utr utr_number transaction_id txn_id imps_ref neft_ref],
      direction:  %w[dr_cr transaction_type txn_type type cr_dr],
      payer_name: %w[payer_name sender_name beneficiary_name name party_name],
    }.freeze

    ParsedRow = Struct.new(
      :txn_date, :amount, :direction, :utr_number, :reference_number,
      :payer_name, :narration,
      keyword_init: true
    )

    ParseError = Class.new(StandardError)

    def self.call(row_hash, bank_account_id:)
      new(row_hash, bank_account_id: bank_account_id).parse
    end

    def initialize(row_hash, bank_account_id:)
      @row       = row_hash.transform_keys { |k| k.to_s.downcase.strip.tr(" ", "_") }
      @ba_id     = bank_account_id
    end

    def parse
      date      = extract_date
      amount    = extract_amount
      direction = extract_direction

      return nil if amount.nil? || amount <= 0
      return nil if date.nil?

      ParsedRow.new(
        txn_date:         date,
        amount:           amount,
        direction:        direction,
        utr_number:       extract_field(:utr)&.strip&.upcase.presence,
        reference_number: extract_field(:reference)&.strip&.upcase.presence,
        payer_name:       extract_field(:payer_name)&.strip.presence,
        narration:        extract_field(:narration)&.strip.presence
      )
    end

    private

    def extract_field(intent)
      COLUMN_MAP[intent].each { |k| return @row[k] if @row.key?(k) }
      nil
    end

    def extract_date
      raw = extract_field(:txn_date)
      return nil unless raw.present?

      # Common Indian date formats: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD
      formats = ["%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%d %b %Y", "%d-%b-%Y"]
      formats.each do |fmt|
        return Date.strptime(raw.to_s.strip, fmt)
      rescue ArgumentError
        next
      end
      nil
    end

    def extract_amount
      # Some banks have separate credit/debit columns
      credit_cols = %w[credit_amount cr_amount]
      debit_cols  = %w[debit_amount dr_amount withdrawal_amount]

      credit_val = credit_cols.filter_map { |k| @row[k].presence }.first
      debit_val  = debit_cols.filter_map  { |k| @row[k].presence }.first

      # If dedicated credit column has a value, use it
      return parse_decimal(credit_val) if credit_val.present? && parse_decimal(credit_val)&.positive?

      # Otherwise use generic amount column
      parse_decimal(extract_field(:amount))
    end

    def extract_direction
      dir_raw = extract_field(:direction)&.upcase&.strip

      # Explicit credit/debit indicator
      return "credit" if dir_raw&.match?(/\A(CR|CREDIT|C)\z/)
      return "debit"  if dir_raw&.match?(/\A(DR|DEBIT|D)\z/)

      # Infer: if credit_amount column present and populated → credit
      credit_cols = %w[credit_amount cr_amount]
      return "credit" if credit_cols.any? { |k| @row[k].present? && parse_decimal(@row[k]).to_f.positive? }

      # Default to credit (reconciliation is primarily about incoming payments)
      "credit"
    end

    def parse_decimal(val)
      return nil if val.blank?
      # Remove commas (1,23,456.78 → 123456.78) and whitespace
      cleaned = val.to_s.gsub(/[,\s]/, "")
      BigDecimal(cleaned)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
