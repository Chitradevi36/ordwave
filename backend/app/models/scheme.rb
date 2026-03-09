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
  validates :budget_amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :budget_alert_pct, numericality: { in: 1..100 }, allow_nil: true
  validate  :end_date_after_start_date
  validate  :utilized_within_budget

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
  scope :with_budget_remaining, -> {
    where('budget_amount IS NULL OR utilized_amount < budget_amount')
  }

  # ── Product-scoped queries ────────────────────────────────────────────────
  # Schemes whose product_inclusion / product_exclusion conditions reference this product.
  # Also matches buy_x_get_y reward rows where target_product_id = product_id.
  scope :involving_product, ->(product_id) {
    pid = product_id.to_i
    joins(:conditions)
      .where(
        "scheme_conditions.condition_type IN ('product_inclusion','product_exclusion') " \
        "AND scheme_conditions.value->'product_ids' @> :pid::jsonb",
        pid: "[#{pid}]"
      )
      .or(
        joins(:rewards).where(scheme_rewards: { target_product_id: pid })
      )
      .distinct
  }

  # Collect all product IDs referenced in a scheme's conditions + rewards (for eager enrichment).
  def all_referenced_product_ids
    cond_ids = conditions
                 .select { |c| %w[product_inclusion product_exclusion].include?(c.condition_type) }
                 .flat_map { |c| Array(c.value['product_ids']).map(&:to_i) }
    reward_ids = rewards.map(&:target_product_id).compact
    (cond_ids + reward_ids).uniq
  end

  # ── Active eligible scope for a cart context ─────────────────────────────
  # Uses organization timezone for applicable_days calculation
  def self.eligible(organization_id:, branch_id:, date: Date.current, timezone: nil)
    tz = timezone || Organization.find_by(id: organization_id)&.timezone || 'Asia/Kolkata'
    local_time = Time.current.in_time_zone(tz)
    wday = local_time.wday == 0 ? 6 : local_time.wday - 1 # ISO: Mon=0

    for_org(organization_id)
      .for_branch(branch_id)
      .active
      .valid_on(date)
      .applicable_on_day(wday)
      .with_budget_remaining
      .by_priority
      .includes(:conditions, :rewards)
  end

  # ── Budget helpers ──────────────────────────────────────────────────────────
  def budget_remaining
    return nil unless budget_amount.present?
    (budget_amount - utilized_amount).round(2)
  end

  def budget_utilization_pct
    return nil unless budget_amount.present? && budget_amount.positive?
    ((utilized_amount / budget_amount) * 100).round(1)
  end

  def budget_exhausted?
    budget_amount.present? && utilized_amount >= budget_amount
  end

  def budget_alert?
    return false unless budget_amount.present? && budget_alert_pct.present?
    budget_utilization_pct.to_f >= budget_alert_pct
  end

  # Atomically increment utilized_amount (thread-safe)
  def record_utilization!(amount)
    return unless budget_amount.present?
    self.class.where(id: id).update_all(
      "utilized_amount = LEAST(utilized_amount + #{amount.to_d}, budget_amount)"
    )
    reload
  end

  private

  def end_date_after_start_date
    return unless start_date.present? && end_date.present?
    errors.add(:end_date, 'must be after start date') if end_date < start_date
  end

  def utilized_within_budget
    return unless budget_amount.present? && utilized_amount.present?
    if utilized_amount > budget_amount
      errors.add(:utilized_amount, 'cannot exceed budget amount')
    end
  end
end
