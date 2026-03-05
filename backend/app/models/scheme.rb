class Scheme < ApplicationRecord
  TYPES    = %w[buy_x_get_y slab_discount item_discount order_value_discount].freeze
  STATUSES = %w[active inactive expired].freeze
  SCOPES   = %w[all retailer_segment specific_retailers route beat].freeze

  # ── Associations ────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch, optional: true
  belongs_to :created_by, class_name: 'User'

  has_many :conditions, class_name: 'SchemeCondition', dependent: :destroy
  has_many :rewards,    class_name: 'SchemeReward',    dependent: :destroy
  has_many :applications, class_name: 'SchemeApplication', dependent: :nullify

  # ── Validations ─────────────────────────────────────────────────────────────
  validates :name,        presence: true
  validates :code,        presence: true, uniqueness: { scope: :organization_id }
  validates :scheme_type, inclusion: { in: TYPES }
  validates :status,      inclusion: { in: STATUSES }
  validates :applies_to,  inclusion: { in: SCOPES }
  validates :priority,    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate  :end_date_after_start_date

  # ── Scopes ──────────────────────────────────────────────────────────────────
  scope :active,       -> { where(status: 'active') }
  scope :for_org,      ->(org_id)   { where(organization_id: org_id) }
  scope :for_branch,   ->(bid)      { where('branch_id IS NULL OR branch_id = ?', bid) }
  scope :by_type,      ->(t)        { where(scheme_type: t) }
  scope :valid_on,     ->(date = Date.current) {
    where('start_date IS NULL OR start_date <= ?', date)
      .where('end_date IS NULL OR end_date >= ?', date)
  }
  scope :applicable_on_day, ->(wday) {
    where('applicable_days = \'{}\' OR applicable_days IS NULL OR ? = ANY(applicable_days)', wday)
  }
  scope :by_priority,  -> { order(priority: :asc) }  # lower number = higher priority

  # ── Active eligible scope for a cart context ─────────────────────────────
  def self.eligible(organization_id:, branch_id:, date: Date.current)
    for_org(organization_id)
      .for_branch(branch_id)
      .active
      .valid_on(date)
      .applicable_on_day(date.wday == 0 ? 6 : date.wday - 1) # ISO: Mon=0
      .by_priority
      .includes(:conditions, :rewards)
  end

  private

  def end_date_after_start_date
    return unless start_date.present? && end_date.present?
    errors.add(:end_date, 'must be after start date') if end_date < start_date
  end
end
