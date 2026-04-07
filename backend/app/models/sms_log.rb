# == Schema Information
#
# Table name: sms_logs
#
#  id                :bigint           primary key
#  phone_number      :string           not null
#  message_body      :text             not null
#  message_type      :string           (delivery_otp, registration_otp, delivery_alert, payment_reminder, custom)
#  twilio_sid        :string           unique SMS identifier from Twilio
#  metadata          :jsonb            extra context (stop_id, trip_id, invoice_id, etc)
#  sent_at           :datetime         when SMS was sent
#  created_at        :datetime

class SmsLog < ApplicationRecord
  self.table_name = 'sms_logs'

  # ── Validations ────────────────────────────────────────────────────────────────
  validates :phone_number, :message_body, :twilio_sid, presence: true
  validates :twilio_sid, uniqueness: true
  validates :message_type, inclusion: {
    in: %w[delivery_otp registration_otp login_otp delivery_alert payment_reminder custom],
    message: "%{value} is not a valid message type"
  }

  # ── Scopes ─────────────────────────────────────────────────────────────────────
  scope :by_type, ->(type) { where(message_type: type) }
  scope :today, -> { where('sent_at >= ?', Time.current.beginning_of_day) }
  scope :week, -> { where('sent_at >= ?', 1.week.ago) }

  # ── Callbacks ──────────────────────────────────────────────────────────────────
  before_validation :set_sent_at

  private

  def set_sent_at
    self.sent_at ||= Time.current
  end
end
