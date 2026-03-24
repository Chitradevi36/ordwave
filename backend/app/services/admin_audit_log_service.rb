class AdminAuditLogService
  def self.log_action(
    admin_user:,
    organization:,
    action_type:,
    resource_type:,
    resource_id: nil,
    resource_name: nil,
    changes: {},
    reason: nil,
    request: nil,
    before_values: {},
    after_values: {}
  )
    AdminAuditLog.create!(
      organization:,
      admin_user:,
      action_type:,
      resource_type:,
      resource_id:,
      resource_name:,
      changes:,
      reason:,
      before_values:,
      after_values:,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent,
      session_id: request&.session&.id
    )
  rescue => e
    Rails.logger.error("Failed to log admin action: #{e.message}")
    nil
  end

  # Specific logging methods for common admin actions
  def self.log_user_created(admin_user, organization, user, request)
    log_action(
      admin_user:,
      organization:,
      action_type: 'create',
      resource_type: 'User',
      resource_id: user.id,
      resource_name: user.email,
      after_values: user_attributes(user),
      request:
    )
  end

  def self.log_user_updated(admin_user, organization, user, changes, request)
    log_action(
      admin_user:,
      organization:,
      action_type: 'update',
      resource_type: 'User',
      resource_id: user.id,
      resource_name: user.email,
      changes:,
      before_values: extract_changed_values(user, changes, :before),
      after_values: extract_changed_values(user, changes, :after),
      request:
    )
  end

  def self.log_user_deleted(admin_user, organization, user, reason, request)
    log_action(
      admin_user:,
      organization:,
      action_type: 'delete',
      resource_type: 'User',
      resource_id: user.id,
      resource_name: user.email,
      reason:,
      before_values: user_attributes(user),
      request:
    )
  end

  def self.log_permissions_changed(admin_user, organization, user, permission_changes, request)
    log_action(
      admin_user:,
      organization:,
      action_type: 'update',
      resource_type: 'UserPermissions',
      resource_id: user.id,
      resource_name: user.email,
      changes: permission_changes,
      request:
    )
  end

  def self.log_settings_changed(admin_user, organization, setting_key, old_value, new_value, request)
    log_action(
      admin_user:,
      organization:,
      action_type: 'update',
      resource_type: 'OrganizationSettings',
      resource_id: organization.id,
      resource_name: setting_key,
      changes: { setting_key => [old_value, new_value] },
      before_values: { setting_key => old_value },
      after_values: { setting_key => new_value },
      request:
    )
  end

  private

  def self.user_attributes(user)
    {
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      status: user.status,
      created_at: user.created_at
    }
  end

  def self.extract_changed_values(record, changes, type)
    result = {}
    changes.each do |key, (before, after)|
      result[key] = type == :before ? before : after
    end
    result
  end
end
