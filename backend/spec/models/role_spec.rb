require 'rails_helper'

RSpec.describe Role, type: :model do
  describe 'validations' do
    subject { create(:role) }

    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:name).case_insensitive }
    it { should validate_inclusion_of(:name).in_array(Role::NAMES) }
  end

  describe 'associations' do
    it { should have_many(:memberships).dependent(:destroy) }
  end

  describe 'predicate methods' do
    it 'identifies owner role' do
      owner = create(:role, name: 'owner')
      admin = create(:role, name: 'admin')

      expect(owner.owner?).to be true
      expect(admin.owner?).to be false
    end

    it 'identifies admin role' do
      owner = create(:role, name: 'owner')
      admin = create(:role, name: 'admin')

      expect(admin.admin?).to be true
      expect(owner.admin?).to be false
    end

    it 'identifies manager role' do
      manager = create(:role, name: 'manager')
      admin = create(:role, name: 'admin')

      expect(manager.manager?).to be true
      expect(admin.manager?).to be false
    end
  end

  describe 'constants' do
    it 'defines all role names' do
      expect(Role::NAMES).to eq(['owner', 'admin', 'manager', 'sales_rep', 'warehouse_staff', 'accountant'])
    end
  end
end
