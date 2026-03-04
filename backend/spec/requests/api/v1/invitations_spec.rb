require 'rails_helper'

RSpec.describe 'Api::V1::Invitations', type: :request do
  let(:owner_role) { create(:role, name: 'owner') }
  let(:sales_role) { create(:role, name: 'sales_rep') }
  let(:org)        { create(:organization) }
  let(:branch)     { create(:branch, organization: org) }
  let(:owner)      { create(:user) }
  let!(:owner_membership) { create(:membership, user: owner, organization: org, branch: branch, role: owner_role) }

  let(:token) { generate_jwt_for(owner) }

  def generate_jwt_for(user)
    payload = {
      sub:   user.id,
      email: user.email,
      jti:   SecureRandom.uuid,
      exp:   24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def auth_headers(user_token = token)
    {
      'Authorization'     => "Bearer #{user_token}",
      'X-Organization-Id' => org.id.to_s
    }
  end

  # ─── POST /api/v1/invitations ──────────────────────────────────────────────
  describe 'POST /api/v1/invitations' do
    let(:valid_params) { { email: 'teammate@example.com', role_id: sales_role.id } }

    it 'creates an invitation and returns it' do
      post '/api/v1/invitations', params: valid_params, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['email']).to eq('teammate@example.com')
      expect(json['data']['status']).to eq('pending')
      expect(json['data']['token']).to be_present  # dev mode
    end

    it 'revokes earlier pending invite when re-inviting same email' do
      first_token_str = Invitation.generate_token
      create(:invitation, email: 'teammate@example.com', organization: org,
             role: sales_role, invited_by: owner,
             token_digest: Invitation.digest(first_token_str), status: 'pending',
             expires_at: 72.hours.from_now)

      post '/api/v1/invitations', params: valid_params, headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(Invitation.pending.where(email: 'teammate@example.com', organization: org).count).to eq(1)
    end

    it 'rejects invalid email' do
      post '/api/v1/invitations', params: { email: 'not-an-email', role_id: sales_role.id }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ─── GET /api/v1/invitations ───────────────────────────────────────────────
  describe 'GET /api/v1/invitations' do
    let!(:invite) do
      raw = Invitation.generate_token
      create(:invitation, email: 'someone@example.com', organization: org,
             role: sales_role, invited_by: owner,
             token_digest: Invitation.digest(raw), status: 'pending',
             expires_at: 72.hours.from_now)
    end

    it 'returns pending invitations' do
      get '/api/v1/invitations', headers: auth_headers

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body)['data'].map { |i| i['id'] }
      expect(ids).to include(invite.id)
    end
  end

  # ─── DELETE /api/v1/invitations/:id ───────────────────────────────────────
  describe 'DELETE /api/v1/invitations/:id' do
    let!(:invite) do
      raw = Invitation.generate_token
      create(:invitation, email: 'pending@example.com', organization: org,
             role: sales_role, invited_by: owner,
             token_digest: Invitation.digest(raw), status: 'pending',
             expires_at: 72.hours.from_now)
    end

    it 'revokes the invitation' do
      delete "/api/v1/invitations/#{invite.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(invite.reload.status).to eq('revoked')
    end
  end

  # ─── POST /api/v1/invitations/accept ──────────────────────────────────────
  describe 'POST /api/v1/invitations/accept' do
    let(:invitee) { create(:user) }
    let(:raw_token) { Invitation.generate_token }
    let!(:invite) do
      create(:invitation, email: invitee.email, organization: org,
             role: sales_role, invited_by: owner,
             token_digest: Invitation.digest(raw_token), status: 'pending',
             expires_at: 72.hours.from_now)
    end
    let(:invitee_token) { generate_jwt_for(invitee) }

    it 'creates a membership for the invitee' do
      post '/api/v1/invitations/accept',
           params:  { token: raw_token },
           headers: { 'Authorization' => "Bearer #{invitee_token}" }

      expect(response).to have_http_status(:ok)
      expect(Membership.active.exists?(user: invitee, organization: org)).to be true
      expect(invite.reload.status).to eq('accepted')
    end

    it 'rejects expired tokens' do
      invite.update!(expires_at: 1.hour.ago)

      post '/api/v1/invitations/accept',
           params:  { token: raw_token },
           headers: { 'Authorization' => "Bearer #{invitee_token}" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].first).to match(/expired/)
    end

    it 'rejects invalid tokens' do
      post '/api/v1/invitations/accept',
           params:  { token: 'invalid-token' },
           headers: { 'Authorization' => "Bearer #{invitee_token}" }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects if user is already a member' do
      create(:membership, user: invitee, organization: org, branch: branch, role: sales_role)

      post '/api/v1/invitations/accept',
           params:  { token: raw_token },
           headers: { 'Authorization' => "Bearer #{invitee_token}" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].first).to match(/already a member/)
    end

    it 'requires authentication' do
      post '/api/v1/invitations/accept', params: { token: raw_token }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
