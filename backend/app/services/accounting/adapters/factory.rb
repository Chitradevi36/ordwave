# frozen_string_literal: true

module Accounting
  module Adapters
    # Instantiates the correct adapter for a given AccountingIntegration.
    #
    # Usage:
    #   adapter = Accounting::Adapters::Factory.build(integration)
    #   adapter.validate_config!
    #   payload = adapter.export(canonical_record)
    module Factory
      module_function

      # @param integration [AccountingIntegration]
      # @return [BaseAdapter] concrete adapter instance
      # @raise [UnsupportedProviderError] when no adapter is registered for the provider
      def build(integration)
        case integration.provider.to_s
        when Tally::Constants::PROVIDER_NAME
          Tally::Adapter.new(integration)
        else
          raise UnsupportedProviderError.new(integration.provider)
        end
      end
    end
  end
end
