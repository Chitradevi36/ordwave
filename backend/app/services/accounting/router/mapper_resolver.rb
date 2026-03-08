# frozen_string_literal: true

module Accounting
  module Router
    # Resolves the correct canonical mapper class for a given OMS entity.
    #
    # Mapping table (Phase 1):
    #   Customer / Retailer            → Accounting::Canonical::RetailerLedgerMapper
    #   Supplier                       → Accounting::Canonical::SupplierLedgerMapper
    #   Product                        → Accounting::Canonical::ProductStockItemMapper
    #   SalesInvoice / Invoice         → Accounting::Canonical::InvoiceToSalesVoucherMapper
    #   Payment / Collection           → Accounting::Canonical::PaymentToReceiptVoucherMapper
    #   CreditNote / Credit note       → Accounting::Canonical::CreditNoteToVoucherMapper
    #   PurchaseInvoice                → Accounting::Canonical::PurchaseInvoiceToVoucherMapper
    #
    # Lookup priority:
    #   1. Class object exact match
    #   2. Inheritance-aware (subclass check)
    #   3. Class name string match for Rails reloading safety
    #   If nothing matches: raise NoMapperFoundError with entity description.
    module MapperResolver
      class NoMapperFoundError < Accounting::Adapters::Error
        def initialize(entity)
          super("No accounting canonical mapper found for #{entity.class.name}")
        end
      end

      # Explicit registry: canonical class name fragment → mapper constant.
      # Keys are lowercase strings matched against entity.class.name.downcase.
      # Using string matching (not autoload constants) so reloading is safe.
      REGISTRY = [
        # Salesforce-friendly pattern: most specific names first.
        { match: "salesinvoice",     mapper: -> { Accounting::Canonical::InvoiceToSalesVoucherMapper } },
        { match: "purchaseinvoice",  mapper: -> { Accounting::Canonical::PurchaseInvoiceToVoucherMapper } },
        { match: "creditnote",       mapper: -> { Accounting::Canonical::CreditNoteToVoucherMapper } },
        { match: "payment",          mapper: -> { Accounting::Canonical::PaymentToReceiptVoucherMapper } },
        { match: "collection",       mapper: -> { Accounting::Canonical::PaymentToReceiptVoucherMapper } },
        { match: "supplier",         mapper: -> { Accounting::Canonical::SupplierLedgerMapper } },
        { match: "vendor",           mapper: -> { Accounting::Canonical::SupplierLedgerMapper } },
        { match: "customer",         mapper: -> { Accounting::Canonical::RetailerLedgerMapper } },
        { match: "retailer",         mapper: -> { Accounting::Canonical::RetailerLedgerMapper } },
        { match: "product",          mapper: -> { Accounting::Canonical::ProductStockItemMapper } }
      ].freeze

      module_function

      # @param entity [Object]
      # @return [Class] canonical mapper class
      # @raise [NoMapperFoundError]
      def call(entity)
        mapper_for(entity)
      end

      # @param entity [Object]
      # @return [Class]
      def mapper_for(entity)
        klass_name = entity.class.name.to_s.downcase

        entry = REGISTRY.find { |r| klass_name.include?(r[:match]) }
        raise NoMapperFoundError.new(entity) unless entry

        entry[:mapper].call
      end
    end
  end
end
