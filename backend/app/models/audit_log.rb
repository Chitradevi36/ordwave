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
  ].freeze

  belongs_to :organization
  belongs_to :actor, class_name: 'User'

  # Polymorphic auditable (the record that was changed)
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, inclusion: { in: ACTIONS }

  scope :for_auditable, ->(obj)    { where(auditable: obj) }
  scope :recent,         ->         { order(created_at: :desc) }
  scope :for_action,     ->(action) { where(action: action) }

  # Ensure created_at is always set even without updated_at
  self.ignored_columns = [] # keep all columns
end
