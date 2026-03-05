require 'rails_helper'

RSpec.describe 'Api::V1::Inventory::Movements', type: :request do
  # ─── Setup ─────────────────────────────────────────────────────────────────
  let(:owner_role) { create(:role, name: 'owner') }
  let(:org)        { create(:organization) }
  let(:branch)     { create(:branch, organization: org) }
  let(:owner)      { create(:user) }
  let!(:owner_membership) do
    create(:membership, user: owner, organization: org, branch: branch, role: owner_role)
  end

  let(:product)  { create(:product, organization: org) }
  let(:product2) { create(:product, organization: org) }

  let!(:mv1) do
    create(:stock_movement,
           organization: org, branch: branch, product: product,
           movement_type: 'purchase_posted', direction: 'in',
           qty: 20, occurred_at: 2.days.ago, created_by: owner)
  end
  let!(:mv2) do
    create(:stock_movement,
           organization: org, branch: branch, product: product2,
           movement_type: 'adjustment_in', direction: 'in',
           qty: 5, occurred_at: 1.day.ago, created_by: owner)
  end

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

  # ─── GET /api/v1/inventory/movements ────────────────────────────────────
  describe 'GET /api/v1/inventory/movements' do
    it 'returns 200 with all movements for the org' do
      get '/api/v1/inventory/movements', headers: auth_headers

      expect(response).to have_http_status(:ok)
      ids = json_body['data'].map { |m| m['id'] }
      expect(ids).to include(mv1.id, mv2.id)
    end

    it 'filters by product_id' do
      get '/api/v1/inventory/movements', params: { product_id: product.id }, headers: auth_headers

      ids = json_body['data'].map { |m| m['id'] }
      expect(ids).to     include(mv1.id)
      expect(ids).not_to include(mv2.id)
    end

    it 'filters by movement_type' do
      get '/api/v1/inventory/movements', params: { movement_type: 'adjustment_in' }, headers: auth_headers

      ids = json_body['data'].map { |m| m['id'] }
      expect(ids).to     include(mv2.id)
      expect(ids).not_to include(mv1.id)
    end

    it 'returns results in occurred_at DESC order' do
      get '/api/v1/inventory/movements', headers: auth_headers
      dates = json_body['data'].map { |m| Time.parse(m['occurred_at']) }
      expect(dates).to eq(dates.sort.reverse)
    end

    it 'does not return movements from other orgs' do
      other_org     = create(:organization)
      other_branch  = create(:branch,        organization: other_org)
      other_product = create(:product,       organization: other_org)
      other_user    = create(:user)
      other_mv      = create(:stock_movement,
                              organization: other_org, branch: other_branch,
                              product: other_product, created_by: other_user)

      get '/api/v1/inventory/movements', headers: auth_headers
      ids = json_body['data'].map { |m| m['id'] }
      expect(ids).not_to include(other_mv.id)
    end

    it 'returns 401 when unauthenticated' do
      get '/api/v1/inventory/movements'
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
