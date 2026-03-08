# frozen_string_literal: true

module Accounting
  module Adapters
    module Tally
      module Constants
        PROVIDER_NAME = "tally"

        # -----------------------------------------------------------------------
        # Supported canonical types (Phase 1)
        # -----------------------------------------------------------------------

        SUPPORTED_MASTER_CLASSES = [
          Accounting::Canonical::Ledger,
          Accounting::Canonical::StockItem
        ].freeze

        SUPPORTED_VOUCHER_CLASSES = [
          Accounting::Canonical::SalesVoucher,
          Accounting::Canonical::ReceiptVoucher,
          Accounting::Canonical::CreditNoteVoucher,
          Accounting::Canonical::PurchaseVoucher
        ].freeze

        # -----------------------------------------------------------------------
        # Connection defaults
        # -----------------------------------------------------------------------

        DEFAULT_HOST = "localhost"
        DEFAULT_PORT = 9000

        # -----------------------------------------------------------------------
        # Format / serialisation hints
        # -----------------------------------------------------------------------

        # Tally XML date format: YYYYMMDD
        DATE_FORMAT = "%Y%m%d"

        # Root XML element tags used by the payload builder
        ENVELOPE_TAG     = "ENVELOPE"
        HEADER_TAG       = "HEADER"
        BODY_TAG         = "BODY"
        IMPORTDATA_TAG   = "IMPORTDATA"
        REQUESTDESC_TAG  = "REQUESTDESC"
        REQUESTDATA_TAG  = "REQUESTDATA"

        TALLY_MESSAGE_TAG      = "TALLYMESSAGE"

        LEDGER_XML_TAG         = "LEDGER"
        STOCK_ITEM_XML_TAG     = "STOCKITEM"
        VOUCHER_XML_TAG        = "VOUCHER"

        # Tally master type identifiers used in <REPORTNAME>
        REPORT_LEDGER         = "All Masters"
        REPORT_STOCK_ITEM     = "All Masters"
        REPORT_VOUCHER        = "Vouchers"

        # Voucher type names as expected by Tally Prime
        VOUCHER_TYPE_SALES       = "Sales"
        VOUCHER_TYPE_RECEIPT     = "Receipt"
        VOUCHER_TYPE_CREDIT_NOTE = "Credit Note"
        VOUCHER_TYPE_PURCHASE    = "Purchase"

        # -----------------------------------------------------------------------
        # Config key requirements (Phase 1)
        # -----------------------------------------------------------------------

        PHASE1_REQUIRED_CONFIG_KEYS = %w[host company_name].freeze

        # -----------------------------------------------------------------------
        # Ledger / group names used by Tally
        # -----------------------------------------------------------------------

        DEFAULT_SALES_LEDGER_GROUP       = "Sales Accounts"
        DEFAULT_PURCHASE_LEDGER_GROUP    = "Purchase Accounts"
        DEFAULT_SUNDRY_DEBTOR_GROUP      = "Sundry Debtors"
        DEFAULT_SUNDRY_CREDITOR_GROUP    = "Sundry Creditors"
        DEFAULT_STOCK_GROUP              = "Primary"

        GST_LEDGER_GROUP = "Duties & Taxes"

        # Canonical ledger_kind values → Tally parent group mapping
        LEDGER_GROUP_MAP = {
          "sales"           => DEFAULT_SALES_LEDGER_GROUP,
          "purchase"        => DEFAULT_PURCHASE_LEDGER_GROUP,
          "sundry_debtor"   => DEFAULT_SUNDRY_DEBTOR_GROUP,
          "sundry_creditor" => DEFAULT_SUNDRY_CREDITOR_GROUP,
          "cgst"            => GST_LEDGER_GROUP,
          "sgst"            => GST_LEDGER_GROUP,
          "igst"            => GST_LEDGER_GROUP,
          "tax"             => GST_LEDGER_GROUP,
          "party_ledger"    => DEFAULT_SUNDRY_DEBTOR_GROUP
        }.freeze
      end
    end
  end
end
