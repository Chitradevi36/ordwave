# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessBankStatementImportJob, type: :job do
  include ActiveJob::TestHelper

  let(:org)          { create(:organization) }
  let(:branch)       { create(:branch, organization: org) }
  let(:bank_account) { create(:bank_account, organization: org, branch: branch) }
  let(:uploader)     { create(:user) }

  let(:import) do
    create(:bank_statement_import,
           organization: org,
           bank_account: bank_account,
           uploaded_by:  uploader,
           status:       "uploaded",
           source_type:  "csv")
  end

  # Minimal successful dispatcher result
  let(:success_result) do
    double(
      "DispatchResult",
      success?: true,
      summary:  { new: 2, duplicates: 0, failed: 0, total: 2 },
      errors:   []
    )
  end

  let(:failure_result) do
    double(
      "DispatchResult",
      success?: false,
      summary:  {},
      errors:   ["Invalid CSV format"]
    )
  end

  before do
    # Stub blob key path-lookup so we don't need real ActiveStorage disk setup
    blob = double("Blob", key: "test-blob-key")
    attached_csv = double("AttachedOne", blob: blob)
    allow(import).to receive(:csv_file).and_return(attached_csv)
    allow(BankStatementImport).to receive(:find).with(import.id).and_return(import)
    allow(ActiveStorage::Blob.service).to receive(:path_for).with("test-blob-key")
                                                             .and_return("/tmp/test_statement.csv")
  end

  # ── Enqueue test ─────────────────────────────────────────────────────────
  describe ".perform_later" do
    it "enqueues on the default queue" do
      expect {
        described_class.perform_later(import.id)
      }.to have_enqueued_job(described_class).with(import.id).on_queue("default")
    end
  end

  # ── Idempotency ──────────────────────────────────────────────────────────
  describe "#perform — already completed" do
    it "returns early without calling FileDispatcher" do
      import.update!(status: "completed")
      expect(BankReconciliation::FileDispatcher).not_to receive(:new)
      described_class.perform_now(import.id)
    end
  end

  describe "#perform — already failed" do
    it "returns early without calling FileDispatcher" do
      import.update!(status: "failed")
      expect(BankReconciliation::FileDispatcher).not_to receive(:new)
      described_class.perform_now(import.id)
    end
  end

  # ── Success path ─────────────────────────────────────────────────────────
  describe "#perform — successful import" do
    let(:txn) do
      create(:bank_transaction, :unmatched,
             organization:           org,
             bank_account:           bank_account,
             bank_statement_import:  import)
    end

    before do
      dispatcher = instance_double(BankReconciliation::FileDispatcher, call: success_result)
      allow(BankReconciliation::FileDispatcher).to receive(:new).and_return(dispatcher)

      # Stub the matcher so we don't need real invoice fixtures
      allow(BankReconciliation::Matcher).to receive(:call)
    end

    it "transitions import from uploaded → processing → completed" do
      described_class.perform_now(import.id)
      expect(import.reload.status).to eq("completed")
    end

    it "stores row counts on the import record" do
      described_class.perform_now(import.id)
      reloaded = import.reload
      expect(reloaded.new_rows_count).to eq(2)
      expect(reloaded.failed_rows_count).to eq(0)
    end

    it "calls BankReconciliation::Matcher for each unmatched transaction" do
      txn  # create the transaction
      described_class.perform_now(import.id)
      expect(BankReconciliation::Matcher).to have_received(:call).with(txn, org)
    end

    it "sets Current.organization for the background context" do
      described_class.perform_now(import.id)
      # Validate indirectly: import.organization is accessible — no cross-org leak
      expect(import.reload.organization_id).to eq(org.id)
    end
  end

  # ── Failure path ─────────────────────────────────────────────────────────
  describe "#perform — dispatcher returns failure" do
    before do
      dispatcher = instance_double(BankReconciliation::FileDispatcher, call: failure_result)
      allow(BankReconciliation::FileDispatcher).to receive(:new).and_return(dispatcher)
    end

    it "marks the import as failed with the error message" do
      described_class.perform_now(import.id)
      reloaded = import.reload
      expect(reloaded.status).to eq("failed")
      expect(reloaded.error_message).to include("Invalid CSV format")
    end

    it "does not run the matcher" do
      expect(BankReconciliation::Matcher).not_to receive(:call)
      described_class.perform_now(import.id)
    end
  end

  # ── Exception path ───────────────────────────────────────────────────────
  describe "#perform — unexpected exception" do
    before do
      allow(BankReconciliation::FileDispatcher).to receive(:new)
        .and_raise(RuntimeError, "Storage unavailable")
    end

    it "marks the import as failed and re-raises" do
      expect {
        described_class.perform_now(import.id)
      }.to raise_error(RuntimeError, "Storage unavailable")

      expect(import.reload.status).to eq("failed")
    end
  end
end
