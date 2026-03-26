# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payment, type: :model do
  subject { build(:payment) }

  # ── Associations ────────────────────────────────────────────────────────────

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:branch) }
    it { is_expected.to belong_to(:customer) }
    it { is_expected.to belong_to(:created_by).class_name('User') }
    it { is_expected.to have_many(:payment_allocations) }
    it { is_expected.to have_many(:advance_payments) }
  end

  # ── Validations ─────────────────────────────────────────────────────────────

  describe 'validations' do
    it { is_expected.to validate_presence_of(:payment_number) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:received_date) }

    context 'payment_mode inclusion' do
      %w[cash cheque upi neft rtgs online razorpay bank_transfer credit_note].each do |mode|
        it "allows #{mode}" do
          subject.payment_mode = mode
          subject.valid?
          expect(subject.errors[:payment_mode]).to be_empty
        end
      end
    end

    context 'status inclusion' do
      %w[draft confirmed reversed].each do |status|
        it "allows #{status}" do
          subject.status = status
          subject.valid?
          expect(subject.errors[:status]).to be_empty
        end
      end
    end

    context 'reversal_reason required when reversed' do
      it 'requires reversal_reason if status is reversed' do
        subject.status = 'reversed'
        subject.reversal_reason = nil
        subject.valid?
        expect(subject.errors[:reversal_reason]).to be_present
      end
    end
  end

  # ── Status helpers ──────────────────────────────────────────────────────────

  describe 'status helpers' do
    it '#draft? returns true for draft payments' do
      subject.status = 'draft'
      expect(subject).to be_draft
    end

    it '#confirmed? returns true for confirmed payments' do
      subject.status = 'confirmed'
      expect(subject).to be_confirmed
    end

    it '#reversed? returns true for reversed payments' do
      subject.status = 'reversed'
      expect(subject).to be_reversed
    end
  end

  # ── Scopes ──────────────────────────────────────────────────────────────────

  describe 'scopes' do
    let!(:org) { create(:organization) }
    let!(:branch) { create(:branch, organization: org) }
    let!(:customer) { create(:customer, organization: org, branch: branch) }
    let!(:user) { create(:user) }
    let!(:payment) do
      create(:payment, organization: org, branch: branch, customer: customer, created_by: user, status: 'confirmed')
    end

    describe '.for_org' do
      it 'scopes to the given organization' do
        expect(Payment.for_org(org)).to include(payment)
      end
    end

    describe '.confirmed' do
      it 'returns only confirmed payments' do
        draft = create(:payment, organization: org, branch: branch, customer: customer, created_by: user, status: 'draft')
        expect(Payment.confirmed).to include(payment)
        expect(Payment.confirmed).not_to include(draft)
      end
    end
  end

  # ── Instance methods ────────────────────────────────────────────────────────

  describe '#confirmable?' do
    it 'returns true for draft payments' do
      subject.status = 'draft'
      expect(subject.confirmable?).to be true
    end

    it 'returns false for already confirmed payments' do
      subject.status = 'confirmed'
      expect(subject.confirmable?).to be false
    end
  end

  describe '#reversible?' do
    it 'returns true for confirmed payments' do
      subject.status = 'confirmed'
      expect(subject.reversible?).to be true
    end

    it 'returns false for draft payments' do
      subject.status = 'draft'
      expect(subject.reversible?).to be false
    end
  end
end
