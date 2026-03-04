require 'rails_helper'

RSpec.describe 'Api::V1::Onboarding', type: :request do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:branch) { create(:branch, organization: organization) }
  let(:role) { create(:role, name: 'owner') }
  let!(:membership) { create(:membership, user: user, organization: organization, branch: branch, role: role) }
  let(:token) { generate_jwt_for(user) }

  def generate_jwt_for(user)
    payload = {
      sub: user.id,
      email: user.email,
      jti: SecureRandom.uuid,
      exp: 24.hours.from_now.to_i
    }
    JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
  end

  describe 'GET /api/v1/onboarding' do
    it 'returns onboarding progress' do
      get '/api/v1/onboarding',
        headers: {
          'Authorization' => "Bearer #{token}",
          'X-Organization-Id' => organization.id.to_s
        }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json['data']['completion_percentage']).to eq(0)
      expect(json['data']['steps']).to be_an(Array)
      expect(json['data']['steps'].size).to eq(OnboardingProgress::CHECKLIST_STEPS.size)
    end

    it 'requires authentication' do
      get '/api/v1/onboarding',
        headers: { 'X-Organization-Id' => organization.id.to_s }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/onboarding/complete_step' do
    let!(:progress) { create(:onboarding_progress, user: user, organization: organization) }

    it 'marks a step as complete' do
      post '/api/v1/onboarding/complete_step',
        params: { step_name: 'add_first_product' },
        headers: {
          'Authorization' => "Bearer #{token}",
          'X-Organization-Id' => organization.id.to_s
        }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      completed_step = json['data']['steps'].find { |s| s['name'] == 'add_first_product' }
      expect(completed_step['completed']).to be true
    end

    it 'rejects invalid step names' do
      post '/api/v1/onboarding/complete_step',
        params: { step_name: 'invalid_step' },
        headers: {
          'Authorization' => "Bearer #{token}",
          'X-Organization-Id' => organization.id.to_s
        }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
