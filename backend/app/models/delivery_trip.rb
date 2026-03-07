class DeliveryTrip < ApplicationRecord
  STATUSES = %w[draft planned dispatched completed cancelled].freeze

  TRANSITIONS = {
    'draft'      => %w[planned dispatched cancelled],
    'planned'    => %w[dispatched cancelled],
    'dispatched' => %w[completed cancelled],
    'completed'  => [],
    'cancelled'  => []
  }.freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :route,           optional: true
  belongs_to :vehicle,         optional: true
  belongs_to :driver, class_name: 'User', foreign_key: :driver_id, optional: true

  has_many :stops,   class_name: 'TripStop', dependent: :destroy
  has_many :orders,  class_name: 'SalesOrder', through: :stops, source: :sales_order
  has_many :audit_logs, as: :auditable, dependent: :nullify

  # ── Validations ──────────────────────────────────────────────────────────
  validates :trip_number, presence: true, uniqueness: { scope: :organization_id }
  validates :trip_date,   presence: true
  validates :status,      inclusion: { in: STATUSES }

  # ── Callbacks ─────────────────────────────────────────────────────────────
  before_validation :assign_trip_number, on: :create

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :recent,        -> { order(trip_date: :desc, created_at: :desc) }
  scope :by_status,     ->(s)   { where(status: s) }
  scope :by_branch,     ->(bid) { where(branch_id: bid) }
  scope :by_date,       ->(d)   { where(trip_date: d) }
  scope :by_date_range, ->(from_d, to_d) {
    scope = all
    scope = scope.where('trip_date >= ?', from_d.to_date) if from_d.present?
    scope = scope.where('trip_date <= ?', to_d.to_date)   if to_d.present?
    scope
  }
  scope :by_driver, ->(uid) { where(driver_id: uid) }

  # ── Status helpers ─────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def cancellable?
    TRANSITIONS[status].include?('cancelled')
  end

  # ── State machine ──────────────────────────────────────────────────────────
  def transition_to!(new_status)
    allowed = TRANSITIONS.fetch(status, [])
    unless allowed.include?(new_status.to_s)
      raise ActiveRecord::RecordInvalid.new(self),
            "Cannot transition from '#{status}' to '#{new_status}'"
    end

    timestamp_col = { 'dispatched' => :dispatched_at, 'completed' => :completed_at }[new_status.to_s]
    attrs = { status: new_status }
    attrs[timestamp_col] = Time.current if timestamp_col
    update!(attrs)
  end

  private

  def assign_trip_number
    return if trip_number.present?

    max = DeliveryTrip.where(organization_id: organization_id).maximum(:id).to_i
    self.trip_number = "DT-#{organization_id.to_s.rjust(4, '0')}-#{(max + 1).to_s.rjust(6, '0')}"
  end
end
