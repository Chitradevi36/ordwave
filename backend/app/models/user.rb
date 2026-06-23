class User < ApplicationRecord
  PLANS = %w[free starter growth enterprise].freeze
  AUTH_CHANNELS = %w[email phone google].freeze

  # Devise modules
  devise :database_authenticatable, :recoverable, :rememberable, :trackable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  # Associations
  has_many :memberships,            dependent: :destroy
  has_many :organizations,          through: :memberships
  has_many :branches,               through: :memberships
  has_many :sent_invitations,       class_name: 'Invitation', foreign_key: :invited_by_id, dependent: :destroy
  has_many :phone_verifications,    dependent: :destroy

  # Validations
  validates :email,      presence: true, uniqueness: { case_sensitive: false },
                         format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name,  length: { maximum: 50 }
  validates :phone,      format: { with: /\A[6-9]\d{9}\z/, message: 'must be a valid 10-digit Indian mobile number' },
                         allow_blank: true
  validates :plan,       presence: true, inclusion: { in: PLANS }

  # Scopes
  scope :active,      -> { where(active: true, deleted_at: nil) }
  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :find_by_oauth, ->(provider, uid) { find_by(oauth_provider: provider, oauth_uid: uid) }

  # Enum for preferred authentication channel
  # enum preferred_auth_method: { email: 'email', phone: 'phone', google: 'google' }, _prefix: :auth_via

  # Normalizations
  before_validation { self.email = email.to_s.downcase.strip }

  # Class method to find or create user from OAuth provider
  # Auto-creates new users on first OAuth login (v2+)
  # For existing users without OAuth, links their email to OAuth credentials
  def self.find_or_create_from_oauth(provider:, uid:, email:, name:)
    # First try to find by OAuth credentials
    user = find_by(oauth_provider: provider, oauth_uid: uid)
    return user if user.present?

    # If no OAuth user found, check if email exists
    # If email exists, link the OAuth credentials
    user = find_by(email: email&.downcase&.strip)
    if user.present?
      user.update!(oauth_provider: provider, oauth_uid: uid)
      return user
    end

    # Auto-create new user from OAuth provider
    # Split name into first_name and last_name
    first_name, last_name = split_name(name)
    
    create!(
      email: email&.downcase&.strip,
      first_name: first_name,
      last_name: last_name,
      oauth_provider: provider,
      oauth_uid: uid,
      active: true,
      plan: 'free', # Default plan for new OAuth users
      phone: nil,   # Optional, not from OAuth
      password: SecureRandom.hex(16),
      password_confirmation: SecureRandom.hex(16)
    )
  rescue ActiveRecord::RecordInvalid => e
    # Handle edge case: email was created between check and create
    user = find_by(email: email&.downcase&.strip)
    return user if user.present?
    raise e
  end

  # Helper to split full name into first and last name
  # Handles various formats: "John Doe", "John", "John M Doe", etc.
  private_class_method def self.split_name(full_name)
    parts = full_name&.strip&.split(/\s+/) || []
    case parts.length
    when 0
      ['User', 'OAuth']
    when 1
      [parts[0], '']
    else
      [parts[0], parts.drop(1).join(' ')]
    end
  end

  def full_name
    "#{first_name} #{last_name}".strip
  end

  # Phone verification helper methods
  def primary_phone
    phone_verifications.order(created_at: :desc).find_by(is_primary: true)&.phone_number
  end

  def verified_phones
    phone_verifications.where(verified: true).pluck(:phone_number)
  end

  def has_verified_phone?
    phone_verified? && phone_verified_at.present?
  end

  def mark_phone_verified!(phone_number = nil)
    update!(
      phone_verified: true,
      phone_verified_at: Time.current,
      phone: phone_number  # Update phone field if provided
    )
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