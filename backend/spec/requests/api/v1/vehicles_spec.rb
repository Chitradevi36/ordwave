require 'rails_helper'

RSpec.describe 'Api::V1::Vehicles', type: :request do
  # ─── Shared setup ─────────────────────────────────────────────────────────
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

  # ─── GET /api/v1/vehicles ─────────────────────────────────────────────────
  describe 'GET /api/v1/vehicles' do
    let!(:vehicle) { create(:vehicle, organization: org) }
    let!(:other_org_vehicle) { create(:vehicle) }

    it 'returns vehicles for org' do
      get '/api/v1/vehicles', headers: auth_headers

      expect(response).to have_http_status(:ok)
      ids = json_body['data'].map { |v| v['id'] }
      expect(ids).to include(vehicle.id)
      expect(ids).not_to include(other_org_vehicle.id)
    end

    it 'requires authentication' do
      get '/api/v1/vehicles', headers: { 'X-Organization-Id' => org.id.to_s }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'filters by status' do
      inactive = create(:vehicle, organization: org, status: 'inactive')

      get '/api/v1/vehicles', params: { status: 'inactive' }, headers: auth_headers

      ids = json_body['data'].map { |v| v['id'] }
      expect(ids).to include(inactive.id)
      expect(ids).not_to include(vehicle.id)
    end

    it 'filters by vehicle_type' do
      bike = create(:vehicle, organization: org, vehicle_type: 'bike')

      get '/api/v1/vehicles', params: { vehicle_type: 'bike' }, headers: auth_headers

      ids = json_body['data'].map { |v| v['id'] }
      expect(ids).to include(bike.id)
      expect(ids).not_to include(vehicle.id)
    end

    it 'excludes soft-deleted vehicles' do
      vehicle.update_columns(deleted_at: Time.current)

      get '/api/v1/vehicles', headers: auth_headers

      ids = json_body['data'].map { |v| v['id'] }
      expect(ids).not_to include(vehicle.id)
    end

    it 'allows sales_rep to list vehicles' do
      get '/api/v1/vehicles', headers: auth_headers(sales_user)
      expect(response).to have_http_status(:ok)
    end
  end

  # ─── GET /api/v1/vehicles/:id ─────────────────────────────────────────────
  describe 'GET /api/v1/vehicles/:id' do
    let!(:vehicle) { create(:vehicle, organization: org) }

    it 'returns vehicle details' do
      get "/api/v1/vehicles/#{vehicle.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['id']).to eq(vehicle.id)
      expect(json_body['data']['registration_number']).to eq(vehicle.registration_number)
    end

    it 'returns 404 for vehicle in another org' do
      other = create(:vehicle)
      get "/api/v1/vehicles/#{other.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for soft-deleted vehicle' do
      vehicle.update_columns(deleted_at: Time.current)
      get "/api/v1/vehicles/#{vehicle.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── POST /api/v1/vehicles ────────────────────────────────────────────────
  describe 'POST /api/v1/vehicles' do
    let(:valid_params) do
      {
        vehicle: {
          registration_number: 'KA03CD1234',
          vehicle_type:        'truck',
          capacity_kg:         2000,
          capacity_units:      800
        }
      }
    end

    it 'creates a vehicle for manager+' do
      post '/api/v1/vehicles', params: valid_params.to_json, headers: auth_headers(manager)

      expect(response).to have_http_status(:created)
      expect(json_body['data']['registration_number']).to eq('KA03CD1234')
    end

    it 'creates a vehicle for owner' do
      post '/api/v1/vehicles', params: valid_params.to_json, headers: auth_headers

      expect(response).to have_http_status(:created)
    end

    it 'creates an audit log entry' do
      expect {
        post '/api/v1/vehicles', params: valid_params.to_json, headers: auth_headers
      }.to change(AuditLog, :count).by(1)

      expect(AuditLog.last.action).to eq('vehicle_created')
    end

    it 'returns 403 for sales_rep' do
      post '/api/v1/vehicles', params: valid_params.to_json, headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 422 for missing registration_number' do
      params = { vehicle: { vehicle_type: 'truck' } }
      post '/api/v1/vehicles', params: params.to_json, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ─── PATCH /api/v1/vehicles/:id ───────────────────────────────────────────
  describe 'PATCH /api/v1/vehicles/:id' do
    let!(:vehicle) { create(:vehicle, organization: org) }

    it 'updates vehicle attributes' do
      patch "/api/v1/vehicles/#{vehicle.id}",
            params: { vehicle: { capacity_kg: 3000 } }.to_json,
            headers: auth_headers(manager)

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['capacity_kg']).to eq(3000)
    end

    it 'creates an audit log on update' do
      expect {
        patch "/api/v1/vehicles/#{vehicle.id}",
              params: { vehicle: { status: 'inactive' } }.to_json,
              headers: auth_headers
      }.to change(AuditLog, :count).by(1)

      expect(AuditLog.last.action).to eq('vehicle_updated')
    end

    it 'returns 403 for sales_rep' do
      patch "/api/v1/vehicles/#{vehicle.id}",
            params: { vehicle: { capacity_kg: 1 } }.to_json,
            headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── DELETE /api/v1/vehicles/:id ──────────────────────────────────────────
  describe 'DELETE /api/v1/vehicles/:id' do
    let!(:vehicle) { create(:vehicle, organization: org) }

    it 'soft-deletes the vehicle' do
      delete "/api/v1/vehicles/#{vehicle.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(vehicle.reload.deleted_at).not_to be_nil
    end

    it 'creates a vehicle_deleted audit log' do
      expect {
        delete "/api/v1/vehicles/#{vehicle.id}", headers: auth_headers
      }.to change(AuditLog, :count).by(1)

      expect(AuditLog.last.action).to eq('vehicle_deleted')
    end

    it 'returns 403 for sales_rep' do
      delete "/api/v1/vehicles/#{vehicle.id}", headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 422 if vehicle has active trips' do
      trip = create(:delivery_trip, organization: org, branch: branch, vehicle: vehicle, status: 'dispatched')

      delete "/api/v1/vehicles/#{vehicle.id}", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(vehicle.reload.deleted_at).to be_nil
    end
  end
end
