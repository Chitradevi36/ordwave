require 'rails_helper'

RSpec.describe 'Api::V1::SalesOrders', type: :request do
  # ─── Shared setup ─────────────────────────────────────────────────────────
  let(:owner_role)  { create(:role, name: 'owner') }
  let(:manager_role){ create(:role, name: 'manager') }
  let(:sales_role)  { create(:role, name: 'sales_rep') }

  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:product)  { create(:product, organization: org) }

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

  let!(:credit_policy) { create(:credit_policy, organization: org) }

  let(:price_result) do
    Pricing::EffectivePriceResolver::Result.new(
      unit_price:      200.0,
      source:          'standard',
      price_list_id:   nil,
      discount_pct:    0,
      min_qty_matched: false,
      valid_from:      nil,
      valid_to:        nil
    )
  end

  before do
    allow(Pricing::EffectivePriceResolver).to receive(:call).and_return(price_result)
    allow(Credit::CreditEngine).to receive(:evaluate_order).and_return(
      { decision: 'ok', reasons: [], metrics: { available: 50_000 }, actions_required: {} }
    )
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

  def create_draft_order(creator: owner)
    order = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: creator)
    create(:sales_order_line, sales_order: order, product: product, qty: 5, unit_price: 200, discount_pct: 0, line_total: 1000)
    order.recalculate_totals!
    order
  end

  # ─── GET /api/v1/sales_orders ─────────────────────────────────────────────
  describe 'GET /api/v1/sales_orders' do
    let!(:order) { create_draft_order }

    it 'returns paginated orders for owner' do
      get '/api/v1/sales_orders', headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']).to be_an(Array)
      expect(json_body['meta']).to include('total_count')
    end

    it 'requires authentication' do
      get '/api/v1/sales_orders', headers: { 'X-Organization-Id' => org.id.to_s }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'filters by status' do
      order2 = create(:sales_order, organization: org, branch: branch, customer: customer,
                      created_by: owner, status: 'submitted', submitted_at: Time.current)

      get '/api/v1/sales_orders', params: { status: 'submitted' }, headers: auth_headers

      ids = json_body['data'].map { |o| o['id'] }
      expect(ids).to include(order2.id)
      expect(ids).not_to include(order.id)
    end

    it 'sales_rep only sees their own orders' do
      other_user = create(:user)
      create(:membership, user: other_user, organization: org, branch: branch, role: owner_role)
      other_order = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: other_user)

      order_for_sales = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: sales_user)

      get '/api/v1/sales_orders', headers: auth_headers(sales_user)

      ids = json_body['data'].map { |o| o['id'] }
      expect(ids).to include(order_for_sales.id)
      expect(ids).not_to include(other_order.id)
    end
  end

  # ─── GET /api/v1/sales_orders/:id ─────────────────────────────────────────
  describe 'GET /api/v1/sales_orders/:id' do
    let!(:order) { create_draft_order }

    it 'returns order with lines and timeline' do
      get "/api/v1/sales_orders/#{order.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['order_number']).to eq(order.order_number)
      expect(json_body['data']['lines']).to be_an(Array)
      expect(json_body['data']['timeline']).to be_an(Array)
    end

    it 'returns 404 for unknown id' do
      get '/api/v1/sales_orders/99999999', headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── POST /api/v1/sales_orders ────────────────────────────────────────────
  describe 'POST /api/v1/sales_orders' do
    let(:valid_params) do
      {
        order: {
          customer_id:   customer.id,
          branch_id:     branch.id,
          delivery_date: 7.days.from_now.to_date,
          notes:         'Test order',
          lines: [
            { product_id: product.id, qty: 5, discount_pct: 0 }
          ]
        }
      }
    end

    it 'creates a draft order' do
      post '/api/v1/sales_orders', params: valid_params.to_json, headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(json_body['data']['status']).to eq('draft')
      expect(json_body['data']['lines'].size).to eq(1)
    end

    it 'returns 422 for missing lines' do
      params = { order: { customer_id: customer.id, branch_id: branch.id, lines: [] } }
      post '/api/v1/sales_orders', params: params.to_json, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ─── POST /api/v1/sales_orders/:id/submit ─────────────────────────────────
  describe 'POST /api/v1/sales_orders/:id/submit' do
    it 'submits a draft order with credit ok — returns credit object in response' do
      order = create_draft_order

      post "/api/v1/sales_orders/#{order.id}/submit",
           params: {}.to_json, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['status']).to eq('submitted')
      expect(json_body['data']['credit_decision']).to eq('ok')
      # Credit envelope is present alongside data
      expect(json_body['credit']).to include('decision' => 'ok', 'reasons' => [])
      expect(json_body['credit']['metrics']).to be_a(Hash)
    end

    it 'puts order on_hold when credit hold — returns credit object with hold decision' do
      allow(Credit::CreditEngine).to receive(:evaluate_order).and_return(
        { decision: 'hold',
          reasons: ['Overdue 20 days', 'Outstanding 85% of limit'],
          metrics: { overdue_days: 20, outstanding: 42_500, credit_limit: 50_000,
                     available: 7_500, order_total: 1_000 },
          actions_required: {} }
      )
      order = create_draft_order

      post "/api/v1/sales_orders/#{order.id}/submit",
           params: {}.to_json, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['status']).to eq('on_hold')
      expect(json_body['credit']['decision']).to eq('hold')
      expect(json_body['credit']['reasons']).to include('Overdue 20 days')
      expect(json_body['credit']['metrics']['overdue_days']).to eq(20)
    end

    it 'returns 422 with credit object when credit blocked — order stays in draft' do
      allow(Credit::CreditEngine).to receive(:evaluate_order).and_return(
        { decision: 'blocked',
          reasons: ['Overdue by 45 days (threshold: 30)'],
          metrics: { overdue_days: 45, credit_limit: 50_000, outstanding: 55_000,
                     available: 0, order_total: 1_000 },
          actions_required: {} }
      )
      order = create_draft_order

      post "/api/v1/sales_orders/#{order.id}/submit",
           params: {}.to_json, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['code']).to eq('credit_blocked')
      expect(json_body['credit']['decision']).to eq('blocked')
      expect(json_body['credit']['reasons']).to include('Overdue by 45 days (threshold: 30)')
      expect(json_body['credit']['metrics']['overdue_days']).to eq(45)
      # Order must still be in draft
      expect(order.reload.status).to eq('draft')
      # But credit snapshot must be persisted for audit
      expect(order.reload.credit_decision).to eq('blocked')
    end

    it 'creates an audit timeline entry for credit checked' do
      order = create_draft_order

      post "/api/v1/sales_orders/#{order.id}/submit",
           params: {}.to_json, headers: auth_headers

      audit_actions = AuditLog.where(auditable: order).pluck(:action)
      expect(audit_actions).to include('order_credit_checked')
    end

    it 'returns 422 when already submitted' do
      order = create(:sales_order, organization: org, branch: branch, customer: customer,
                     created_by: owner, status: 'submitted', submitted_at: Time.current)

      post "/api/v1/sales_orders/#{order.id}/submit",
           params: {}.to_json, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'forbids sales_rep from submitting another user\'s order' do
      order = create_draft_order(creator: owner)

      post "/api/v1/sales_orders/#{order.id}/submit",
           params: {}.to_json, headers: auth_headers(sales_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── POST /api/v1/sales_orders/:id/approve ────────────────────────────────
  describe 'POST /api/v1/sales_orders/:id/approve' do
    let!(:on_hold_order) do
      create(:sales_order, organization: org, branch: branch, customer: customer,
             created_by: owner, status: 'on_hold', submitted_at: Time.current)
    end

    it 'approves an on_hold order (manager+)' do
      post "/api/v1/sales_orders/#{on_hold_order.id}/approve",
           params: { decision: 'approved' }.to_json,
           headers: auth_headers(manager)

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['status']).to eq('approved')
    end

    it 'approves a submitted order directly (manager+)' do
      submitted_order = create(:sales_order, organization: org, branch: branch, customer: customer,
                               created_by: owner, status: 'submitted', submitted_at: Time.current)

      post "/api/v1/sales_orders/#{submitted_order.id}/approve",
           params: { decision: 'approved' }.to_json,
           headers: auth_headers(manager)

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['status']).to eq('approved')
    end

    it 'forbids approving a submitted order as sales_rep' do
      submitted_order = create(:sales_order, organization: org, branch: branch, customer: customer,
                               created_by: owner, status: 'submitted', submitted_at: Time.current)

      post "/api/v1/sales_orders/#{submitted_order.id}/approve",
           params: { decision: 'approved' }.to_json,
           headers: auth_headers(sales_user)

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects with reason' do
      post "/api/v1/sales_orders/#{on_hold_order.id}/approve",
           params: { decision: 'rejected', reason: 'Credit risk too high' }.to_json,
           headers: auth_headers(manager)

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['status']).to eq('rejected')
    end

    it 'forbids sales_rep from approving' do
      post "/api/v1/sales_orders/#{on_hold_order.id}/approve",
           params: { decision: 'approved' }.to_json,
           headers: auth_headers(sales_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── POST /api/v1/sales_orders/:id/hold ───────────────────────────────────
  describe 'POST /api/v1/sales_orders/:id/hold' do
    let!(:submitted_order) do
      create(:sales_order, organization: org, branch: branch, customer: customer,
             created_by: owner, status: 'submitted', submitted_at: Time.current)
    end

    it 'places a submitted order on hold (manager+)' do
      post "/api/v1/sales_orders/#{submitted_order.id}/hold",
           params: { reason: 'Awaiting stock confirmation' }.to_json,
           headers: auth_headers(manager)

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['status']).to eq('on_hold')
    end

    it 'returns 422 when reason is blank' do
      post "/api/v1/sales_orders/#{submitted_order.id}/hold",
           params: { reason: '' }.to_json,
           headers: auth_headers(manager)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 422 when order is not submitted' do
      post "/api/v1/sales_orders/#{on_hold_order.id}/hold",
           params: { reason: 'Already on hold' }.to_json,
           headers: auth_headers(manager)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'forbids sales_rep from placing on hold' do
      post "/api/v1/sales_orders/#{submitted_order.id}/hold",
           params: { reason: 'rep trying to hold' }.to_json,
           headers: auth_headers(sales_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── POST /api/v1/sales_orders/:id/cancel ─────────────────────────────────
  describe 'POST /api/v1/sales_orders/:id/cancel' do
    it 'cancels a draft order with reason' do
      order = create_draft_order

      post "/api/v1/sales_orders/#{order.id}/cancel",
           params: { reason: 'Customer changed mind' }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['status']).to eq('cancelled')
      expect(json_body['data']['cancellation_reason']).to eq('Customer changed mind')
    end

    it 'returns 422 when reason is blank' do
      order = create_draft_order

      post "/api/v1/sales_orders/#{order.id}/cancel",
           params: { reason: '' }.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ─── GET /api/v1/sales_orders — filter extensions ────────────────────────
  describe 'GET /api/v1/sales_orders — filters' do
    it 'filters by q (order_number match)' do
      order   = create_draft_order
      target  = order.order_number

      get '/api/v1/sales_orders', params: { q: target }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      ids = json_body['data'].map { |o| o['id'] }
      expect(ids).to include(order.id)
    end

    it 'filters by date_from (excludes older orders)' do
      old_order = create(:sales_order, organization: org, branch: branch, customer: customer,
                         created_by: owner)
      old_order.update_column(:created_at, 30.days.ago)

      get '/api/v1/sales_orders',
          params: { date_from: 7.days.ago.to_date.iso8601 },
          headers: auth_headers

      ids = json_body['data'].map { |o| o['id'] }
      expect(ids).not_to include(old_order.id)
    end

    it 'filters by date_to (excludes future-created orders)' do
      old_order = create(:sales_order, organization: org, branch: branch, customer: customer,
                         created_by: owner)
      old_order.update_column(:created_at, 30.days.ago)
      recent    = create_draft_order

      get '/api/v1/sales_orders',
          params: { date_to: 10.days.ago.to_date.iso8601 },
          headers: auth_headers

      ids = json_body['data'].map { |o| o['id'] }
      expect(ids).to include(old_order.id)
      expect(ids).not_to include(recent.id)
    end

    it 'filters by branch_id' do
      other_branch = create(:branch, organization: org)
      other_order  = create(:sales_order, organization: org, branch: other_branch,
                             customer: customer, created_by: owner)
      my_order = create_draft_order

      get '/api/v1/sales_orders',
          params: { branch_id: branch.id },
          headers: auth_headers

      ids = json_body['data'].map { |o| o['id'] }
      expect(ids).to include(my_order.id)
      expect(ids).not_to include(other_order.id)
    end
  end

  # ─── GET /api/v1/sales_orders/recent_for_customer ─────────────────────────
  describe 'GET /api/v1/sales_orders/recent_for_customer' do
    let!(:order) { create_draft_order }

    it 'returns recent orders for the given customer' do
      get '/api/v1/sales_orders/recent_for_customer',
          params: { customer_id: customer.id },
          headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']).to be_an(Array)
    end

    it 'does not double-render (no 500 error)' do
      # Regression: DoubleRenderError was triggered when verify_authorized
      # fired after a policy_scope-only action
      get '/api/v1/sales_orders/recent_for_customer',
          params: { customer_id: customer.id },
          headers: auth_headers

      expect(response).not_to have_http_status(:internal_server_error)
    end

    it 'requires authentication' do
      get '/api/v1/sales_orders/recent_for_customer',
          params: { customer_id: customer.id },
          headers: { 'X-Organization-Id' => org.id.to_s }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ─── PATCH /api/v1/sales_orders/:id ───────────────────────────────────────
  describe 'PATCH /api/v1/sales_orders/:id' do
    context 'draft order' do
      let!(:order) { create_draft_order }

      it 'updates the draft and returns the updated order' do
        new_date = 14.days.from_now.to_date

        patch "/api/v1/sales_orders/#{order.id}",
              params: {
                order: {
                  customer_id:   customer.id,
                  branch_id:     branch.id,
                  delivery_date: new_date.iso8601,
                  notes:         'edited note',
                  lines: [{ product_id: product.id, qty: 8, discount_pct: 5 }]
                }
              }.to_json,
              headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_body['data']['status']).to eq('draft')
        expect(json_body['data']['notes']).to eq('edited note')
        expect(order.reload.delivery_date.to_s).to eq(new_date.to_s)
      end

      it 'returns 422 when lines are empty' do
        patch "/api/v1/sales_orders/#{order.id}",
              params: { order: { customer_id: customer.id, branch_id: branch.id, lines: [] } }.to_json,
              headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'forbids sales_rep from editing another user\'s draft' do
        another_user = create(:user)
        create(:membership, user: another_user, organization: org, branch: branch, role: owner_role)
        others_draft = create(:sales_order, organization: org, branch: branch,
                               customer: customer, created_by: another_user)
        create(:sales_order_line, sales_order: others_draft, product: product,
               qty: 1, unit_price: 200, discount_pct: 0, line_total: 200)
        others_draft.recalculate_totals!

        patch "/api/v1/sales_orders/#{others_draft.id}",
              params: {
                order: { customer_id: customer.id, branch_id: branch.id,
                         notes: 'hack', lines: [{ product_id: product.id, qty: 1, discount_pct: 0 }] }
              }.to_json,
              headers: auth_headers(sales_user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'submitted / on_hold order — limited update' do
      let!(:submitted_order) do
        order = create_draft_order
        order.transition_to!('submitted')
        order
      end

      it 'updates only delivery_date and notes for manager' do
        new_date = 20.days.from_now.to_date

        patch "/api/v1/sales_orders/#{submitted_order.id}",
              params: {
                order: { delivery_date: new_date.iso8601, notes: 'logistics update' }
              }.to_json,
              headers: auth_headers(manager)

        expect(response).to have_http_status(:ok)
        expect(submitted_order.reload.notes).to eq('logistics update')
        expect(submitted_order.reload.delivery_date.to_s).to eq(new_date.to_s)
      end

      it 'keeps order in submitted status after limited update' do
        patch "/api/v1/sales_orders/#{submitted_order.id}",
              params: { order: { notes: 'no status change' } }.to_json,
              headers: auth_headers(manager)

        expect(submitted_order.reload.status).to eq('submitted')
      end

      it 'writes an order_updated audit log' do
        expect {
          patch "/api/v1/sales_orders/#{submitted_order.id}",
                params: { order: { notes: 'audit trail' } }.to_json,
                headers: auth_headers(manager)
        }.to change { AuditLog.where(auditable: submitted_order, action: 'order_updated').count }.by(1)
      end

      it 'forbids sales_rep from doing a limited update' do
        patch "/api/v1/sales_orders/#{submitted_order.id}",
              params: { order: { notes: 'forbidden' } }.to_json,
              headers: auth_headers(sales_user)

        expect(response).to have_http_status(:forbidden)
      end

      it 'returns 403 when trying to update an approved (non-editable) order' do
        approved_order = create(:sales_order, organization: org, branch: branch, customer: customer,
                                created_by: owner, status: 'approved',
                                submitted_at: Time.current, approved_at: Time.current)

        patch "/api/v1/sales_orders/#{approved_order.id}",
              params: { order: { notes: 'post-approval edit' } }.to_json,
              headers: auth_headers(manager)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # ─── POST /api/v1/sales_orders/from_mobile ────────────────────────────────
  describe 'POST /api/v1/sales_orders/from_mobile' do
    let(:valid_params) do
      {
        order: {
          customer_id:   customer.id,
          branch_id:     branch.id,
          delivery_date: 7.days.from_now.to_date,
          lines: [{ product_id: product.id, qty: 3, discount_pct: 0 }]
        },
        idempotency_key: SecureRandom.uuid
      }
    end

    it 'creates and submits in one call' do
      post '/api/v1/sales_orders/from_mobile',
           params: valid_params.to_json,
           headers: auth_headers

      expect(response).to have_http_status(:created)
      expect(json_body['data']['status']).to eq('submitted')
    end

    it 'is idempotent — returns existing order on duplicate key' do
      key = SecureRandom.uuid
      post '/api/v1/sales_orders/from_mobile',
           params: valid_params.merge(idempotency_key: key).to_json,
           headers: auth_headers
      expect(response).to have_http_status(:created)

      first_id = json_body['data']['id']

      # Second call with same key
      post '/api/v1/sales_orders/from_mobile',
           params: valid_params.merge(idempotency_key: key).to_json,
           headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['id']).to eq(first_id)
    end
  end
end
