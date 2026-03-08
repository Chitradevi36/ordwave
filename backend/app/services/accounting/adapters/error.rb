module Accounting
  module Adapters
    # Base class for all accounting adapter errors.
    class Error < StandardError
      def initialize(msg = "Accounting adapter error")
        super
      end
    end

    # Raised when a requested provider has no registered adapter.
    class UnsupportedProviderError < Error
      def initialize(provider)
        super("Accounting provider '#{provider}' is not supported")
      end
    end

    # Raised when an integration's config_json is missing required fields.
    class InvalidConfigurationError < Error
      def initialize(provider, missing_fields)
        fields = Array(missing_fields).join(", ")
        super("#{provider} integration config is invalid — missing required fields: #{fields}")
      end
    end

    # Raised when a canonical entity type is not supported by the adapter.
    class UnsupportedEntityError < Error
      def initialize(adapter_name, entity)
        type = entity.is_a?(Class) ? entity.name : entity.class.name
        super("#{adapter_name} adapter does not support entity type '#{type}'")
      end
    end
  end
end
