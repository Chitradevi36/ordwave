module Accounting
  module Canonical
    # Provider-neutral postal address.
    # Used inside Ledger and optionally in voucher metadata.
    class Address < BaseRecord
      fields :line1,
             :line2,
             :city,
             :state,
             :state_code,
             :postal_code,
             :country

      def blank?
        [line1, line2, city, state, postal_code].all?(&:blank?)
      end

      def present?
        !blank?
      end

      # Returns a compact single string representation for narrations/notes.
      def to_s
        [line1, line2, city, state, postal_code, country].compact.reject(&:blank?).join(", ")
      end
    end
  end
end
