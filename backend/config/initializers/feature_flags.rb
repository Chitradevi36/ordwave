# frozen_string_literal: true

# Feature flags for OrderLane Pro
# Used to control experimental or risky features on a per-org or global basis.
# Each flag can be overridden at the organization level if needed.

module FEATURES
  # ── Invoicing ────────────────────────────────────────────────────────────

  def self.auto_invoice_enabled?(organization = nil)
    # If organization-specific override exists, use that
    if organization.present?
      org_setting = organization.credit_policy&.auto_invoice_trigger
      return !org_setting.blank? && org_setting != 'disabled'
    end

    # Global default: enabled
    true
  end

  # ── Email Notifications ──────────────────────────────────────────────────

  def self.invoice_email_notifications_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'invoice_email_notifications')
      return override unless override.nil?
    end
    # Global default: enabled
    true
  end

  def self.invoice_sms_notifications_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'invoice_sms_notifications')
      return override unless override.nil?
    end
    # Global default: disabled (requires SMS gateway setup)
    false
  end

  # ── Onboarding ───────────────────────────────────────────────────────────

  def self.onboarding_reminder_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'onboarding_reminder')
      return override unless override.nil?
    end
    # Global default: enabled (sends friendly reminder 48h after onboarding)
    true
  end

  # ── Collections & Dunning ────────────────────────────────────────────────

  def self.dunning_sequence_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'dunning_sequence')
      return override unless override.nil?
    end
    # Global default: disabled (requires careful tuning)
    false
  end

  def self.bulk_invoice_generation_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'bulk_invoice_generation')
      return override unless override.nil?
    end
    # Global default: enabled
    true
  end

  def self.payment_sync_cascading_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'payment_sync_cascading')
      return override unless override.nil?
    end
    # Global default: enabled
    true
  end

  def self.payment_retry_automation_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'payment_retry_automation')
      return override unless override.nil?
    end
    # Global default: enabled
    true
  end

  def self.dunning_suspension_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'dunning_suspension')
      return override unless override.nil?
    end
    # Global default: disabled (requires careful tuning per org)
    false
  end

  # ── Bank Reconciliation ──────────────────────────────────────────────────

  def self.bank_reconciliation_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'bank_reconciliation')
      return override unless override.nil?
    end
    # Global default: enabled
    true
  end

  def self.bank_reconciliation_auto_post_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'bank_reconciliation_auto_post')
      return override unless override.nil?
    end
    # Global default: enabled (auto-post high-confidence matches)
    true
  end

  # ── Delivery & Route Optimization ────────────────────────────────────────

  def self.route_optimization_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'route_optimization')
      return override unless override.nil?
    end
    # Global default: disabled (requires OSRM setup)
    false
  end

def self.geofence_validation_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'geofence_validation')
      return override unless override.nil?
    end
    # Global default: disabled (requires mobile app update)
    false
  end

  def self.failed_delivery_auto_reschedule_enabled?(organization = nil)
    if organization.present?
      override = organization.settings&.dig('feature_flags', 'failed_delivery_auto_reschedule')
      return override unless override.nil?
    end
    # Global default: enabled
    true
  end
end
