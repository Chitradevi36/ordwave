require 'rails_helper'

RSpec.describe 'Api::V1::AuditLogs', type: :request do
  # ─── Setup ──────────────────────────────────────────────────────────────────
  let(:owner_role)   { create(:role, name: 'owner') }
  let(:manager_role) { create(:role, name: 'manager') }
  let(:sales_role)   { create(:role, name: 'sales_rep') }

  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  let(:owner)   { create(:user) }
  let(:manager) { create(:user) }
  let(:sales)   { create(:user) }

  let!(:owner_membership)   { create(:membership, user: owner,   organization: org, branch: branch, role: owner_role) }
  let!(:manager_membership) { create(:membership, user: manager, organization: org, branch: branch, role: manager_role) }
  let!(:sales_membership)   { create(:membership, user: sales,   organization: org, branch: branch, role: sales_role) }

  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:credit_account) { create(:credit_account, customer: customer, organization: org, branch: branch) }

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

  def json
    JSON.parse(response.body)
  end

  # Create some audit logs scoped to this org
  let!(:log1) do
    create(:audit_log, organization: org, actor: owner,
           auditable: credit_account, action: 'credit_limit_changed',
           changes_data: { from: 50_000, to: 100_000 },
           created_at: 3.days.ago)
  end
  let!(:log2) do
    create(:audit_log, organization: org, actor: manager,
           auditable: credit_account, action: 'credit_status_changed',
           changes_data: { status: 'hold' },
           created_at: 1.day.ago)
  end
  # Log for a different org — should never appear
  let!(:other_log) { create(:audit_log, action: 'credit_limit_changed') }

  # ─── GET /api/v1/audit_logs ─────────────────────────────────────────────────
  describe 'GET /api/v1/audit_logs' do
    it 'returns 200 and audit logs for owner' do
      get '/api/v1/audit_logs', headers: auth_headers(owner)

      expect(response).to have_http_status(:ok)
      ids = json['data'].map { |l| l['id'] }
      expect(ids).to include(log1.id, log2.id)
      expect(ids).not_to include(other_log.id)
    end

    it 'returns 200 for manager' do
      get '/api/v1/audit_logs', headers: auth_headers(manager)
      expect(response).to have_http_status(:ok)
    end

    it 'returns 403 for sales_rep' do
      get '/api/v1/audit_logs', headers: auth_headers(sales)
      expect(response).to have_http_status(:forbidden)
    end

    it 'requires authentication' do
      get '/api/v1/audit_logs', headers: { 'X-Organization-Id' => org.id.to_s }
      expect(response).to have_http_status(:unauthorized)
    end

    context 'filtering' do
      it 'filters by auditable_type' do
        # Create a log for a different auditable type
        order = create(:sales_order, organization: org, branch: branch,
                       customer: customer, created_by: owner, status: 'draft')
        order_log = create(:audit_log, organization: org, actor: owner,
                           auditable: order, action: 'order_submitted')

        get '/api/v1/audit_logs', params: { auditable_type: 'CreditAccount' }, headers: auth_headers

        ids = json['data'].map { |l| l['id'] }
        expect(ids).to include(log1.id, log2.id)
        expect(ids).not_to include(order_log.id)
      end

      it 'filters by action' do
        get '/api/v1/audit_logs', params: { action: 'credit_limit_changed' }, headers: auth_headers

        ids = json['data'].map { |l| l['id'] }
        expect(ids).to include(log1.id)
        expect(ids).not_to include(log2.id)
      end

      it 'filters by date_from' do
        get '/api/v1/audit_logs', params: { date_from: 2.days.ago.iso8601 }, headers: auth_headers

        ids = json['data'].map { |l| l['id'] }
        expect(ids).to include(log2.id)
        expect(ids).not_to include(log1.id)
      end

      it 'filters by date_to' do
        get '/api/v1/audit_logs', params: { date_to: 2.days.ago.iso8601 }, headers: auth_headers

        ids = json['data'].map { |l| l['id'] }
        expect(ids).to include(log1.id)
        expect(ids).not_to include(log2.id)
      end
    end

    context 'pagination' do
      before do
        # Ensure there are enough logs to paginate
        create_list(:audit_log, 26, organization: org, actor: owner,
                    auditable: credit_account, action: 'credit_limit_changed')
      end

      it 'includes pagination meta' do
        get '/api/v1/audit_logs', params: { page: 1 }, headers: auth_headers

        expect(json['meta']).to include(
          'current_page' => 1,
          'per_page'     => 25
        )
        expect(json['meta']['total_pages']).to be >= 2
        expect(json['meta']['total_count']).to be >= 27
      end

      it 'returns the second page' do
        get '/api/v1/audit_logs', params: { page: 2 }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json['meta']['current_page']).to eq(2)
        expect(json['data']).not_to be_empty
      end
    end

    context 'response shape' do
      it 'includes expected fields on each entry' do
        get '/api/v1/audit_logs', headers: auth_headers

        entry = json['data'].first
        expect(entry.keys).to include('id', 'action', 'auditable_type', 'auditable_id',
                                      'reason', 'changes', 'created_at', 'actor')
        expect(entry['actor'].keys).to include('id', 'name')
      end
    end
  end
end
