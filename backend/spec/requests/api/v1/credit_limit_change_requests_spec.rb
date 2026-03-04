require 'rails_helper'

RSpec.describe 'Api::V1::CreditLimitChangeRequests', type: :request do
  let(:owner_role)     { create(:role, name: 'owner') }
  let(:manager_role)   { create(:role, name: 'manager') }
  let(:sales_role)     { create(:role, name: 'sales_rep') }

  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  let(:owner)   { create(:user) }
  let(:manager) { create(:user) }
  let(:sales)   { create(:user) }

  let!(:owner_membership)   { create(:membership, user: owner,   organization: org, branch: branch, role: owner_role) }
  let!(:manager_membership) { create(:membership, user: manager, organization: org, branch: branch, role: manager_role) }
  let!(:sales_membership)   { create(:membership, user: sales,   organization: org, branch: branch, role: sales_role) }

  let!(:customer)       { create(:customer, organization: org, branch: branch) }
  let!(:credit_account) { create(:credit_account, organization: org, branch: branch, customer: customer, credit_limit: 50_000) }
  let!(:policy)         { create(:credit_policy, organization: org) }

  def generate_jwt_for(user)
    payload = { sub: user.id, email: user.email, jti: SecureRandom.uuid, exp: 24.hours.from_now.to_i }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  def auth_headers(user = owner)
    {
      'Authorization'     => "Bearer #{generate_jwt_for(user)}",
      'X-Organization-Id' => org.id.to_s
    }
  end

  def json_body
    JSON.parse(response.body)
  end

  # ─── POST /api/v1/credit_accounts/:id/limit_change_requests ──────────────
  describe 'POST /api/v1/credit_accounts/:id/limit_change_requests' do
    let(:valid_params) do
      { credit_limit_change_request: { new_limit: 100_000, reason: 'Business expansion' } }
    end

    it 'allows manager to submit a request' do
      post "/api/v1/credit_accounts/#{credit_account.id}/limit_change_requests",
           params:  valid_params,
           headers: auth_headers(manager)

      expect(response).to have_http_status(:created)
      expect(json_body['data']['status']).to eq('pending')
      expect(json_body['data']['new_limit']).to eq(100_000.0)
    end

    it 'creates an audit log' do
      expect {
        post "/api/v1/credit_accounts/#{credit_account.id}/limit_change_requests",
             params:  valid_params,
             headers: auth_headers(manager)
      }.to change(AuditLog, :count).by(1)
    end

    it 'rejects request without reason' do
      post "/api/v1/credit_accounts/#{credit_account.id}/limit_change_requests",
           params:  { credit_limit_change_request: { new_limit: 100_000 } },
           headers: auth_headers(manager)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'denies sales_rep from submitting request' do
      post "/api/v1/credit_accounts/#{credit_account.id}/limit_change_requests",
           params:  valid_params,
           headers: auth_headers(sales)

      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── GET /api/v1/credit_limit_change_requests ─────────────────────────────
  describe 'GET /api/v1/credit_limit_change_requests' do
    let!(:req) { create(:credit_limit_change_request, credit_account: credit_account, requested_by: manager) }

    it 'returns list of requests' do
      get '/api/v1/credit_limit_change_requests', headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']).to be_an(Array)
      expect(json_body['data'].first['id']).to eq(req.id)
    end

    it 'filters by status' do
      approved_req = create(:credit_limit_change_request,
                            credit_account: credit_account, requested_by: manager, status: 'approved')

      get '/api/v1/credit_limit_change_requests', params: { status: 'pending' }, headers: auth_headers
      ids = json_body['data'].map { |r| r['id'] }
      expect(ids).to include(req.id)
      expect(ids).not_to include(approved_req.id)
    end
  end

  # ─── POST /api/v1/credit_limit_change_requests/:id/decision ──────────────
  describe 'POST /api/v1/credit_limit_change_requests/:id/decision' do
    let!(:pending_req) { create(:credit_limit_change_request, credit_account: credit_account, requested_by: manager) }

    context 'approved' do
      it 'approves the request and updates credit limit' do
        post "/api/v1/credit_limit_change_requests/#{pending_req.id}/decision",
             params:  { decision: 'approved', decision_note: 'Approved after review' },
             headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_body['data']['status']).to eq('approved')
        expect(credit_account.reload.credit_limit).to eq(pending_req.new_limit)
      end

      it 'creates two audit log entries (limit_request_decided + credit_limit_changed)' do
        expect {
          post "/api/v1/credit_limit_change_requests/#{pending_req.id}/decision",
               params:  { decision: 'approved' },
               headers: auth_headers
        }.to change(AuditLog, :count).by(2)
      end
    end

    context 'rejected' do
      it 'rejects the request without changing credit limit' do
        original_limit = credit_account.credit_limit

        post "/api/v1/credit_limit_change_requests/#{pending_req.id}/decision",
             params:  { decision: 'rejected', decision_note: 'Not justified' },
             headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_body['data']['status']).to eq('rejected')
        expect(credit_account.reload.credit_limit).to eq(original_limit)
      end
    end

    context 'countered' do
      it 'counters with a different limit' do
        post "/api/v1/credit_limit_change_requests/#{pending_req.id}/decision",
             params:  { decision: 'countered', counter_offer_limit: 75_000, decision_note: 'Partial approval' },
             headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_body['data']['status']).to eq('countered')
        expect(json_body['data']['counter_offer_limit']).to eq(75_000.0)
      end

      it 'returns error when counter_offer_limit is missing' do
        post "/api/v1/credit_limit_change_requests/#{pending_req.id}/decision",
             params:  { decision: 'countered' },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'denies manager from deciding' do
      post "/api/v1/credit_limit_change_requests/#{pending_req.id}/decision",
           params:  { decision: 'approved' },
           headers: auth_headers(manager)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
