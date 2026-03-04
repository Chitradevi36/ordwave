require 'rails_helper'

RSpec.describe CreditAccount, type: :model do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }

  describe 'validations' do
    it { should belong_to(:customer) }
    it { should belong_to(:organization) }
    it { should belong_to(:branch) }

    it 'validates credit_limit >= 0' do
      ca = build(:credit_account, customer: customer, organization: org, branch: branch, credit_limit: -100)
      expect(ca).not_to be_valid
    end
  end

  describe '#credit_available?' do
    it 'returns true when available_credit > 0' do
      ca = build(:credit_account, customer: customer, organization: org, branch: branch,
                  credit_limit: 10_000, current_balance: 5_000, available_credit: 5_000)
      expect(ca.credit_available?).to be true
    end

    it 'returns false when available_credit is 0' do
      ca = build(:credit_account, customer: customer, organization: org, branch: branch,
                  credit_limit: 10_000, current_balance: 10_000, available_credit: 0)
      expect(ca.credit_available?).to be false
    end
  end

  describe '#over_limit?' do
    it 'returns true when current_balance > credit_limit' do
      ca = build(:credit_account, customer: customer, organization: org, branch: branch,
                  credit_limit: 10_000, current_balance: 12_000, available_credit: 0)
      expect(ca.over_limit?).to be true
    end

    it 'returns false when within limit' do
      ca = build(:credit_account, customer: customer, organization: org, branch: branch,
                  credit_limit: 10_000, current_balance: 5_000, available_credit: 5_000)
      expect(ca.over_limit?).to be false
    end
  end

  describe 'before_save recalculate_available_credit' do
    it 'auto-computes available_credit as limit minus balance' do
      ca = create(:credit_account, customer: customer, organization: org, branch: branch,
                   credit_limit: 20_000, current_balance: 8_000, available_credit: 0)
      expect(ca.reload.available_credit).to eq(12_000)
    end

    it 'does not go below 0' do
      ca = create(:credit_account, customer: customer, organization: org, branch: branch,
                   credit_limit: 5_000, current_balance: 9_000, available_credit: 0)
      expect(ca.reload.available_credit).to eq(0)
    end
  end
end
