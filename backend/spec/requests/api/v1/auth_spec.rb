require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  let(:user) { create(:user, email: 'test@example.com', password: 'Password@123') }

  describe 'POST /api/v1/auth/login' do
    context 'with valid credentials' do
      it 'returns a JWT token' do
        post '/api/v1/auth/login', params: {
          email: user.email,
          password: 'Password@123'
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['token']).to be_present
        expect(json['data']['user']['email']).to eq(user.email)
      end
    end

    context 'with invalid credentials' do
      it 'returns unauthorized' do
        post '/api/v1/auth/login', params: {
          email: user.email,
          password: 'WrongPassword'
        }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'with inactive user' do
      it 'returns unauthorized' do
        user.update!(active: false)
        
        post '/api/v1/auth/login', params: {
          email: user.email,
          password: 'Password@123'
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/auth/logout' do
    it 'returns success' do
      delete '/api/v1/auth/logout'

      expect(response).to have_http_status(:no_content)
    end
  end
end
