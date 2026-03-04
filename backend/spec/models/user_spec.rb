require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end

  describe 'associations' do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:organizations).through(:memberships) }
    it { should have_many(:branches).through(:memberships) }
  end

  describe 'scopes' do
    it 'returns only active users' do
      active_user = create(:user, active: true, deleted_at: nil)
      inactive_user = create(:user, active: false)
      deleted_user = create(:user, deleted_at: Time.current)

      expect(User.active).to include(active_user)
      expect(User.active).not_to include(inactive_user, deleted_user)
    end
  end

  describe '#full_name' do
    it 'returns first and last name combined' do
      user = build(:user, first_name: 'John', last_name: 'Doe')
      expect(user.full_name).to eq('John Doe')
    end
  end

  describe '#soft_delete!' do
    it 'marks user as deleted' do
      user = create(:user)
      user.soft_delete!
      
      expect(user.deleted?).to be true
      expect(user.active).to be false
      expect(user.deleted_at).to be_present
    end
  end
end
