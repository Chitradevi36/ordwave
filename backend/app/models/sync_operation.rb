# == Schema Information
# sync_operations: id, organization_id, user_id, idempotency_key, entity_type,
#                  operation, payload, status, server_id, error_message, processed_at
class SyncOperation < ApplicationRecord
  STATUSES  = %w[pending success conflict error].freeze
  ENTITIES  = %w[order payment visit].freeze
  OPERATIONS = %w[create update].freeze

  belongs_to :organization
  belongs_to :user

  validates :idempotency_key, presence: true, uniqueness: true
  validates :status,     inclusion: { in: STATUSES }
  validates :entity_type, inclusion: { in: ENTITIES }
  validates :operation,   inclusion: { in: OPERATIONS }

  scope :pending, -> { where(status: 'pending') }

  def succeeded?; status == 'success' end
  def conflicted?; status == 'conflict' end
end
