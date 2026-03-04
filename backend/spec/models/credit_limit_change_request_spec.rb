require 'rails_helper'

RSpec.describe CreditLimitChangeRequest, type: :model do
  let(:org)            { create(:organization) }
  let(:branch)         { create(:branch, organization: org) }
  let(:customer)       { create(:customer, organization: org, branch: branch) }
  let(:credit_account) { create(:credit_account, organization: org, branch: branch, customer: customer) }
  let(:user)           { create(:user) }

  subject(:req) do
    build(:credit_limit_change_request, credit_account: credit_account, requested_by: user)
  end

  it 'is valid with required attributes' do
    expect(req).to be_valid
  end

  it 'requires new_limit to be positive' do
    req.new_limit = 0
    expect(req).not_to be_valid
    expect(req.errors[:new_limit]).to be_present
  end

  it 'requires reason' do
    req.reason = ''
    expect(req).not_to be_valid
  end

  it 'requires counter_offer_limit when status is countered' do
    req.status              = 'countered'
    req.counter_offer_limit = nil
    expect(req).not_to be_valid
    expect(req.errors[:counter_offer_limit]).to be_present
  end

  describe 'status helpers' do
    it 'returns true for pending?' do
      req.status = 'pending'
      expect(req.pending?).to be true
    end

    it 'returns true for approved?' do
      req.status = 'approved'
      expect(req.approved?).to be true
    end

    it 'returns true for rejected?' do
      req.status = 'rejected'
      expect(req.rejected?).to be true
    end
  end

  describe 'delegations' do
    before { req.save! }

    it 'delegates customer to credit_account' do
      expect(req.customer).to eq(customer)
    end

    it 'delegates organization to credit_account' do
      expect(req.organization).to eq(org)
    end
  end
end
