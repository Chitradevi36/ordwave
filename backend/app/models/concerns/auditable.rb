# Concern that automatically writes AuditLog entries on create / update / destroy.
#
# Usage:
#   class SalesOrder < ApplicationRecord
#     include Auditable
#   end
#
# Relies on Current.user and Current.organization (set by BaseController).
# Errors are rescued so a failed audit never prevents the primary transaction.
module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_logs, as: :auditable, dependent: :nullify

    after_create  :_audit_record_created
    after_update  :_audit_record_updated
    after_destroy :_audit_record_deleted
  end

  private

  def _audit_organization
    try(:organization) || Current.organization
  end

  def _audit_actor
    Current.user
  end

  def _audit_record_created
    _write_audit("record_created", {})
  end

  def _audit_record_updated
    _write_audit("record_updated", saved_changes.except("updated_at"))
  end

  def _audit_record_deleted
    _write_audit("record_deleted", attributes)
  end

  def _write_audit(action, changes_data)
    org   = _audit_organization
    actor = _audit_actor

    return unless org && actor

    AuditLog.create!(
      organization: org,
      actor:        actor,
      auditable:    self,
      action:       action,
      changes_data: changes_data
    )
  rescue => e
    Rails.logger.error("[Auditable] #{self.class.name}##{id} – #{e.message}")
  end
end
