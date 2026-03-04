require 'rails_helper'

RSpec.describe 'Api::V1::Users', type: :request do
  let(:owner_role)  { create(:role, name: 'owner') }
  let(:admin_role)  { create(:role, name: 'admin') }
  let(:manager_role) { create(:role, name: 'manager') }
  let(:sales_role)  { create(:role, name: 'sales_rep') }

  let(:org)         { create(:organization) }
  let(:branch)      { create(:branch, organization: org) }
  let(:owner)       { create(:user) }
  let!(:owner_membership) { create(:membership, user: owner, organization: org, branch: branch, role: owner_role) }

  let(:other_user)  { create(:user) }
  let!(:other_membership) { create(:membership, user: other_user, organization: org, branch: branch, role: sales_role) }

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

  # ─── GET /api/v1/users ─────────────────────────────────────────────────────
  describe 'GET /api/v1/users' do
    it 'returns all active members in the organization' do
      get '/api/v1/users', headers: auth_headers

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body)['data'].map { |u| u['id'] }
      expect(ids).to include(owner.id, other_user.id)
    end

    it 'filters by role_id' do
      get '/api/v1/users', params: { role_id: sales_role.id }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body)['data'].map { |u| u['id'] }
      expect(ids).to include(other_user.id)
      expect(ids).not_to include(owner.id)
    end

    it 'filters by search query' do
      get '/api/v1/users', params: { q: other_user.first_name }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body)['data'].map { |u| u['id'] }
      expect(ids).to include(other_user.id)
    end

    it 'requires authentication' do
      get '/api/v1/users', headers: { 'X-Organization-Id' => org.id.to_s }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'requires organization header' do
      get '/api/v1/users', headers: { 'Authorization' => "Bearer #{token}" }
      expect(response).to have_http_status(:bad_request)
    end

    it 'includes membership info in response' do
      get '/api/v1/users', headers: auth_headers

      json = JSON.parse(response.body)
      user_data = json['data'].find { |u| u['id'] == other_user.id }
      expect(user_data['membership']['role']['name']).to eq('sales_rep')
    end
  end

  # ─── GET /api/v1/users/:id ─────────────────────────────────────────────────
  describe 'GET /api/v1/users/:id' do
    it 'returns the user with membership info' do
      get "/api/v1/users/#{other_user.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq(other_user.id)
      expect(json['data']['membership']).to be_present
    end

    it 'returns 404 for unknown user' do
      get '/api/v1/users/9999999', headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── POST /api/v1/users/invite ─────────────────────────────────────────────
  describe 'POST /api/v1/users/invite' do
    let(:valid_params) { { email: 'new@example.com', role_id: sales_role.id, branch_id: branch.id } }

    it 'creates an invitation' do
      post '/api/v1/users/invite', params: valid_params, headers: auth_headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['email']).to eq('new@example.com')
      expect(Invitation.exists?(email: 'new@example.com', organization: org)).to be true
    end

    it 'returns dev token in non-production env' do
      post '/api/v1/users/invite', params: valid_params, headers: auth_headers

      json = JSON.parse(response.body)
      expect(json['data']['token']).to be_present
    end

    it 'rejects invite for existing member' do
      post '/api/v1/users/invite',
           params: { email: other_user.email, role_id: sales_role.id },
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)['errors'].first).to match(/already a member/)
    end

    it 'requires owner or admin role' do
      manager_user = create(:user)
      create(:membership, user: manager_user, organization: org, branch: branch, role: manager_role)
      manager_token = generate_jwt_for(manager_user)

      post '/api/v1/users/invite', params: valid_params, headers: auth_headers(manager_token)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── POST /api/v1/users/:id/deactivate ─────────────────────────────────────
  describe 'POST /api/v1/users/:id/deactivate' do
    it 'soft-deletes the user membership from org' do
      post "/api/v1/users/#{other_user.id}/deactivate", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(other_membership.reload.deleted_at).to be_present
    end

    it 'prevents owner self-deactivation' do
      post "/api/v1/users/#{owner.id}/deactivate", headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'prevents deactivating the organization owner' do
      # Try to deactivate the owner (who has owner role)
      admin_user = create(:user)
      create(:membership, user: admin_user, organization: org, branch: branch, role: admin_role)
      admin_token = generate_jwt_for(admin_user)

      post "/api/v1/users/#{owner.id}/deactivate", headers: auth_headers(admin_token)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
