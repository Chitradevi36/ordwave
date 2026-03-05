require 'rails_helper'

RSpec.describe 'Api::V1::Suppliers', type: :request do
  # ─── Shared setup ──────────────────────────────────────────────────────────
  let(:owner_role)     { create(:role, name: 'owner') }
  let(:manager_role)   { create(:role, name: 'manager') }
  let(:sales_role)     { create(:role, name: 'sales_rep') }
  let(:accountant_role){ create(:role, name: 'accountant') }

  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  let(:owner)   { create(:user) }
  let!(:owner_membership) do
    create(:membership, user: owner, organization: org, branch: branch, role: owner_role)
  end

  let(:sales_user) { create(:user) }
  let!(:sales_membership) do
    create(:membership, user: sales_user, organization: org, branch: branch, role: sales_role)
  end

  let(:accountant_user) { create(:user) }
  let!(:accountant_membership) do
    create(:membership, user: accountant_user, organization: org, branch: branch, role: accountant_role)
  end

  let!(:supplier) do
    create(:supplier, organization: org, name: 'Sharma Distributors', code: 'SUPP-001', status: 'active')
  end

  def generate_jwt_for(user)
    payload = { sub: user.id, email: user.email, jti: SecureRandom.uuid, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def auth_headers(user = owner)
    {
      'Authorization'     => "Bearer #{generate_jwt_for(user)}",
      'X-Organization-Id' => org.id.to_s,
      'Content-Type'      => 'application/json'
    }
  end

  def json_body
    JSON.parse(response.body)
  end

  # ─── GET /api/v1/suppliers ─────────────────────────────────────────────────
  describe 'GET /api/v1/suppliers' do
    it 'returns paginated suppliers' do
      get '/api/v1/suppliers', headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']).to be_an(Array)
      expect(json_body['meta']).to include('total_count', 'current_page')
    end

    it 'filters by status' do
      inactive = create(:supplier, organization: org, code: 'SUPP-002', status: 'inactive')
      get '/api/v1/suppliers', params: { status: 'active' }, headers: auth_headers

      ids = json_body['data'].map { |s| s['id'] }
      expect(ids).to include(supplier.id)
      expect(ids).not_to include(inactive.id)
    end

    it 'searches by name' do
      get '/api/v1/suppliers', params: { q: 'Sharma' }, headers: auth_headers

      ids = json_body['data'].map { |s| s['id'] }
      expect(ids).to include(supplier.id)
    end

    it 'excludes soft-deleted suppliers' do
      supplier.soft_delete!
      get '/api/v1/suppliers', headers: auth_headers

      ids = json_body['data'].map { |s| s['id'] }
      expect(ids).not_to include(supplier.id)
    end

    it 'allows sales_rep to list (member? = true)' do
      get '/api/v1/suppliers', headers: auth_headers(sales_user)
      expect(response).to have_http_status(:ok)
    end

    it 'requires authentication' do
      get '/api/v1/suppliers', headers: { 'X-Organization-Id' => org.id.to_s }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ─── GET /api/v1/suppliers/:id ─────────────────────────────────────────────
  describe 'GET /api/v1/suppliers/:id' do
    it 'returns detail with supplier_products array' do
      get "/api/v1/suppliers/#{supplier.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      data = json_body['data']
      expect(data['id']).to eq(supplier.id)
      expect(data).to have_key('supplier_products')
    end

    it 'returns 404 for soft-deleted supplier' do
      supplier.soft_delete!
      get "/api/v1/suppliers/#{supplier.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── POST /api/v1/suppliers ────────────────────────────────────────────────
  describe 'POST /api/v1/suppliers' do
    let(:valid_attrs) do
      {
        supplier: {
          name:               'New Vendor Ltd',
          code:               'SUPP-NEW',
          status:             'active',
          payment_terms_days: 30
        }
      }
    end

    it 'creates a supplier as owner' do
      post '/api/v1/suppliers', params: valid_attrs.to_json, headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(json_body['data']['name']).to eq('New Vendor Ltd')
    end

    it 'creates a supplier as accountant' do
      post '/api/v1/suppliers', params: valid_attrs.to_json, headers: auth_headers(accountant_user)
      expect(response).to have_http_status(:created)
    end

    it 'denies creation for sales_rep' do
      post '/api/v1/suppliers', params: valid_attrs.to_json, headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns errors for invalid data' do
      post '/api/v1/suppliers',
           params: { supplier: { name: '', code: 'SUPP-X', payment_terms_days: 30 } }.to_json,
           headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to be_present
    end

    it 'rejects duplicate code in same org' do
      post '/api/v1/suppliers',
           params: { supplier: { name: 'Dupe', code: 'SUPP-001', payment_terms_days: 30 } }.to_json,
           headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ─── PATCH /api/v1/suppliers/:id ──────────────────────────────────────────
  describe 'PATCH /api/v1/suppliers/:id' do
    it 'updates a supplier' do
      patch "/api/v1/suppliers/#{supplier.id}",
            params: { supplier: { phone: '9123456789' } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['phone']).to eq('9123456789')
    end

    it 'denies update for sales_rep' do
      patch "/api/v1/suppliers/#{supplier.id}",
            params: { supplier: { phone: '9123456789' } }.to_json,
            headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── DELETE /api/v1/suppliers/:id ─────────────────────────────────────────
  describe 'DELETE /api/v1/suppliers/:id' do
    it 'soft-deletes a supplier' do
      delete "/api/v1/suppliers/#{supplier.id}",
             params: { reason: 'No longer active' }.to_json,
             headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(supplier.reload.deleted_at).not_to be_nil
    end

    it 'denies deletion for sales_rep' do
      delete "/api/v1/suppliers/#{supplier.id}", headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── POST /api/v1/suppliers/:id/blacklist ─────────────────────────────────
  describe 'POST /api/v1/suppliers/:id/blacklist' do
    it 'blacklists a supplier' do
      post "/api/v1/suppliers/#{supplier.id}/blacklist", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(supplier.reload.status).to eq('blacklisted')
    end
  end

  # ─── POST /api/v1/suppliers/:id/activate ──────────────────────────────────
  describe 'POST /api/v1/suppliers/:id/activate' do
    before { supplier.update!(status: 'blacklisted') }

    it 'activates a supplier' do
      post "/api/v1/suppliers/#{supplier.id}/activate", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(supplier.reload.status).to eq('active')
    end
  end

  # ─── Nested: supplier_products ────────────────────────────────────────────
  describe 'POST /api/v1/suppliers/:supplier_id/supplier_products' do
    let(:product) do
      create(:product, organization: org)
    end

    it 'adds a product to the supplier' do
      post "/api/v1/suppliers/#{supplier.id}/supplier_products",
           params: {
             supplier_product: { product_id: product.id, purchase_price: 150.50, lead_time_days: 5 }
           }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(json_body['data']['product_id']).to eq(product.id)
      expect(json_body['data']['purchase_price'].to_f).to eq(150.50)
    end

    it 'prevents duplicate product on same supplier' do
      create(:supplier_product, supplier: supplier, product: product)

      post "/api/v1/suppliers/#{supplier.id}/supplier_products",
           params: { supplier_product: { product_id: product.id } }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/v1/suppliers/:supplier_id/supplier_products/:id' do
    let(:product)          { create(:product, organization: org) }
    let!(:supplier_product) { create(:supplier_product, supplier: supplier, product: product) }

    it 'removes the product from supplier' do
      delete "/api/v1/suppliers/#{supplier.id}/supplier_products/#{supplier_product.id}",
             headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(SupplierProduct.exists?(supplier_product.id)).to be false
    end
  end
end
