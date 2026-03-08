module Accounting
  module Canonical
    # Represents either a party ledger (retailer, supplier) or an accounting
    # ledger (tax account, bank, sales account, etc.).
    # Provider adapters consume this to create/update ledger masters.
    class Ledger < BaseRecord
      # Recognised ledger_kind values (informational — not validated here):
      # retailer | supplier | bank | cash | sales | purchase | tax | round_off
      PARTY_KINDS = %w[retailer supplier].freeze
      TAX_KINDS   = %w[tax].freeze

      fields :name,
             :group_name,
             :ledger_kind,
             :gstin,
             :pan,
             :state,
             :state_code,
             :address,         # Address object or nil
             :phone,
             :email,
             :credit_limit,
             :payment_terms_days,
             :active

      def active?
        active != false
      end

      def party_ledger?
        PARTY_KINDS.include?(ledger_kind.to_s)
      end

      def tax_ledger?
        TAX_KINDS.include?(ledger_kind.to_s)
      end

      def to_h
        base = super
        base[:address] = address&.to_h
        base
      end
    end
  end
end
