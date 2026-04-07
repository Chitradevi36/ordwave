class OtpRequest < ApplicationRecord
  # OTP request for login flow (separate from signup flow)
  OTP_EXPIRY = 10.minutes
  MAX_OTP_ATTEMPTS = 5

  # Enums
  enum identifier_type: { email: 0, phone: 1 }

  # Validations
  validates :identifier, presence: true
  validates :otp_code, presence: true
  validates :identifier_type, presence: true
  validates :request_id, presence: true, uniqueness: true

  # Scopes
  scope :active, -> { where('created_at > ?', OTP_EXPIRY.ago) }
  scope :for_identifier, ->(identifier) { where(identifier: normalize_identifier(identifier)) }

  before_create :generate_request_id

  def generate_otp!
    update!(
      otp_code: format('%06d', SecureRandom.random_number(1_000_000)),
      otp_sent_at: Time.current,
      otp_attempts: 0
    )
  end

  def verify_otp(code)
    return false if otp_expired? || otp_attempts >= MAX_OTP_ATTEMPTS
    return false if otp_code != code

    if otp_code == code
      update!(verified: true, verified_at: Time.current)
      return true
    end

    increment!(:otp_attempts)
    false
  end

  def otp_expired?
    otp_sent_at.blank? || otp_sent_at < OTP_EXPIRY.ago
  end

  def expired?
    created_at < OTP_EXPIRY.ago
  end

  def valid_otp?
    !otp_expired? && otp_attempts < MAX_OTP_ATTEMPTS
  end

  # Find user by identifier (email or phone)
  def find_user
    case identifier_type.to_sym
    when :email
      User.find_by(email: identifier)
    when :phone
      User.find_by(phone: identifier)
    end
  end

  private

  def generate_request_id
    self.request_id ||= SecureRandom.hex(16)
  end

  def self.normalize_identifier(identifier)
    if identifier.match?(/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/)
      # Email — lowercase
      identifier.downcase.strip
    else
      # Phone — digits only
      identifier.gsub(/\D/, '')
    end
  end
end
