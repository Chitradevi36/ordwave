require 'rails_helper'

RSpec.describe 'Api::V1::Signup', type: :request do
  let(:email) { 'newuser@example.com' }

  describe 'POST /api/v1/signup/initiate' do
    it 'creates a pending registration and returns OTP in dev' do
      post '/api/v1/signup/initiate', params: { email: email }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['email']).to eq(email)
      expect(json['data']['message']).to include('OTP sent')
      
      expect(PendingRegistration.exists?(email: email)).to be true
    end

    it 'rejects if user already exists' do
      create(:user, email: email)
      
      post '/api/v1/signup/initiate', params: { email: email }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['errors']).to include(match(/already registered/))
    end
  end

  describe 'POST /api/v1/signup/verify_otp' do
    let!(:pending) { create(:pending_registration, email: email, otp_code: '123456', current_step: 'initiate') }

    it 'verifies OTP and advances step' do
      post '/api/v1/signup/verify_otp', params: {
        email: email,
        otp_code: '123456'
      }

      expect(response).to have_http_status(:ok)
      expect(pending.reload.current_step).to eq('verify_otp')
    end

    it 'rejects invalid OTP' do
      post '/api/v1/signup/verify_otp', params: {
        email: email,
        otp_code: '000000'
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'POST /api/v1/signup/choose_plan' do
    let!(:pending) do
      create(:pending_registration,
        email: email,
        current_step: 'choose_plan',
        data: {
          'password' => 'Password@123'
        }
      )
    end

    it 'completes signup and creates user only' do
      post '/api/v1/signup/choose_plan', params: {
        email: email,
        plan: 'starter',
        first_name: 'John',
        last_name: 'Doe'
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      expect(json['data']['token']).to be_present
      expect(json['data']['user']['email']).to eq(email)
      expect(json['data']['user']['plan']).to eq('starter')
      expect(json['data']).not_to have_key('organization')
      
      # Verify only user created
      user = User.find_by(email: email)
      expect(user).to be_present
      expect(user.plan).to eq('starter')
      expect(user.organizations.count).to eq(0)
      expect(user.memberships.count).to eq(0)
      expect(OnboardingProgress.where(user: user).count).to eq(0)
      expect(pending.reload.completed).to be true
    end
  end
end
