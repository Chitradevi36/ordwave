require 'rails_helper'

RSpec.describe Organizations::CreateOrganizationService do
  describe '.call' do
    let!(:owner_role) { create(:role, name: 'owner') }
    let(:user) { create(:user, plan: 'growth') }
    let(:params) do
      {
        name: 'Test Organization',
        gst_number: '29ABCDE1234F1Z5',
        creator: user
      }
    end

    context 'with valid params' do
      it 'creates organization, branch, and membership' do
        expect {
          result = described_class.new(**params).call
          
          expect(result.success?).to be true
          expect(result.organization).to be_persisted
        }.to change(Organization, :count).by(1)
          .and change(Branch, :count).by(1)
          .and change(Membership, :count).by(1)
      end

      it 'creates owner membership for creator' do
        result = described_class.new(**params).call
        
        membership = Membership.find_by(
          user: user,
          organization: result.organization
        )
        
        expect(membership).to be_present
        expect(membership.role.name).to eq('owner')
      end

      it 'sets organization plan from creator plan' do
        result = described_class.new(**params).call
        org = result.organization
        
        expect(org.name).to eq('Test Organization')
        expect(org.plan).to eq(user.plan)
        expect(org.gst_number).to eq('29ABCDE1234F1Z5')
        expect(org.slug).to be_present
      end
    end

    context 'with invalid organization params' do
      it 'returns error and rolls back transaction' do
        invalid_params = params.merge(name: '')
        
        expect {
          result = described_class.call(invalid_params)
          
          expect(result.success?).to be false
          expect(result.errors).to be_present
        }.not_to change(Organization, :count)
      end
    end

    context 'with invalid branch params' do
      it 'returns error and rolls back transaction' do
        invalid_params = params.merge(branch_code: '')
        
        expect {
          result = described_class.call(invalid_params)
          
          expect(result.success?).to be false
        }.not_to change(Organization, :count)
      end
    end
  end
end
