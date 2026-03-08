# frozen_string_literal: true

module Accounting
  module Adapters
    module Tally
      # Builds a Tally LEDGER master import XML fragment from a canonical Ledger.
      #
      # Produces a TALLYMESSAGE > LEDGER element suitable for inclusion in a
      # master import envelope (REPORTNAME: "All Masters").
      #
      # Supports ledger_kind values: retailer (sundry_debtor), supplier
      # (sundry_creditor), sales, purchase, tax (cgst/sgst/igst), bank, cash.
      #
      # Calibration notes are inline where Tally field behaviour may vary.
      class LedgerXmlBuilder < BaseXmlBuilder
        def export_kind = :master
        def report_name = XmlHelper::REPORT_ALL_MASTERS

        # -----------------------------------------------------------------------
        # Template method implementation
        # -----------------------------------------------------------------------

        # @param xml [Nokogiri::XML::Builder] scoped inside TALLYMESSAGE
        def build_message(xml)
          xml.LEDGER(NAME: sanitize_name(ledger_name), ACTION: XmlHelper::ACTION_CREATE) do
            build_ledger_message(xml)
          end
        end

        # -----------------------------------------------------------------------
        # Named helpers (public so callers can inspect derived values)
        # -----------------------------------------------------------------------

        def ledger_name
          sanitize_name(field(:name).to_s)
        end

        # Determines the Tally parent group from canonical group_name or ledger_kind.
        # Falls back to Constants::LEDGER_GROUP_MAP, then XmlHelper::FALLBACK_LEDGER_NAMES.
        def parent_group_name
          explicit = field(:group_name).to_s.strip
          return explicit if explicit.present?

          kind = field(:ledger_kind).to_s.downcase
          Constants::LEDGER_GROUP_MAP[kind] ||
            resolve_name(kind) ||
            Constants::DEFAULT_SUNDRY_DEBTOR_GROUP
        end

        def gstin
          field(:gstin).to_s.strip.upcase
        end

        def pan
          field(:pan).to_s.strip.upcase
        end

        def phone
          field(:phone).to_s.strip
        end

        def email
          field(:email).to_s.strip.downcase
        end

        def opening_balance
          field(:opening_balance)
        end

        # -----------------------------------------------------------------------
        protected
        # -----------------------------------------------------------------------

        def build_ledger_message(xml)
          add_simple_node(xml, "NAME", ledger_name)
          add_simple_node(xml, "PARENT", parent_group_name)

          add_gst_registration_nodes(xml)
          add_address_nodes(xml, field(:address))
          add_contact_nodes(xml)
          add_opening_balance_node(xml)
          add_party_flags(xml)
        end

        # -----------------------------------------------------------------------
        # GST / Tax registration section
        # Calibrate: exact tag names vary across Tally versions.
        # In Tally Prime, the canonical tags are GSTREGISTRATIONTYPE and PARTYGSTIN.
        # In TallyERP9, some users use LEDGERGSTREGISTRATIONTYPE.
        # -----------------------------------------------------------------------
        def add_gst_registration_nodes(xml)
          return unless gstin.present? || pan.present?

          # GSTREGISTRATIONTYPE: Regular, Composition, URD, etc.
          # Calibrate: derive from customer flags if available.
          xml.GSTREGISTRATIONTYPE("Regular") if gstin.present?
          add_simple_node(xml, "PARTYGSTIN", gstin)     if gstin.present?
          add_simple_node(xml, "PANNO",      pan)       if pan.present?

          # State code derived from GSTIN prefix (first 2 digits) when present.
          if gstin.length >= 2
            derived_state_code = gstin[0..1]
            xml.COUNTRYNAME("India")
            # Calibrate: LEDSTATECODE vs STATECODE tag name for your Tally version
            xml.LEDSTATECODE(derived_state_code)
          end
        end

        def add_contact_nodes(xml)
          add_simple_node(xml, "LEDPHONE",     phone) if phone.present?
          add_simple_node(xml, "LEDEMAIL",     email) if email.present?
        end

        def add_opening_balance_node(xml)
          bal = opening_balance
          return if bal.nil?

          formatted = format_amount(bal)
          return if formatted == "0.00"

          # Calibrate: OPENINGBALANCE sign convention — Dr is positive, Cr is negative.
          xml.OPENINGBALANCE(formatted)
        end

        # Party-level flags relevant for bill-by-bill tracking and credit control.
        # Calibrate: these depend on the integration configuration and Tally version.
        def add_party_flags(xml)
          kind = field(:ledger_kind).to_s.downcase
          return unless %w[retailer sundry_debtor supplier sundry_creditor party_ledger].include?(kind)

          # Bill-by-bill settlement — most OMS workflows require this.
          xml.ISBILLWISEON(TALLY_YES)

          # Credit limit — Calibrate: CREDITLIMIT tag may vary
          credit_limit = field(:credit_limit)
          if credit_limit.present?
            xml.CREDITLIMIT(format_amount(credit_limit))
          end
        end
      end
    end
  end
end
