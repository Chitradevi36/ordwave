module Accounting
  module Canonical
    # Minimal base for all canonical value objects.
    # Provides keyword initialization, array normalization, to_h, and as_json.
    # Subclasses declare fields via `.fields` and get attr_readers + to_h for free.
    class BaseRecord
      def self.fields(*names)
        @fields ||= []
        if names.any?
          @fields += names
          attr_reader(*names)
        end
        @fields
      end

      def self.inherited(subclass)
        super
        subclass.instance_variable_set(:@fields, [])
      end

      def initialize(**kwargs)
        self.class.fields.each do |field|
          val = kwargs[field]
          instance_variable_set(:"@#{field}", normalize_value(field, val))
        end
      end

      def to_h
        self.class.fields.each_with_object({}) do |field, hash|
          val = public_send(field)
          hash[field] = val.respond_to?(:to_h) ? val.to_h : val
        end
      end

      def as_json(_ = nil)
        to_h.transform_values { |v| deep_as_json(v) }
      end

      def inspect
        fields_str = self.class.fields.map { |f| "#{f}=#{public_send(f).inspect}" }.join(", ")
        "#<#{self.class.name} #{fields_str}>"
      end

      private

      # Coerce array fields; leave others untouched.
      def normalize_value(field, val)
        return Array(val).compact if val.is_a?(Array)
        val
      end

      def deep_as_json(val)
        case val
        when Array  then val.map { |v| deep_as_json(v) }
        when BaseRecord then val.as_json
        when Hash   then val.transform_values { |v| deep_as_json(v) }
        else val
        end
      end
    end
  end
end
