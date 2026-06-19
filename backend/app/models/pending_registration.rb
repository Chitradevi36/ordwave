class PendingRegistration < ApplicationRecord
  STEPS = %w[initiate verify_otp set_password org_details first_branch choose_plan billing_pending].freeze
  OTP_EXPIRY = 10.minutes
  MAX_OTP_ATTEMPTS = 5

  validate :email_or_phone_present
  validates :email, uniqueness: true, allow_nil: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { email.present? }
  validates :phone, uniqueness: true, allow_nil: true
  validates :current_step, inclusion: { in: STEPS }

  scope :active, -> { where(completed: false).where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  before_create :set_expiry

  def generate_otp!
    self.otp_code = format('%06d', SecureRandom.random_number(1_000_000))
    self.otp_sent_at = Time.current
    self.otp_attempts = 0
    save!
  end

  def identifier
    email.presence || phone.presence
  end

  def verify_otp(code)
    return false if otp_expired? || otp_attempts >= MAX_OTP_ATTEMPTS

    if otp_code == code
      true
    else
      increment!(:otp_attempts)
      false
    end
  end

  def otp_expired?
    otp_sent_at.blank? || otp_sent_at < OTP_EXPIRY.ago
  end

  def advance_to!(step)
    raise ArgumentError, "Invalid step: #{step}" unless STEPS.include?(step.to_s)
    update!(current_step: step)
  end

  def store_data!(hash)
    self.data = data.merge(hash.deep_stringify_keys)
    save!
  end

  private

  def email_or_phone_present
    unless email.present? || phone.present?
      errors.add(:base, 'Either email or phone must be present')
    end
  end

  def mark_completed!
    update!(completed: true)
  end

  private

  def set_expiry
    self.expires_at ||= 24.hours.from_now
  end
end
