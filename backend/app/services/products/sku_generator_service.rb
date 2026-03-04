module Products
  # Generates a collision-free SKU for an organisation.
  #
  # Format: PROD-<6 uppercase alphanumeric chars>  →  e.g. PROD-A3K7M2
  #
  # Usage:
  #   sku = Products::SkuGeneratorService.new(organization: org).generate
  #
  class SkuGeneratorService
    PREFIX      = 'PROD'
    CHARSET     = (('A'..'Z').to_a + ('0'..'9').to_a).freeze
    RAND_LENGTH = 6
    MAX_ATTEMPTS = 50

    def initialize(organization:)
      @organization = organization
    end

    def generate
      MAX_ATTEMPTS.times do
        candidate = "#{PREFIX}-#{Array.new(RAND_LENGTH) { CHARSET.sample }.join}"
        return candidate unless @organization.products.not_deleted.exists?(sku: candidate)
      end

      # Fallback: timestamp-based (extremely unlikely path)
      "PROD-#{Time.current.to_i}"
    end
  end
end
