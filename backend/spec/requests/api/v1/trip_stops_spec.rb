require 'rails_helper'

RSpec.describe 'Api::V1::TripStops', type: :request do
  # ─── Shared setup ─────────────────────────────────────────────────────────
  let(:owner_role)   { create(:role, name: 'owner') }
  let(:manager_role) { create(:role, name: 'manager') }
  let(:wh_role)      { create(:role, name: 'warehouse_staff') }

  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:product)  { create(:product, organization: org) }
  let(:vehicle)  { create(:vehicle, organization: org) }

  let(:owner) { create(:user) }
  let!(:owner_membership) do
    create(:membership, user: owner, organization: org, branch: branch, role: owner_role)
  end

  let(:wh_user) { create(:user) }
  let!(:wh_membership) do
    create(:membership, user: wh_user, organization: org, branch: branch, role: wh_role)
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

  # Build a dispatched trip with one stop and one order line
  def build_dispatched_stop
    order = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: owner)
    line  = create(:sales_order_line, sales_order: order, product: product,
                   qty: 10, unit_price: 200, discount_pct: 0, line_total: 2000)
    order.update_columns(status: 'dispatched', approved_at: Time.current, dispatched_at: Time.current)

    trip = create(:delivery_trip, organization: org, branch: branch, vehicle: vehicle,
                  driver: owner, status: 'dispatched', dispatched_at: Time.current)
    stop = create(:trip_stop, delivery_trip: trip, sales_order: order, sequence: 1, status: 'pending')

    { trip: trip, stop: stop, order: order, line: line }
  end

  # ─── GET /api/v1/delivery_trips/:trip_id/trip_stops ───────────────────────
  describe 'GET /api/v1/delivery_trips/:trip_id/trip_stops' do
    let!(:ctx) { build_dispatched_stop }

    it 'returns stops for the trip' do
      get "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']).to be_an(Array)
      expect(json_body['data'].first['id']).to eq(ctx[:stop].id)
    end

    it 'returns 404 when trip belongs to another org' do
      other_trip = create(:delivery_trip)
      get "/api/v1/delivery_trips/#{other_trip.id}/trip_stops", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it 'requires authentication' do
      get "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops",
          headers: { 'X-Organization-Id' => org.id.to_s }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ─── GET /api/v1/delivery_trips/:trip_id/trip_stops/:id ───────────────────
  describe 'GET /api/v1/delivery_trips/:trip_id/trip_stops/:id' do
    let!(:ctx) { build_dispatched_stop }

    it 'returns detailed stop with lines' do
      get "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}",
          headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['id']).to eq(ctx[:stop].id)
      expect(json_body['data']['lines']).to be_an(Array)
    end

    it 'returns 404 for stop from another trip' do
      other_ctx = build_dispatched_stop
      get "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{other_ctx[:stop].id}",
          headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── POST .../trip_stops/:id/complete — delivered ─────────────────────────
  describe 'POST .../trip_stops/:id/complete (delivered)' do
    let!(:ctx) { build_dispatched_stop }

    let(:complete_params) do
      {
        outcome:          'delivered',
        delivery_notes:   'All good',
        idempotency_key:  "#{ctx[:stop].id}-#{Time.current.to_i}",
        latitude:         18.9647,
        longitude:        72.8258,
        device_id:        'device-001',
        proof:            { proof_type: 'photo' },
        returns:          [],
        delivered_lines:  [{ sales_order_line_id: ctx[:line].id, delivered_qty: 10 }]
      }
    end

    it 'marks stop as delivered and transitions order to delivered' do
      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: complete_params.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(ctx[:stop].reload.status).to eq('delivered')
      expect(ctx[:order].reload.status).to eq('delivered')
    end

    it 'updates delivered_qty on the sales order line' do
      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: complete_params.to_json,
           headers: auth_headers

      expect(ctx[:line].reload.delivered_qty).to eq(10)
    end

    it 'creates a DeliveryProof record' do
      expect {
        post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
             params: complete_params.to_json,
             headers: auth_headers
      }.to change(DeliveryProof, :count).by(1)
    end

    it 'auto-completes trip when it is the last stop' do
      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: complete_params.to_json,
           headers: auth_headers

      expect(ctx[:trip].reload.status).to eq('completed')
    end

    it 'creates audit logs for stop_completed' do
      expect {
        post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
             params: complete_params.to_json,
             headers: auth_headers
      }.to change(AuditLog, :count).by_at_least(1)

      actions = AuditLog.last(5).map(&:action)
      expect(actions).to include('stop_completed')
    end

    it 'allows warehouse_staff to complete a stop' do
      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: complete_params.to_json,
           headers: auth_headers(wh_user)

      expect(response).to have_http_status(:ok)
    end
  end

  # ─── POST .../complete — partial_delivery ────────────────────────────────
  describe 'POST .../complete (partial_delivery with returns)' do
    let!(:ctx) { build_dispatched_stop }

    let(:partial_params) do
      {
        outcome:         'partial_delivery',
        delivery_notes:  'Customer refused 3 units',
        idempotency_key: "#{ctx[:stop].id}-partial-#{Time.current.to_i}",
        proof:           { proof_type: 'photo' },
        returns: [
          {
            product_id:   product.id,
            qty_returned: 3,
            condition:    'good',
            reason_code:  'refused'
          }
        ],
        delivered_lines: [{ sales_order_line_id: ctx[:line].id, delivered_qty: 7 }]
      }
    end

    it 'marks stop and order as partial_delivery' do
      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: partial_params.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(ctx[:stop].reload.status).to eq('partial_delivery')
      expect(ctx[:order].reload.status).to eq('partial_delivery')
    end

    it 'creates a ReturnRecord for returned items' do
      expect {
        post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
             params: partial_params.to_json,
             headers: auth_headers
      }.to change(ReturnRecord, :count).by(1)

      expect(ReturnRecord.last.qty_returned).to eq(3)
    end

    it 'updates returned_qty on the sales order line' do
      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: partial_params.to_json,
           headers: auth_headers

      expect(ctx[:line].reload.returned_qty).to eq(3)
    end
  end

  # ─── POST .../complete — failed ───────────────────────────────────────────
  describe 'POST .../complete (failed)' do
    let!(:ctx) { build_dispatched_stop }

    let(:failed_params) do
      {
        outcome:         'failed',
        exception_code:  'not_home',
        delivery_notes:  'Nobody answered the door',
        idempotency_key: "#{ctx[:stop].id}-failed-#{Time.current.to_i}",
        proof:           { proof_type: 'photo' },
        returns:         [],
        delivered_lines: [{ sales_order_line_id: ctx[:line].id, delivered_qty: 0 }]
      }
    end

    it 'marks stop as failed and order remains dispatched' do
      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: failed_params.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(ctx[:stop].reload.status).to eq('failed')
      expect(ctx[:order].reload.status).to eq('dispatched')
    end

    it 'stores the exception_code on the stop' do
      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: failed_params.to_json,
           headers: auth_headers

      expect(ctx[:stop].reload.exception_code).to eq('not_home')
    end

    it 'creates a stop_exception_flagged audit log' do
      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: failed_params.to_json,
           headers: auth_headers

      actions = AuditLog.last(5).map(&:action)
      expect(actions).to include('stop_exception_flagged')
    end

    it 'returns 422 if exception_code is missing for failed outcome' do
      params = failed_params.merge(exception_code: nil)
      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: params.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ─── POST .../complete — idempotency ─────────────────────────────────────
  describe 'POST .../complete (idempotency)' do
    let!(:ctx) { build_dispatched_stop }
    let(:idem_key) { "#{ctx[:stop].id}-idem-#{SecureRandom.hex(4)}" }

    let(:complete_params) do
      {
        outcome:         'delivered',
        delivery_notes:  'First attempt',
        idempotency_key: idem_key,
        proof:           { proof_type: 'photo' },
        returns:         [],
        delivered_lines: [{ sales_order_line_id: ctx[:line].id, delivered_qty: 10 }]
      }
    end

    it 'returns 200 without duplicating records on repeated call with same key' do
      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: complete_params.to_json,
           headers: auth_headers

      proof_count_after_first = DeliveryProof.count

      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: complete_params.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(DeliveryProof.count).to eq(proof_count_after_first)
    end
  end

  # ─── POST .../complete — error cases ─────────────────────────────────────
  describe 'POST .../complete (error cases)' do
    it 'returns 422 if trip is not dispatched' do
      order = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: owner)
      line  = create(:sales_order_line, sales_order: order, product: product,
                     qty: 5, unit_price: 200, discount_pct: 0, line_total: 1000)
      order.update_columns(status: 'approved', approved_at: Time.current)

      trip = create(:delivery_trip, organization: org, branch: branch, vehicle: vehicle,
                    driver: owner, status: 'draft')
      stop = create(:trip_stop, delivery_trip: trip, sales_order: order, sequence: 1)

      params = {
        outcome:         'delivered',
        idempotency_key: "#{stop.id}-draft",
        proof:           { proof_type: 'photo' },
        returns:         [],
        delivered_lines: [{ sales_order_line_id: line.id, delivered_qty: 5 }]
      }

      post "/api/v1/delivery_trips/#{trip.id}/trip_stops/#{stop.id}/complete",
           params: params.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 when stop is already completed with a different idempotency_key' do
      ctx = build_dispatched_stop
      first_key = "#{ctx[:stop].id}-first"

      first_params = {
        outcome:         'delivered',
        idempotency_key: first_key,
        proof:           { proof_type: 'photo' },
        returns:         [],
        delivered_lines: [{ sales_order_line_id: ctx[:line].id, delivered_qty: 10 }]
      }

      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: first_params.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:ok)

      second_params = first_params.merge(idempotency_key: "#{ctx[:stop].id}-second")
      post "/api/v1/delivery_trips/#{ctx[:trip].id}/trip_stops/#{ctx[:stop].id}/complete",
           params: second_params.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
