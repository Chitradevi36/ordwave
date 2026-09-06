class DeliveryProof < ApplicationRecord
  PROOF_TYPES = %w[photo signature otp override].freeze

  # ── ActiveStorage ─────────────────────────────────────────────────────────
  has_one_attached :photo
  has_one_attached :signature_image

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :trip_stop
  belongs_to :overridden_by, class_name: 'User', optional: true

  # ── Validations ──────────────────────────────────────────────────────────
  # validates :proof_type, inclusion: { in: PROOF_TYPES }
  validates :override_reason, presence: true, if: -> { proof_type == 'override' }

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :recent, -> { order(created_at: :desc) }

  # ── OTP helpers ──────────────────────────────────────────────────────────
  # Store a bcrypt digest of the OTP so raw value is never persisted in plain text.
  def otp_matches?(raw_otp)
    return false if otp_code_digest.blank?

    BCrypt::Password.new(otp_code_digest) == raw_otp.to_s
  end

  def self.digest_otp(raw_otp)
    BCrypt::Password.create(raw_otp.to_s)
  end
end
