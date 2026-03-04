require 'rails_helper'

RSpec.describe Membership, type: :model do
  describe 'validations' do
    subject { create(:membership) }

    it { should validate_presence_of(:user_id) }
    it { should validate_presence_of(:organization_id) }
    it { should validate_presence_of(:role_id) }

    it 'validates uniqueness of user/organization/branch combination' do
      membership = create(:membership)
      duplicate = build(:membership,
        user: membership.user,
        organization: membership.organization,
        branch: membership.branch
      )

      expect(duplicate).not_to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:organization) }
    it { should belong_to(:role) }
    it { should belong_to(:branch).optional }
  end

  describe 'scopes' do
    let!(:active_membership) { create(:membership) }
    let!(:deleted_membership) { create(:membership, deleted_at: Time.current) }

    it 'filters active memberships' do
      # Assuming you have an active scope
      expect(Membership.where(deleted_at: nil)).to include(active_membership)
      expect(Membership.where(deleted_at: nil)).not_to include(deleted_membership)
    end
  end
end
