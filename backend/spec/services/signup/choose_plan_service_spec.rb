require 'rails_helper'

RSpec.describe Signup::ChoosePlanService do
  describe '.call' do
    let(:email) { 'newuser@example.com' }
    let!(:pending) do
      create(:pending_registration,
        email: email,
        current_step: 'choose_plan',
        data: {
          'password' => 'Password@123'
        }
      )
    end

    context 'with valid params' do
      let(:params) do
        {
          email: email,
          plan: 'starter',
          first_name: 'John',
          last_name: 'Doe'
        }
      end

      it 'creates user with plan' do
        expect {
          result = described_class.call(params)
          
          expect(result.success?).to be true
          expect(result.user).to be_persisted
          expect(result.user.plan).to eq('starter')
          expect(result.token).to be_present
        }.to change(User, :count).by(1)
      end

      it 'does not create organization' do
        expect {
          described_class.call(params)
        }.not_to change(Organization, :count)
      end

      it 'does not create branch' do
        expect {
          described_class.call(params)
        }.not_to change(Branch, :count)
      end

      it 'does not create membership' do
        expect {
          described_class.call(params)
        }.not_to change(Membership, :count)
      end

      it 'does not create onboarding progress' do
        expect {
          described_class.call(params)
        }.not_to change(OnboardingProgress, :count)
      end

      it 'marks pending registration as completed' do
        described_class.call(params)
        
        expect(pending.reload.completed).to be true
      end
    end

    context 'with invalid plan' do
      it 'returns error' do
        result = described_class.call(
          email: email,
          plan: 'invalid_plan',
          first_name: 'John',
          last_name: 'Doe'
        )
        
        expect(result.success?).to be false
      end
    end
  end
end
