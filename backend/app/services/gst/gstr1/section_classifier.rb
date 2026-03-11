# frozen_string_literal: true

module Gst
  module Gstr1
    # Classifies each invoice / credit-note into the appropriate GSTR-1 section.
    #
    # Invoice sections:
    #   :b2b       — to a registered dealer (customer GSTIN present)
    #   :b2cl      — to an unregistered buyer, inter-state, invoice > ₹2,50,000
    #   :b2cs      — to an unregistered buyer (intra-state OR inter-state ≤ ₹2,50,000)
    #   :nil_exempt — nil-rated / exempt supply to an unregistered buyer (all lines gst_rate=0)
    #   :exp       — export invoice (not yet supported; kept as enum value for future)
    #
    # Credit-note sections:
    #   :cdnr      — credit note against a registered dealer (GSTIN present)
    #   :cdnur     — credit note against an unregistered buyer (taxable)
    #   :nil_exempt — credit note against unregistered buyer, nil-rated / exempt
    #
    # Usage:
    #   section = Gst::Gstr1::SectionClassifier.invoice_section(invoice, seller_state_code: '27')
    #   section = Gst::Gstr1::SectionClassifier.credit_note_section(credit_note)
    #
    class SectionClassifier
      B2C_LARGE_THRESHOLD = BigDecimal('250000')

      # Classify a single sales invoice.
      # @param invoice [SalesInvoice]
      # @param seller_state_code [String] 2-digit state code of the billing branch
      # @return [Symbol] one of :b2b, :b2cl, :b2cs, :nil_exempt, :exp
      def self.invoice_section(invoice, seller_state_code:)
        customer = invoice.customer
        return :b2b if customer&.gstin.present?

        # Unregistered customer — check if nil-rated / exempt (all lines gst_rate == 0)
        return :nil_exempt if nil_rated_invoice?(invoice)

        # Unregistered + taxable — determine inter/intra state for B2CL vs B2CS
        pos      = place_of_supply_code(invoice)
        is_inter = seller_state_code.to_s.strip != pos.to_s.strip

        if is_inter && invoice.grand_total.to_d >= B2C_LARGE_THRESHOLD
          :b2cl
        else
          :b2cs
        end
      end

      # Classify a single credit note.
      # @param credit_note [CreditNote]
      # @return [Symbol] :cdnr, :cdnur, or :nil_exempt
      def self.credit_note_section(credit_note)
        return :cdnr if credit_note.customer&.gstin.present?
        # Unregistered customer: nil-rated credit notes go to nil_exempt, others to cdnur
        nil_rated_credit_note?(credit_note) ? :nil_exempt : :cdnur
      end

      # Returns true if every line on the invoice has a zero GST rate.
      # These supplies fall into GSTR-1 Table 8 (nil/exempt/non-GST section).
      def self.nil_rated_invoice?(invoice)
        lines = invoice.try(:lines) || invoice.try(:invoice_lines) || []
        return false if lines.empty?
        lines.all? { |l| l.gst_rate.to_d.zero? }
      end

      # Returns true if every line on the credit note has a zero GST rate.
      def self.nil_rated_credit_note?(credit_note)
        lines = credit_note.try(:lines) || []
        return false if lines.empty?
        lines.all? { |l| l.gst_rate.to_d.zero? }
      end

      # Returns `true` if the invoice is inter-state based on branch state vs POS.
      def self.inter_state?(invoice_or_cn, seller_state_code:)
        pos = place_of_supply_code(invoice_or_cn)
        seller_state_code.to_s.strip != pos.to_s.strip
      end

      # ── Place of supply ──────────────────────────────────────────────────────

      # Derives the 2-digit GST state code for the place of supply.
      #
      # Priority:
      #   1. Customer GSTIN first two digits  (registered buyers)
      #   2. Customer billing address state   (unregistered buyers)
      #   3. Branch state_code                (fallback — usually intra-state)
      #
      def self.place_of_supply_code(doc)
        customer = doc.customer
        if customer&.gstin.present?
          customer.gstin[0..1]
        elsif customer.respond_to?(:addresses) && customer.addresses.any?
          billing = customer.addresses.find { |a| a.label == 'billing' } ||
                    customer.addresses.first
          state_name_to_code(billing&.state.to_s) || branch_state_code(doc)
        else
          branch_state_code(doc)
        end
      end

      private_class_method def self.branch_state_code(doc)
        branch = doc.try(:branch)
        code   = branch&.state_code.presence
        return code if code.present? && code != '00'

        # Derive from the branch's plain state name when state_code is absent/00
        if branch&.state.present?
          derived = STATE_CODE_MAP[branch.state.to_s.downcase.strip]
          return derived if derived
        end

        '00'
      end

      private_class_method def self.state_name_to_code(state_name)
        STATE_CODE_MAP[state_name.to_s.downcase.strip]
      end

      STATE_CODE_MAP = {
        'jammu and kashmir'          => '01',
        'himachal pradesh'           => '02',
        'punjab'                     => '03',
        'chandigarh'                 => '04',
        'uttarakhand'                => '05',
        'haryana'                    => '06',
        'delhi'                      => '07',
        'rajasthan'                  => '08',
        'uttar pradesh'              => '09',
        'bihar'                      => '10',
        'sikkim'                     => '11',
        'arunachal pradesh'          => '12',
        'nagaland'                   => '13',
        'manipur'                    => '14',
        'mizoram'                    => '15',
        'tripura'                    => '16',
        'meghalaya'                  => '17',
        'assam'                      => '18',
        'west bengal'                => '19',
        'jharkhand'                  => '20',
        'odisha'                     => '21',
        'chhattisgarh'               => '22',
        'madhya pradesh'             => '23',
        'gujarat'                    => '24',
        'daman and diu'              => '25',
        'dadra and nagar haveli'     => '26',
        'maharashtra'                => '27',
        'andhra pradesh'             => '37',
        'karnataka'                  => '29',
        'goa'                        => '30',
        'lakshadweep'                => '31',
        'kerala'                     => '32',
        'tamil nadu'                 => '33',
        'puducherry'                 => '34',
        'andaman and nicobar'        => '35',
        'telangana'                  => '36',
        'ladakh'                     => '38'
      }.freeze
    end
  end
end
