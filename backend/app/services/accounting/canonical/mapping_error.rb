module Accounting
  module Canonical
    # Raised when a required field cannot be resolved from the source domain record.
    class MappingError < StandardError
      def initialize(msg = "Accounting mapping failed")
        super
      end
    end
  end
end
