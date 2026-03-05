require 'rails_helper'

RSpec.describe 'Api::V1::SalesInvoices', type: :request do
  # ── Helpers ───────────────────────────────────────────────────────────────────

  let(:org)     { create(:organization) }
  let(:branch)  { create(:branch, organization: org) }
  let(:owner)   { create(:user, organization: org, branch: branch, role: 'owner') }
  let(:manager) { create(:user, organization: org, branch: branch, role: 'manager') }
  let(:sales)   { create(:user, organization: org, branch: branch, role: 'sales_rep') }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:product)  { create(:product, organization: org) }

  def generate_jwt_for(user)
    JWT.encode(
      { sub: user.id, org: user.organization_id, exp: 1.hour.from_now.to_i },
      Rails.application.credentials.jwt_secret || 'test-secret',
      'HS256'
    )
  end

  def auth_headers(user = owner)
    {
      'Authorization' => "Bearer #{generate_jwt_for(user)}",
      'X-Organization-Id' => org.id.to_s,
      'Content-Type' => 'application/json'
    }
  end

  def json_body
    JSON.parse(response.body)
  end

  def create_issued_invoice(user: owner, **overrides)
    create(:sales_invoice,
           organization: org, branch: branch, customer: customer,
           created_by: user, status: 'issued', issued_at: Time.current,
           **overrides)
  end

  # ── GET /api/v1/sales_invoices ────────────────────────────────────────────────

  describe 'GET /api/v1/sales_invoices' do
    before { create_list(:sales_invoice, 3, organization: org, branch: branch,
                          customer: customer, created_by: owner,
                          status: 'issued', issued_at: Time.current) }

    context 'as an authenticated member' do
      it 'returns 200 with a list of invoices' do
        get '/api/v1/sales_invoices', headers: auth_headers(manager)
        expect(response).to have_http_status(:ok)
        expect(json_body['data'].length).to eq(3)
      end

      it 'includes meta with total count' do
        get '/api/v1/sales_invoices', headers: auth_headers
        expect(json_body['meta']['total']).to be >= 3
      end
    end

    context 'filter by status' do
      before do
        create(:sales_invoice, organization: org, branch: branch, customer: customer,
               created_by: owner, status: 'draft')
      end

      it 'filters to issued only' do
        get '/api/v1/sales_invoices?status=issued', headers: auth_headers
        statuses = json_body['data'].map { |i| i['status'] }.uniq
        expect(statuses).to eq(['issued'])
      end

      it 'filters to draft only' do
        get '/api/v1/sales_invoices?status=draft', headers: auth_headers
        statuses = json_body['data'].map { |i| i['status'] }.uniq
        expect(statuses).to eq(['draft'])
      end
    end

    context 'filter by customer_id' do
      let(:other_customer) { create(:customer, organization: org, branch: branch) }

      before do
        create(:sales_invoice, organization: org, branch: branch, customer: other_customer,
               created_by: owner, status: 'issued', issued_at: Time.current)
      end

      it 'returns only invoices for the specified customer' do
        get "/api/v1/sales_invoices?customer_id=#{customer.id}",
            headers: auth_headers
        ids = json_body['data'].map { |i| i['customer']['id'] }.uniq
        expect(ids).to eq([customer.id])
      end
    end

    context 'filter by date range' do
      before do
        create(:sales_invoice, organization: org, branch: branch, customer: customer,
               created_by: owner, status: 'issued', issued_at: Time.current,
               invoice_date: 30.days.ago.to_date)
      end

      it 'returns invoices within the date range' do
        get "/api/v1/sales_invoices?from_date=#{7.days.ago.to_date}&to_date=#{Date.today}",
            headers: auth_headers
        invoice_dates = json_body['data'].map { |i| i['invoice_date'] }
        expect(invoice_dates).not_to include(30.days.ago.to_date.iso8601)
      end
    end

    context 'filter by branch_id' do
      let(:other_branch)  { create(:branch, organization: org, code: 'OTR') }

      before do
        create(:sales_invoice, organization: org, branch: other_branch,
               customer: customer, created_by: owner,
               status: 'issued', issued_at: Time.current)
      end

      it 'scopes to specified branch' do
        get "/api/v1/sales_invoices?branch_id=#{branch.id}", headers: auth_headers
        branch_ids = json_body['data'].map { |i| i['branch_id'] }.uniq
        expect(branch_ids).to eq([branch.id])
      end
    end

    context 'search by invoice_number (q param)' do
      let!(:target) { create_issued_invoice(invoice_number: 'SI-MUM-202603-0099') }

      it 'returns matching invoice' do
        get '/api/v1/sales_invoices?q=SI-MUM-202603-0099', headers: auth_headers
        numbers = json_body['data'].map { |i| i['invoice_number'] }
        expect(numbers).to include('SI-MUM-202603-0099')
      end
    end

    context 'without auth' do
      it 'returns 401' do
        get '/api/v1/sales_invoices'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ── GET /api/v1/sales_invoices/:id ────────────────────────────────────────────

  describe 'GET /api/v1/sales_invoices/:id' do
    let(:invoice) { create_issued_invoice }

    it 'returns invoice detail for a member' do
      get "/api/v1/sales_invoices/#{invoice.id}", headers: auth_headers(manager)
      expect(response).to have_http_status(:ok)
      expect(json_body['data']['id']).to eq(invoice.id)
    end

    it 'includes lines in detailed response' do
      create(:sales_invoice_line, sales_invoice: invoice, product: product,
             qty: 5, unit_price: 100, gst_rate: 18,
             taxable_value: 500, tax_amount: 90, line_total: 590,
             cgst_rate: 9, sgst_rate: 9, igst_rate: 0,
             cgst_amount: 45, sgst_amount: 45, igst_amount: 0)
      get "/api/v1/sales_invoices/#{invoice.id}", headers: auth_headers
      expect(json_body['data']['lines'].length).to eq(1)
    end

    it 'returns 404 for unknown id' do
      get '/api/v1/sales_invoices/0', headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── POST /api/v1/sales_invoices ───────────────────────────────────────────────

  describe 'POST /api/v1/sales_invoices' do
    let(:valid_params) do
      {
        sales_invoice: {
          branch_id:         branch.id,
          customer_id:       customer.id,
          invoice_date:      Date.today.iso8601,
          generation_source: 'manual_direct',
          lines_attributes:  [
            {
              product_id:    product.id,
              qty:           5,
              unit_price:    200,
              discount_pct:  0,
              hsn_code:      '22011000',
              gst_rate:      18
            }
          ]
        }
      }
    end

    context 'as manager' do
      it 'creates and returns 201' do
        post '/api/v1/sales_invoices', params: valid_params.to_json,
             headers: auth_headers(manager)
        expect(response).to have_http_status(:created)
        expect(json_body['data']['invoice_number']).to match(/\ASI-/)
      end
    end

    context 'as sales_rep' do
      it 'returns 403' do
        post '/api/v1/sales_invoices', params: valid_params.to_json,
             headers: auth_headers(sales)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without auth' do
      it 'returns 401' do
        post '/api/v1/sales_invoices', params: valid_params.to_json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ── POST /api/v1/sales_invoices/generate_from_order/:id ──────────────────────

  describe 'POST generate_from_order' do
    let(:order) do
      create(:sales_order, organization: org, branch: branch, customer: customer,
             created_by: owner, status: 'delivered')
    end
    let(:sol) do
      create(:sales_order_line, sales_order: order, product: product,
             qty: 10, unit_price: 100, discount_pct: 0,
             gst_rate: 18, hsn_code: '22011000',
             delivered_qty: 10, invoiced_qty: 0)
    end

    let(:params) do
      {
        lines: [{
          sales_order_line_id: sol.id,
          product_id:          product.id,
          qty:                 sol.delivered_qty
        }]
      }
    end

    before { sol } # materialise

    it 'generates an invoice and returns 201 for manager' do
      post "/api/v1/sales_invoices/generate_from_order/#{order.id}",
           params: params.to_json, headers: auth_headers(manager)
      expect(response).to have_http_status(:created)
    end

    it 'returns 403 for sales_rep' do
      post "/api/v1/sales_invoices/generate_from_order/#{order.id}",
           params: params.to_json, headers: auth_headers(sales)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ── POST /api/v1/sales_invoices/:id/issue ─────────────────────────────────────

  describe 'POST /api/v1/sales_invoices/:id/issue' do
    let(:draft) do
      create(:sales_invoice, organization: org, branch: branch, customer: customer,
             created_by: owner, status: 'draft')
    end

    it 'issues a draft invoice for manager' do
      post "/api/v1/sales_invoices/#{draft.id}/issue", headers: auth_headers(manager)
      expect(response).to have_http_status(:ok)
      expect(json_body['data']['status']).to eq('issued')
    end

    it 'returns 403 for sales_rep' do
      post "/api/v1/sales_invoices/#{draft.id}/issue", headers: auth_headers(sales)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ── POST /api/v1/sales_invoices/:id/void ─────────────────────────────────────

  describe 'POST /api/v1/sales_invoices/:id/void' do
    let(:invoice) { create_issued_invoice }

    it 'voids an invoice for owner' do
      post "/api/v1/sales_invoices/#{invoice.id}/void",
           params: { reason: 'Duplicate entry' }.to_json,
           headers: auth_headers(owner)
      expect(response).to have_http_status(:ok)
      expect(json_body['data']['status']).to eq('void')
    end

    it 'returns 403 for manager' do
      post "/api/v1/sales_invoices/#{invoice.id}/void",
           params: { reason: 'Not allowed' }.to_json,
           headers: auth_headers(manager)
      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 422 when reason is blank' do
      post "/api/v1/sales_invoices/#{invoice.id}/void",
           params: { reason: '' }.to_json,
           headers: auth_headers(owner)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ── GET /api/v1/sales_invoices/:id/pdf ───────────────────────────────────────

  describe 'GET /api/v1/sales_invoices/:id/pdf' do
    let(:invoice) { create_issued_invoice }

    before do
      allow_any_instance_of(Invoice::PdfRendererService)
        .to receive(:call).and_return(
          Invoice::PdfRendererService::Result.new(
            success?: true, url: 'https://example.com/signed/invoice.pdf', error: nil
          )
        )
    end

    it 'returns a signed download_url for a member' do
      get "/api/v1/sales_invoices/#{invoice.id}/pdf",
          headers: auth_headers(sales)
      expect(response).to have_http_status(:ok)
      expect(json_body['data']['download_url']).to be_present
    end

    it 'returns 403 for unauthenticated request' do
      get "/api/v1/sales_invoices/#{invoice.id}/pdf"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
