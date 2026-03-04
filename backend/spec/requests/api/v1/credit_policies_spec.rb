require 'rails_helper'

RSpec.describe 'Api::V1::CreditPolicies', type: :request do
  let(:owner_role)   { create(:role, name: 'owner') }
  let(:manager_role) { create(:role, name: 'manager') }

  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  let(:owner) { create(:user) }
  let!(:owner_membership) do
    create(:membership, user: owner, organization: org, branch: branch, role: owner_role)
  end

  let(:manager) { create(:user) }
  let!(:manager_membership) do
    create(:membership, user: manager, organization: org, branch: branch, role: manager_role)
  end

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

  # ─── GET /api/v1/credit_policy ─────────────────────────────────────────────
  describe 'GET /api/v1/credit_policy' do
    it 'auto-creates policy with defaults and returns it' do
      get '/api/v1/credit_policy', headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['hard_block_overdue_days']).to eq(30)
    end

    it 'requires authentication' do
      get '/api/v1/credit_policy', headers: { 'X-Organization-Id' => org.id.to_s }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'denies manager access' do
      get '/api/v1/credit_policy', headers: auth_headers(manager)
      expect(response).to have_http_status(:forbidden)
    end
  end

  # ─── PATCH /api/v1/credit_policy ───────────────────────────────────────────
  describe 'PATCH /api/v1/credit_policy' do
    it 'allows owner to update policy' do
      patch '/api/v1/credit_policy',
            params:  { credit_policy: { hard_block_overdue_days: 45 } },
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(json_body['data']['hard_block_overdue_days']).to eq(45)
    end

    it 'rejects invalid values' do
      patch '/api/v1/credit_policy',
            params:  { credit_policy: { soft_hold_overdue_days_min: 40, soft_hold_overdue_days_max: 10 } },
            headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'creates an audit log entry on update' do
      expect {
        patch '/api/v1/credit_policy',
              params:  { credit_policy: { hard_block_overdue_days: 60 } },
              headers: auth_headers
      }.to change(AuditLog, :count).by(1)

      log = AuditLog.last
      expect(log.action).to eq('credit_policy_updated')
      expect(log.actor).to eq(owner)
    end

    it 'denies manager from updating policy' do
      patch '/api/v1/credit_policy',
            params:  { credit_policy: { hard_block_overdue_days: 45 } },
            headers: auth_headers(manager)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
