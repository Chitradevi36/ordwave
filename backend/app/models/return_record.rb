# ReturnRecord — individual line items captured by a driver at point of delivery.
#
# NOTE: This model predates the Returns Engine. Going forward, driver-side returns
# should be linked to a ReturnRequest via return_request_id (added in migration
# 20260310000013). New code should use ReturnRequest / ReturnLine directly.
# ReturnRecord is retained for backward-compatibility with existing trip workflows.
#
# DEPRECATED (Phase 5): Do not create new ReturnRecord rows from application code.
# The mobile app should submit returns via POST /api/v1/return_requests instead.
# Existing rows remain queryable for audit purposes. A future migration will drop
# this table once all trip-stop integrations have completed migration.
#
# @deprecated Use ReturnRequest / ReturnLine for all new returns logic.
class ReturnRecord < ApplicationRecord
  CONDITIONS   = %w[good damaged expired].freeze
  REASON_CODES = %w[refused not_home short_delivery quality other].freeze

  # ── Associations ─────────────────────────────────────────────────────────
  belongs_to :trip_stop
  belongs_to :product
  belongs_to :return_request, optional: true  # linked when Returns Engine processes this record

  # ── Validations ──────────────────────────────────────────────────────────
  validates :qty_returned, numericality: { only_integer: true, greater_than: 0 }
  validates :condition,    inclusion: { in: CONDITIONS }
  validates :reason_code,  inclusion: { in: REASON_CODES }

  # ── Scopes ───────────────────────────────────────────────────────────────
  scope :by_condition,   ->(c) { where(condition: c) }
  scope :by_reason_code, ->(r) { where(reason_code: r) }
end
