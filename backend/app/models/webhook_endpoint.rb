class WebhookEndpoint < ApplicationRecord
  EVENTS = %w[
    order.created
    order.approved
    order.delivered
    invoice.generated
    payment.received
    inventory.low_stock
    customer.credit_blocked
  ].freeze

  # ── Associations ────────────────────────────────────────────────────────────
  belongs_to :organization
  has_many   :webhook_deliveries, dependent: :destroy

  # ── Validations ─────────────────────────────────────────────────────────────
  validates :url,    presence: true,
                     format: { with: URI::DEFAULT_PARSER.make_regexp(%w[https]), message: "must be an HTTPS URL" }
  validates :secret, presence: true, length: { minimum: 16 }
  validate  :events_must_be_valid

  # ── Callbacks ───────────────────────────────────────────────────────────────
  before_validation :generate_secret, on: :create

  # ── Scopes ──────────────────────────────────────────────────────────────────
  scope :active,        ->           { where(active: true) }
  scope :for_event,     ->(event)    { where("events @> ?", [event].to_json) }
  scope :healthy,       ->           { where("failure_count < 10") }

  # ── Class helpers ────────────────────────────────────────────────────────────
  # Enqueue delivery for all active endpoints subscribed to this event
  def self.deliver_event(organization:, event:, payload:)
    active.for_event(event).where(organization: organization).find_each do |ep|
      delivery = ep.webhook_deliveries.create!(
        organization: organization,
        event:        event,
        payload:      payload
      )
      DeliverWebhookJob.perform_later(delivery.id)
    end
  end

  # ── Instance helpers ─────────────────────────────────────────────────────────
  def signing_signature(payload_json)
    OpenSSL::HMAC.hexdigest("SHA256", secret, payload_json)
  end

  def disable_due_to_failures!
    update!(active: false)
    Rails.logger.warn("[WebhookEndpoint##{id}] Disabled after #{failure_count} consecutive failures")
  end

  private

  def generate_secret
    self.secret ||= SecureRandom.hex(32)
  end

  def events_must_be_valid
    return if events.blank?
    invalid = Array(events) - EVENTS
    errors.add(:events, "contains unknown events: #{invalid.join(', ')}") if invalid.any?
  end
end
