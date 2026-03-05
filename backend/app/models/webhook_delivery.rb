class WebhookDelivery < ApplicationRecord
  STATUSES = %w[pending delivered failed].freeze

  belongs_to :webhook_endpoint
  belongs_to :organization

  validates :event,   presence: true
  validates :status,  inclusion: { in: STATUSES }

  scope :pending,   -> { where(status: "pending") }
  scope :delivered, -> { where(status: "delivered") }
  scope :failed,    -> { where(status: "failed") }
  scope :recent,    -> { order(created_at: :desc) }
end
