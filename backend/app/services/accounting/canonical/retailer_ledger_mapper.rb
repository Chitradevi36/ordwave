module Accounting
  module Canonical
    # Maps a Customer (retailer/wholesaler) to a canonical Ledger.
    #
    # Field mapping from OMS Customer:
    #   name          -> ledger name
    #   gstin         -> gstin
    #   state (from billing address) -> state / state_code
    #   phone         -> phone
    #   email         -> email
    #   credit_limit  -> credit_limit
    #   credit_days   -> payment_terms_days
    #   status        -> active
    class RetailerLedgerMapper < BaseMapper
      def call
        customer = record

        name = require_present!(
          fetch_first_present(customer, :name, :business_name, :legal_name),
          "customer name"
        )

        billing_address = primary_address(customer)
        address_obj     = build_address_from(billing_address)
        state           = fetch_first_present(billing_address, :state) if billing_address

        Ledger.new(
          name:                name,
          group_name:          nil,            # caller / integration config sets group
          ledger_kind:         "retailer",
          gstin:               string_value(customer.try(:gstin)),
          pan:                 string_value(customer.try(:pan)),
          state:               string_value(state),
          state_code:          state_code_from_gstin(customer.try(:gstin)),
          address:             address_obj,
          phone:               string_value(fetch_first_present(customer, :phone, :mobile, :phone_number)),
          email:               string_value(customer.try(:email)),
          credit_limit:        decimal(customer.try(:credit_limit)),
          payment_terms_days:  customer.try(:credit_days).to_i,
          active:              active?(customer)
        )
      end

      private

      def primary_address(customer)
        return nil unless customer.respond_to?(:addresses)

        customer.addresses
                .find { |a| a.try(:label) == "billing" } ||
          customer.addresses.first
      end

      # Derive 2-digit state code from GSTIN (first 2 chars).
      def state_code_from_gstin(gstin)
        return nil if gstin.blank?
        gstin.to_s[0, 2]
      end

      def active?(customer)
        status = fetch_first_present(customer, :status)
        status.to_s == "active"
      end
    end
  end
end
