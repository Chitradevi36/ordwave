class SchemeCondition < ApplicationRecord
  TYPES = %w[
    min_order_value
    min_total_qty
    product_inclusion
    product_exclusion
    category_inclusion
    retailer_inclusion
    retailer_exclusion
    customer_tier
    customer_channel
  ].freeze

  OPERATORS = %w[>= > = in not_in].freeze

  # JSON Schema definitions for condition value validation
  VALUE_SCHEMAS = {
    'min_order_value'    => { required: ['amount'],       types: { 'amount' => Numeric } },
    'min_total_qty'      => { required: ['qty'],          types: { 'qty' => Numeric } },
    'product_inclusion'  => { required: ['product_ids'],  types: { 'product_ids' => Array } },
    'product_exclusion'  => { required: ['product_ids'],  types: { 'product_ids' => Array } },
    'category_inclusion' => { required: ['category_ids'], types: { 'category_ids' => Array } },
    'retailer_inclusion' => { required: ['customer_ids'], types: { 'customer_ids' => Array } },
    'retailer_exclusion' => { required: ['customer_ids'], types: { 'customer_ids' => Array } },
    'customer_tier'      => { required: ['tiers'],        types: { 'tiers' => Array } },
    'customer_channel'   => { required: ['channels'],     types: { 'channels' => Array } }
  }.freeze

  belongs_to :scheme

  validates :condition_type, inclusion: { in: TYPES }
  validates :operator,       inclusion: { in: OPERATORS }
  validates :value,          presence: true
  validate  :validate_value_schema

  private

  # Validates that the JSONB `value` field contains the required keys
  # with appropriate types for the given condition_type.
  def validate_value_schema
    schema = VALUE_SCHEMAS[condition_type]
    return unless schema

    schema[:required].each do |key|
      unless value.key?(key)
        errors.add(:value, "must contain '#{key}' for #{condition_type}")
        next
      end

      expected_type = schema[:types][key]
      actual_value  = value[key]

      case expected_type.name
      when 'Numeric'
        unless actual_value.is_a?(Numeric) || actual_value.to_s.match?(/\A-?\d+\.?\d*\z/)
          errors.add(:value, "'#{key}' must be a number for #{condition_type}")
        end
      when 'Array'
        unless actual_value.is_a?(Array)
          errors.add(:value, "'#{key}' must be an array for #{condition_type}")
        end
      end
    end
  end
end
