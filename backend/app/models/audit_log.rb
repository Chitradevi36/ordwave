class AuditLog < ApplicationRecord
  self.ignored_columns = []

  ACTIONS = %w[
    credit_limit_changed
    flag_changed
    limit_request_created
    limit_request_decided
    credit_policy_updated
    prepayment_sku_added
    prepayment_sku_deactivated
    order_created
    order_updated
    order_submitted
    order_credit_checked
    order_on_hold
    order_approved
    order_rejected
    order_cancelled
    order_price_refreshed
    order_dispatched
    order_delivered
    order_partial_delivery
    trip_created
    trip_planned
    trip_dispatched
    trip_completed
    trip_cancelled
    stop_completed
    stop_exception_flagged
    vehicle_created
    vehicle_updated
    vehicle_deleted
    supplier_created
    supplier_updated
    supplier_deleted
    supplier_blacklisted
    supplier_gstin_changed
    supplier_product_added
    supplier_product_updated
    supplier_product_removed
    purchase_invoice_created
    purchase_invoice_updated
    purchase_invoice_posted
    purchase_invoice_cancelled
    transfer_created
    transfer_updated
    transfer_dispatched
    transfer_received
    transfer_partially_received
    transfer_cancelled
    return_created
    return_updated
    return_submitted
    return_qc_started
    return_qc_completed
    return_cancelled
    credit_note_issued
    credit_note_voided
    invoice_created
    invoice_issued
    invoice_voided
    invoice_pdf_generated
    payment_created
    payment_confirmed
    payment_reversed
    payment_allocation_created
    payment_allocation_reversed
    advance_payment_created
    advance_payment_applied
    advance_payment_refunded
  ].freeze

  belongs_to :organization
  belongs_to :actor, class_name: 'User'

  # Polymorphic auditable (the record that was changed)
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, inclusion: { in: ACTIONS }

  scope :for_auditable, ->(obj)    { where(auditable: obj) }
  scope :recent,        ->         { order(created_at: :desc) }
  scope :for_action,    ->(action) { where(action: action) }

  # Ensure created_at is always set even without updated_at
  self.ignored_columns = [] # keep all columns
end