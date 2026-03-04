require 'rails_helper'

RSpec.describe Onboarding::InitializeService do
  describe '.call' do
    let(:user) { create(:user, plan: 'starter') }
    let!(:owner_role) { create(:role, name: 'owner') }

    let(:params) do
      {
        user: user,
        org_name: 'Test Organization',
        branch_name: 'Head Office',
        branch_code: 'HQ-01',
        city: 'Mumbai',
        state: 'Maharashtra',
        gst_number: '29ABCDE1234F1Z5',
        contact_phone: '9876543210'
      }
    end

    context 'with valid params' do
      it 'creates organization with user plan' do
        expect {
          result = described_class.call(params)
          
          expect(result.success?).to be true
          expect(result.organization).to be_persisted
          expect(result.organization.plan).to eq(user.plan)
        }.to change(Organization, :count).by(1)
      end

      it 'creates first branch' do
        expect {
          described_class.call(params)
        }.to change(Branch, :count).by(1)
      end

      it 'creates owner membership' do
        expect {
          result = described_class.call(params)
          
          expect(result.membership).to be_persisted
          expect(result.membership.user).to eq(user)
          expect(result.membership.role.name).to eq('owner')
        }.to change(Membership, :count).by(1)
      end

      it 'creates onboarding progress' do
        expect {
          result = described_class.call(params)
          
          progress = OnboardingProgress.find_by(user: user, organization: result.organization)
          expect(progress).to be_present
        }.to change(OnboardingProgress, :count).by(1)
      end

      it 'sets correct organization details' do
        result = described_class.call(params)
        org = result.organization
        
        expect(org.name).to eq('Test Organization')
        expect(org.city).to eq('Mumbai')
        expect(org.state).to eq('Maharashtra')
        expect(org.gst_number).to eq('29ABCDE1234F1Z5')
        expect(org.contact_phone).to eq('9876543210')
      end

      it 'sets correct branch details' do
        result = described_class.call(params)
        branch = result.organization.branches.first
        
        expect(branch.name).to eq('Head Office')
        expect(branch.code).to eq('HQ-01')
        expect(branch.city).to eq('Mumbai')
        expect(branch.state).to eq('Maharashtra')
      end
    end

    context 'with missing required params' do
      it 'raises error when org_name is missing' do
        result = described_class.call(params.except(:org_name))
        expect(result.success?).to be false
      end

      it 'raises error when branch_name is missing' do
        result = described_class.call(params.except(:branch_name))
        expect(result.success?).to be false
      end
    end

    context 'on transaction rollback' do
      before { allow(Role).to receive(:find_by!).and_raise(ActiveRecord::RecordNotFound) }

      it 'returns error' do
        result = described_class.call(params)
        expect(result.success?).to be false
      end
    end
  end
end
