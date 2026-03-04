require 'rails_helper'

RSpec.describe Signup::VerifyOtpService do
  describe '.call' do
    let(:email) { 'test@example.com' }
    let!(:pending) { create(:pending_registration, email: email, otp_code: '123456', current_step: 'initiate') }

    context 'with correct OTP' do
      it 'verifies and advances step' do
        result = described_class.call(email: email, otp_code: '123456')

        expect(result.success?).to be true
        expect(pending.reload.current_step).to eq('verify_otp')
      end
    end

    context 'with incorrect OTP' do
      it 'returns error and increments attempts' do
        result = described_class.call(email: email, otp_code: '000000')

        expect(result.success?).to be false
        expect(result.errors).to include('Invalid OTP')
        expect(pending.reload.otp_attempts).to eq(1)
      end
    end

    context 'with expired OTP' do
      before { pending.update!(otp_sent_at: 11.minutes.ago) }

      it 'returns error' do
        result = described_class.call(email: email, otp_code: '123456')

        expect(result.success?).to be false
        expect(result.errors).to include(match(/expired/i))
      end
    end

    context 'with max attempts exceeded' do
      before { pending.update!(otp_attempts: 5) }

      it 'returns error' do
        result = described_class.call(email: email, otp_code: '000000')

        expect(result.success?).to be false
        expect(result.errors).to include(match(/maximum attempts/i))
      end
    end
  end
end
