# frozen_string_literal: true

require "rails_helper"

RSpec.describe BankReconciliation::PostingService do
  let(:org)          { create(:organization) }
  let(:branch)       { create(:branch, organization: org) }
  let(:bank_account) { create(:bank_account, organization: org, branch: branch) }
  let(:customer)     { create(:customer, organization: org, branch: branch) }
  let(:reviewer)     { create(:user, organization: org) }

  let(:invoice) do
    create(:sales_invoice,
           organization: org,
           customer:     customer,
           grand_total:  10_000,
           status:       :issued)
  end

  let(:txn) do
    create(:bank_transaction,
           organization: org,
           bank_account: bank_account,
           direction:    "credit",
           status:       "suggested",
           amount:       10_000,
           txn_date:     Date.today)
  end

  def call(allocations: nil)
    described_class.call(
      bank_transaction: txn,
      allocations:      allocations || [{ invoice_id: invoice.id, amount: 10_000 }],
      reviewed_by:      reviewer
    )
  end

  describe "#call" do
    context "with valid allocation" do
      it "returns success" do
        expect(call.success?).to be true
      end

      it "creates a Payment record" do
        expect { call }.to change(Payment, :count).by(1)
      end

      it "creates a PaymentAllocation record" do
        expect { call }.to change(PaymentAllocation, :count).by(1)
      end

      it "marks the invoice as paid" do
        call
        expect(invoice.reload.status).to eq("paid")
      end

      it "marks the transaction as matched" do
        call
        expect(txn.reload.status).to eq("matched")
      end

      it "sets matched_payment_id on the transaction" do
        result = call
        expect(txn.reload.matched_payment_id).to eq(result.payment.id)
      end
    end

    context "when already posted" do
      before { txn.update!(matched_payment_id: 999) }

      it "returns failure" do
        expect(call.success?).to be false
      end

      it "does not create a Payment" do
        expect { call }.not_to change(Payment, :count)
      end
    end

    context "with no allocations" do
      it "returns failure" do
        result = described_class.call(
          bank_transaction: txn,
          allocations:      [],
          reviewed_by:      reviewer
        )
        expect(result.success?).to be false
      end
    end

    context "when allocated amount exceeds transaction amount" do
      it "returns failure with an error message" do
        result = call(allocations: [{ invoice_id: invoice.id, amount: 99_999 }])
        expect(result.success?).to be false
        expect(result.errors.first).to match(/exceeds/)
      end
    end

    context "with partial allocation (excess → advance)" do
      let(:invoice2) do
        create(:sales_invoice, organization: org, customer: customer,
               grand_total: 6_000, status: :issued)
      end

      it "creates an AdvancePayment for excess" do
        expect {
          described_class.call(
            bank_transaction: txn,
            allocations:      [{ invoice_id: invoice2.id, amount: 6_000 }],
            reviewed_by:      reviewer
          )
        }.to change(AdvancePayment, :count).by(1)
      end
    end
  end
end
