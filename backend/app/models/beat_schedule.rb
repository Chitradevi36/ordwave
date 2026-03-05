class BeatSchedule < ApplicationRecord
  # 0=Monday … 6=Sunday (ISO-aligned)
  WEEKDAYS = (0..6).to_a.freeze
  WEEKDAY_NAMES = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :beat
  belongs_to :sales_rep, class_name: 'User'

  has_many :beat_retailers, dependent: :destroy
  has_many :customers, through: :beat_retailers
  has_many :visit_logs, dependent: :nullify

  # ── Validations ──────────────────────────────────────────────────────────
  validates :weekday, presence: true, inclusion: { in: WEEKDAYS }
  validates :sales_rep_id,
            uniqueness: {
              scope: %i[branch_id weekday],
              message: 'already has a beat schedule on this day for this branch'
            }

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :active,       -> { where(active: true) }
  scope :for_rep,      ->(uid) { where(sales_rep_id: uid) }
  scope :for_weekday,  ->(d)   { where(weekday: d) }
  scope :for_branch,   ->(bid) { where(branch_id: bid) }

  # ── Helpers ──────────────────────────────────────────────────────────────
  def weekday_name
    WEEKDAY_NAMES[weekday]
  end
end
