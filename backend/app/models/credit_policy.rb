class CreditPolicy < ApplicationRecord
  AUTO_INVOICE_TRIGGERS = %w[on_delivery on_dispatch on_invoice_creation].freeze
  COLLECTION_BUCKETS    = %w[mild moderate serious critical].freeze

  belongs_to :organization

  validates :organization_id, uniqueness: true, presence: true
  validates :hard_block_overdue_days,    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :hard_block_margin_pct,      numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 500 }
  validates :soft_hold_overdue_days_min, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :soft_hold_overdue_days_max, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :soft_hold_outstanding_pct,  numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 500 }
  validates :approval_sla_hours_manager, numericality: { only_integer: true, greater_than: 0 }
  validates :approval_sla_hours_owner,   numericality: { only_integer: true, greater_than: 0 }
  validates :auto_invoice_trigger,       inclusion: { in: AUTO_INVOICE_TRIGGERS }
  validates :collection_first_bucket,    inclusion: { in: COLLECTION_BUCKETS }
  validate  :soft_hold_overdue_days_range

  DEFAULTS = {
    hard_block_overdue_days:    30,
    hard_block_margin_pct:      20.0,
    soft_hold_overdue_days_min: 15,
    soft_hold_overdue_days_max: 29,
    soft_hold_outstanding_pct:  100.0,
    collection_first_bucket:    "serious",
    approval_sla_hours_manager: 4,
    approval_sla_hours_owner:   8,
    auto_invoice_trigger:       "on_delivery",
    allow_partial_allocation:   true,
  }.freeze

  def self.for_org!(organization)
    find_or_create_by!(organization: organization) do |cp|
      DEFAULTS.each { |k, v| cp.public_send(:"#{k}=", v) }
    end
  end

  private

  def soft_hold_overdue_days_range
    return unless soft_hold_overdue_days_min && soft_hold_overdue_days_max
    if soft_hold_overdue_days_min > soft_hold_overdue_days_max
      errors.add(:soft_hold_overdue_days_min, "must be less than or equal to soft_hold_overdue_days_max")
    end
  end
end
