class Vehicle < ApplicationRecord
  TYPES    = %w[truck tempo bike van auto car other].freeze
  STATUSES = %w[active inactive].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :default_driver, class_name: 'User', optional: true
  has_many   :delivery_trips

  # ── Validations ──────────────────────────────────────────────────────────
  validates :registration_number, presence: true,
            uniqueness: { scope: :organization_id, conditions: -> { not_deleted } }
  validates :vehicle_type, inclusion: { in: TYPES }
  validates :status,       inclusion: { in: STATUSES }
  validates :capacity_kg,  numericality: { greater_than: 0 }, allow_nil: true
  validates :capacity_units, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :active,      -> { not_deleted.where(status: 'active') }
  scope :by_type,     ->(t) { where(vehicle_type: t) }

  # ── Status helpers ────────────────────────────────────────────────────────
  def active?    = status == 'active'
  def inactive?  = status == 'inactive'

  # ── Soft delete ───────────────────────────────────────────────────────────
  def soft_delete!
    if delivery_trips.where(status: %w[draft planned dispatched]).exists?
      raise ActiveRecord::RecordInvalid.new(self), 'Cannot delete a vehicle with active trips'
    end

    update!(deleted_at: Time.current)
  end
end
