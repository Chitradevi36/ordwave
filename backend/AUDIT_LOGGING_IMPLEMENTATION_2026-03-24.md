## 📝 AUDIT LOGGING FOR ADMIN CHANGES
## Complete Implementation

**Status:** READY TO IMPLEMENT  
**Estimated Effort:** 3-4 hours  
**Owner:** Backend Engineer  
**Target Date:** April 14, 2026  

---

## 📋 IMPLEMENTATION PLAN

### Step 1: Create Migration
```ruby
# backend/db/migrate/[timestamp]_create_audit_logs_for_admin_changes.rb

class CreateAuditLogsForAdminChanges < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_audit_logs do |t|
      # Basic info
      t.references :organization, null: false, foreign_key: true
      t.references :admin_user, null: false, foreign_key: { to_table: :users }
      
      # What changed
      t.string :action_type, null: false, index: true  # create, update, delete, approve, reject
      t.string :resource_type, null: false, index: true  # User, Role, Settings, Organization, etc.
      t.bigint :resource_id, null: true, index: true  # ID of changed resource
      t.string :resource_name, null: true  # Human-readable name
      
      # Before/After data
      t.jsonb :changes, default: {}, null: false  # What changed
      t.jsonb :before_values, default: {}, null: false  # Previous values
      t.jsonb :after_values, default: {}, null: false  # New values
      
      # Context
      t.string :reason, null: true  # Why the change was made
      t.string :ip_address, null: true
      t.string :user_agent, null: true
      t.string :session_id, null: true
      
      # Status
      t.string :status, null: false, default: 'completed'  # completed, pending, rejected
      t.string :request_id, null: true
      
      # Approval workflow (if needed)
      t.references :approved_by, null: true, foreign_key: { to_table: :users }
      t.datetime :approved_at, null: true
      t.string :approval_reason, null: true

      t.timestamps

      # Indexes for common queries
      t.index [:organization_id, :created_at], name: 'idx_audit_logs_org_time'
      t.index [:admin_user_id, :created_at], name: 'idx_audit_logs_user_time'
      t.index [:resource_type, :action_type], name: 'idx_audit_logs_resource_action'
      t.index [:status, :created_at], name: 'idx_audit_logs_status_time'
      t.index :action_type
    end
  end
end
```

### Step 2: Create Model
```ruby
# backend/app/models/admin_audit_log.rb

class AdminAuditLog < ApplicationRecord
  belongs_to :organization
  belongs_to :admin_user, class_name: 'User'
  belongs_to :approved_by, class_name: 'User', optional: true

  validates :action_type, presence: true, inclusion: {
    in: %w[create update delete approve reject suspend],
    message: '%{value} is not a valid action type'
  }
  validates :resource_type, presence: true
  validates :organization_id, presence: true
  validates :admin_user_id, presence: true

  # Scopes
  scope :by_action, ->(action) { where(action_type: action) }
  scope :by_resource, ->(resource_type) { where(resource_type: resource_type) }
  scope :by_admin, ->(user_id) { where(admin_user_id: user_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_org, ->(org_id) { where(organization_id: org_id) }
  scope :pending_approval, -> { where(status: 'pending') }
  scope :since, ->(date) { where('created_at >= ?', date) }

  # Instance methods
  def formatted_changes
    changes.map { |key, value| "#{key}: #{value[0]} → #{value[1]}" }
  end

  def describe
    "#{action_type.upcase} #{resource_type}: #{resource_name}"
  end

  def admin_name
    admin_user.email
  end

  def approve!(approver:, reason: nil)
    update!(
      status: 'completed',
      approved_by: approver,
      approved_at: Time.current,
      approval_reason: reason
    )
  end

  def reject!(reason:)
    update!(
      status: 'rejected',
      approval_reason: reason
    )
  end
end
```

### Step 3: Create Logging Service
```ruby
# backend/app/services/admin_audit_log_service.rb

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
      after_values: user.attributes.except('password_digest', 'encrypted_password'),
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
      before_values: user.previous_attributes.slice(*changes.keys),
      after_values: user.attributes.slice(*changes.keys),
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
      before_values: user.attributes.except('password_digest', 'encrypted_password'),
      request:
    )
  end

  def self.log_permissions_changed(admin_user, organization, user, changes, request)
    log_action(
      admin_user:,
      organization:,
      action_type: 'update',
      resource_type: 'UserPermissions',
      resource_id: user.id,
      resource_name: user.email,
      changes:,
      request:
    )
  end

  def self.log_settings_changed(admin_user, organization, settings_key, changes, request)
    log_action(
      admin_user:,
      organization:,
      action_type: 'update',
      resource_type: 'OrganizationSettings',
      resource_id: organization.id,
      resource_name: settings_key,
      changes:,
      request:
    )
  end
end
```

