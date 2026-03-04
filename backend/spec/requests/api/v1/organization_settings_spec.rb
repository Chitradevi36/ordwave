require 'rails_helper'

RSpec.describe 'Api::V1::OrganizationSettings', type: :request do
  let(:owner_role) { create(:role, name: 'owner') }
  let(:sales_role) { create(:role, name: 'sales_rep') }

  let(:org)    { create(:organization, name: 'Test Corp', gst_number: nil) }
  let(:branch) { create(:branch, organization: org) }
  let(:owner)  { create(:user) }
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
    { 'Authorization' => "Bearer #{user_token}" }
  end

  # ─── GET /api/v1/organizations/:id/settings ───────────────────────────────
  describe 'GET /api/v1/organizations/:id/settings' do
    it 'returns org settings' do
      get "/api/v1/organizations/#{org.id}/settings", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq(org.id)
      expect(json['data']).to have_key('settings')
      expect(json['data']).to have_key('timezone')
    end

    it 'requires authentication' do
      get "/api/v1/organizations/#{org.id}/settings"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 403 for non-member' do
      outsider = create(:user)
      get "/api/v1/organizations/#{org.id}/settings",
          headers: { 'Authorization' => "Bearer #{generate_jwt_for(outsider)}" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── PATCH /api/v1/organizations/:id/settings ─────────────────────────────
  describe 'PATCH /api/v1/organizations/:id/settings' do
    it 'updates basic org info' do
      patch "/api/v1/organizations/#{org.id}/settings",
            params:  { name: 'Updated Corp', contact_email: 'info@updated.com' },
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['name']).to eq('Updated Corp')
      expect(org.reload.name).to eq('Updated Corp')
    end

    it 'updates settings jsonb' do
      patch "/api/v1/organizations/#{org.id}/settings",
            params:  { settings: { fiscal_year_start: 'April' } },
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(org.reload.settings['fiscal_year_start']).to eq('April')
    end

    it 'auto-derives PAN from GSTIN if provided' do
      patch "/api/v1/organizations/#{org.id}/settings",
            params:  { gst_number: '27AAAAA0000A1Z5', pan: 'AAAAA0000A' },
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(org.reload.pan).to eq('AAAAA0000A')
    end

    it 'requires owner or admin' do
      sales_user = create(:user)
      create(:membership, user: sales_user, organization: org, branch: branch, role: sales_role)

      patch "/api/v1/organizations/#{org.id}/settings",
            params:  { name: 'Hacked' },
            headers: { 'Authorization' => "Bearer #{generate_jwt_for(sales_user)}" }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
