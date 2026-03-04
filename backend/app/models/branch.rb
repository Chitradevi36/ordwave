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
end