### Step 4: Integrate into Controllers
```ruby
# backend/app/controllers/api/v1/admin/users_controller.rb

module Api
  module V1
    module Admin
      class UsersController < BaseController
        before_action :require_admin!

        def create
          user = User.new(user_params)
          user.organization = current_organization

          if user.save
            # Log the action
            AdminAuditLogService.log_user_created(
              current_user, current_organization, user, request
            )

            render json: user, status: :created
          else
            render json: { errors: user.errors }, status: :unprocessable_entity
          end
        end

        def update
          user = User.find(params[:id])
          changes = user.changes_to_save

          if user.update(user_params)
            # Log the action
            AdminAuditLogService.log_user_updated(
              current_user, current_organization, user, changes, request
            )

            render json: user
          else
            render json: { errors: user.errors }, status: :unprocessable_entity
          end
        end

        def destroy
          user = User.find(params[:id])
          reason = params[:reason]

          user.destroy

          # Log the action
          AdminAuditLogService.log_user_deleted(
            current_user, current_organization, user, reason, request
          )

          head :no_content
        end

        private

        def user_params
          params.require(:user).permit(:email, :name, :role, :status)
        end
      end
    end
  end
end

# backend/app/controllers/api/v1/admin/settings_controller.rb

def update
  setting_key = params[:key]
  new_value = params[:value]
  old_value = current_organization.settings[setting_key]

  current_organization.settings[setting_key] = new_value
  current_organization.save!

  # Log the change
  AdminAuditLogService.log_settings_changed(
    current_user,
    current_organization,
    setting_key,
    { setting_key => [old_value, new_value] },
    request
  )

  render json: { message: 'Setting updated' }
end
```

### Step 5: Create Admin Dashboard
```typescript
// web/app/admin/audit-logs/page.tsx

'use client';

import { useEffect, useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Select } from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';

interface AuditLog {
  id: number;
  action_type: string;
  resource_type: string;
  resource_name: string;
  admin_user: { email: string };
  changes: Record<string, any>;
  created_at: string;
  ip_address: string;
}

export default function AuditLogsPage() {
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [filters, setFilters] = useState({
    action: '',
    resource: '',
    admin: '',
    dateFrom: '',
    dateTo: '',
  });

  useEffect(() => {
    fetchLogs();
  }, [filters]);

  async function fetchLogs() {
    const params = new URLSearchParams();
    if (filters.action) params.append('action_type', filters.action);
    if (filters.resource) params.append('resource_type', filters.resource);
    if (filters.admin) params.append('admin_user_id', filters.admin);
    if (filters.dateFrom) params.append('from', filters.dateFrom);
    if (filters.dateTo) params.append('to', filters.dateTo);

    const res = await fetch(`/api/v1/admin/audit-logs?${params}`);
    const data = await res.json();
    setLogs(data.audit_logs);
  }

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold">Admin Audit Logs</h1>

      {/* Filters */}
      <Card>
        <CardHeader>
          <CardTitle>Filters</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
            <Select
              value={filters.action}
              onChange={(e) => setFilters({ ...filters, action: e.target.value })}
            >
              <option value="">All Actions</option>
              <option value="create">Create</option>
              <option value="update">Update</option>
              <option value="delete">Delete</option>
            </Select>

            <Select
              value={filters.resource}
              onChange={(e) => setFilters({ ...filters, resource: e.target.value })}
            >
              <option value="">All Resources</option>
              <option value="User">Users</option>
              <option value="OrganizationSettings">Settings</option>
              <option value="Role">Roles</option>
            </Select>

            <Input
              type="date"
              value={filters.dateFrom}
              onChange={(e) => setFilters({ ...filters, dateFrom: e.target.value })}
              placeholder="From Date"
            />

            <Input
              type="date"
              value={filters.dateTo}
              onChange={(e) => setFilters({ ...filters, dateTo: e.target.value })}
              placeholder="To Date"
            />

            <button
              onClick={() => setFilters({ action: '', resource: '', admin: '', dateFrom: '', dateTo: '' })}
              className="px-4 py-2 bg-gray-200 rounded hover:bg-gray-300"
            >
              Clear Filters
            </button>
          </div>
        </CardContent>
      </Card>

      {/* Logs Table */}
      <Card>
        <CardHeader>
          <CardTitle>Audit Logs ({logs.length})</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="border-b bg-gray-50">
                <tr>
                  <th className="text-left py-2 px-4">Time</th>
                  <th className="text-left py-2 px-4">Admin</th>
                  <th className="text-left py-2 px-4">Action</th>
                  <th className="text-left py-2 px-4">Resource</th>
                  <th className="text-left py-2 px-4">Changes</th>
                  <th className="text-left py-2 px-4">IP</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((log) => (
                  <tr key={log.id} className="border-b hover:bg-gray-50">
                    <td className="py-2 px-4 text-xs">
                      {new Date(log.created_at).toLocaleString()}
                    </td>
                    <td className="py-2 px-4">{log.admin_user.email}</td>
                    <td className="py-2 px-4">
                      <Badge variant={
                        log.action_type === 'delete' ? 'destructive' : 'default'
                      }>
                        {log.action_type}
                      </Badge>
                    </td>
                    <td className="py-2 px-4">
                      {log.resource_type}: {log.resource_name}
                    </td>
                    <td className="py-2 px-4">
                      <details>
                        <summary className="cursor-pointer text-blue-600">
                          View
                        </summary>
                        <pre className="mt-2 p-2 bg-gray-100 text-xs overflow-auto">
                          {JSON.stringify(log.changes, null, 2)}
                        </pre>
                      </details>
                    </td>
                    <td className="py-2 px-4 text-xs">{log.ip_address}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
```

