# Controllers Integration Guide - Audit Logging

## Overview
This guide shows how to integrate audit logging into existing controllers. We've already created:
- ✅ `AdminAuditLog` model with scopes and business logic
- ✅ `AdminAuditLogService` with specific logging methods
- ✅ Database migration for audit_logs table
- ✅ API endpoint for viewing audit logs

Now we need to integrate audit logging calls into controllers.

## Implementation Steps

### Step 1: Add Audit Logging to Users Controller

**File:** `backend/app/controllers/api/v1/admin/users_controller.rb`

**Add this at the top of the controller:**
```ruby
include AdminAuditLogHelper

before_action :log_audit_trail, only: [:create, :update, :destroy]

private

def log_audit_trail
  @user_before = User.find(params[:id]).attributes if action_name != 'create'
end
```

**Wrap create action:**
```ruby
def create
  @user = User.new(user_params)
  
  if @user.save
    AdminAuditLogService.new(current_user, request).log_user_created(
      @user,
      reason: params[:reason]
    )
    render_success(@user, status: :created)
  else
    render_error(@user.errors)
  end
end
```

**Wrap update action:**
```ruby
def update
  @user = User.find(params[:id])
  old_attributes = @user.attributes.dup
  
  if @user.update(user_params)
    AdminAuditLogService.new(current_user, request).log_user_updated(
      @user,
      old_attributes: old_attributes,
      reason: params[:reason]
    )
    render_success(@user)
  else
    render_error(@user.errors)
  end
end
```

**Wrap destroy action:**
```ruby
def destroy
  @user = User.find(params[:id])
  user_name = @user.email
  
  if @user.destroy
    AdminAuditLogService.new(current_user, request).log_user_deleted(
      user_id: @user.id,
      user_email: user_name,
      reason: params[:reason]
    )
    render_success(message: 'User deleted successfully')
  else
    render_error('Failed to delete user')
  end
end
```

### Step 2: Add Audit Logging to Permissions Controller

**File:** `backend/app/controllers/api/v1/admin/permissions_controller.rb`

**Example implementation:**
```ruby
def grant_permission
  user = User.find(params[:user_id])
  permission = Permission.find(params[:permission_id])
  
  user.permissions << permission unless user.permissions.include?(permission)
  
  AdminAuditLogService.new(current_user, request).log_permissions_changed(
    user,
    old_permissions: user.permissions.pluck(:id) - [permission.id],
    new_permissions: user.permissions.pluck(:id),
    reason: "Granted #{permission.name} permission"
  )
  
  render_success(user)
end

def revoke_permission
  user = User.find(params[:user_id])
  permission = Permission.find(params[:permission_id])
  old_permissions = user.permissions.pluck(:id).dup
  
  user.permissions.delete(permission)
  
  AdminAuditLogService.new(current_user, request).log_permissions_changed(
    user,
    old_permissions: old_permissions,
    new_permissions: user.permissions.pluck(:id),
    reason: "Revoked #{permission.name} permission"
  )
  
  render_success(user)
end
```

### Step 3: Add Audit Logging to Organization Settings Controller

**File:** `backend/app/controllers/api/v1/admin/organization_settings_controller.rb`

```ruby
def update
  @settings = current_organization.organization_settings
  old_settings = @settings.attributes.dup
  
  if @settings.update(settings_params)
    AdminAuditLogService.new(current_user, request).log_settings_changed(
      current_organization,
      setting_name: params[:setting_name],
      old_value: old_settings[params[:setting_name]],
      new_value: @settings[params[:setting_name]],
      reason: params[:reason]
    )
    render_success(@settings)
  else
    render_error(@settings.errors)
  end
end
```

## Helper Module

Create this helper module to share auth checking logic:

**File:** `backend/app/helpers/admin_audit_log_helper.rb`

```ruby
module AdminAuditLogHelper
  private

  def require_admin!
    authorize :admin_audit_log, :view?
  rescue Pundit::NotAuthorizedError
    render_error('Unauthorized', status: :forbidden)
  end

  def audit_service
    @audit_service ||= AdminAuditLogService.new(current_user, request)
  end
end
```

## Integration Checklist

- [ ] Update `users_controller.rb` with audit logging for create/update/delete
- [ ] Update `permissions_controller.rb` with audit logging for permission changes
- [ ] Update `organization_settings_controller.rb` with audit logging for settings changes
- [ ] Create `AdminAuditLogHelper` module in `app/helpers/`
- [ ] Add `AdminAuditLogPolicy` for Pundit authorization
- [ ] Update routes to include audit logs API endpoint
- [ ] Test all logging by performing admin actions and checking audit_logs table
- [ ] Verify admin dashboard queries work correctly
- [ ] Add monitoring/alerting for suspicious activity

## Testing

### Test User Creation Logging
```bash
curl -X POST http://localhost:3000/api/v1/admin/users \
  -H "Authorization: Bearer {admin_token}" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "test@example.com",
      "name": "Test User",
      "role": "sales_rep"
    },
    "reason": "Adding new sales representative"
  }'
```

### Verify in Database
```sql
SELECT * FROM admin_audit_logs 
WHERE action_type = 'create' 
  AND resource_type = 'User'
ORDER BY created_at DESC 
LIMIT 1;
```

### Test Admin Dashboard
Navigate to: `http://localhost:3000/admin/audit-logs`

## Monitoring & Alerts

The `AdminAuditLog.suspicious_activity_for_org` method detects:
- Mass user deletions (>10 in 1 hour)
- Bulk permission changes
- Settings modifications by non-admins
- Unauthorized access attempts

Set up monitoring by checking for suspicious activity:
```ruby
# In a scheduled job
class MonitorAuditAnomalies
  def perform
    Organization.find_each do |org|
      suspicious = AdminAuditLog.suspicious_activity_for_org(org)
      if suspicious.any?
        AdminMailer.suspicious_activity_alert(org, suspicious).deliver_later
      end
    end
  end
end
```

## Error Handling

All logging is wrapped in error handling to prevent transaction failures:
```ruby
def log_action(resource_id:, action_type:, resource_type:, before_values: nil, after_values: nil, reason: nil)
  begin
    AdminAuditLog.create!(
      organization: @organization,
      admin_user: @user,
      resource_type: resource_type,
      resource_id: resource_id,
      action_type: action_type,
      before_values: before_values,
      after_values: after_values,
      reason: reason,
      ip_address: @ip_address,
      user_agent: @user_agent,
      session_id: @session_id
    )
  rescue StandardError => e
    Rails.logger.error("Audit logging failed: #{e.message}")
    # Do not raise - logging failures shouldn't block transactions
  end
end
```

## Performance Considerations

✅ **Optimized with proper indexes:**
- `organization_id + created_at` - for org audit history
- `admin_user_id + created_at` - for user action tracking
- `resource_type + action_type` - for resource-specific queries
- `status + created_at` - for approval workflow queries
- `action_type` - for action filtering

✅ **Retention and Cleanup:**
- Default retention: 90 days
- Automatic cleanup via rake task: `AdminAuditLog.cleanup_old_logs(180)`
- Soft delete support if needed

## Next Steps

1. Run migration: `bundle exec rake db:migrate`
2. Add audit logging to controllers (see Checklist above)
3. Create Pundit policy for audit log access
4. Test all audit logging functionality
5. Deploy to staging for validation
6. Monitor logs in production dashboard
7. Set up alerting for suspicious activity
