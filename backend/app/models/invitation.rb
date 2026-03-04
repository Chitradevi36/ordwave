class Invitation < ApplicationRecord
  STATUSES = %w[pending accepted revoked expired].freeze

  # Associations
  belongs_to :organization
  belongs_to :role
  belongs_to :branch, optional: true
  belongs_to :invited_by, class_name: 'User'

  # Validations
  validates :email,      presence: true,
                         format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status,     presence: true, inclusion: { in: STATUSES }
  validates :expires_at, presence: true

  # Scopes
  scope :pending,   -> { where(status: 'pending') }
  scope :accepted,  -> { where(status: 'accepted') }
  scope :active,    -> { pending.where('expires_at > ?', Time.current) }

  # Token helpers
  def self.generate_token
    SecureRandom.urlsafe_base64(32)
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def expired?
    expires_at < Time.current
  end

  def pending?
    status == 'pending'
  end

  def accept!(user)
    update!(status: 'accepted', accepted_at: Time.current)
    Membership.create!(
      user:         user,
      organization: organization,
      branch:       branch || organization.branches.first,
      role:         role,
      active:       true,
      status:       'active'
    )
  end

  def revoke!
    update!(status: 'revoked')
  end
end
