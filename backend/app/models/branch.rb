class Branch < ApplicationRecord
  # Associations
  belongs_to :organization
  has_many   :memberships, dependent: :destroy
  has_many   :invitations, dependent: :nullify

  # Validations
  validates :name,         presence: true, length: { maximum: 100 }
  validates :code,         presence: true, uniqueness: true,
                           format: { with: /\A[A-Z0-9\-]+\z/, message: 'only uppercase letters, numbers, and hyphens' }
  validates :organization, presence: true
  validates :address,      length: { maximum: 255 }, allow_blank: true
  validates :pincode,      format: { with: /\A[0-9]{6}\z/, message: 'must be a 6-digit PIN code' }, allow_blank: true

  # Scopes
  scope :active,     -> { where(active: true, deleted_at: nil) }
  scope :not_deleted, -> { where(deleted_at: nil) }

  def soft_delete!
    update!(deleted_at: Time.current, active: false)
  end

  def deleted?
    deleted_at.present?
  end

  # Settings helpers
  def setting(key, default: nil)
    settings.fetch(key.to_s, default)
  end

  def update_setting!(key, value)
    settings_will_change!
    update!(settings: settings.merge(key.to_s => value))
  end

  # ── GST Configuration (TIER 3: Branch-level overrides) ──────────────────────

  def gst_override_gstin
    settings.dig("gst_override", "branch_gstin")
  end

  def effective_gstin
    # Three-tier hierarchy: override > state > org
    override_gstin = gst_override_gstin
    return override_gstin if override_gstin.present?

    state_gstin = organization.gst_for_state(state_code)
    return state_gstin if state_gstin.present?

    organization.gst_number
  end

  def using_state_gstin?
    gst_override_gstin.blank? && organization.gst_for_state(state_code).present?
  end

  def using_override_gstin?
    gst_override_gstin.present?
  end

  def using_org_gstin?
    gst_override_gstin.blank? && organization.gst_for_state(state_code).blank?
  end
end
