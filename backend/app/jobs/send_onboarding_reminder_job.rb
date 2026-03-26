# frozen_string_literal: true

# Sends a reminder email to newly onboarded organizations
# if they haven't added their first order within 48 hours.
#
# Triggered by: OnboardingProgress when onboarding is marked complete
# Execution: 48 hours after job enqueue (perform_in)
#
# This job:
# 1. Checks if organization has any sales orders
# 2. If no orders, sends reminder email to the owner
# 3. Silently discards if org deleted or already has orders
#
class SendOnboardingReminderJob < ApplicationJob
  queue_as :emails

  # Retry on transient errors (network, timeout, etc)
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Discard silently on permanent failures
  discard_on ActiveRecord::RecordNotFound   # Org/user deleted
  discard_on ArgumentError                   # Invalid arguments

  # @param organization_id [Integer] Organization that completed onboarding
  def perform(organization_id)
    organization = Organization.find(organization_id)
    
    # Check if organization already has sales orders (user might have created one)
    if organization.sales_orders.any?
      Rails.logger.info("[SendOnboardingReminderJob] Org #{organization_id} already has orders, skipping reminder")
      return
    end

    # Get owner user for this organization
    owner_membership = organization.memberships.joins(:role).where(roles: { name: 'owner' }).first
    unless owner_membership&.user
      Rails.logger.warn("[SendOnboardingReminderJob] No owner found for org #{organization_id}")
      return
    end

    owner = owner_membership.user

    # Skip if feature disabled
    unless FEATURES.onboarding_reminder_enabled?(organization)
      Rails.logger.info("[SendOnboardingReminderJob] Onboarding reminders disabled for org #{organization_id}")
      return
    end

    # Skip if no email
    unless owner.email.present?
      Rails.logger.warn("[SendOnboardingReminderJob] No email for owner of org #{organization_id}")
      return
    end

    started_at = Time.current

    begin
      OnboardingMailer.first_order_reminder(owner, organization).deliver_later

      duration = ((Time.current - started_at) * 1000).round
      Rails.logger.info("[SendOnboardingReminderJob] Reminder email enqueued for org #{organization_id} to #{owner.email} (#{duration}ms)")

      # Record that we sent the reminder
      organization.update_setting!('first_order_reminder_sent_at', Time.current.iso8601)
    rescue StandardError => e
      Rails.logger.error("[SendOnboardingReminderJob] Failed to send reminder for org #{organization_id}: #{e.class} — #{e.message}")
      raise
    end
  end
end
