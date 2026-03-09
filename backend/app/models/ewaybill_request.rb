# frozen_string_literal: true

class EwaybillRequest < ApplicationRecord
  STATUSES        = %w[pending generated cancelled expired error].freeze
  TRANSPORT_MODES = %w[road rail air ship].freeze

  # ── Associations ─────────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :sales_invoice, optional: true
  belongs_to :requestable, polymorphic: true, optional: true

  # ── Validations ──────────────────────────────────────────────────────────────
  validates :status, inclusion: { in: STATUSES }
  validates :transport_mode, inclusion: { in: TRANSPORT_MODES }
  validates :ewaybill_number, uniqueness: true, allow_nil: true
  validates :vehicle_number, presence: true, if: -> { transport_mode == 'road' }

  # ── Scopes ───────────────────────────────────────────────────────────────────
  scope :for_org, ->(org_id) { where(organization_id: org_id) }
  scope :by_status, ->(s) { where(status: s) }
  scope :active, -> { where(status: 'generated').where('valid_until > ?', Time.current) }
  scope :expired_uncancelled, -> { where(status: 'generated').where('valid_until <= ?', Time.current) }

  # ── State helpers ────────────────────────────────────────────────────────────
  STATUSES.each { |s| define_method(:"#{s}?") { status == s } }

  def mark_generated!(ewaybill_number:, valid_from:, valid_until:, response_json: {})
    update!(
      status:          'generated',
      ewaybill_number: ewaybill_number,
      valid_from:      valid_from,
      valid_until:     valid_until,
      response_json:   response_json,
      generated_at:    Time.current,
      error_message:   nil
    )
  end

  def mark_cancelled!(reason: nil)
    update!(
      status:       'cancelled',
      cancelled_at: Time.current,
      error_message: reason
    )
  end

  def mark_error!(message)
    update!(
      status:        'error',
      error_message: message
    )
  end

  def expired?
    generated? && valid_until.present? && valid_until < Time.current
  end
end
