class PendingRegistration < ApplicationRecord
  STEPS = %w[initiate verify_otp set_password org_details first_branch choose_plan].freeze
  OTP_EXPIRY = 10.minutes
  MAX_OTP_ATTEMPTS = 5

  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
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

  def mark_completed!
    update!(completed: true)
  end

  private

  def set_expiry
    self.expires_at ||= 24.hours.from_now
  end
end