### Step 6: Add Retention Policy
```ruby
# backend/app/models/admin_audit_log.rb

# Add to model:
def self.cleanup_old_logs(days = 90)
  where('created_at < ?', days.days.ago).delete_all
end

# backend/lib/tasks/audit_logs.rake

namespace :audit_logs do
  desc "Clean up audit logs older than 90 days"
  task cleanup: :environment do
    count = AdminAuditLog.cleanup_old_logs(90)
    puts "Deleted #{count} audit log records"
  end
end

# Add to cron:
# Add to config/schedule.yml or use: bundle exec whenever --write-cron
# 0 2 * * * cd /var/www/orderlane_pro && bundle exec rake audit_logs:cleanup RAILS_ENV=production
```

### Step 7: Create Alerts
```ruby
# backend/app/services/audit_alert_service.rb

class AuditAlertService
  def self.check_suspicious_activity(organization)
    # Check for high-risk actions
    recent_logs = AdminAuditLog.for_org(organization).recent.limit(20)

    suspicious_patterns = []

    # Pattern 1: Multiple user deletions in short time
    deletions = recent_logs.by_action('delete').by_resource('User').size
    if deletions > 5
      suspicious_patterns << "#{deletions} users deleted in last hour"
    end

    # Pattern 2: Permission changes by non-owner
    permission_changes = recent_logs.by_action('update').by_resource('UserPermissions')
    non_owner_changes = permission_changes.where.not(admin_user: organization.owner)
    if non_owner_changes.any?
      suspicious_patterns << "Permission changes by non-owner users"
    end

    # Pattern 3: Settings changed multiple times in short period
    setting_changes = recent_logs.by_action('update').by_resource('OrganizationSettings')
    if setting_changes.count > 10
      suspicious_patterns << "#{setting_changes.count} setting changes in short period"
    end

    # Send alerts
    if suspicious_patterns.any?
      AlertService.notify(
        type: 'suspicious_admin_activity',
        organization:,
        patterns: suspicious_patterns,
        severity: 'high'
      )
    end
  end
end
```

---

## 📋 DEPLOYMENT CHECKLIST

- [ ] Create migration file
- [ ] Create AdminAuditLog model
- [ ] Create AdminAuditLogService
- [ ] Add logging to user controllers
- [ ] Add logging to settings controllers
- [ ] Create admin dashboard page
- [ ] Add retention policy job
- [ ] Add alert service
- [ ] Write tests
- [ ] Deploy to staging
- [ ] Test all admin actions
- [ ] Deploy to production
- [ ] Monitor audit logs

---

## ✅ TESTING CHECKLIST

- [ ] Create user and verify log
- [ ] Update user and verify log with changes
- [ ] Delete user and verify log with reason
- [ ] Change organization settings and verify log
- [ ] Change permissions and verify log
- [ ] Filter logs by action
- [ ] Filter logs by admin user
- [ ] Filter logs by date range
- [ ] Verify retention policy removes old logs

---

**Status:** READY TO IMPLEMENT  
**Next Step:** Create PR with this code
