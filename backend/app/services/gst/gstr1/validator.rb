# frozen_string_literal: true

module Gst
  module Gstr1
    # Validates invoices and credit notes before building the GSTR-1 return.
    #
    # Returns a ValidationResult with arrays of hard errors and soft warnings.
    # A ValidationResult is considered `valid?` only when there are no errors.
    #
    # Usage:
    #   result = Gst::Gstr1::Validator.call(
    #     gstin:        org.gst_number,
    #     invoices:     invoice_array,
    #     credit_notes: credit_note_array
    #   )
    #   result.valid?    # => true / false
    #   result.errors    # => [{code:, message:, invoice_number:}, ...]
    #   result.warnings  # => [{code:, message:, invoice_number:}, ...]
    #
    class Validator
      GSTIN_REGEX = /\A\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}Z[A-Z\d]{1}\z/i

      ValidationResult = Struct.new(
        :errors,
        :warnings,
        keyword_init: true
      ) do
        def valid?          = errors.empty?
        def error_count     = errors.size
        def warning_count   = warnings.size
      end

      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(gstin:, invoices:, credit_notes:)
        @gstin        = gstin
        @invoices     = invoices
        @credit_notes = credit_notes
        @errors       = []
        @warnings     = []
      end

      def call
        validate_seller_gstin
        validate_invoices
        validate_credit_notes

        ValidationResult.new(errors: @errors.freeze, warnings: @warnings.freeze)
      end

      private

      # ── Seller validation ──────────────────────────────────────────────────

      def validate_seller_gstin
        if @gstin.blank?
          @errors << { code: 'MISSING_SELLER_GSTIN',
                       message: 'Organisation GSTIN is missing. GSTR-1 cannot be filed.' }
        elsif !GSTIN_REGEX.match?(@gstin.to_s.upcase)
          @errors << { code: 'INVALID_SELLER_GSTIN',
                       message: "Organisation GSTIN '#{@gstin}' has an invalid format." }
        end
      end

      # ── Invoice validation ─────────────────────────────────────────────────

      def validate_invoices
        @invoices.each { |inv| validate_invoice(inv) }
      end

      def validate_invoice(inv)
        ref = inv.invoice_number.presence || "(id #{inv.id})"

        if inv.customer.nil?
          @errors << error(ref, 'MISSING_CUSTOMER', 'Invoice has no customer attached.')
          return
        end

        # B2B invoices must have a valid buyer GSTIN
        if inv.customer.gstin.present? && !GSTIN_REGEX.match?(inv.customer.gstin.to_s.upcase)
          @errors << error(ref, 'INVALID_BUYER_GSTIN',
                           "Customer GSTIN '#{inv.customer.gstin}' is invalid.")
        end

        # Invoice date must be present
        if inv.invoice_date.blank?
          @errors << error(ref, 'MISSING_INVOICE_DATE', 'Invoice date is missing.')
        end

        # Grand total must be positive
        if inv.grand_total.to_d <= 0
          @errors << error(ref, 'ZERO_VALUE_INVOICE', 'Invoice grand total is zero or negative.')
        end

        # Place of supply must be determinable
        pos = derive_pos(inv)
        if pos == '00'
          @warnings << warning(ref, 'UNKNOWN_POS',
                                'Unable to determine place of supply. Defaulting to 00.')
        end

        # HSN codes — warn on missing (portal requires them for B2B above threshold)
        inv.lines.each do |line|
          if line.hsn_code.blank? && line.product&.hsn_code.blank?
            @warnings << warning(ref, 'MISSING_HSN_CODE',
                                  "Line item for '#{line.product&.name}' has no HSN/SAC code.")
          end
        end

        # Warn if status is not a "finalized" status
        unless inv.status.in?(%w[issued partially_paid paid])
          @warnings << warning(ref, 'NON_FINALIZED_STATUS',
                                "Invoice has status '#{inv.status}'. Expected issued/paid.")
        end
      end

      # ── Credit note validation ─────────────────────────────────────────────

      def validate_credit_notes
        @credit_notes.each { |cn| validate_credit_note(cn) }
      end

      def validate_credit_note(cn)
        ref = cn.credit_note_number.presence || "(id #{cn.id})"

        if cn.customer.nil?
          @errors << error(ref, 'MISSING_CUSTOMER', 'Credit note has no customer attached.')
          return
        end

        if cn.issued_at.blank?
          @errors << error(ref, 'MISSING_ISSUE_DATE', 'Credit note issue date is missing.')
        end

        if cn.total.to_d <= 0
          @warnings << warning(ref, 'ZERO_VALUE_CREDIT_NOTE',
                                'Credit note total is zero or negative.')
        end

        cn.lines.each do |line|
          if line.hsn_code.blank? && line.product&.hsn_code.blank?
            @warnings << warning(ref, 'MISSING_HSN_CODE',
                                  "Credit note line for '#{line.product&.name}' has no HSN code.")
          end
        end
      end

      # ── Helpers ───────────────────────────────────────────────────────────

      def derive_pos(inv)
        customer = inv.customer
        if customer.gstin.present?
          customer.gstin[0..1]
        elsif customer.respond_to?(:addresses)
          billing = customer.addresses.find { |a| a.label == 'billing' } ||
                    customer.addresses.first
          Gst::Gstr1::SectionClassifier::STATE_CODE_MAP[billing&.state.to_s.downcase.strip] || '00'
        else
          inv.branch&.state_code.presence || '00'
        end
      end

      def error(ref, code, message)
        { document_number: ref, code: code, message: message }
      end

      def warning(ref, code, message)
        { document_number: ref, code: code, message: message }
      end
    end
  end
end
