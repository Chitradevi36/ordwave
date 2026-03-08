# frozen_string_literal: true

module Accounting
  module Adapters
    module Tally
      # Builds a Tally Receipt voucher import XML fragment from a canonical ReceiptVoucher.
      #
      # A Receipt voucher records a payment received from a customer.
      #
      # Amount/sign convention (Tally Prime standard):
      #   Cash/Bank ledger (Dr) — ISDEEMEDPOSITIVE=Yes, AMOUNT = -amount
      #   Party ledger     (Cr) — ISDEEMEDPOSITIVE=No,  AMOUNT = +amount
      #
      # Bill allocations record which open invoices this payment settles.
      #
      # Calibration: validate sign conventions and BILLALLOCATIONS.LIST structure
      # against a live Tally export before going to production.
      class ReceiptVoucherXmlBuilder < BaseXmlBuilder
        def export_kind = :voucher
        def report_name = XmlHelper::REPORT_VOUCHERS

        # -----------------------------------------------------------------------
        # Template method
        # -----------------------------------------------------------------------

        def build_message(xml)
          xml.VOUCHER(
            VCHTYPE: voucher_type_name,
            ACTION:  XmlHelper::ACTION_CREATE
          ) do
            build_voucher_message(xml)
          end
        end

        # -----------------------------------------------------------------------
        # Named helpers
        # -----------------------------------------------------------------------

        def voucher_type_name
          Constants::VOUCHER_TYPE_RECEIPT
        end

        def voucher_number
          field(:voucher_number).to_s.strip
        end

        def voucher_date
          format_date(field(:voucher_date) || field(:received_date))
        end

        def party_ledger_name
          sanitize_name(field(:party_ledger_name).to_s)
        end

        # The cash or bank account through which payment was received.
        def receipt_ledger_name
          n = field(:receipt_ledger_name).to_s.strip
          return sanitize_name(n) if n.present?

          # Derive a sensible fallback from payment_mode if available.
          mode = field(:payment_mode).to_s.downcase
          case mode
          when "cash"  then resolve_name("cash")
          when "cheque", "neft", "rtgs", "upi", "bank" then resolve_name("bank")
          else resolve_name("bank")
          end
        end

        def amount
          field(:amount)
        end

        def reference_number
          field(:reference_number).to_s.strip
        end

        def narration
          field(:narration).to_s.strip
        end

        def bill_allocations
          Array(field(:bill_allocations))
        end

        # -----------------------------------------------------------------------
        protected
        # -----------------------------------------------------------------------

        def build_voucher_message(xml)
          add_header_nodes(xml)
          add_receipt_entry(xml)
          add_party_entry(xml)
          add_narration(xml)
        end

        def add_header_nodes(xml)
          xml.DATE(voucher_date)
          xml.VOUCHERTYPENAME(voucher_type_name)
          add_simple_node(xml, "VOUCHERNUMBER", voucher_number)
          add_simple_node(xml, "PARTYLEDGERNAME", party_ledger_name)
        end

        # Cash/Bank account — Dr side of the receipt.
        # ISDEEMEDPOSITIVE=Yes, amount NEGATIVE.
        def add_receipt_entry(xml)
          xml.send(:"ALLLEDGERENTRIES.LIST") do
            xml.LEDGERNAME(receipt_ledger_name)
            xml.ISDEEMEDPOSITIVE(TALLY_YES)
            xml.AMOUNT(format_amount_negative(amount))
            add_reference_details(xml)
          end
        end

        # Party (customer) — Cr side of the receipt.
        # ISDEEMEDPOSITIVE=No, amount POSITIVE.
        def add_party_entry(xml)
          xml.send(:"ALLLEDGERENTRIES.LIST") do
            xml.LEDGERNAME(party_ledger_name)
            xml.ISDEEMEDPOSITIVE(TALLY_NO)
            xml.AMOUNT(format_amount(amount))
            add_bill_allocations(xml)
          end
        end

        # Bill allocation list — links receipt to specific open invoices.
        #
        # Each BillAllocation has: bill_name, bill_type ("Agst Ref"/"New Ref"),
        # amount, reference_date.
        #
        # Calibration: BILLALLOCATIONS.LIST and its child tags are sensitive
        # to Tally configuration.  Verify BILLTYPE values ("Agst Ref", "New Ref",
        # "Advance", "On Account") against your Tally setup.
        def add_bill_allocations(xml)
          allocations = bill_allocations

          if allocations.empty?
            # No specific invoice references — record as on-account.
            xml.send(:"BILLALLOCATIONS.LIST") do
              xml.NAME(voucher_number.presence || reference_number.presence || "On Account")
              xml.BILLTYPE("On Account")
              xml.AMOUNT(format_amount(amount))
            end
            return
          end

          allocations.each do |alloc|
            bill_name = read_alloc(alloc, :bill_name) || read_alloc(alloc, :reference)
            bill_type = read_alloc(alloc, :bill_type).to_s.strip.presence || "Agst Ref"
            alloc_amt = read_alloc(alloc, :amount)
            ref_date  = read_alloc(alloc, :reference_date)

            next if bill_name.blank?

            xml.send(:"BILLALLOCATIONS.LIST") do
              xml.NAME(sanitize_name(bill_name))
              xml.BILLTYPE(bill_type)
              xml.AMOUNT(format_amount(alloc_amt))
              add_simple_node(xml, "BILLDATE", format_date(ref_date)) if ref_date.present?
            end
          end
        end

        # CHEQUENUMBER / TRANSACTIONTYPE details for non-cash modes.
        # Calibrate: tag names vary across Tally versions.
        def add_reference_details(xml)
          return unless reference_number.present?

          # Calibrate: CHEQUENUMBER vs TRANSACTIONID
          xml.CHEQUENUMBER(reference_number)
        end

        def add_narration(xml)
          add_simple_node(xml, "NARRATION", narration, allow_blank: true)
        end

        # -----------------------------------------------------------------------
        private
        # -----------------------------------------------------------------------

        def read_alloc(alloc, key)
          sym = key.to_sym
          str = key.to_s
          if alloc.is_a?(Hash)
            alloc[sym] || alloc[str]
          elsif alloc.respond_to?(sym)
            alloc.public_send(sym)
          end
        end
      end
    end
  end
end
