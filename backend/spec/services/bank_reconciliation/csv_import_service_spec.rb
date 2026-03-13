# frozen_string_literal: true

require "rails_helper"
require "csv"

RSpec.describe BankReconciliation::CsvImportService, type: :service do
  let(:org)          { create(:organization) }
  let(:branch)       { create(:branch, organization: org) }
  let(:bank_account) { create(:bank_account, organization: org, branch: branch) }
  let(:user)         { create(:user) }
  let(:import) do
    create(:bank_statement_import,
           organization: org,
           bank_account: bank_account,
           uploaded_by:  user)
  end

  def build_csv(*rows)
    header = "date,narration,amount,dr_cr\n"
    body   = rows.map { |r| r.join(",") }.join("\n")
    header + body
  end

  VALID_ROW   = ["12/03/2026", "UPI/CR/RAJU STORES/UTR938383", "1180.00", "CR"].freeze
  DEBIT_ROW   = ["12/03/2026", "ATM WITHDRAWAL",               "500.00",  "DR"].freeze
  INVALID_ROW = ["",           "",                              "",        ""].freeze

  describe ".call" do
    context "with valid CSV" do
      it "creates BankTransaction records for credit rows" do
        csv = build_csv(VALID_ROW)
        expect {
          described_class.call(import: import, csv_data: csv)
        }.to change(BankTransaction, :count).by(1)
      end

      it "returns success result" do
        result = described_class.call(import: import, csv_data: build_csv(VALID_ROW))
        expect(result.success?).to be true
        expect(result.summary[:new]).to eq 1
        expect(result.summary[:total]).to eq 1
      end

      it "creates transaction with correct attributes" do
        described_class.call(import: import, csv_data: build_csv(VALID_ROW))
        txn = BankTransaction.last
        expect(txn.amount.to_f).to eq 1180.0
        expect(txn.direction).to eq "credit"
        expect(txn.status).to eq "unmatched"
        expect(txn.bank_account).to eq bank_account
        expect(txn.organization).to eq org
      end

      it "marks the import completed" do
        described_class.call(import: import, csv_data: build_csv(VALID_ROW))
        expect(import.reload.status).to eq "completed"
      end
    end

    context "deduplication" do
      it "does not import duplicate rows (same idempotency key)" do
        csv = build_csv(VALID_ROW)
        described_class.call(import: import, csv_data: csv)

        import2 = create(:bank_statement_import, organization: org, bank_account: bank_account, uploaded_by: user)
        expect {
          described_class.call(import: import2, csv_data: csv)
        }.not_to change(BankTransaction, :count)
      end

      it "increments the duplicate counter on the import" do
        csv = build_csv(VALID_ROW)
        described_class.call(import: import, csv_data: csv)

        import2 = create(:bank_statement_import, organization: org, bank_account: bank_account, uploaded_by: user)
        described_class.call(import: import2, csv_data: csv)

        expect(import2.reload.duplicate_rows_count).to eq 1
      end
    end

    context "with malformed CSV" do
      it "returns failure and marks import failed" do
        result = described_class.call(import: import, csv_data: "\"unclosed string")
        expect(result.success?).to be false
        expect(import.reload.status).to eq "failed"
      end
    end

    context "with unparseable rows" do
      it "counts failed rows but still succeeds overall" do
        csv = build_csv(VALID_ROW, INVALID_ROW)
        result = described_class.call(import: import, csv_data: csv)
        expect(result.summary[:new]).to eq 1
        expect(result.summary[:failed]).to eq 1
      end
    end

    context "with debit rows" do
      it "still imports debit transactions for completeness" do
        csv = build_csv(DEBIT_ROW)
        expect {
          described_class.call(import: import, csv_data: csv)
        }.to change(BankTransaction, :count).by(1)
        expect(BankTransaction.last.direction).to eq "debit"
      end
    end

    context "with missing required columns" do
      it "marks import failed when headers are missing" do
        bad_csv = "foo,bar,baz\n1,2,3\n"
        result  = described_class.call(import: import, csv_data: bad_csv)
        expect(result.success?).to be false
        expect(import.reload.status).to eq "failed"
      end
    end

    context "idempotency key generation" do
      it "builds a unique deterministic key" do
        key1 = BankTransaction.build_idempotency_key(
          bank_account_id: 1, txn_date: Date.today, amount: 1000,
          reference: "UTR001", narration: "Test"
        )
        key2 = BankTransaction.build_idempotency_key(
          bank_account_id: 1, txn_date: Date.today, amount: 1000,
          reference: "UTR001", narration: "Test"
        )
        expect(key1).to eq key2
      end

      it "differs for different amounts" do
        base = { bank_account_id: 1, txn_date: Date.today, reference: "X", narration: "Y" }
        expect(
          BankTransaction.build_idempotency_key(**base, amount: 100)
        ).not_to eq(
          BankTransaction.build_idempotency_key(**base, amount: 200)
        )
      end
    end
  end
end
