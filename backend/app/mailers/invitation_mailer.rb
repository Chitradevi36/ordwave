class InvitationMailer < ApplicationMailer
  def invite(invitation:, token:)
    @invitation   = invitation
    @token        = token
    @organization = invitation.organization
    @invited_by   = invitation.invited_by
    @role         = invitation.role
    @accept_url   = "#{ENV.fetch('WEB_APP_URL', 'http://localhost:4400')}/invite/accept?token=#{token}"

    mail(
      to:      invitation.email,
      subject: "You've been invited to join #{@organization.name} on OmniDist"
    )
  end
end
