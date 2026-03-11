# frozen_string_literal: true

module BankReconciliation
  # Normalizes raw bank narration strings into a canonical form and extracts
  # structured signals for the matching engine.
  #
  # Usage:
  #   result = BankReconciliation::NarrationNormalizer.call("UPI/CR/RAJU STORES/UTR938383")
  #   result.normalized         # => "UPI CR RAJU STORES UTR938383"
  #   result.invoice_numbers    # => []
  #   result.customer_codes     # => []
  #   result.utr_candidates     # => ["UTR938383"]
  #   result.phone_fragments    # => []
  #   result.tokens             # => ["UPI", "CR", "RAJU", "STORES", "UTR938383"]
  class NarrationNormalizer
    Result = Struct.new(
      :normalized,       # String: cleaned, uppercased, collapsed narration
      :tokens,           # Array<String>: individual words
      :invoice_numbers,  # Array<String>: likely invoice number patterns
      :customer_codes,   # Array<String>: likely retailer/customer codes (RT001 etc.)
      :utr_candidates,   # Array<String>: UTR / IMPS ref / NEFT ref patterns
      :phone_fragments,  # Array<String>: 10-digit phone-like numbers found
      keyword_init: true
    )

    # Common Indian bank narration prefixes to strip for cleaner matching
    NOISE_PREFIXES = %w[UPI NEFT RTGS IMPS CMS INB CR DR VPA].freeze

    # Patterns for extracting structured signals
    INVOICE_PATTERN  = /\b(SI|INV|SINV|SIN|SO|BILL)[\/\-]?[A-Z0-9]{2,15}[\/\-][0-9]{2,8}\b/i
    CUSTOMER_CODE_PATTERN = /\b(RT|CUST|C)[0-9]{3,8}\b/i
    UTR_PATTERN      = /\b([A-Z0-9]{12,22})\b/
    PHONE_PATTERN    = /\b[6-9][0-9]{9}\b/

    def self.call(raw_narration)
      new(raw_narration).normalize
    end

    def initialize(raw_narration)
      @raw = raw_narration.to_s
    end

    def normalize
      text = @raw.dup

      # 1. Uppercase
      text = text.upcase

      # 2. Strip punctuation noise (keep alphanumeric, slash, space, hyphen)
      text = text.gsub(/[^A-Z0-9\/\- ]/, " ")

      # 3. Collapse whitespace
      text = text.gsub(/\s+/, " ").strip

      normalized    = text
      tokens        = text.split(" ").uniq

      invoice_numbers = @raw.scan(INVOICE_PATTERN).map { |m| m.join("") }.map(&:upcase).uniq
      customer_codes  = @raw.scan(CUSTOMER_CODE_PATTERN).map { |m| m.join("") }.map(&:upcase).uniq
      utr_candidates  = extract_utrs(text)
      phone_fragments = @raw.scan(PHONE_PATTERN).flatten.uniq

      Result.new(
        normalized:      normalized,
        tokens:          tokens,
        invoice_numbers: invoice_numbers,
        customer_codes:  customer_codes,
        utr_candidates:  utr_candidates,
        phone_fragments: phone_fragments
      )
    end

    private

    def extract_utrs(text)
      candidates = []

      # UTR format: 22 alphanum chars (strict NEFT/RTGS UTR)
      candidates += text.scan(/\b([A-Z]{4}[0-9]{18})\b/).flatten

      # Looser: alphanumeric 12–22 chars that are NOT common words
      text.scan(UTR_PATTERN).flatten.each do |token|
        next if NOISE_PREFIXES.include?(token)
        next if token.length < 10
        candidates << token
      end

      candidates.uniq
    end
  end
end
