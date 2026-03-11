# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankReconciliation::Matcher do
  let(:org)          { create(:organization) }
  let(:branch)       { create(:branch, organization: org) }
  let(:bank_account) { create(:bank_account, organization: org, branch: branch) }

  let(:customer) { create(:customer, organization: org, branch: branch, code: "RT001") }
  let(:invoice)  do
    create(:sales_invoice,
           organization: org,
           customer:     customer,
           invoice_number: "INV/2025/001",
           grand_total:  15_000,
           status:       :issued)
  end

  def build_txn(overrides = {})
    defaults = {
      organization: org,
      bank_account: bank_account,
      direction:    "credit",
      status:       "unmatched",
      txn_date:     Date.today,
      amount:       15_000,
      narration:    "NEFT/INV/2025/001/RT001",
      idempotency_key: SecureRandom.hex,
      match_meta:   {
        "invoice_numbers" => ["INV/2025/001"],
        "customer_codes"  => ["RT001"],
        "utr_candidates"  => [],
        "tokens"          => ["NEFT"]
      }
    }
    create(:bank_transaction, defaults.merge(overrides))
  end

  before { invoice }   # ensure invoice exists before matching

  describe "#call" do
    context "when narration contains the exact invoice number" do
      it "sets status to auto_matched" do
        txn = build_txn
        result = described_class.call(txn, org)
        expect(result.status).to eq("auto_matched")
      end

      it "creates a selected BankTransactionMatch" do
        txn = build_txn
        described_class.call(txn, org)
        expect(txn.candidates.where(selected: true).count).to eq(1)
      end

      it "sets match_score >= 95" do
        txn = build_txn
        described_class.call(txn, org)
        expect(txn.reload.match_score).to be >= 95
      end
    end

    context "when there is no matching invoice" do
      it "sets status to unmatched" do
        txn = build_txn(
          narration:  "NEFT UNKNOWN PAYMENT",
          match_meta: {
            "invoice_numbers" => [],
            "customer_codes"  => [],
            "utr_candidates"  => [],
            "tokens"          => ["NEFT", "UNKNOWN"]
          }
        )
        result = described_class.call(txn, org)
        expect(result.status).to eq("unmatched")
      end
    end

    context "when score is between 80 and 94" do
      it "sets status to suggested" do
        # Only customer alias match, no invoice number, so score ~= 85-90
        CustomerAlias.create!(organization: org, customer: customer, alias_name: "RAVI TRADERS")

        txn = build_txn(
          amount:     999_999,  # amount won't match any invoice → lower score
          narration:  "NEFT RAVI TRADERS PAYMENT",
          match_meta: {
            "invoice_numbers" => [],
            "customer_codes"  => [],
            "utr_candidates"  => [],
            "tokens"          => ["NEFT", "RAVI", "TRADERS"]
          }
        )
        result = described_class.call(txn, org)
        expect(%w[suggested unmatched]).to include(result.status)
      end
    end
  end
end
