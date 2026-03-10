require 'rails_helper'

RSpec.describe CreditNote, type: :model do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:creator)  { create(:user) }
  let(:return_request) { create(:return_request, organization: org, branch: branch, customer: customer) }

  def build_cn(overrides = {})
    build(:credit_note,
          organization:  org,
          branch:        branch,
          customer:      customer,
          created_by:    creator,
          **overrides)
  end

  # ─── BUG-C04 regression ─────────────────────────────────────────────────────
  # Migration 000019 made credit_notes.return_request_id nullable so that
  # standalone / goodwill credit notes (adjustment_type: 'manual') can be
  # created without a ReturnRequest.  Both the model AND the database must
  # permit nil.
  describe 'return_request association (BUG-C04 regression)' do
    it 'model is valid without a return_request' do
      cn = build_cn(return_request: nil, adjustment_type: 'manual')
      expect(cn).to be_valid
    end

    it 'persists to the database without a return_request (nullable FK)' do
      expect do
        create(:credit_note, organization: org, branch: branch, customer: customer,
               created_by: creator, return_request: nil, adjustment_type: 'manual')
      end.not_to raise_error
    end

    it 'is valid with a return_request' do
      cn = build_cn(return_request: return_request)
      expect(cn).to be_valid
    end
  end

  # ─── Required associations ───────────────────────────────────────────────────
  describe 'required associations' do
    it 'is invalid without a customer' do
      cn = build_cn(customer: nil)
      expect(cn).not_to be_valid
      expect(cn.errors[:customer]).to be_present
    end

    it 'is invalid without an organization' do
      cn = build_cn(organization: nil)
      expect(cn).not_to be_valid
    end

    it 'is invalid without a branch' do
      cn = build_cn(branch: nil)
      expect(cn).not_to be_valid
    end

    it 'is invalid without a created_by user' do
      cn = build_cn(created_by: nil)
      expect(cn).not_to be_valid
    end
  end

  # ─── Status ──────────────────────────────────────────────────────────────────
  describe 'status' do
    it 'defaults to draft' do
      cn = build_cn
      expect(cn.status).to eq('draft')
    end

    it 'is invalid with an unknown status' do
      cn = build_cn(status: 'invalid_status')
      expect(cn).not_to be_valid
    end
  end
end
