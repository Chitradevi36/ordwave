class ReturnRecord < ApplicationRecord
  CONDITIONS   = %w[good damaged expired].freeze
  REASON_CODES = %w[refused not_home short_delivery quality other].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :trip_stop
  belongs_to :product

  # ── Validations ──────────────────────────────────────────────────────────
  validates :qty_returned, numericality: { only_integer: true, greater_than: 0 }
  validates :condition,    inclusion: { in: CONDITIONS }
  validates :reason_code,  inclusion: { in: REASON_CODES }

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :by_condition,   ->(c) { where(condition: c) }
  scope :by_reason_code, ->(r) { where(reason_code: r) }
end
