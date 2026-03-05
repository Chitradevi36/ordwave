require 'rails_helper'

RSpec.describe 'Api::V1::PurchaseInvoices', type: :request do
  # ─── Setup ─────────────────────────────────────────────────────────────────
  let(:owner_role)      { create(:role, name: 'owner') }
  let(:accountant_role) { create(:role, name: 'accountant') }
  let(:sales_role)      { create(:role, name: 'sales_rep') }

  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  let(:owner) { create(:user) }
  let!(:owner_membership) do
    create(:membership, user: owner, organization: org, branch: branch, role: owner_role)
  end

  let(:sales_user) { create(:user) }
  let!(:sales_membership) do
    create(:membership, user: sales_user, organization: org, branch: branch, role: sales_role)
  end

  let(:supplier) { create(:supplier, organization: org) }
  let(:product)  { create(:product,  organization: org) }

  let!(:invoice) do
    create(:purchase_invoice, organization: org, branch: branch, supplier: supplier, created_by: owner)
  end

  def generate_jwt_for(user)
    payload = { sub: user.id, email: user.email, jti: SecureRandom.uuid, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def auth_headers(user = owner)
    {
      'Authorization'      => "Bearer #{generate_jwt_for(user)}",
      'X-Organization-Id'  => org.id.to_s,
      'Content-Type'       => 'application/json'
    }
  end

  def json_body = JSON.parse(response.body)

  # ─── GET /api/v1/purchase_invoices ─────────────────────────────────────────
  describe 'GET /api/v1/purchase_invoices' do
    it 'returns paginated invoices' do
      get '/api/v1/purchase_invoices', headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']).to be_an(Array)
      expect(json_body['data'].map { |i| i['id'] }).to include(invoice.id)
    end

    it 'filters by status' do
      posted = create(:purchase_invoice, :posted,
                      organization: org, branch: branch, supplier: supplier, created_by: owner)
      get '/api/v1/purchase_invoices', params: { status: 'posted' }, headers: auth_headers

      ids = json_body['data'].map { |i| i['id'] }
      expect(ids).to     include(posted.id)
      expect(ids).not_to include(invoice.id)
    end

    it 'filters by supplier_id' do
      other_supplier = create(:supplier, organization: org)
      other_inv = create(:purchase_invoice,
                         organization: org, branch: branch,
                         supplier: other_supplier, created_by: owner)
      get '/api/v1/purchase_invoices',
          params: { supplier_id: supplier.id }, headers: auth_headers

      ids = json_body['data'].map { |i| i['id'] }
      expect(ids).to     include(invoice.id)
      expect(ids).not_to include(other_inv.id)
    end

    it 'isolates invoices to the current organization' do
      other_org      = create(:organization)
      other_branch   = create(:branch, organization: other_org)
      other_supplier = create(:supplier, organization: other_org)
      other_user     = create(:user)
      create(:membership, user: other_user, organization: other_org,
             branch: other_branch, role: owner_role)
      create(:purchase_invoice,
             organization: other_org, branch: other_branch,
             supplier: other_supplier, created_by: other_user)

      get '/api/v1/purchase_invoices', headers: auth_headers
      org_ids = json_body['data'].map { |i| i['id'] }
      expect(org_ids).to include(invoice.id)
      expect(org_ids.length).to eq(1)
    end
  end

  # ─── GET /api/v1/purchase_invoices/:id ─────────────────────────────────────
  describe 'GET /api/v1/purchase_invoices/:id' do
    it 'returns detailed invoice with lines and stock_movements' do
      create(:purchase_invoice_line, purchase_invoice: invoice, product: product)

      get "/api/v1/purchase_invoices/#{invoice.id}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      data = json_body['data']
      expect(data['invoice_number']).to eq(invoice.invoice_number)
      expect(data['lines']).to be_an(Array)
      expect(data['stock_movements']).to be_an(Array)
    end

    it 'returns 404 for unknown id' do
      get '/api/v1/purchase_invoices/999999', headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ─── POST /api/v1/purchase_invoices ────────────────────────────────────────
  describe 'POST /api/v1/purchase_invoices' do
    let(:valid_params) do
      {
        purchase_invoice: {
          supplier_id:    supplier.id,
          branch_id:      branch.id,
          invoice_number: 'INV-TEST-001',
          invoice_date:   Date.current.iso8601,
          currency:       'INR',
          lines_attributes: [
            {
              product_id:   product.id,
              qty:          '3',
              unit_price:   '200',
              discount_pct: '0',
              tax_rate:     '18',
            }
          ]
        }
      }
    end

    it 'creates a draft invoice with lines' do
      expect {
        post '/api/v1/purchase_invoices', params: valid_params.to_json, headers: auth_headers
      }.to change(PurchaseInvoice, :count).by(1)
       .and change(PurchaseInvoiceLine, :count).by(1)

      expect(response).to have_http_status(:created)
      data = json_body['data']
      expect(data['status']).to eq('draft')
      expect(data['invoice_number']).to eq('INV-TEST-001')
      expect(data['lines'].length).to eq(1)
    end

    it 'returns errors for missing required fields' do
      params = { purchase_invoice: { supplier_id: supplier.id, invoice_number: '' } }
      post '/api/v1/purchase_invoices', params: params.to_json, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body['errors']).to be_present
    end

    it 'returns 403 for sales_rep' do
      post '/api/v1/purchase_invoices', params: valid_params.to_json, headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── PATCH /api/v1/purchase_invoices/:id ───────────────────────────────────
  describe 'PATCH /api/v1/purchase_invoices/:id' do
    it 'updates a draft invoice' do
      patch "/api/v1/purchase_invoices/#{invoice.id}",
            params: { purchase_invoice: { notes: 'updated note' } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['notes']).to eq('updated note')
    end

    it 'rejects update of a posted invoice' do
      posted = create(:purchase_invoice, :posted,
                      organization: org, branch: branch, supplier: supplier, created_by: owner)
      patch "/api/v1/purchase_invoices/#{posted.id}",
            params: { purchase_invoice: { notes: 'hack' } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ─── POST /api/v1/purchase_invoices/:id/post ───────────────────────────────
  describe 'POST /api/v1/purchase_invoices/:id/post' do
    it 'transitions invoice from draft to posted and creates stock movements' do
      line = create(:purchase_invoice_line, purchase_invoice: invoice, product: product,
                    qty: 4, unit_price: 100, tax_rate: 18, tax_amount: 72, line_total: 472)
      invoice.recalculate_totals!

      expect {
        post "/api/v1/purchase_invoices/#{invoice.id}/post", headers: auth_headers
      }.to change(StockMovement, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['status']).to eq('posted')

      movement = StockMovement.last
      expect(movement.movement_type).to eq('purchase')
      expect(movement.direction).to     eq('in')
      expect(movement.qty.to_f).to      eq(4.0)

      level = InventoryLevel.find_by(branch: branch, product: product)
      expect(level).to             be_present
      expect(level.qty_on_hand.to_f).to eq(4.0)
    end

    it 'returns error for already-posted invoice' do
      posted = create(:purchase_invoice, :posted,
                      organization: org, branch: branch, supplier: supplier, created_by: owner)
      post "/api/v1/purchase_invoices/#{posted.id}/post", headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns 403 for sales_rep' do
      post "/api/v1/purchase_invoices/#{invoice.id}/post", headers: auth_headers(sales_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── POST /api/v1/purchase_invoices/:id/cancel ─────────────────────────────
  describe 'POST /api/v1/purchase_invoices/:id/cancel' do
    context 'cancelling a draft invoice' do
      it 'cancels without creating stock movements' do
        expect {
          post "/api/v1/purchase_invoices/#{invoice.id}/cancel",
               params: { reason: 'Test' }.to_json, headers: auth_headers
        }.not_to change(StockMovement, :count)

        expect(response).to have_http_status(:ok)
        expect(json_body['data']['status']).to eq('cancelled')
      end
    end

    context 'cancelling a posted invoice' do
      it 'creates reversal stock movements and decreases inventory' do
        line = create(:purchase_invoice_line, purchase_invoice: invoice, product: product,
                      qty: 3, unit_price: 100, tax_rate: 18, tax_amount: 54, line_total: 354)
        invoice.recalculate_totals!

        # First post it
        post "/api/v1/purchase_invoices/#{invoice.id}/post", headers: auth_headers
        expect(response).to have_http_status(:ok)

        level_before = InventoryLevel.find_by(branch: branch, product: product).qty_on_hand.to_f
        expect(level_before).to eq(3.0)

        # Then cancel it
        expect {
          post "/api/v1/purchase_invoices/#{invoice.id}/cancel",
               params: { reason: 'Returned to supplier' }.to_json, headers: auth_headers
        }.to change(StockMovement, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json_body['data']['status']).to eq('cancelled')

        reversal = StockMovement.last
        expect(reversal.movement_type).to eq('reversal')
        expect(reversal.direction).to     eq('out')

        level_after = InventoryLevel.find_by(branch: branch, product: product).qty_on_hand.to_f
        expect(level_after).to eq(0.0)
      end
    end
  end
end
