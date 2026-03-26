# frozen_string_literal: true

# Sends onboarding-related emails to users
class OnboardingMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_FROM_ADDRESS', 'noreply@orderlane.pro')

  # Sends first order reminder email 48 hours after onboarding completion
  # Called by: SendOnboardingReminderJob
  #
  # @param user [User] The organization owner
  # @param organization [Organization] The organization that completed onboarding
  def first_order_reminder(user, organization)
    @user = user
    @organization = organization
    @first_name = user.first_name || 'there'
    @dashboard_link = dashboard_url(organization_id: organization.id)
    
    return unless user.email.present?

    mail(
      to: user.email,
      subject: "Ready to take your first order? 📦 — #{organization.name}",
      headers: {
        'X-Organization-ID' => organization.id,
        'X-Email-Type'      => 'onboarding_reminder',
        'List-Unsubscribe'  => "<mailto:#{ENV['MAILER_FROM_ADDRESS']}?subject=unsubscribe>"
      }
    )
  end

  # Sends onboarding completion congratulations email
  # Called by: OnboardingProgress when setup is complete
  #
  # @param user [User] The organization owner
  # @param organization [Organization] The newly created organization
  def onboarding_complete(user, organization)
    @user = user
    @organization = organization
    @first_name = user.first_name || 'there'
    @dashboard_link = dashboard_url(organization_id: organization.id)

    return unless user.email.present?

    mail(
      to: user.email,
      subject: "Welcome to Orderlane! 🚀 — #{organization.name}",
      headers: {
        'X-Organization-ID' => organization.id,
        'X-Email-Type'      => 'onboarding_complete',
        'List-Unsubscribe'  => "<mailto:#{ENV['MAILER_FROM_ADDRESS']}?subject=unsubscribe>"
      }
    )
  end

  private

  def dashboard_url(organization_id: nil)
    # Return the frontend dashboard URL
    base_url = ENV.fetch('FRONTEND_URL', 'https://app.orderlane.pro')
    "#{base_url}/dashboard"
  end
end
