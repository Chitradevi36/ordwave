class User < ApplicationRecord
  PLANS = %w[free starter growth enterprise].freeze

  # Devise modules
  devise :database_authenticatable, :recoverable, :rememberable, :trackable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  # Associations
  has_many :memberships,            dependent: :destroy
  has_many :organizations,          through: :memberships
  has_many :branches,               through: :memberships
  has_many :sent_invitations,       class_name: 'Invitation', foreign_key: :invited_by_id, dependent: :destroy

  # Validations
  validates :email,      presence: true, uniqueness: { case_sensitive: false },
                         format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name,  presence: true, length: { maximum: 50 }
  validates :phone,      format: { with: /\A[6-9]\d{9}\z/, message: 'must be a valid 10-digit Indian mobile number' },
                         allow_blank: true
  validates :plan,       presence: true, inclusion: { in: PLANS }

  # Scopes
  scope :active,      -> { where(active: true, deleted_at: nil) }
  scope :not_deleted, -> { where(deleted_at: nil) }

  # Normalizations
  before_validation { self.email = email.to_s.downcase.strip }

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def membership_for(organization)
    memberships.active.find_by(organization: organization)
  end

  def role_in(organization)
    membership_for(organization)&.role
  end

  def current_organization_id
    # Return the ID of the user's first active organization
    # Used during login to set the initial organization context
    organizations.active.pick(:id)
  end

  def soft_delete!
    update!(deleted_at: Time.current, active: false)
  end

  def deleted?
    deleted_at.present?
  end

  # Override Devise methods for soft delete
  def active_for_authentication?
    super && active && !deleted?
  end

  def inactive_message
    deleted? ? :deleted_account : super
  end

  #  JWT token revocation hooks 
  # Revoke all tokens on sensitive field changes so stale sessions are
  # immediately invalidated. Uses Users::RevokeTokensService internally.
  after_update :revoke_tokens_on_sensitive_change!

  # Also exposed for explicit calls (e.g. from MembershipsController)
  def revoke_all_tokens!(reason: "manual_revocation")
    Users::RevokeTokensService.call(user: self, reason: reason)
  end

  private

  def revoke_tokens_on_sensitive_change!
    reason = if saved_change_to_encrypted_password?
               "password_changed"
             elsif saved_change_to_active? && !active?
               "account_deactivated"
             end
    return unless reason

    Users::RevokeTokensService.call(user: self, reason: reason)
  end
end