module Accounting
  module Canonical
    # Maps a Supplier to a canonical Ledger.
    #
    # Field mapping from OMS Supplier:
    #   name                -> ledger name
    #   gstin               -> gstin
    #   pan                 -> pan
    #   phone               -> phone
    #   email               -> email
    #   credit_limit        -> credit_limit
    #   payment_terms_days  -> payment_terms_days
    #   status              -> active
    #
    # Supplier has no address table — address fields stored directly on record.
    class SupplierLedgerMapper < BaseMapper
      def call
        supplier = record

        name = require_present!(
          fetch_first_present(supplier, :name, :business_name),
          "supplier name"
        )

        address_obj = build_inline_address(supplier)
        gstin       = string_value(supplier.try(:gstin))

        Ledger.new(
          name:                name,
          group_name:          nil,
          ledger_kind:         "supplier",
          gstin:               gstin,
          pan:                 string_value(supplier.try(:pan)),
          state:               string_value(fetch_first_present(supplier, :state, :billing_state)),
          state_code:          state_code_from_gstin(gstin),
          address:             address_obj,
          phone:               string_value(fetch_first_present(supplier, :phone, :mobile, :phone_number)),
          email:               string_value(supplier.try(:email)),
          credit_limit:        decimal(supplier.try(:credit_limit)),
          payment_terms_days:  supplier.try(:payment_terms_days).to_i,
          active:              active?(supplier)
        )
      end

      private

      # Supplier address stored inline on the record, not in a separate table.
      def build_inline_address(supplier)
        # Try address object association first, then inline columns
        if supplier.respond_to?(:address) && supplier.address.is_a?(ActiveRecord::Base)
          return build_address_from(supplier.address)
        end

        # Fall back to individual address columns on supplier
        line1       = fetch_first_present(supplier, :address_line1, :line1, :address)
        line2       = fetch_first_present(supplier, :address_line2, :line2)
        city        = supplier.try(:city)
        state       = fetch_first_present(supplier, :state, :billing_state)
        postal_code = fetch_first_present(supplier, :postal_code, :pincode)

        return nil if [line1, city, state].all?(&:blank?)

        Address.new(
          line1:       string_value(line1),
          line2:       string_value(line2),
          city:        string_value(city),
          state:       string_value(state),
          state_code:  nil,
          postal_code: string_value(postal_code),
          country:     "India"
        )
      end

      def state_code_from_gstin(gstin)
        return nil if gstin.blank?
        gstin.to_s[0, 2]
      end

      def active?(supplier)
        status = fetch_first_present(supplier, :status)
        status.to_s == "active"
      end
    end
  end
end
