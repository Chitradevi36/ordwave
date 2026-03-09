# frozen_string_literal: true

class DeliveryRejection < ApplicationRecord
  REASON_CODES = %w[
    customer_refused
    quality_issue
    expired
    short_supply
    wrong_item
    damaged
    other
  ].freeze

  CONDITIONS = %w[unopened opened damaged].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :trip_stop
  belongs_to :sales_order
  belongs_to :product
  belongs_to :rejected_by, class_name: 'User'
  belongs_to :return_request, optional: true

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :qty_rejected, numericality: { greater_than: 0 }
  validates :reason_code, inclusion: { in: REASON_CODES }
  validates :condition, inclusion: { in: CONDITIONS }

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :for_trip_stop, ->(stop_id) { where(trip_stop_id: stop_id) }
  scope :with_auto_return, -> { where(auto_return: true) }
  scope :by_reason, ->(code) { where(reason_code: code) }
  scope :pending_return, -> { where(auto_return: true, return_request_id: nil) }
end
