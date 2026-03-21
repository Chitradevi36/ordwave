# frozen_string_literal: true

class InvoiceGenerationQuarantine < ApplicationRecord
  # Stores failed invoice generation attempts for review and retry
  # Tracks context needed to reprocess the invoice generation
  
  STATUSES = %w[quarantined processing resolved archived].freeze

  belongs_to :organization
  belongs_to :trip_stop
  belongs_to :sales_order
  belongs_to :branch
  belongs_to :resolved_by, class_name: "User", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :error_message, presence: true
  validates :delivered_lines, presence: true
  validates :trip_stop_id, uniqueness: { scope: [:organization_id], message: "can only have one quarantine entry per stop" }

  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :for_org, ->(org) { where(organization: org) }
  scope :unresolved, -> { where.not(status: %w[resolved archived]) }
  scope :oldest_first, -> { order(:created_at) }
  scope :newest_first, -> { order(created_at: :desc) }
  scope :by_days_old, ->(days) { where("created_at <= ?", days.days.ago) }

  def days_in_quarantine
    ((Time.current - created_at) / 1.day).to_i
  end

  def quarantine_urgent?
    # Flag as urgent if > 3 days in quarantine or > 2 retry attempts
    days_in_quarantine >= 3 || retry_count >= 2
  end

  def customer
    sales_order.customer
  end

  def order_number
    sales_order.order_number
  end

  def trip_number
    trip_stop.delivery_trip.trip_number
  end
end
