class Beat < ApplicationRecord
  WEEKDAY_NAMES = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :route,      optional: true
  belongs_to :created_by, class_name: 'User'

  has_many :beat_schedules, dependent: :destroy

  # ── Validations ──────────────────────────────────────────────────────────
  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true,
                   uniqueness: { scope: :branch_id, message: 'has already been taken for this branch' },
                   format: { with: /\A[A-Z0-9\-]+\z/, message: 'only uppercase letters, numbers, and hyphens' }
  validates :branch,       presence: true
  validates :organization, presence: true

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :active,  -> { where(active: true) }
  scope :for_org, ->(org_id) { where(organization_id: org_id) }

  def deactivate!
    update!(active: false)
  end
end
