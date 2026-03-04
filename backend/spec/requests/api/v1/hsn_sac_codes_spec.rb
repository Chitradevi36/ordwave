require 'rails_helper'

RSpec.describe 'Api::V1::HsnSacCodes', type: :request do
  # ─── Shared setup ──────────────────────────────────────────────────────────
  let(:owner_role)   { create(:role, name: 'owner') }
  let(:manager_role) { create(:role, name: 'manager') }
  let(:sales_role)   { create(:role, name: 'sales_rep') }

  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  let(:owner) { create(:user) }
  let!(:owner_membership) do
    create(:membership, user: owner, organization: org, branch: branch, role: owner_role)
  end

  let(:manager) { create(:user) }
  let!(:manager_membership) do
    create(:membership, user: manager, organization: org, branch: branch, role: manager_role)
  end

  let(:sales_user) { create(:user) }
  let!(:sales_membership) do
    create(:membership, user: sales_user, organization: org, branch: branch, role: sales_role)
  end

  let!(:hsn_code) { create(:hsn_sac_code, code: '10061090', gst_rate: 5, active: true) }
  let!(:sac_code) { create(:hsn_sac_code, code: '99631000', code_type: 'SAC', gst_rate: 18, active: true) }

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

  # ─── GET /api/v1/hsn_sac_codes ─────────────────────────────────────────────
  describe 'GET /api/v1/hsn_sac_codes' do
    it 'returns paginated HSN/SAC codes for owner' do
      get '/api/v1/hsn_sac_codes', headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']).to be_an(Array)
      expect(json_body['meta']).to include('total_count', 'current_page')
    end

    it 'returns codes for manager (read access)' do
      get '/api/v1/hsn_sac_codes', headers: auth_headers(manager)
      expect(response).to have_http_status(:ok)
    end

    it 'forbids sales_rep' do
      get '/api/v1/hsn_sac_codes', headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'filters by code_type' do
      get '/api/v1/hsn_sac_codes', params: { code_type: 'SAC' }, headers: auth_headers
      ids = json_body['data'].map { |r| r['id'] }
      expect(ids).to include(sac_code.id)
      expect(ids).not_to include(hsn_code.id)
    end

    it 'filters by gst_rate' do
      get '/api/v1/hsn_sac_codes', params: { gst_rate: 5 }, headers: auth_headers
      ids = json_body['data'].map { |r| r['id'] }
      expect(ids).to include(hsn_code.id)
      expect(ids).not_to include(sac_code.id)
    end

    it 'searches by partial code' do
      get '/api/v1/hsn_sac_codes', params: { q: '10061' }, headers: auth_headers
      ids = json_body['data'].map { |r| r['id'] }
      expect(ids).to include(hsn_code.id)
    end

    it 'requires authentication' do
      get '/api/v1/hsn_sac_codes', headers: { 'X-Organization-Id' => org.id.to_s }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ─── GET /api/v1/hsn_sac_codes/:id ────────────────────────────────────────
  describe 'GET /api/v1/hsn_sac_codes/:id' do
    it 'returns the code details' do
      get "/api/v1/hsn_sac_codes/#{hsn_code.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['code']).to eq('10061090')
      expect(json_body['data']['gst_rate'].to_f).to eq(5.0)
      expect(json_body['data']).to include('cgst_rate', 'sgst_rate', 'igst_rate', 'current_rate')
    end

    it 'returns 404 for unknown id' do
      get '/api/v1/hsn_sac_codes/999999', headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── GET /api/v1/hsn_sac_codes/lookup ─────────────────────────────────────
  describe 'GET /api/v1/hsn_sac_codes/lookup' do
    it 'returns rate details for an existing code' do
      get '/api/v1/hsn_sac_codes/lookup', params: { code: '10061090' }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      data = json_body['data']
      expect(data['gst_rate'].to_f).to eq(5.0)
    end

    it 'returns a warning for an unknown code' do
      get '/api/v1/hsn_sac_codes/lookup', params: { code: 'ZZZZZZZZ' }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['warning']).to be_present
    end
  end

  # ─── POST /api/v1/hsn_sac_codes ────────────────────────────────────────────
  describe 'POST /api/v1/hsn_sac_codes' do
    let(:valid_params) do
      {
        hsn_sac_code: {
          code:           '85171200',
          code_type:      'HSN',
          description:    'Smartphones',
          chapter:        '85',
          gst_rate:       18,
          effective_from: '2024-01-01'
        }
      }
    end

    it 'creates a new HSN code as owner' do
      expect {
        post '/api/v1/hsn_sac_codes', params: valid_params, headers: auth_headers
      }.to change(HsnSacCode, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_body['data']['code']).to eq('85171200')
    end

    it 'computes split rates automatically' do
      post '/api/v1/hsn_sac_codes', params: valid_params, headers: auth_headers

      data = json_body['data']
      expect(data['cgst_rate'].to_f).to eq(9.0)
      expect(data['sgst_rate'].to_f).to eq(9.0)
      expect(data['igst_rate'].to_f).to eq(18.0)
    end

    it 'forbids manager from creating codes' do
      post '/api/v1/hsn_sac_codes', params: valid_params, headers: auth_headers(manager)
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns validation errors for invalid params' do
      post '/api/v1/hsn_sac_codes',
           params: { hsn_sac_code: { code: '', gst_rate: 99 } },
           headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ─── PATCH /api/v1/hsn_sac_codes/:id ──────────────────────────────────────
  describe 'PATCH /api/v1/hsn_sac_codes/:id' do
    it 'updates the description' do
      patch "/api/v1/hsn_sac_codes/#{hsn_code.id}",
            params: { hsn_sac_code: { description: 'Updated description' } },
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['description']).to eq('Updated description')
    end

    it 'forbids manager from updating' do
      patch "/api/v1/hsn_sac_codes/#{hsn_code.id}",
            params: { hsn_sac_code: { description: 'x' } },
            headers: auth_headers(manager)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── DELETE /api/v1/hsn_sac_codes/:id (deactivate) ────────────────────────
  describe 'DELETE /api/v1/hsn_sac_codes/:id' do
    it 'soft-deactivates the record (sets active=false and effective_to)' do
      delete "/api/v1/hsn_sac_codes/#{hsn_code.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      hsn_code.reload
      expect(hsn_code.active).to be false
      expect(hsn_code.effective_to).to eq(Date.current)
    end

    it 'forbids manager from deactivating' do
      delete "/api/v1/hsn_sac_codes/#{hsn_code.id}", headers: auth_headers(manager)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── POST /api/v1/hsn_sac_codes/:id/rate_change ───────────────────────────
  describe 'POST /api/v1/hsn_sac_codes/:id/rate_change' do
    let(:future_date) { (Date.current + 30.days).to_s }

    it 'closes the old record and creates a new one with the new rate' do
      expect {
        post "/api/v1/hsn_sac_codes/#{hsn_code.id}/rate_change",
             params: { gst_rate: 12, effective_from: future_date },
             headers: auth_headers
      }.to change(HsnSacCode, :count).by(1)

      expect(response).to have_http_status(:created)
      hsn_code.reload
      expect(hsn_code.effective_to).to eq(Date.parse(future_date) - 1.day)

      new_code = HsnSacCode.order(created_at: :desc).first
      expect(new_code.gst_rate).to eq(12)
      expect(new_code.code).to eq(hsn_code.code)
    end

    it 'returns error for missing gst_rate param' do
      post "/api/v1/hsn_sac_codes/#{hsn_code.id}/rate_change",
           params: { effective_from: future_date },
           headers: auth_headers
      expect(response).to have_http_status(:bad_request)
    end
  end

  # ─── POST /api/v1/hsn_sac_codes/bulk_import ───────────────────────────────
  describe 'POST /api/v1/hsn_sac_codes/bulk_import' do
    let(:csv_content) do
      <<~CSV
        code,code_type,description,gst_rate,effective_from,chapter
        99991111,HSN,Test Item A,5,2024-01-01,99
        99991112,HSN,Test Item B,18,2024-01-01,99
      CSV
    end

    let(:csv_file) do
      Rack::Test::UploadedFile.new(
        StringIO.new(csv_content),
        'text/csv',
        original_filename: 'import.csv'
      )
    end

    it 'imports codes from CSV and returns success_count' do
      expect {
        post '/api/v1/hsn_sac_codes/bulk_import',
             params: { file: csv_file },
             headers: auth_headers.except('Content-Type')
      }.to change(HsnSacCode, :count).by(2)

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['success_count']).to eq(2)
    end

    it 'returns an error when no file is provided' do
      post '/api/v1/hsn_sac_codes/bulk_import', headers: auth_headers
      expect(response).to have_http_status(:bad_request)
    end
  end
end
