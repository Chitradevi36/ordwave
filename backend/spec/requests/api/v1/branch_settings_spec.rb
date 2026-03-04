require 'rails_helper'

RSpec.describe 'Api::V1::BranchSettings', type: :request do
  let(:owner_role)   { create(:role, name: 'owner') }
  let(:manager_role) { create(:role, name: 'manager') }
  let(:sales_role)   { create(:role, name: 'sales_rep') }

  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org, name: 'Main Branch') }
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
    {
      'Authorization'     => "Bearer #{user_token}",
      'X-Organization-Id' => org.id.to_s
    }
  end

  # ─── GET /api/v1/branches/:id/settings ─────────────────────────────────────
  describe 'GET /api/v1/branches/:id/settings' do
    it 'returns branch with settings' do
      get "/api/v1/branches/#{branch.id}/settings", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq(branch.id)
      expect(json['data']).to have_key('settings')
    end

    it 'requires authentication' do
      get "/api/v1/branches/#{branch.id}/settings", headers: { 'X-Organization-Id' => org.id.to_s }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 404 for branch in another org' do
      other_org    = create(:organization)
      other_branch = create(:branch, organization: other_org)

      get "/api/v1/branches/#{other_branch.id}/settings", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── PATCH /api/v1/branches/:id/settings ───────────────────────────────────
  describe 'PATCH /api/v1/branches/:id/settings' do
    it 'updates basic branch info' do
      patch "/api/v1/branches/#{branch.id}/settings",
            params:  { name: 'East Wing', city: 'Pune' },
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['name']).to eq('East Wing')
      expect(branch.reload.city).to eq('Pune')
    end

    it 'updates operational settings' do
      patch "/api/v1/branches/#{branch.id}/settings",
            params:  { settings: { credit_limit: 50000, credit_terms_days: 30, min_order_value: 500 } },
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(branch.reload.settings['credit_limit']).to eq(50000)
      expect(branch.reload.settings['credit_terms_days']).to eq(30)
    end

    it 'merges settings instead of replacing' do
      branch.update!(settings: { 'credit_limit' => 10000, 'opening_time' => '09:00' })

      patch "/api/v1/branches/#{branch.id}/settings",
            params:  { settings: { credit_limit: 20000 } },
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      settings = branch.reload.settings
      expect(settings['credit_limit']).to eq(20000)
      expect(settings['opening_time']).to eq('09:00')  # preserved
    end

    it 'requires owner or admin (not manager)' do
      manager_user = create(:user)
      create(:membership, user: manager_user, organization: org, branch: branch, role: manager_role)

      patch "/api/v1/branches/#{branch.id}/settings",
            params:  { name: 'Hacked Branch' },
            headers: auth_headers(generate_jwt_for(manager_user))

      expect(response).to have_http_status(:forbidden)
    end
  end
end
