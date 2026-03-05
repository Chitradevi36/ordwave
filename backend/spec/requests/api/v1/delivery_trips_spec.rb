require 'rails_helper'

RSpec.describe 'Api::V1::DeliveryTrips', type: :request do
  # ─── Shared setup ─────────────────────────────────────────────────────────
  let(:owner_role)   { create(:role, name: 'owner') }
  let(:manager_role) { create(:role, name: 'manager') }
  let(:sales_role)   { create(:role, name: 'sales_rep') }

  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:product)  { create(:product, organization: org) }
  let(:vehicle)  { create(:vehicle, organization: org) }

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

  # Build a sales order in approved status bypassing state machine for speed
  def create_approved_order
    order = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: owner)
    create(:sales_order_line, sales_order: order, product: product, qty: 5, unit_price: 200, discount_pct: 0, line_total: 1000)
    order.update_columns(status: 'approved', approved_at: Time.current)
    order
  end

  # ─── GET /api/v1/delivery_trips ───────────────────────────────────────────
  describe 'GET /api/v1/delivery_trips' do
    let!(:trip)  { create(:delivery_trip, organization: org, branch: branch, vehicle: vehicle, driver: owner) }
    let!(:other) { create(:delivery_trip) }

    it 'returns trips for org only' do
      get '/api/v1/delivery_trips', headers: auth_headers

      ids = json_body['data'].map { |t| t['id'] }
      expect(ids).to include(trip.id)
      expect(ids).not_to include(other.id)
    end

    it 'includes status counts in meta' do
      get '/api/v1/delivery_trips', headers: auth_headers

      expect(json_body['meta']).to have_key('counts')
    end

    it 'requires authentication' do
      get '/api/v1/delivery_trips', headers: { 'X-Organization-Id' => org.id.to_s }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'filters by status' do
      dispatched = create(:delivery_trip, organization: org, branch: branch, vehicle: vehicle,
                          driver: owner, status: 'dispatched', dispatched_at: Time.current)

      get '/api/v1/delivery_trips', params: { status: 'dispatched' }, headers: auth_headers

      ids = json_body['data'].map { |t| t['id'] }
      expect(ids).to include(dispatched.id)
      expect(ids).not_to include(trip.id)
    end

    it 'filters by trip_date' do
      yesterday_trip = create(:delivery_trip, organization: org, branch: branch, vehicle: vehicle,
                               driver: owner, trip_date: Date.yesterday)

      get '/api/v1/delivery_trips', params: { trip_date: Date.today.iso8601 }, headers: auth_headers

      ids = json_body['data'].map { |t| t['id'] }
      expect(ids).to include(trip.id)
      expect(ids).not_to include(yesterday_trip.id)
    end
  end

  # ─── GET /api/v1/delivery_trips/:id ──────────────────────────────────────
  describe 'GET /api/v1/delivery_trips/:id' do
    let!(:trip)  { create(:delivery_trip, organization: org, branch: branch, vehicle: vehicle, driver: owner) }
    let!(:order) { create_approved_order }
    let!(:stop)  { create(:trip_stop, delivery_trip: trip, sales_order: order, sequence: 1) }

    it 'returns trip detail with stops' do
      get "/api/v1/delivery_trips/#{trip.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['id']).to eq(trip.id)
      expect(json_body['data']['stops']).to be_an(Array)
    end

    it 'returns 404 for trip in another org' do
      other = create(:delivery_trip)
      get "/api/v1/delivery_trips/#{other.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── POST /api/v1/delivery_trips ─────────────────────────────────────────
  describe 'POST /api/v1/delivery_trips' do
    let!(:order) { create_approved_order }

    let(:valid_params) do
      {
        delivery_trip: {
          branch_id:  branch.id,
          vehicle_id: vehicle.id,
          driver_id:  owner.id,
          trip_date:  Date.today.iso8601,
          order_ids:  [order.id]
        }
      }
    end

    it 'creates trip with ordered stops for manager+' do
      post '/api/v1/delivery_trips', params: valid_params.to_json, headers: auth_headers(manager)

      expect(response).to have_http_status(:created)
      expect(json_body['data']['status']).to eq('draft')
      expect(json_body['data']['stops'].size).to eq(1)
      expect(json_body['data']['stops'].first['sales_order_id']).to eq(order.id)
    end

    it 'creates an audit log entry' do
      expect {
        post '/api/v1/delivery_trips', params: valid_params.to_json, headers: auth_headers
      }.to change(AuditLog, :count).by(1)

      expect(AuditLog.last.action).to eq('trip_created')
    end

    it 'returns 422 when order is not approved' do
      order.update_columns(status: 'draft')

      post '/api/v1/delivery_trips', params: valid_params.to_json, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 when order_ids is empty' do
      params = valid_params.deep_merge(delivery_trip: { order_ids: [] })
      post '/api/v1/delivery_trips', params: params.to_json, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 when vehicle belongs to another org' do
      other_vehicle = create(:vehicle)
      params = valid_params.deep_merge(delivery_trip: { vehicle_id: other_vehicle.id })
      post '/api/v1/delivery_trips', params: params.to_json, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 403 for sales_rep' do
      post '/api/v1/delivery_trips', params: valid_params.to_json, headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end

    it 'preserves caller-specified stop order' do
      order2 = create_approved_order
      params = valid_params.deep_merge(delivery_trip: { order_ids: [order2.id, order.id] })

      post '/api/v1/delivery_trips', params: params.to_json, headers: auth_headers

      stops = json_body['data']['stops'].sort_by { |s| s['sequence'] }
      expect(stops.first['sales_order_id']).to eq(order2.id)
      expect(stops.last['sales_order_id']).to eq(order.id)
    end
  end

  # ─── PATCH /api/v1/delivery_trips/:id ────────────────────────────────────
  describe 'PATCH /api/v1/delivery_trips/:id' do
    let!(:trip) { create(:delivery_trip, organization: org, branch: branch, vehicle: vehicle, driver: owner) }

    it 'updates trip notes in draft status' do
      patch "/api/v1/delivery_trips/#{trip.id}",
            params: { delivery_trip: { notes: 'Handle with care' } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
    end

    it 'returns 422 when trip is dispatched' do
      trip.update_columns(status: 'dispatched', dispatched_at: Time.current)

      patch "/api/v1/delivery_trips/#{trip.id}",
            params: { delivery_trip: { notes: 'Updated note' } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ─── POST /api/v1/delivery_trips/:id/dispatch ────────────────────────────
  describe 'POST /api/v1/delivery_trips/:id/dispatch' do
    let!(:order) { create_approved_order }
    let!(:trip)  { create(:delivery_trip, organization: org, branch: branch, vehicle: vehicle, driver: owner) }
    let!(:stop)  { create(:trip_stop, delivery_trip: trip, sales_order: order, sequence: 1) }

    it 'transitions trip and stops orders to dispatched' do
      post "/api/v1/delivery_trips/#{trip.id}/dispatch", headers: auth_headers(manager)

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['status']).to eq('dispatched')
      expect(order.reload.status).to eq('dispatched')
    end

    it 'creates audit logs for trip_dispatched and order_dispatched' do
      expect {
        post "/api/v1/delivery_trips/#{trip.id}/dispatch", headers: auth_headers
      }.to change(AuditLog, :count).by_at_least(2)

      actions = AuditLog.last(10).map(&:action)
      expect(actions).to include('trip_dispatched')
      expect(actions).to include('order_dispatched')
    end

    it 'returns 422 when trip is already dispatched' do
      trip.update_columns(status: 'dispatched', dispatched_at: Time.current)

      post "/api/v1/delivery_trips/#{trip.id}/dispatch", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 403 for sales_rep' do
      post "/api/v1/delivery_trips/#{trip.id}/dispatch", headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── POST /api/v1/delivery_trips/:id/cancel ──────────────────────────────
  describe 'POST /api/v1/delivery_trips/:id/cancel' do
    let!(:order) { create_approved_order }
    let!(:trip)  { create(:delivery_trip, organization: org, branch: branch, vehicle: vehicle,
                           driver: owner, status: 'dispatched', dispatched_at: Time.current) }
    let!(:stop) do
      order.update_columns(status: 'dispatched', dispatched_at: Time.current)
      create(:trip_stop, delivery_trip: trip, sales_order: order, sequence: 1)
    end

    it 'cancels the trip and reverts dispatched orders to approved' do
      post "/api/v1/delivery_trips/#{trip.id}/cancel",
           params: { reason: 'Vehicle breakdown' }.to_json,
           headers: auth_headers(manager)

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['status']).to eq('cancelled')
      expect(order.reload.status).to eq('approved')
    end

    it 'stores the cancellation reason' do
      post "/api/v1/delivery_trips/#{trip.id}/cancel",
           params: { reason: 'Driver unavailable' }.to_json,
           headers: auth_headers

      expect(trip.reload.cancellation_reason).to eq('Driver unavailable')
    end

    it 'returns 422 without a reason' do
      post "/api/v1/delivery_trips/#{trip.id}/cancel",
           params: { reason: '' }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 if trip is already completed' do
      trip.update_columns(status: 'completed', completed_at: Time.current)

      post "/api/v1/delivery_trips/#{trip.id}/cancel",
           params: { reason: 'Error' }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 403 for sales_rep' do
      post "/api/v1/delivery_trips/#{trip.id}/cancel",
           params: { reason: 'Test' }.to_json,
           headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
