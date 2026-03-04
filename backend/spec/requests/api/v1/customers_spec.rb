require 'rails_helper'

RSpec.describe 'Api::V1::Customers', type: :request do
  # ─── Shared setup ──────────────────────────────────────────────────────────
  let(:owner_role)   { create(:role, name: 'owner') }
  let(:manager_role) { create(:role, name: 'manager') }
  let(:sales_role)   { create(:role, name: 'sales_rep') }

  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:route)  { create(:route, organization: org, branch: branch) }

  let(:owner) { create(:user) }
  let!(:owner_membership) do
    create(:membership, user: owner, organization: org, branch: branch, role: owner_role)
  end

  let(:sales_user) { create(:user) }
  let!(:sales_membership) do
    create(:membership, user: sales_user, organization: org, branch: branch, role: sales_role)
  end

  let!(:customer) do
    create(:customer, organization: org, branch: branch, route: route,
           name: 'Rani Stores', code: 'CUST-0001', channel: 'general_trade', tier: 'gold')
  end

  def generate_jwt_for(user)
    payload = { sub: user.id, email: user.email, jti: SecureRandom.uuid, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def auth_headers(user = owner)
    {
      'Authorization'     => "Bearer #{generate_jwt_for(user)}",
      'X-Organization-Id' => org.id.to_s
    }
  end

  def json_body
    JSON.parse(response.body)
  end

  # ─── GET /api/v1/customers ─────────────────────────────────────────────────
  describe 'GET /api/v1/customers' do
    it 'returns paginated customers' do
      get '/api/v1/customers', headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']).to be_an(Array)
      expect(json_body['meta']).to include('total_count', 'current_page')
    end

    it 'filters by channel' do
      c2 = create(:customer, organization: org, branch: branch, channel: 'horeca', code: 'CUST-0002')
      get '/api/v1/customers', params: { channel: 'general_trade' }, headers: auth_headers

      ids = json_body['data'].map { |c| c['id'] }
      expect(ids).to include(customer.id)
      expect(ids).not_to include(c2.id)
    end

    it 'searches by name' do
      get '/api/v1/customers', params: { q: 'Rani' }, headers: auth_headers

      ids = json_body['data'].map { |c| c['id'] }
      expect(ids).to include(customer.id)
    end

    it 'requires authentication' do
      get '/api/v1/customers', headers: { 'X-Organization-Id' => org.id.to_s }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'excludes soft-deleted customers' do
      customer.soft_delete!
      get '/api/v1/customers', headers: auth_headers

      ids = json_body['data'].map { |c| c['id'] }
      expect(ids).not_to include(customer.id)
    end
  end

  # ─── GET /api/v1/customers/:id ─────────────────────────────────────────────
  describe 'GET /api/v1/customers/:id' do
    it 'returns the customer with addresses, contacts, credit_account' do
      get "/api/v1/customers/#{customer.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      data = json_body['data']
      expect(data['id']).to eq(customer.id)
      expect(data).to include('addresses', 'contacts', 'credit_account')
    end

    it 'returns 404 for non-existent customer' do
      get '/api/v1/customers/9999999', headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for customer in another organization' do
      org2 = create(:organization)
      b2   = create(:branch, organization: org2)
      c2   = create(:customer, organization: org2, branch: b2, code: 'CUST-X')

      get "/api/v1/customers/#{c2.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── POST /api/v1/customers ────────────────────────────────────────────────
  describe 'POST /api/v1/customers' do
    let(:valid_params) do
      {
        customer: {
          name:         'New Outlet',
          code:         'CUST-0099',
          channel:      'pharmacy',
          tier:         'silver',
          branch_id:    branch.id,
          route_id:     route.id,
          phone:        '9876543210',
          credit_limit: 25_000
        }
      }
    end

    it 'creates a new customer' do
      expect {
        post '/api/v1/customers', params: valid_params, headers: auth_headers
      }.to change(Customer, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_body['data']['name']).to eq('New Outlet')
    end

    it 'auto-creates a credit account' do
      expect {
        post '/api/v1/customers', params: valid_params, headers: auth_headers
      }.to change(CreditAccount, :count).by(1)
    end

    it 'returns errors for invalid params' do
      post '/api/v1/customers',
           params: { customer: { name: '', code: '', channel: 'bad', tier: 'bad', branch_id: branch.id } },
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to be_present
    end

    it 'sales_rep cannot create customers' do
      post '/api/v1/customers', params: valid_params, headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── PATCH /api/v1/customers/:id ───────────────────────────────────────────
  describe 'PATCH /api/v1/customers/:id' do
    it 'updates the customer' do
      patch "/api/v1/customers/#{customer.id}",
            params: { customer: { name: 'Renamed Store' } },
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['name']).to eq('Renamed Store')
    end

    it 'sales_rep cannot update customers' do
      patch "/api/v1/customers/#{customer.id}",
            params: { customer: { name: 'Hack' } },
            headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── DELETE /api/v1/customers/:id ──────────────────────────────────────────
  describe 'DELETE /api/v1/customers/:id' do
    it 'soft-deletes the customer' do
      delete "/api/v1/customers/#{customer.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(customer.reload.deleted?).to be true
    end

    it 'sales_rep cannot delete customers' do
      delete "/api/v1/customers/#{customer.id}", headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── POST /api/v1/customers/:id/block ──────────────────────────────────────
  describe 'POST /api/v1/customers/:id/block' do
    it 'blocks an active customer' do
      post "/api/v1/customers/#{customer.id}/block", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(customer.reload.status).to eq('blocked')
    end

    it 'sales_rep cannot block customers' do
      post "/api/v1/customers/#{customer.id}/block", headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 404 for non-existent customer' do
      post '/api/v1/customers/9999999/block', headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── POST /api/v1/customers/:id/unblock ────────────────────────────────────
  describe 'POST /api/v1/customers/:id/unblock' do
    before { customer.update!(status: 'blocked') }

    it 'unblocks a blocked customer' do
      post "/api/v1/customers/#{customer.id}/unblock", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(customer.reload.status).to eq('active')
    end

    it 'sales_rep cannot unblock customers' do
      post "/api/v1/customers/#{customer.id}/unblock", headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── POST /api/v1/customers/:id/deactivate ─────────────────────────────────
  describe 'POST /api/v1/customers/:id/deactivate' do
    it 'deactivates an active customer' do
      post "/api/v1/customers/#{customer.id}/deactivate", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(customer.reload.status).to eq('inactive')
    end

    it 'sales_rep cannot deactivate customers' do
      post "/api/v1/customers/#{customer.id}/deactivate", headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── credit_status filter ───────────────────────────────────────────────────
  describe 'GET /api/v1/customers?credit_status=overdue' do
    let!(:overdue_customer) do
      c  = create(:customer, organization: org, branch: branch, code: 'CUST-OVD')
      ca = create(:credit_account, customer: c, credit_limit: 10_000,
                  current_balance: 5_000, overdue_amount: 2_000, overdue_days: 15)
      c
    end

    it 'returns only customers with overdue amounts' do
      get '/api/v1/customers', params: { credit_status: 'overdue' }, headers: auth_headers

      ids = json_body['data'].map { |c| c['id'] }
      expect(ids).to include(overdue_customer.id)
      expect(ids).not_to include(customer.id)
    end
  end

  # ─── status filter ──────────────────────────────────────────────────────────
  describe 'GET /api/v1/customers?status=blocked' do
    let!(:blocked_customer) do
      create(:customer, organization: org, branch: branch, code: 'CUST-BLK', status: 'blocked')
    end

    it 'returns only blocked customers' do
      get '/api/v1/customers', params: { status: 'blocked' }, headers: auth_headers

      ids = json_body['data'].map { |c| c['id'] }
      expect(ids).to include(blocked_customer.id)
      expect(ids).not_to include(customer.id)
    end
  end
end
