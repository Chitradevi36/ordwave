require 'rails_helper'

RSpec.describe 'Api::V1::Inventory::Balances', type: :request do
  # ─── Setup ─────────────────────────────────────────────────────────────────
  let(:owner_role)   { create(:role, name: 'owner') }
  let(:manager_role) { create(:role, name: 'manager') }

  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  let(:owner) { create(:user) }
  let!(:owner_membership) do
    create(:membership, user: owner, organization: org, branch: branch, role: owner_role)
  end

  let(:product)  { create(:product, organization: org) }
  let(:product2) { create(:product, organization: org) }

  let!(:level)  { create(:inventory_level, organization: org, branch: branch, product: product,  qty_on_hand: 100, qty_reserved: 10) }
  let!(:level2) { create(:inventory_level, organization: org, branch: branch, product: product2, qty_on_hand: 3,   qty_reserved: 0, min_qty_threshold: 5) }

  def generate_jwt_for(user)
    payload = { sub: user.id, email: user.email, jti: SecureRandom.uuid, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def auth_headers(user = owner)
    {
      'Authorization'     => "Bearer #{generate_jwt_for(user)}",
      'X-Organization-Id' => org.id.to_s,
      'Content-Type'      => 'application/json',
    }
  end

  def json_body = JSON.parse(response.body)

  # ─── GET /api/v1/inventory/balances ──────────────────────────────────────
  describe 'GET /api/v1/inventory/balances' do
    it 'returns 200 with all balances' do
      get '/api/v1/inventory/balances', headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']).to be_an(Array)
      ids = json_body['data'].map { |b| b['id'] }
      expect(ids).to include(level.id, level2.id)
    end

    it 'includes qty_available as on_hand minus reserved' do
      get '/api/v1/inventory/balances', headers: auth_headers

      rec = json_body['data'].find { |b| b['id'] == level.id }
      expect(rec['qty_available'].to_d).to eq(90)
    end

    it 'filters by low_stock=true' do
      get '/api/v1/inventory/balances', params: { low_stock: 'true' }, headers: auth_headers

      ids = json_body['data'].map { |b| b['id'] }
      expect(ids).to     include(level2.id)
      expect(ids).not_to include(level.id)
    end

    it 'filters by branch_id' do
      other_branch  = create(:branch, organization: org)
      other_product = create(:product, organization: org)
      other_level   = create(:inventory_level, organization: org, branch: other_branch, product: other_product)

      get '/api/v1/inventory/balances', params: { branch_id: branch.id }, headers: auth_headers
      ids = json_body['data'].map { |b| b['id'] }
      expect(ids).not_to include(other_level.id)
    end

    it 'returns 401 when unauthenticated' do
      get '/api/v1/inventory/balances'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ─── GET /api/v1/inventory/balances/:id ──────────────────────────────────
  describe 'GET /api/v1/inventory/balances/:id' do
    it 'returns a single balance record' do
      get "/api/v1/inventory/balances/#{level.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['id']).to eq(level.id)
    end

    it 'returns 404 for unknown id' do
      get '/api/v1/inventory/balances/999999', headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
