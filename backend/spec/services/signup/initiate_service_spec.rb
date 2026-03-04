require 'rails_helper'

RSpec.describe Signup::InitiateService do
  describe '.call' do
    let(:email) { 'newuser@example.com' }

    context 'with new email' do
      it 'creates pending registration and returns success' do
        result = described_class.call(email: email)

        expect(result.success?).to be true
        expect(result.pending_registration).to be_persisted
        expect(result.pending_registration.email).to eq(email)
        expect(result.pending_registration.otp_code).to be_present
        expect(result.pending_registration.current_step).to eq('initiate')
      end
    end

    context 'with existing user email' do
      before { create(:user, email: email) }

      it 'returns error' do
        result = described_class.call(email: email)

        expect(result.success?).to be false
        expect(result.errors).to include(match(/already registered/))
      end
    end

    context 'with invalid email' do
      it 'returns error' do
        result = described_class.call(email: 'invalid')

        expect(result.success?).to be false
        expect(result.errors).to be_present
      end
    end
  end
end
