class SchemeCondition < ApplicationRecord
  TYPES = %w[
    min_order_value
    min_total_qty
    product_inclusion
    product_exclusion
    category_inclusion
    retailer_inclusion
    retailer_exclusion
  ].freeze

  OPERATORS = %w[>= > = in].freeze

  belongs_to :scheme

  validates :condition_type, inclusion: { in: TYPES }
  validates :operator,       inclusion: { in: OPERATORS }
  validates :value,          presence: true
end
