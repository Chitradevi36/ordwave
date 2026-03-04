require 'rails_helper'

RSpec.describe PendingRegistration, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
  end

  describe '#generate_otp!' do
    it 'generates a 6-digit OTP' do
      registration = create(:pending_registration, otp_code: nil)
      registration.generate_otp!
      
      expect(registration.otp_code).to match(/^\d{6}$/)
      expect(registration.otp_sent_at).to be_present
      expect(registration.otp_attempts).to eq(0)
    end
  end

  describe '#verify_otp' do
    let(:registration) { create(:pending_registration, otp_code: '123456') }

    it 'returns true for correct OTP' do
      expect(registration.verify_otp('123456')).to be true
    end

    it 'returns false and increments attempts for incorrect OTP' do
      expect(registration.verify_otp('000000')).to be false
      expect(registration.reload.otp_attempts).to eq(1)
    end

    it 'returns false for expired OTP' do
      registration.update!(otp_sent_at: 15.minutes.ago)
      expect(registration.verify_otp('123456')).to be false
    end
  end

  describe '#advance_to!' do
    it 'advances to the next step' do
      registration = create(:pending_registration, current_step: 'initiate')
      registration.advance_to!('verify_otp')
     
      expect(registration.current_step).to eq('verify_otp')
    end
  end
end
