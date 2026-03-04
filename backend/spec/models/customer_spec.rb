require 'rails_helper'

RSpec.describe Customer, type: :model do
  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }
  let(:route)  { create(:route, organization: org, branch: branch) }

  describe 'validations' do
    subject { create(:customer, organization: org, branch: branch, route: route) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:code) }
    it { should validate_presence_of(:channel) }
    it { should validate_presence_of(:tier) }

    it 'validates code uniqueness within organization' do
      create(:customer, organization: org, branch: branch, code: 'CUST-0001')
      dup = build(:customer, organization: org, branch: branch, code: 'CUST-0001')
      expect(dup).not_to be_valid
      expect(dup.errors[:code]).to be_present
    end

    it 'allows same code in different organizations' do
      org2 = create(:organization)
      b2   = create(:branch, organization: org2)
      create(:customer, organization: org,  branch: branch, code: 'CUST-0001')
      dup  = build(:customer,  organization: org2, branch: b2,     code: 'CUST-0001')
      expect(dup).to be_valid
    end

    it 'validates channel inclusion' do
      c = build(:customer, organization: org, branch: branch, channel: 'grocery')
      expect(c).not_to be_valid
    end

    it 'validates tier inclusion' do
      c = build(:customer, organization: org, branch: branch, tier: 'diamond')
      expect(c).not_to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:organization) }
    it { should belong_to(:branch) }
    it { should belong_to(:route).optional }
    it { should have_many(:addresses).class_name('CustomerAddress').dependent(:destroy) }
    it { should have_many(:contacts).class_name('CustomerContact').dependent(:destroy) }
    it { should have_one(:credit_account).dependent(:destroy) }
  end

  describe 'soft delete' do
    it '#soft_delete! sets deleted_at and status to inactive' do
      customer = create(:customer, organization: org, branch: branch)
      customer.soft_delete!
      expect(customer.reload.deleted_at).to be_present
      expect(customer.status).to eq('inactive')
    end

    it '#deleted? returns true after soft delete' do
      customer = create(:customer, organization: org, branch: branch)
      expect { customer.soft_delete! }.to change { customer.deleted? }.from(false).to(true)
    end
  end

  describe 'scopes' do
    let!(:active_customer)  { create(:customer, organization: org, branch: branch, status: 'active') }
    let!(:inactive_customer) { create(:customer, organization: org, branch: branch, status: 'inactive') }
    let!(:deleted_customer) do
      c = create(:customer, organization: org, branch: branch)
      c.soft_delete!
      c
    end

    it '.not_deleted excludes soft-deleted records' do
      expect(Customer.not_deleted).to include(active_customer, inactive_customer)
      expect(Customer.not_deleted).not_to include(deleted_customer)
    end

    it '.active returns only active, non-deleted customers' do
      expect(Customer.active).to include(active_customer)
      expect(Customer.active).not_to include(inactive_customer, deleted_customer)
    end

    it '.by_channel filters by channel' do
      gt = create(:customer, organization: org, branch: branch, channel: 'general_trade')
      ht = create(:customer, organization: org, branch: branch, channel: 'horeca')
      expect(Customer.by_channel('general_trade')).to include(gt)
      expect(Customer.by_channel('general_trade')).not_to include(ht)
    end

    it '.by_status filters by status' do
      blocked = create(:customer, organization: org, branch: branch, status: 'blocked')
      expect(Customer.by_status('blocked')).to include(blocked)
      expect(Customer.by_status('blocked')).not_to include(active_customer)
    end
  end

  describe 'status transitions' do
    let(:customer) { create(:customer, organization: org, branch: branch, status: 'active') }

    describe '#block!' do
      it 'sets status to blocked' do
        customer.block!
        expect(customer.reload.status).to eq('blocked')
      end
    end

    describe '#unblock!' do
      it 'sets status back to active' do
        customer.update!(status: 'blocked')
        customer.unblock!
        expect(customer.reload.status).to eq('active')
      end
    end

    describe '#deactivate!' do
      it 'sets status to inactive' do
        customer.deactivate!
        expect(customer.reload.status).to eq('inactive')
      end
    end

    describe '#blocked?' do
      it 'returns true when status is blocked' do
        customer.update!(status: 'blocked')
        expect(customer.blocked?).to be true
      end

      it 'returns false when status is active' do
        expect(customer.blocked?).to be false
      end
    end

    describe '#active?' do
      it 'returns true when status is active' do
        expect(customer.active?).to be true
      end

      it 'returns false when blocked' do
        customer.update!(status: 'blocked')
        expect(customer.active?).to be false
      end
    end
  end
end
