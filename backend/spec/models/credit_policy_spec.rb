require 'rails_helper'

RSpec.describe CreditPolicy, type: :model do
  let(:org) { create(:organization) }

  describe '.for_org!' do
    context 'when no policy exists' do
      it 'creates one with defaults' do
        expect { CreditPolicy.for_org!(org) }.to change(CreditPolicy, :count).by(1)
      end

      it 'uses default hard_block_overdue_days of 30' do
        policy = CreditPolicy.for_org!(org)
        expect(policy.hard_block_overdue_days).to eq(30)
      end
    end

    context 'when a policy exists' do
      before { create(:credit_policy, organization: org, hard_block_overdue_days: 45) }

      it 'returns existing policy without creating another' do
        expect { CreditPolicy.for_org!(org) }.not_to change(CreditPolicy, :count)
      end

      it 'returns the existing policy' do
        policy = CreditPolicy.for_org!(org)
        expect(policy.hard_block_overdue_days).to eq(45)
      end
    end
  end

  describe 'validations' do
    let(:policy) { build(:credit_policy, organization: org) }

    it 'is valid with defaults' do
      expect(policy).to be_valid
    end

    it 'requires soft_hold_overdue_days_min <= max' do
      policy.soft_hold_overdue_days_min = 30
      policy.soft_hold_overdue_days_max = 10
      expect(policy).not_to be_valid
      expect(policy.errors[:soft_hold_overdue_days_min]).to include(/must be less than or equal to max/)
    end

    it 'validates auto_invoice_trigger inclusion' do
      policy.auto_invoice_trigger = 'invalid_trigger'
      expect(policy).not_to be_valid
    end

    it 'validates collection_first_bucket inclusion' do
      policy.collection_first_bucket = 'nonexistent'
      expect(policy).not_to be_valid
    end

    it 'requires hard_block_overdue_days to be positive' do
      policy.hard_block_overdue_days = -1
      expect(policy).not_to be_valid
    end
  end
end
