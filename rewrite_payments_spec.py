content = r"""require 'rails_helper'

RSpec.describe 'Api::V1::Payments', type: :request do
  # ── Test setup ───────────────────────────────────────────────────────────────
  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  def find_or_create_role(name)
    Role.find_by(name: name) || create(:role, name: name)
  end

  def create_user_with_role(role_name)
    user = create(:user)
    role = find_or_create_role(role_name)
    create(:membership, user: user, organization: org, branch: branch, role: role, active: true)
    user
  end

  let(:owner)    { create_user_with_role('owner') }
  let(:manager)  { create_user_with_role('manager') }
  let(:member)   { create_user_with_role('sales_rep') }
  let(:customer) { create(:customer, organization: org) }

  let(:credit_account) do
    create(:credit_account,
           organization:    org,
           customer:        customer,
           current_balance:  0,
           available_credit: 50_000,
           credit_limit:     50_000)
  end

  def generate_jwt_for(user)
    JWT.encode(
      { sub: user.id, exp: 1.hour.from_now.to_i },
      Rails.application.secret_key_base,
      'HS256'
    )
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

  def make_invoice(grand_total: 1_000.0, status: 'issued', days_ago: 5)
    create(:sales_invoice,
           organization:       org,
           branch:             branch,
           customer:           customer,
           created_by:         owner,
           grand_total:        grand_total,
           subtotal:           grand_total,
           tax_total:          0,
           outstanding_amount: grand_total,
           paid_amount:        0,
           status:             status,
           invoice_date:       Date.today - days_ago.days,
           issued_at:          Time.current - days_ago.days)
  end

  def make_draft_payment(amount: 1_000.0, mode: 'cash')
    create(:payment,
           organization:  org,
           branch:        branch,
           customer:      customer,
           created_by:    owner,
           amount:        amount,
           payment_mode:  mode,
           status:        'draft')
  end

  before { credit_account }

  # ── GET /api/v1/payments ─────────────────────────────────────────────────────
  describe 'GET /api/v1/payments' do
    before { 3.times { make_draft_payment } }

    context 'as an authenticated user' do
      it 'returns 200 with a list of payments' do
        get '/api/v1/payments', headers: auth_headers(manager)
        expect(response).to have_http_status(:ok)
        expect(json_body['data'].length).to be >= 3
      end

      it 'includes meta with total count' do
        get '/api/v1/payments', headers: auth_headers
        expect(json_body['meta']).to have_key('total')
      end
    end

    context 'filter by status' do
      before { make_draft_payment.update_columns(status: 'confirmed', confirmed_at: Time.current) }

      it 'filters to confirmed only' do
        get '/api/v1/payments?status=confirmed', headers: auth_headers
        statuses = json_body['data'].map { |p| p['status'] }.uniq
        expect(statuses).to eq(['confirmed'])
      end
    end

    context 'filter by customer_id' do
      let(:other_customer) { create(:customer, organization: org) }
      before { create(:payment, organization: org, branch: branch, customer: other_customer, created_by: owner) }

      it 'returns payments for the specified customer only' do
        get "/api/v1/payments?customer_id=#{customer.id}", headers: auth_headers
        customer_ids = json_body['data'].map { |p| p['customer_id'] }.uniq
        expect(customer_ids).to all(eq(customer.id))
      end
    end

    context 'without authentication' do
      it 'returns 401' do
        get '/api/v1/payments'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ── POST /api/v1/payments ────────────────────────────────────────────────────
  describe 'POST /api/v1/payments' do
    let(:valid_params) do
      {
        payment: {
          customer_id:   customer.id,
          branch_id:     branch.id,
          amount:        1_500.0,
          payment_mode:  'cash',
          received_date: Date.today.to_s,
          notes:         'Test payment'
        }
      }
    end

    context 'as a manager' do
      it 'creates a draft payment and returns 201' do
        post '/api/v1/payments', headers: auth_headers(manager), params: valid_params.to_json
        expect(response).to have_http_status(:created)
        expect(json_body['data']['status']).to eq('draft')
        expect(json_body['data']['amount'].to_f).to eq(1_500.0)
      end
    end

    context 'as a member (insufficient role)' do
      it 'returns 403' do
        post '/api/v1/payments', headers: auth_headers(member), params: valid_params.to_json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns 401' do
        post '/api/v1/payments', params: valid_params.to_json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ── GET /api/v1/payments/:id ─────────────────────────────────────────────────
  describe 'GET /api/v1/payments/:id' do
    let!(:payment) { make_draft_payment }

    context 'as an authenticated user' do
      it 'returns 200 with payment details' do
        get "/api/v1/payments/#{payment.id}", headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(json_body['data']['id']).to eq(payment.id)
        expect(json_body['data']).to have_key('allocations')
      end
    end

    context 'for a payment in another org' do
      let(:other_org)    { create(:organization) }
      let(:other_branch) { create(:branch, organization: other_org) }
      let(:other_user)   { create(:user) }
      let(:other_cust)   { create(:customer, organization: other_org) }
      let!(:other_payment) do
        create(:payment, organization: other_org, branch: other_branch,
               customer: other_cust, created_by: other_user)
      end

      it 'returns 404' do
        get "/api/v1/payments/#{other_payment.id}", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ── POST /api/v1/payments/:id/confirm ────────────────────────────────────────
  describe 'POST /api/v1/payments/:id/confirm' do
    let!(:inv)     { make_invoice(grand_total: 800.0) }
    let!(:payment) { make_draft_payment(amount: 800.0) }

    context 'as a manager' do
      it 'confirms the payment and returns 200' do
        post "/api/v1/payments/#{payment.id}/confirm", headers: auth_headers(manager)
        expect(response).to have_http_status(:ok)
        expect(json_body['data']['status']).to eq('confirmed')
      end

      it 'creates allocations to outstanding invoices' do
        expect do
          post "/api/v1/payments/#{payment.id}/confirm", headers: auth_headers(manager)
        end.to change(PaymentAllocation, :count).by(1)
      end
    end

    context 'as a member (insufficient role)' do
      it 'returns 403' do
        post "/api/v1/payments/#{payment.id}/confirm", headers: auth_headers(member)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when payment is already confirmed' do
      before { payment.update_columns(status: 'confirmed', confirmed_at: Time.current) }

      it 'returns 422' do
        post "/api/v1/payments/#{payment.id}/confirm", headers: auth_headers(manager)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ── POST /api/v1/payments/:id/reverse ────────────────────────────────────────
  describe 'POST /api/v1/payments/:id/reverse' do
    let!(:payment) { make_draft_payment(amount: 500.0) }

    before do
      inv = make_invoice(grand_total: 500.0)
      payment.update_columns(status: 'confirmed', confirmed_at: Time.current,
                             allocated_amount: 500, unallocated_amount: 0)
      create(:payment_allocation, payment: payment, sales_invoice: inv,
             allocated_amount: 500, status: 'active')
      inv.update_columns(outstanding_amount: 0, paid_amount: 500)
    end

    context 'as owner (authorized role)' do
      it 'reverses the payment and returns 200' do
        post "/api/v1/payments/#{payment.id}/reverse",
             headers: auth_headers(owner),
             params:  { reason: 'Cheque bounced' }.to_json
        expect(response).to have_http_status(:ok)
        expect(json_body['data']['status']).to eq('reversed')
      end
    end

    context 'as manager (insufficient role for reversal)' do
      it 'returns 403' do
        post "/api/v1/payments/#{payment.id}/reverse",
             headers: auth_headers(manager),
             params:  { reason: 'Test' }.to_json
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without a reason' do
      it 'returns 422' do
        post "/api/v1/payments/#{payment.id}/reverse",
             headers: auth_headers(owner),
             params:  { reason: '' }.to_json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
"""

with open('/mnt/c/Users/chitr/Projects/orderlane_pro/backend/spec/requests/api/v1/payments_spec.rb', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done.')
