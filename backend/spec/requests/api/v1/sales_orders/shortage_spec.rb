require 'rails_helper'

RSpec.describe Api::V1::SalesOrdersController, type: :request do
  let(:org) { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:user) { create(:user, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:product) { create(:product, organization: org, name: 'Widget') }

  let(:order) do
    o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: user)
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

  describe 'POST /api/v1/sales_orders/:id/detect_shortage' do
    before do
      allow_any_instance_of(Api::V1::BaseController).to receive(:current_user).and_return(user)
    end

    context 'with no shortage' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 100, qty_reserved: 0)
      end

      it 'returns has_shortage: false' do
        post "/api/v1/sales_orders/#{order.id}/detect_shortage", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['has_shortage']).to be false
        expect(json['data']['shortage_items']).to be_empty
      end
    end

    context 'with partial shortage' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 30, qty_reserved: 0)
      end

      it 'returns shortage details' do
        post "/api/v1/sales_orders/#{order.id}/detect_shortage", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['has_shortage']).to be true
        expect(json['data']['shortage_items'].count).to eq(1)
        expect(json['data']['shortage_items'][0]['shortage_qty']).to eq(20)
        expect(json['data']['shortage_items'][0]['shortage_value']).to eq(2000)
        expect(json['data']['total_shortage_value']).to eq(2000)
      end

      it 'includes resolution options' do
        post "/api/v1/sales_orders/#{order.id}/detect_shortage", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['resolution_options']).to include('refund', 'partial', 'reschedule', 'override')
      end
    end

    context 'with complete shortage' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 0, qty_reserved: 0)
      end

      it 'detects complete shortage' do
        post "/api/v1/sales_orders/#{order.id}/detect_shortage", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['has_shortage']).to be true
        expect(json['data']['shortage_items'][0]['shortage_qty']).to eq(50)
        expect(json['data']['total_shortage_qty']).to eq(50)
      end
    end

    context 'with multiple items with mixed shortages' do
      let(:product_b) { create(:product, organization: org, name: 'Item B') }
      let(:order) do
        o = create(:sales_order, organization: org, branch: branch, customer: customer, created_by: user)
        create(:sales_order_line, sales_order: o, product: product, qty: 100, unit_price: 10)
        create(:sales_order_line, sales_order: o, product: product_b, qty: 50, unit_price: 20)
        o.recalculate_totals!
        o
      end

      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 100, qty_reserved: 0)
        create(:inventory_level, organization: org, branch: branch, product: product_b,
               qty_on_hand: 25, qty_reserved: 0)
      end

      it 'returns shortage for items with insufficient stock' do
        post "/api/v1/sales_orders/#{order.id}/detect_shortage", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['shortage_items'].count).to eq(1) # Only product_b has shortage
        expect(json['data']['shortage_items'][0]['product_id']).to eq(product_b.id)
        expect(json['data']['shortage_items'][0]['shortage_qty']).to eq(25)
      end
    end

    context 'when order does not exist' do
      it 'returns not found' do
        post "/api/v1/sales_orders/99999/detect_shortage", headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /api/v1/sales_orders/:id/resolve_shortage' do
    before do
      allow_any_instance_of(Api::V1::BaseController).to receive(:current_user).and_return(user)
      allow_any_instance_of(Api::V1::BaseController).to receive(:authorize) { true }
    end

    context 'refund resolution' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 0, qty_reserved: 0)
      end

      it 'cancels order with refund resolution' do
        post "/api/v1/sales_orders/#{order.id}/resolve_shortage",
             params: {
               resolution_type: 'refund',
               notes:           'Out of stock, full refund approved'
             }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['order']['status']).to eq('cancelled')
        expect(json['data']['refunded_amount']).to eq(5000)
      end

      it 'includes resolution notes in response' do
        post "/api/v1/sales_orders/#{order.id}/resolve_shortage",
             params: {
               resolution_type: 'refund'
             }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['resolution_notes']).to be_present
      end
    end

    context 'partial resolution' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 30, qty_reserved: 0)
      end

      it 'processes partial delivery' do
        post "/api/v1/sales_orders/#{order.id}/resolve_shortage",
             params: {
               resolution_type: 'partial',
               notes:           'Partial stock available'
             }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['order']['status']).to eq('partially_fulfilled')
        expect(json['data']['refunded_amount']).to eq(2000) # 20 items * 100
      end
    end

    context 'reschedule resolution' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 30, qty_reserved: 0)
      end

      it 'reschedules order' do
        post "/api/v1/sales_orders/#{order.id}/resolve_shortage",
             params: {
               resolution_type: 'reschedule',
               notes:           'Stock arriving next week'
             }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['order']['status']).to eq('rescheduled')
        expect(json['data']['refunded_amount']).to eq(0)
      end
    end

    context 'override resolution' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 0, qty_reserved: 0)
      end

      it 'approves order despite shortage' do
        post "/api/v1/sales_orders/#{order.id}/resolve_shortage",
             params: {
               resolution_type: 'override',
               notes:           'Manager approved for VIP customer'
             }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['order']['status']).to eq('approved')
      end
    end

    context 'with customer communication preferences' do
      before do
        create(:inventory_level, organization: org, branch: branch, product: product,
               qty_on_hand: 30, qty_reserved: 0)
      end

      it 'accepts email communication flag' do
        post "/api/v1/sales_orders/#{order.id}/resolve_shortage",
             params: {
               resolution_type: 'partial',
               customer_communication: { email: true }
             }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
      end

      it 'accepts SMS communication flag' do
        post "/api/v1/sales_orders/#{order.id}/resolve_shortage",
             params: {
               resolution_type: 'partial',
               customer_communication: { sms: true }
             }.to_json,
             headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'error handling' do
      it 'fails with invalid resolution type' do
        post "/api/v1/sales_orders/#{order.id}/resolve_shortage",
             params: {
               resolution_type: 'invalid_type'
             }.to_json,
             headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end

      it 'fails when order does not exist' do
        post "/api/v1/sales_orders/99999/resolve_shortage",
             params: {
               resolution_type: 'refund'
             }.to_json,
             headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
