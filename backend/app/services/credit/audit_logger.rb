module Credit
  class AuditLogger
    # Credit::AuditLogger.log(
    #   actor:        User,
    #   organization: Organization,
    #   auditable:    AR record,
    #   action:       String (one of AuditLog::ACTIONS),
    #   changes:      Hash,
    #   reason:       String (optional)
    # )
    def self.log(actor:, organization:, auditable:, action:, changes: {}, reason: nil)
      AuditLog.create!(
        actor:          actor,
        organization:   organization,
        auditable:      auditable,
        action:         action,
        changes_data:   changes,
        reason:         reason
      )
    end
  end
end
