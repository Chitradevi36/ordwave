# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvitationMailer, type: :mailer do
  let(:org)  { create(:organization) }
  let(:role) { create(:role, name: 'manager') }
  let(:inviter) { create(:user) }
  let(:invitation) do
    create(:invitation, organization: org, role: role, invited_by: inviter)
  end
  let(:token) { 'sample-invite-token-123' }

  describe '#invite' do
    subject(:mail) { described_class.invite(invitation: invitation, token: token) }

    it 'renders the headers' do
      expect(mail.to).to eq([invitation.email])
      expect(mail.subject).to include(org.name)
      expect(mail.subject).to include('invited')
    end

    it 'renders the body with the accept URL' do
      expect(mail.body.encoded).to include(token)
    end

    it 'includes the inviter name' do
      expect(mail.body.encoded).to include(inviter.full_name).or include('administrator')
    end
  end
end
