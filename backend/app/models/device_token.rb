class DeviceToken < ApplicationRecord
  PLATFORMS = %w[ios android web].freeze

  # ── Associations ────────────────────────────────────────────────────────────
  belongs_to :user
  belongs_to :organization

  # ── Validations ─────────────────────────────────────────────────────────────
  validates :token,    presence: true,
                       uniqueness: { scope: :user_id, message: "already registered for this user" }
  validates :platform, presence: true, inclusion: { in: PLATFORMS }

  # ── Scopes ──────────────────────────────────────────────────────────────────
  scope :active,       ->         { where(active: true) }
  scope :for_platform, ->(p)      { where(platform: p) }
  scope :for_user,     ->(u)      { where(user: u) }
  scope :for_org,      ->(org)    { where(organization: org) }

  # Touch last_used_at when token is used for delivery
  def touch_used!
    update_column(:last_used_at, Time.current)
  end
end
