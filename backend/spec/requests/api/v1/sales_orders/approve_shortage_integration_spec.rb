require 'rails_helper'

RSpec.describe Api::V1::SalesOrdersController, type: :request do
  let(:org) { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:user) { create(:user, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:product) { create(:product, organization: org) }

  let(:order) do
    o = create(:sales_order, organization: org, branch: branch, customer: customer, 
               created_by: user, status: 'on_hold')
    create(:sales_order_line, sales_order: o, product: product, qty: 50, unit_price: 100)
    o.recalculate_totals!
    o
  end

  let(:headers) do
    {
      'Authorization' => "Bearer #{user.auth_token}",
      'X-Organization-ID' => org.id.to_s,
      'Content-Type' => 'application/json'
    }
  end

  describe 'Feature 12 Integration: POST /api/v1/sales_orders/:id/approve with shortage detection' do
    before do
      allow_any_instance_of(Api::V1::BaseController).to receive(:current_user).and_return(user)
    end

    context 'when no shortage exists' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 100, qty_reserved: 0)
      end

      it 'approves order immediately without shortage check delay' do
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['status']).to eq('approved')
        expect(json['data']['shortage_blocked']).to be_falsey
      end
    end

    context 'when partial shortage exists' do
      before do
        # 50 requested, 30 available, 20 short
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 30, qty_reserved: 0)
      end

      it 'blocks approval and returns shortage details' do
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['data']['shortage_blocked']).to be true
      end

      it 'includes shortage_detection in response' do
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        json = JSON.parse(response.body)
        shortage = json['data']['shortage_detection']
        expect(shortage['has_shortage']).to be true
        expect(shortage['shortage_items']).to be_present
        expect(shortage['total_shortage_qty']).to eq(20)
        expect(shortage['total_shortage_value']).to eq(2000)
        expect(shortage['resolution_options']).to include('refund', 'partial', 'reschedule', 'override')
        expect(shortage['message']).to include('resolve shortage')
      end

      it 'does not change order status' do
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        expect(order.reload.status).to eq('on_hold')
      end

      it 'returns order data in response for UI context' do
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        json = JSON.parse(response.body)
        expect(json['data']['order']).to be_present
        expect(json['data']['order']['id']).to eq(order.id)
        expect(json['data']['order']['status']).to eq('on_hold')
      end
    end

    context 'workflow: shortage detected → resolved → approved' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 30, qty_reserved: 0)
      end

      it 'first approve call blocks with shortage' do
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['data']['shortage_blocked']).to be true
      end

      it 'can resolve via partial and then approve' do
        # First attempt blocked
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)

        # Resolve shortage
        post "/api/v1/sales_orders/#{order.id}/resolve_shortage",
             params: {
               resolution_type: 'partial'
             }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)

        # Second approve should succeed
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['status']).to eq('approved')
      end

      it 'can resolve via override and then approve' do
        # First attempt blocked
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)

        # Resolve via override
        post "/api/v1/sales_orders/#{order.id}/resolve_shortage",
             params: {
               resolution_type: 'override',
               notes: 'Manager approved'
             }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)

        # Approve should now succeed
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        expect(order.reload.status).to eq('approved')
      end
    end

    context 'rejection bypasses shortage check' do
      before do
        # Complete shortage
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 0, qty_reserved: 0)
      end

      it 'rejects order despite shortage' do
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: {
               decision: 'rejected',
               reason: 'Insufficient credit'
             }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['status']).to eq('rejected')
        expect(json['data']['shortage_blocked']).to be_falsey
      end
    end

    context 'complete shortage' do
      before do
        # 50 requested, 0 available
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 0, qty_reserved: 0)
      end

      it 'blocks with complete shortage details' do
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        shortage = json['data']['shortage_detection']
        expect(shortage['total_shortage_qty']).to eq(50)
        expect(shortage['total_shortage_value']).to eq(5000)
      end
    end

    context 'multiple items with mixed shortages' do
      let(:product_b) { create(:product, organization: org) }
      let(:order) do
        o = create(:sales_order, organization: org, branch: branch, customer: customer, 
                   created_by: user, status: 'on_hold')
        create(:sales_order_line, sales_order: o, product: product, qty: 100, unit_price: 10)
        create(:sales_order_line, sales_order: o, product: product_b, qty: 50, unit_price: 20)
        o.recalculate_totals!
        o
      end

      before do
        # Product A: no shortage
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 100, qty_reserved: 0)
        # Product B: 25 short
        create(:inventory_level, organization: org, branch: branch, product: product_b,
               qty_on_hand: 25, qty_reserved: 0)
      end

      it 'reports shortage for affected items only' do
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        json = JSON.parse(response.body)
        shortage = json['data']['shortage_detection']
        expect(shortage['shortage_items'].length).to eq(1)
        expect(shortage['shortage_items'][0]['product_id']).to eq(product_b.id)
        expect(shortage['shortage_items'][0]['shortage_qty']).to eq(25)
      end
    end

    context 'when dunning suspension exists' do
      before do
        customer.update(dunning_suspended_at: Time.current)
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 100, qty_reserved: 0)
      end

      it 'returns dunning error before checking shortages' do
        post "/api/v1/sales_orders/#{order.id}/approve",
             params: { decision: 'approved' }.to_json,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to include(/suspended/)
      end
    end
  end
end
