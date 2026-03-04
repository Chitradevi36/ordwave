require 'rails_helper'

RSpec.describe 'Api::V1::Products', type: :request do
  # ─── Shared setup ─────────────────────────────────────────────────────────
  let(:owner_role)   { create(:role, name: 'owner') }
  let(:manager_role) { create(:role, name: 'manager') }
  let(:sales_role)   { create(:role, name: 'sales_rep') }

  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  let(:owner)   { create(:user) }
  let(:manager) { create(:user) }
  let(:sales)   { create(:user) }

  let!(:owner_membership)   { create(:membership, user: owner,   organization: org, branch: branch, role: owner_role) }
  let!(:manager_membership) { create(:membership, user: manager, organization: org, branch: branch, role: manager_role) }
  let!(:sales_membership)   { create(:membership, user: sales,   organization: org, branch: branch, role: sales_role) }

  let(:hsn)      { create(:hsn_sac_code, code: '10061090', gst_rate: 5) }
  let(:category) { create(:product_category, organization: org) }
  let(:uom)      { create(:unit_of_measure) }

  let!(:product) do
    create(:product, organization: org, product_category: category,
                     unit_of_measure: uom, hsn_sac_code: hsn, status: 'active')
  end

  def generate_jwt_for(user)
    payload = { sub: user.id, email: user.email, jti: SecureRandom.uuid, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def auth_headers(user = owner)
    {
      'Authorization'      => "Bearer #{generate_jwt_for(user)}",
      'X-Organization-Id'  => org.id.to_s
    }
  end

  def json_body = JSON.parse(response.body)

  # ─── GET /api/v1/products ───────────────────────────────────────────────────
  describe 'GET /api/v1/products' do
    it 'returns paginated products for owner' do
      get '/api/v1/products', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json_body['data']).to be_an(Array)
      expect(json_body['data'].first['id']).to eq(product.id)
    end

    it 'is accessible to sales_rep (member)' do
      get '/api/v1/products', headers: auth_headers(sales)
      expect(response).to have_http_status(:ok)
    end

    it 'requires authentication' do
      get '/api/v1/products'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'filters by status' do
      disc = create(:product, organization: org, product_category: category,
                              unit_of_measure: uom, hsn_sac_code: hsn, status: 'discontinued')
      get '/api/v1/products', params: { status: 'discontinued' }, headers: auth_headers
      ids = json_body['data'].map { |r| r['id'] }
      expect(ids).to include(disc.id)
      expect(ids).not_to include(product.id)
    end

    it 'searches by name' do
      get '/api/v1/products', params: { q: product.name[0..4] }, headers: auth_headers
      expect(json_body['data'].map { |r| r['id'] }).to include(product.id)
    end

    it 'excludes soft-deleted products' do
      product.soft_delete!
      get '/api/v1/products', headers: auth_headers
      expect(json_body['data'].map { |r| r['id'] }).not_to include(product.id)
    end
  end

  # ─── GET /api/v1/products/:id ──────────────────────────────────────────────
  describe 'GET /api/v1/products/:id' do
    it 'returns product detail' do
      get "/api/v1/products/#{product.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)
      data = json_body['data']
      expect(data['id']).to eq(product.id)
      expect(data['hsn']).to include('code' => hsn.code)
    end

    it 'returns 404 for deleted product' do
      product.soft_delete!
      get "/api/v1/products/#{product.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── POST /api/v1/products ─────────────────────────────────────────────────
  describe 'POST /api/v1/products' do
    let(:valid_params) do
      {
        product: {
          sku:                 'NEW-SKU-001',
          name:                'New Product',
          product_category_id: category.id,
          unit_of_measure_id:  uom.id,
          hsn_sac_code_id:     hsn.id,
          min_order_qty:       1,
          status:              'active'
        }
      }
    end

    it 'creates a product for manager' do
      post '/api/v1/products', params: valid_params, headers: auth_headers(manager)
      expect(response).to have_http_status(:created)
      expect(json_body['data']['sku']).to eq('NEW-SKU-001')
      # gst_rate auto-filled from HSN
      expect(json_body['data']['gst_rate']).to eq(hsn.gst_rate)
    end

    it 'creates a product for owner' do
      post '/api/v1/products', params: valid_params, headers: auth_headers
      expect(response).to have_http_status(:created)
    end

    it 'forbids sales_rep' do
      post '/api/v1/products', params: valid_params, headers: auth_headers(sales)
      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects duplicate SKU within same org' do
      params = valid_params.deep_merge(product: { sku: product.sku })
      post '/api/v1/products', params: params, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects missing required fields' do
      post '/api/v1/products', params: { product: { name: '' } }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ─── PATCH /api/v1/products/:id ────────────────────────────────────────────
  describe 'PATCH /api/v1/products/:id' do
    it 'updates name' do
      patch "/api/v1/products/#{product.id}",
            params: { product: { name: 'Updated Name' } },
            headers: auth_headers(manager)
      expect(response).to have_http_status(:ok)
      expect(json_body['data']['name']).to eq('Updated Name')
    end

    it 'forbids sales_rep' do
      patch "/api/v1/products/#{product.id}",
            params: { product: { name: 'Hacked' } },
            headers: auth_headers(sales)
      expect(response).to have_http_status(:forbidden)
    end

    it 'auto-fills gst_rate when hsn_sac_code_id changes' do
      new_hsn = create(:hsn_sac_code, code: '15121110', gst_rate: 12)
      patch "/api/v1/products/#{product.id}",
            params: { product: { hsn_sac_code_id: new_hsn.id } },
            headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json_body['data']['gst_rate']).to eq(12)
    end
  end

  # ─── DELETE /api/v1/products/:id ───────────────────────────────────────────
  describe 'DELETE /api/v1/products/:id' do
    it 'soft-deletes the product' do
      delete "/api/v1/products/#{product.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(product.reload.deleted_at).not_to be_nil
    end

    it 'forbids sales_rep' do
      delete "/api/v1/products/#{product.id}", headers: auth_headers(sales)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── POST /api/v1/products/:id/discontinue ─────────────────────────────────
  describe 'POST /api/v1/products/:id/discontinue' do
    it 'sets status to discontinued' do
      post "/api/v1/products/#{product.id}/discontinue", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(product.reload.status).to eq('discontinued')
    end

    it 'forbids sales_rep' do
      post "/api/v1/products/#{product.id}/discontinue", headers: auth_headers(sales)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── GET /api/v1/products/sample_csv ───────────────────────────────────────
  describe 'GET /api/v1/products/sample_csv' do
    it 'returns a CSV file for manager' do
      get '/api/v1/products/sample_csv', headers: auth_headers(manager)
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/csv')
      expect(response.headers['Content-Disposition']).to include('sample_products.csv')
    end

    it 'includes expected CSV headers' do
      get '/api/v1/products/sample_csv', headers: auth_headers
      rows = CSV.parse(response.body, headers: true)
      expect(rows.headers).to include('sku', 'name', 'hsn_code', 'uom_symbol', 'min_order_qty')
    end

    it 'includes at least one sample data row' do
      get '/api/v1/products/sample_csv', headers: auth_headers
      rows = CSV.parse(response.body, headers: true)
      expect(rows.size).to be >= 1
    end

    it 'forbids sales_rep' do
      get '/api/v1/products/sample_csv', headers: auth_headers(sales)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── POST /api/v1/products/bulk_import ─────────────────────────────────────
  describe 'POST /api/v1/products/bulk_import' do
    def csv_file(content, filename: 'products.csv')
      Rack::Test::UploadedFile.new(
        StringIO.new(content),
        'text/csv',
        original_filename: filename
      )
    end

    let(:valid_csv) do
      <<~CSV
        sku,name,category_name,uom_symbol,hsn_code,min_order_qty,purchase_price,barcode,weight_kg,description,image_url,status
        IMPORT-001,Rice 5kg,Grains,#{uom.symbol},#{hsn.code},10,350.00,,,Premium rice,,active
      CSV
    end

    it 'imports valid rows for manager' do
      post '/api/v1/products/bulk_import',
           params:  { file: csv_file(valid_csv) },
           headers: auth_headers(manager)
      expect(response).to have_http_status(:ok)
      expect(json_body['data']['success_count']).to eq(1)
    end

    it 'skips duplicate SKUs' do
      dup_csv = <<~CSV
        sku,name,category_name,uom_symbol,hsn_code,min_order_qty,purchase_price,barcode,weight_kg,description,image_url,status
        #{product.sku},Duplicate,Grains,#{uom.symbol},#{hsn.code},1,,,,,, active
      CSV
      post '/api/v1/products/bulk_import',
           params:  { file: csv_file(dup_csv) },
           headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json_body['data']['skipped_rows'].length).to eq(1)
      expect(json_body['data']['success_count']).to eq(0)
    end

    it 'returns error for unknown HSN code' do
      bad_csv = <<~CSV
        sku,name,category_name,uom_symbol,hsn_code,min_order_qty,purchase_price,barcode,weight_kg,description,image_url,status
        BAD-001,Bad Product,Grains,#{uom.symbol},UNKNOWN_HSN,1,,,,,,active
      CSV
      post '/api/v1/products/bulk_import',
           params:  { file: csv_file(bad_csv) },
           headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json_body['data']['failed_rows'].length).to eq(1)
      expect(json_body['data']['failed_rows'].first['errors'].first).to include('not found in master')
    end

    it 'returns 400 when no file is attached' do
      post '/api/v1/products/bulk_import', headers: auth_headers
      expect(response).to have_http_status(:bad_request)
    end

    it 'forbids sales_rep' do
      post '/api/v1/products/bulk_import',
           params:  { file: csv_file(valid_csv) },
           headers: auth_headers(sales)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── GET /api/v1/products/generate_sku ─────────────────────────────────────
  describe 'GET /api/v1/products/generate_sku' do
    it 'returns a generated SKU for owner' do
      get '/api/v1/products/generate_sku', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json_body['data']['sku']).to match(/\APROD-[A-Z0-9]{6}\z/)
    end

    it 'returns a generated SKU for manager' do
      get '/api/v1/products/generate_sku', headers: auth_headers(manager)
      expect(response).to have_http_status(:ok)
      expect(json_body['data']['sku']).to match(/\APROD-[A-Z0-9]{6}\z/)
    end

    it 'returns a SKU that is not already taken' do
      get '/api/v1/products/generate_sku', headers: auth_headers
      expect(json_body['data']['sku']).not_to eq(product.sku)
    end

    it 'forbids sales_rep' do
      get '/api/v1/products/generate_sku', headers: auth_headers(sales)
      expect(response).to have_http_status(:forbidden)
    end

    it 'requires authentication' do
      get '/api/v1/products/generate_sku'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ─── Purchase price visibility (role-based) ─────────────────────────────────
  describe 'purchase_price visibility in product detail' do
    before do
      product.update!(purchase_price: 250.00)
    end

    it 'is included for owner' do
      get "/api/v1/products/#{product.id}", headers: auth_headers(owner)
      expect(response).to have_http_status(:ok)
      expect(json_body['data']).to have_key('purchase_price')
      expect(json_body['data']['purchase_price'].to_f).to eq(250.00)
    end

    it 'is included for admin' do
      admin_role = create(:role, name: 'admin')
      admin_user = create(:user)
      create(:membership, user: admin_user, organization: org, branch: branch, role: admin_role)
      get "/api/v1/products/#{product.id}", headers: auth_headers(admin_user)
      expect(response).to have_http_status(:ok)
      expect(json_body['data']).to have_key('purchase_price')
    end

    it 'is excluded for sales_rep' do
      get "/api/v1/products/#{product.id}", headers: auth_headers(sales)
      expect(response).to have_http_status(:ok)
      expect(json_body['data']).not_to have_key('purchase_price')
    end

    it 'is excluded for manager' do
      get "/api/v1/products/#{product.id}", headers: auth_headers(manager)
      expect(response).to have_http_status(:ok)
      expect(json_body['data']).not_to have_key('purchase_price')
    end
  end

  # ─── Minimal create (advanced fields optional) ──────────────────────────────
  describe 'POST /api/v1/products — minimal fields' do
    it 'creates product with only the required fields' do
      params = {
        product: {
          sku:                 'MIN-001',
          name:                'Minimal Product',
          product_category_id: category.id,
          unit_of_measure_id:  uom.id,
          hsn_sac_code_id:     hsn.id,
          status:              'active',
        }
      }
      post '/api/v1/products', params: params, headers: auth_headers(manager)
      expect(response).to have_http_status(:created)
      data = json_body['data']
      expect(data['sku']).to eq('MIN-001')
      expect(data['gst_rate']).to eq(hsn.gst_rate)          # auto-filled
      expect(data['min_order_qty']).to eq(1)                 # default
    end

    it 'omitting advanced fields does not cause errors' do
      params = {
        product: {
          sku:                 'MIN-002',
          name:                'Another Minimal',
          product_category_id: category.id,
          unit_of_measure_id:  uom.id,
          hsn_sac_code_id:     hsn.id,
          status:              'active',
        }
      }
      post '/api/v1/products', params: params, headers: auth_headers
      expect(response).to have_http_status(:created)
      prod = Product.find(json_body['data']['id'])
      expect(prod.barcode).to be_nil
      expect(prod.weight_kg).to be_nil
      expect(prod.description).to be_nil
      expect(prod.purchase_price).to be_nil
    end
  end
end
