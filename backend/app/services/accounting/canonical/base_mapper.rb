module Accounting
  module Canonical
    # Lightweight base for all canonical mapper classes.
    # Provides .call convenience, money/type helpers, and defensive attribute reading.
    # Subclasses implement: #call -> canonical object
    class BaseMapper
      def self.call(record)
        new(record).call
      end

      def initialize(record)
        @record = record
      end

      private

      attr_reader :record

      # ---------------------------------------------------------------------------
      # Type-safe conversion helpers
      # ---------------------------------------------------------------------------

      # Safe BigDecimal coercion — returns nil for nil, 0 for blank.
      def decimal(value)
        return nil if value.nil?
        BigDecimal(value.to_s)
      rescue ArgumentError, TypeError
        BigDecimal("0")
      end

      # Returns "0" safe decimal (never nil).
      def decimal!(value)
        decimal(value) || BigDecimal("0")
      end

      def string_value(value)
        val = value.to_s.strip
        val.empty? ? nil : val
      end

      def boolean_value(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      # ---------------------------------------------------------------------------
      # Defensive multi-method attribute reader
      # Tries each method name in order and returns the first non-blank result.
      # ---------------------------------------------------------------------------
      def fetch_first_present(obj, *methods)
        methods.each do |m|
          next unless obj.respond_to?(m, true)
          val = obj.public_send(m) rescue nil
          return val if val.present?
        end
        nil
      end

      # ---------------------------------------------------------------------------
      # Address extraction helper
      # Accepts an ActiveRecord address-like object and maps to canonical Address.
      # ---------------------------------------------------------------------------
      def build_address_from(addr_obj)
        return nil if addr_obj.nil?

        Address.new(
          line1:       string_value(fetch_first_present(addr_obj, :line1, :address_line1)),
          line2:       string_value(fetch_first_present(addr_obj, :line2, :address_line2)),
          city:        string_value(fetch_first_present(addr_obj, :city)),
          state:       string_value(fetch_first_present(addr_obj, :state)),
          state_code:  string_value(fetch_first_present(addr_obj, :state_code)),
          postal_code: string_value(fetch_first_present(addr_obj, :postal_code, :pincode)),
          country:     string_value(fetch_first_present(addr_obj, :country)) || "India"
        )
      end

      # ---------------------------------------------------------------------------
      # Metadata builder
      # ---------------------------------------------------------------------------
      def build_metadata(source_type:, source_id:, organization_id: nil, **extra)
        { source_type: source_type, source_id: source_id, organization_id: organization_id }.merge(extra).compact
      end

      # ---------------------------------------------------------------------------
      # Guard: raise MappingError if value is blank
      # ---------------------------------------------------------------------------
      def require_present!(value, field_desc)
        return value if value.present?
        raise MappingError, "#{self.class.name}: #{field_desc} is required but was blank"
      end
    end
  end
end
