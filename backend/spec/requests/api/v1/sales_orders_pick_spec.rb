require 'rails_helper'

# MED-07: Spec for POST /api/v1/sales_orders/:id/pick and :confirm_pick
# Tests role gating, status guards, happy paths, and audit log creation.
RSpec.describe 'Api::V1::SalesOrders pick/confirm_pick', type: :request do
  # ─── Shared setup ──────────────────────────────────────────────────────────
  let(:owner_role)          { create(:role, name: 'owner') }
  let(:manager_role)        { create(:role, name: 'manager') }
  let(:warehouse_role)      { create(:role, name: 'warehouse_staff') }
  let(:sales_role)          { create(:role, name: 'sales_rep') }

  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }

  let(:owner)   { create(:user) }
  let(:manager) { create(:user) }
  let(:warehouse_user) { create(:user) }
  let(:sales_user) { create(:user) }

  let!(:credit_policy) { create(:credit_policy, organization: org) }

  before do
    create(:membership, user: owner,          organization: org, branch: branch, role: owner_role)
    create(:membership, user: manager,        organization: org, branch: branch, role: manager_role)
    create(:membership, user: warehouse_user, organization: org, branch: branch, role: warehouse_role)
    create(:membership, user: sales_user,     organization: org, branch: branch, role: sales_role)
  end

  # Helper: approved order ready for picking
  def approved_order
    order = create(:sales_order, organization: org, branch: branch, customer: customer,
                   created_by: sales_user, status: 'approved')
    # pick_status defaults to pending_pick (0) from the migration
    order
  end

  def generate_jwt_for(user)
    payload = { sub: user.id, email: user.email, jti: SecureRandom.uuid, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def auth_headers(user)
    {
      'Authorization'     => "Bearer #{generate_jwt_for(user)}",
      'X-Organization-Id' => org.id.to_s,
      'Content-Type'      => 'application/json'
    }
  end

  def json_body
    JSON.parse(response.body)
  end

  # ── POST /api/v1/sales_orders/:id/pick ─────────────────────────────────────
  describe 'POST /api/v1/sales_orders/:id/pick' do
    context 'as warehouse_staff with approved (pending_pick) order' do
      it 'transitions pick_status to picked and records picked_by/picked_at' do
        order = approved_order

        post "/api/v1/sales_orders/#{order.id}/pick",
             headers: auth_headers(warehouse_user)

        expect(response).to have_http_status(:ok)
        body = json_body
        expect(body['pick_status']).to eq('picked')
        expect(body['picked_by_id']).to eq(warehouse_user.id)
        expect(body['picked_at']).to be_present

        # Verify audit log created
        log = AuditLog.find_by(auditable: order, action: 'order_picked')
        expect(log).to be_present
        expect(log.actor_id).to eq(warehouse_user.id)
      end
    end

    context 'as manager with approved (pending_pick) order' do
      it 'returns 200 — managers can also pick' do
        order = approved_order
        post "/api/v1/sales_orders/#{order.id}/pick", headers: auth_headers(manager)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as sales_rep' do
      it 'returns 403 — sales reps cannot pick orders' do
        order = approved_order
        post "/api/v1/sales_orders/#{order.id}/pick", headers: auth_headers(sales_user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns 401' do
        order = approved_order
        post "/api/v1/sales_orders/#{order.id}/pick"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when order is already picked' do
      it 'returns 422 — cannot pick twice' do
        order = approved_order
        order.update_columns(pick_status: 1) # picked

        post "/api/v1/sales_orders/#{order.id}/pick", headers: auth_headers(warehouse_user)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_body['errors']).to be_present
      end
    end

    context 'when order is still in submitted status (not approved)' do
      it 'returns 422 — order not ready for picking' do
        order = create(:sales_order, organization: org, branch: branch, customer: customer,
                       created_by: sales_user, status: 'submitted')

        post "/api/v1/sales_orders/#{order.id}/pick", headers: auth_headers(warehouse_user)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'cross-organisation isolation' do
      it 'returns 404 for an order belonging to a different org' do
        other_org    = create(:organization)
        other_branch = create(:branch, organization: other_org)
        other_cust   = create(:customer, organization: other_org, branch: other_branch)
        other_order  = create(:sales_order, organization: other_org, branch: other_branch,
                              customer: other_cust, created_by: create(:user), status: 'approved')

        post "/api/v1/sales_orders/#{other_order.id}/pick", headers: auth_headers(warehouse_user)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── POST /api/v1/sales_orders/:id/confirm_pick ────────────────────────────
  describe 'POST /api/v1/sales_orders/:id/confirm_pick' do
    def picked_order
      order = approved_order
      order.update_columns(pick_status: 1, picked_by_id: warehouse_user.id, picked_at: Time.current)
      order
    end

    context 'as manager with a picked order' do
      it 'transitions pick_status to pick_confirmed' do
        order = picked_order

        post "/api/v1/sales_orders/#{order.id}/confirm_pick",
             headers: auth_headers(manager)

        expect(response).to have_http_status(:ok)
        body = json_body
        expect(body['pick_status']).to eq('pick_confirmed')
        expect(body['pick_confirmed_by_id']).to eq(manager.id)
        expect(body['pick_confirmed_at']).to be_present

        log = AuditLog.find_by(auditable: order, action: 'order_pick_confirmed')
        expect(log).to be_present
      end
    end

    context 'as owner' do
      it 'returns 200 — owners can confirm picks' do
        order = picked_order
        post "/api/v1/sales_orders/#{order.id}/confirm_pick", headers: auth_headers(owner)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as warehouse_staff' do
      it 'returns 403 — warehouse staff cannot confirm picks' do
        order = picked_order
        post "/api/v1/sales_orders/#{order.id}/confirm_pick", headers: auth_headers(warehouse_user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as sales_rep' do
      it 'returns 403' do
        order = picked_order
        post "/api/v1/sales_orders/#{order.id}/confirm_pick", headers: auth_headers(sales_user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when order is still pending_pick (not yet picked)' do
      it 'returns 422 — must be picked first' do
        order = approved_order # pick_status: pending_pick

        post "/api/v1/sales_orders/#{order.id}/confirm_pick", headers: auth_headers(manager)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when order is already pick_confirmed' do
      it 'returns 422 — cannot confirm twice' do
        order = approved_order
        order.update_columns(pick_status: 2) # pick_confirmed

        post "/api/v1/sales_orders/#{order.id}/confirm_pick", headers: auth_headers(manager)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
