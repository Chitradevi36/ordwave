require 'rails_helper'

RSpec.describe Branch, type: :model do
  describe 'validations' do
    subject { create(:branch) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:organization_id) }
    
    it 'validates code uniqueness within organization' do
      org = create(:organization)
      create(:branch, organization: org, code: 'HQ-01')
      duplicate = build(:branch, organization: org, code: 'HQ-01')
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:code]).to include('has already been taken')
    end

    it 'allows same code in different organizations' do
      org1 = create(:organization)
      org2 = create(:organization)
      create(:branch, organization: org1, code: 'HQ-01')
      duplicate = build(:branch, organization: org2, code: 'HQ-01')
      
      expect(duplicate).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should have_many(:memberships).dependent(:destroy) }
  end

  describe 'soft delete' do
    it 'sets deleted_at timestamp' do
      branch = create(:branch)
      branch.update!(deleted_at: Time.current)
      
      expect(branch.deleted_at).to be_present
    end
  end

  describe 'scopes' do
    let(:organization) { create(:organization) }
    let!(:active_branch) { create(:branch, organization: organization) }
    let!(:deleted_branch) { create(:branch, organization: organization, deleted_at: Time.current) }

    it 'excludes deleted branches' do
      # Assuming you have an active scope
      expect(organization.branches.where(deleted_at: nil)).to include(active_branch)
      expect(organization.branches.where(deleted_at: nil)).not_to include(deleted_branch)
    end
  end
end
