class AdminAuditLog < ApplicationRecord
  # ── Associations ───────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :admin_user, class_name: 'User'
  belongs_to :approved_by, class_name: 'User', optional: true

  # ── Validations ────────────────────────────────────────────────────────────
  validates :action_type, presence: true, inclusion: {
    in: %w[create update delete approve reject suspend],
    message: '%{value} is not a valid action type'
  }
  validates :resource_type, presence: true
  validates :organization_id, presence: true
  validates :admin_user_id, presence: true

  # ── Scopes ─────────────────────────────────────────────────────────────────
  scope :by_action, ->(action) { where(action_type: action) }
  scope :by_resource, ->(resource_type) { where(resource_type: resource_type) }
  scope :by_admin, ->(user_id) { where(admin_user_id: user_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_org, ->(org_id) { where(organization_id: org_id) }
  scope :since, ->(date) { where('created_at >= ?', date) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  # ── Instance Methods ───────────────────────────────────────────────────────
  
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

  # ── Class Methods ──────────────────────────────────────────────────────────
  
  def self.cleanup_old_logs(days = 90)
    deleted_count = where('created_at < ?', days.days.ago).delete_all
    Rails.logger.info("Deleted #{deleted_count} audit logs older than #{days} days")
    deleted_count
  end

  def self.suspicious_activity_for_org(organization, hours = 1)
    threshold_time = hours.hours.ago
    recent_logs = for_org(organization).since(threshold_time)

    suspicious = []

    # Check for mass deletions
    delete_count = recent_logs.by_action('delete').count
    if delete_count > 5
      suspicious << {
        type: 'mass_deletion',
        count: delete_count,
        message: "#{delete_count} deletions in last #{hours} hour(s)"
      }
    end

    # Check for permission changes
    perm_changes = recent_logs.by_action('update').by_resource('UserPermissions')
    if perm_changes.count > 3
      suspicious << {
        type: 'permission_changes',
        count: perm_changes.count,
        message: "#{perm_changes.count} permission changes in last #{hours} hour(s)"
      }
    end

    # Check for settings modifications by non-owner
    non_owner_changes = recent_logs
      .by_action('update')
      .by_resource('OrganizationSettings')
      .where.not(admin_user: organization.owner)
    
    if non_owner_changes.any?
      suspicious << {
        type: 'unauthorized_settings',
        count: non_owner_changes.count,
        message: "Settings changed by non-owner (#{non_owner_changes.map { |l| l.admin_user.email }.uniq.join(', ')})"
      }
    end

    suspicious
  end
end
