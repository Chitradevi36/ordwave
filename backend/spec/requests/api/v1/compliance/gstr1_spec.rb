# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Compliance::Gstr1', type: :request do
  # ── Shared setup ─────────────────────────────────────────────────────────────

  let(:owner_role)   { create(:role, name: 'owner') }
  let(:manager_role) { create(:role, name: 'manager') }
  let(:sales_role)   { create(:role, name: 'sales_rep') }

  let(:org)    { create(:organization, gst_number: '27ABCDE1234F1Z5') }
  let(:branch) { create(:branch, organization: org, state_code: '27', state: 'Maharashtra') }
  let(:owner)  { create(:user) }
  let(:manager) { create(:user) }
  let(:sales_rep) { create(:user) }

  let!(:owner_membership) do
    create(:membership, user: owner, organization: org, branch: branch, role: owner_role)
  end
  let!(:manager_membership) do
    create(:membership, user: manager, organization: org, branch: branch, role: manager_role)
  end
  let!(:sales_membership) do
    create(:membership, user: sales_rep, organization: org, branch: branch, role: sales_role)
  end

  # Customer with GSTIN (B2B)
  let(:registered_customer) do
    create(:customer, organization: org, branch: branch,
           gstin: '29AAAAA0000A1Z5', name: 'Karnataka Customer')
  end

  # Customer without GSTIN (B2C)
  let(:unregistered_customer) do
    create(:customer, organization: org, branch: branch, gstin: nil, name: 'Walk-in Customer')
  end

  let(:product) { create(:product, organization: org, hsn_code: '10060010') }

  let(:this_month) { Date.current.beginning_of_month }
  let(:month)      { Date.current.month }
  let(:year)       { Date.current.year }

  # Factory helper — creates an invoice with a single line
  def make_invoice(customer:, total: 1_180.0, status: 'issued')
    inv = create(:sales_invoice,
      organization: org,
      branch:       branch,
      customer:     customer,
      status:       status,
      subtotal:     1_000.0,
      tax_total:      180.0,
      grand_total:  total,
      invoice_date: this_month + 5
    )
    create(:sales_invoice_line,
      sales_invoice: inv,
      product:       product,
      qty:           10,
      unit_price:    100.0,
      taxable_value: 1_000.0,
      hsn_code:      '10060010',
      gst_rate:      18.0,
      cgst_rate: 9.0, cgst_amount: 90.0,
      sgst_rate: 9.0, sgst_amount: 90.0,
      igst_rate: 0.0, igst_amount:  0.0,
      tax_amount:    180.0,
      line_total:  1_180.0
    )
    inv
  end

  # ── Auth helpers ─────────────────────────────────────────────────────────────

  def generate_jwt_for(user)
    payload = {
      sub:   user.id,
      email: user.email,
      jti:   SecureRandom.uuid,
      exp:   24.hours.from_now.to_i
    }
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

  # ── GET /api/v1/compliance/gstr1/preview ─────────────────────────────────────

  describe 'GET /api/v1/compliance/gstr1/preview' do
    let!(:b2b_invoice) { make_invoice(customer: registered_customer) }
    let!(:b2c_invoice) { make_invoice(customer: unregistered_customer) }

    context 'as a member (sales rep)' do
      it 'returns 200 with preview data' do
        get '/api/v1/compliance/gstr1/preview',
            headers: auth_headers(sales_rep),
            params:  { month: month, year: year }

        expect(response).to have_http_status(:ok)
      end

      it 'response includes required top-level keys' do
        get '/api/v1/compliance/gstr1/preview',
            headers: auth_headers(sales_rep),
            params:  { month: month, year: year }

        data = json_body['data']
        expect(data.keys).to include('b2b', 'b2c', 'cdnr', 'hsn_summary', 'summary', 'validation')
      end

      it 'b2b array has correct shape' do
        get '/api/v1/compliance/gstr1/preview',
            headers: auth_headers(sales_rep),
            params:  { month: month, year: year }

        b2b = json_body['data']['b2b']
        expect(b2b).to be_an(Array)
        expect(b2b.first.keys).to include('customer_name', 'gstin', 'invoice_count', 'taxable_value', 'tax_amount', 'total')
      end

      it 'summary has correct aggregation' do
        get '/api/v1/compliance/gstr1/preview',
            headers: auth_headers(sales_rep),
            params:  { month: month, year: year }

        summary = json_body['data']['summary']
        expect(summary['total_invoices']).to eq(2)
        expect(summary['total_taxable'].to_f).to be_within(0.01).of(2_000.0)
      end

      it 'includes validation section' do
        get '/api/v1/compliance/gstr1/preview',
            headers: auth_headers(sales_rep),
            params:  { month: month, year: year }

        validation = json_body['data']['validation']
        expect(validation.keys).to include('valid', 'error_count', 'warning_count', 'errors', 'warnings')
      end
    end

    context 'without authentication' do
      it 'returns 401' do
        get '/api/v1/compliance/gstr1/preview', params: { month: month, year: year }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with explicit period_from / period_to params' do
      it 'accepts date params and returns filtered data' do
        get '/api/v1/compliance/gstr1/preview',
            headers: auth_headers,
            params:  {
              period_from: this_month.iso8601,
              period_to:   this_month.end_of_month.iso8601
            }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when org has no gst_number configured' do
      let(:no_gst_org)    { create(:organization, gst_number: nil) }
      let(:no_gst_branch) { create(:branch, organization: no_gst_org, state_code: '27') }
      let(:no_gst_owner)  { create(:user) }
      let!(:no_gst_ms)    do
        create(:membership, user: no_gst_owner, organization: no_gst_org,
               branch: no_gst_branch, role: owner_role)
      end

      it 'still returns 200 but validation.valid? is false' do
        get '/api/v1/compliance/gstr1/preview',
            headers: { 'Authorization' => "Bearer #{generate_jwt_for(no_gst_owner)}",
                       'X-Organization-Id' => no_gst_org.id.to_s },
            params: { month: month, year: year }

        expect(response).to have_http_status(:ok)
        expect(json_body['data']['validation']['valid']).to be false
      end
    end
  end

  # ── GET /api/v1/compliance/gstr1/export ──────────────────────────────────────

  describe 'GET /api/v1/compliance/gstr1/export' do
    let!(:b2b_invoice) { make_invoice(customer: registered_customer) }

    context 'as manager' do
      it 'returns a JSON file attachment' do
        get '/api/v1/compliance/gstr1/export',
            headers: auth_headers(manager),
            params:  { month: month, year: year }

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to include('application/json')
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include('.json')
      end

      it 'returns valid JSON with portal-required keys' do
        get '/api/v1/compliance/gstr1/export',
            headers: auth_headers(manager),
            params:  { month: month, year: year }

        json = JSON.parse(response.body)
        expect(json.keys).to include('gstin', 'fp', 'b2b', 'b2cl', 'b2cs', 'cdnr', 'hsn', 'doc_issue')
      end

      it 'filename contains the GSTIN and period' do
        get '/api/v1/compliance/gstr1/export',
            headers: auth_headers(manager),
            params:  { month: month, year: year }

        disposition = response.headers['Content-Disposition']
        expect(disposition).to include('27ABCDE1234F1Z5')
        expect(disposition).to include("#{month.to_s.rjust(2, '0')}#{year}")
      end

      it 'creates a Gstr1ExportRecord audit row' do
        expect {
          get '/api/v1/compliance/gstr1/export',
              headers: auth_headers(manager),
              params:  { month: month, year: year }
        }.to change(Gstr1ExportRecord, :count).by(1)
      end

      it 'includes FINALIZED invoices (paid, partially_paid) — regression' do
        paid_inv = make_invoice(customer: registered_customer, status: 'paid')
        partial_inv = make_invoice(customer: registered_customer, status: 'partially_paid')

        get '/api/v1/compliance/gstr1/export',
            headers: auth_headers(manager),
            params:  { month: month, year: year }

        json      = JSON.parse(response.body)
        b2b_invs  = json['b2b'].flat_map { |g| g['inv'] }
        inv_nums  = b2b_invs.map { |i| i['inum'] }
        expect(inv_nums).to include(paid_inv.invoice_number, partial_inv.invoice_number)
      end
    end

    context 'as sales_rep (insufficient role)' do
      it 'returns 403 forbidden' do
        get '/api/v1/compliance/gstr1/export',
            headers: auth_headers(sales_rep),
            params:  { month: month, year: year }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when org has no GSTIN (MISSING_SELLER_GSTIN error)' do
      let(:no_gst_org)    { create(:organization, gst_number: nil) }
      let(:no_gst_branch) { create(:branch, organization: no_gst_org, state_code: '27') }
      let(:no_gst_manager) { create(:user) }
      let!(:_ms) do
        create(:membership, user: no_gst_manager, organization: no_gst_org,
               branch: no_gst_branch, role: manager_role)
      end

      it 'returns 422 unprocessable_entity' do
        get '/api/v1/compliance/gstr1/export',
            headers: { 'Authorization' => "Bearer #{generate_jwt_for(no_gst_manager)}",
                       'X-Organization-Id' => no_gst_org.id.to_s },
            params: { month: month, year: year }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ── GET /api/v1/compliance/gstr1/export_records ──────────────────────────────

  describe 'GET /api/v1/compliance/gstr1/export_records' do
    let!(:export_record) do
      create(:gstr1_export_record,
        organization:  org,
        generated_by:  owner,
        gstin:         '27ABCDE1234F1Z5',
        return_period: '032026',
        period_from:   Date.new(2026, 3, 1),
        period_to:     Date.new(2026, 3, 31),
        status:        'ready'
      ) rescue nil  # skip if factory not yet defined (factory added below)
    end

    context 'as manager' do
      it 'returns 200 with export_records array' do
        get '/api/v1/compliance/gstr1/export_records',
            headers: auth_headers(manager)

        expect(response).to have_http_status(:ok)
        expect(json_body['data']).to have_key('export_records')
      end
    end

    context 'as sales_rep' do
      it 'returns 403' do
        get '/api/v1/compliance/gstr1/export_records',
            headers: auth_headers(sales_rep)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
