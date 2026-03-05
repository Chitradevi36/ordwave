class BeatRetailer < ApplicationRecord
  VISIT_OVERRIDES = %w[default force_include force_exclude].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :beat_schedule
  belongs_to :customer

  # ── Validations ──────────────────────────────────────────────────────────
  validates :visit_override,
            presence: true,
            inclusion: { in: VISIT_OVERRIDES }
  validates :customer_id,
            uniqueness: {
              scope: :beat_schedule_id,
              message: 'is already assigned to this beat schedule'
            }
  validates :sequence_number, numericality: { greater_than_or_equal_to: 0 }

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :ordered,       -> { order(:sequence_number) }
  scope :force_include, -> { where(visit_override: 'force_include') }
  scope :force_exclude, -> { where(visit_override: 'force_exclude') }
end
