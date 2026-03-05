class SchemeReward < ApplicationRecord
  REWARD_TYPES  = %w[percent_off amount_off free_qty fixed_price].freeze
  TARGET_SCOPES = %w[order line product].freeze

  belongs_to :scheme
  belongs_to :target_product, class_name: 'Product', optional: true

  validates :reward_type,   inclusion: { in: REWARD_TYPES }
  validates :target_scope,  inclusion: { in: TARGET_SCOPES }
  validates :reward_value,  numericality: { greater_than_or_equal_to: 0 }
  validates :target_product, presence: true, if: -> { %w[free_qty fixed_price].include?(reward_type) && target_scope == 'product' }
end
