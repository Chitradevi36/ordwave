class SalesOrder < ApplicationRecord
  STATUSES = %w[draft submitted on_hold approved rejected cancelled].freeze

  # Valid state transitions
  TRANSITIONS = {
    'draft'     => %w[submitted cancelled],
    'submitted' => %w[on_hold approved rejected cancelled],
    'on_hold'   => %w[approved rejected cancelled],
    'approved'  => %w[cancelled],
    'rejected'  => [],
    'cancelled' => []
  }.freeze

  CREDIT_DECISIONS = %w[ok hold blocked].freeze

  # ── Associations ──────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :customer
  belongs_to :created_by, class_name: 'User'

  has_many :lines, class_name: 'SalesOrderLine', dependent: :destroy, inverse_of: :sales_order
  has_many :audit_logs, as: :auditable, dependent: :nullify

  accepts_nested_attributes_for :lines, allow_destroy: true

  # ── Validations ──────────────────────────────────────────────────────────
  validates :status,       inclusion: { in: STATUSES }
  validates :order_number, presence: true,
                           uniqueness: { scope: :organization_id }
  validates :cancellation_reason, presence: true, if: -> { status == 'cancelled' }

  # ── Callbacks ─────────────────────────────────────────────────────────────
  before_validation :assign_order_number, on: :create

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :not_deleted,    -> { where(deleted_at: nil) }
  scope :by_status,      ->(s)   { where(status: s) }
  scope :by_branch,      ->(bid) { where(branch_id: bid) }
  scope :by_customer,    ->(cid) { where(customer_id: cid) }
  scope :by_created_by,  ->(uid) { where(created_by_id: uid) }
  scope :recent,         ->      { order(created_at: :desc) }
  scope :by_date_range,  ->(from_d, to_d) {
    scope = all
    scope = scope.where('sales_orders.created_at >= ?', from_d.to_date.beginning_of_day) if from_d.present?
    scope = scope.where('sales_orders.created_at <= ?', to_d.to_date.end_of_day)         if to_d.present?
    scope
  }
  scope :search_q, ->(q) {
    term = "%#{sanitize_sql_like(q)}%"
    joins(:customer)
      .where(
        'sales_orders.order_number ILIKE :t OR customers.name ILIKE :t OR customers.code ILIKE :t',
        t: term
      )
  }

  # ── Status helpers ────────────────────────────────────────────────────────
  STATUSES.each do |s|
    define_method(:"#{s}?") { status == s }
  end

  def editable?
    draft?
  end

  # Managers/owners can update delivery_date and notes even after submission.
  def limited_editable?
    %w[submitted on_hold].include?(status)
  end

  def cancellable?
    TRANSITIONS[status].include?('cancelled')
  end

  # ── State machine ─────────────────────────────────────────────────────────
  def transition_to!(new_status, reason: nil)
    allowed = TRANSITIONS.fetch(status, [])
    unless allowed.include?(new_status.to_s)
      raise ActiveRecord::RecordInvalid.new(self),
            "Cannot transition from '#{status}' to '#{new_status}'"
    end

    timestamp_col = {
      'submitted' => :submitted_at,
      'approved'  => :approved_at,
      'cancelled' => :cancelled_at
    }[new_status.to_s]

    attrs = { status: new_status }
    attrs[timestamp_col] = Time.current if timestamp_col
    attrs[:cancellation_reason] = reason if new_status.to_s == 'cancelled'

    update!(attrs)
  end

  # ── Financials ────────────────────────────────────────────────────────────
  def recalculate_totals!
    t = lines.sum(&:line_total)
    d = lines.sum { |l| l.unit_price * l.qty * (l.discount_pct / 100.0) }
    update!(total_amount: t, discount_amount: d.round(2))
  end

  private

  def assign_order_number
    return if order_number.present?

    max = SalesOrder.where(organization_id: organization_id).maximum(:id).to_i
    self.order_number = "SO-#{organization_id.to_s.rjust(4, '0')}-#{(max + 1).to_s.rjust(6, '0')}"
  end
end
