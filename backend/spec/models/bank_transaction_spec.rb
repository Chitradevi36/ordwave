# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankTransaction, type: :model do
  let(:org)          { create(:organization) }
  let(:branch)       { create(:branch, organization: org) }
  let(:bank_account) { create(:bank_account, organization: org, branch: branch) }

  subject(:txn) do
    build(:bank_transaction,
          organization: org,
          bank_account: bank_account)
  end

  describe "validations" do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:txn_date) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
    it { is_expected.to validate_inclusion_of(:direction).in_array(BankTransaction::DIRECTIONS) }
    it { is_expected.to validate_inclusion_of(:status).in_array(BankTransaction::STATUSES) }
    it { is_expected.to validate_presence_of(:idempotency_key) }
    it { is_expected.to validate_uniqueness_of(:idempotency_key) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:bank_account) }
    it { is_expected.to have_many(:candidates).class_name("BankTransactionMatch").dependent(:destroy) }
  end

  describe ".build_idempotency_key" do
    it "returns a SHA256 hex string" do
      key = described_class.build_idempotency_key(
        bank_account_id: 1,
        txn_date:        Date.today,
        amount:          1000,
        reference:       "UTR001",
        narration:       "Test narration"
      )
      expect(key).to match(/\A[a-f0-9]{64}\z/)
    end

    it "is idempotent for the same inputs" do
      args = { bank_account_id: 1, txn_date: Date.today, amount: 1000, reference: "X", narration: "Y" }
      expect(described_class.build_idempotency_key(**args))
        .to eq(described_class.build_idempotency_key(**args))
    end

    it "differs for different amounts" do
      base = { bank_account_id: 1, txn_date: Date.today, reference: "X", narration: "Y" }
      expect(described_class.build_idempotency_key(**base, amount: 100))
        .not_to eq(described_class.build_idempotency_key(**base, amount: 200))
    end
  end

  describe "#postable?" do
    it "is true for a credit suggested transaction" do
      txn.direction = "credit"
      txn.status    = "suggested"
      expect(txn.postable?).to be true
    end

    it "is false for debits" do
      txn.direction = "debit"
      txn.status    = "suggested"
      expect(txn.postable?).to be false
    end

    it "is false for already matched transactions" do
      txn.direction = "credit"
      txn.status    = "matched"
      expect(txn.postable?).to be false
    end
  end
end
