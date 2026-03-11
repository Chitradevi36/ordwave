# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BankTransactions", type: :request do
  let(:org)          { create(:organization) }
  let(:branch)       { create(:branch, organization: org) }
  let(:bank_account) { create(:bank_account, organization: org, branch: branch) }
  let(:user)         { create(:user, organization: org, role: :finance) }
  let(:headers)      { auth_headers(user) }

  let!(:txn) do
    create(:bank_transaction,
           organization: org,
           bank_account: bank_account,
           status:       :suggested,
           direction:    :credit,
           amount:       5000)
  end

  describe "GET /api/v1/bank_transactions" do
    it "returns 200 and a list" do
      get "/api/v1/bank_transactions", headers: headers
      expect(response).to have_http_status(:ok)
      ids = json_body["data"].pluck("id")
      expect(ids).to include(txn.id)
    end

    it "filters by status" do
      create(:bank_transaction, organization: org, bank_account: bank_account, status: :ignored)
      get "/api/v1/bank_transactions?status=suggested", headers: headers
      statuses = json_body["data"].pluck("status").uniq
      expect(statuses).to eq(["suggested"])
    end
  end

  describe "GET /api/v1/bank_transactions/:id" do
    it "returns the transaction" do
      get "/api/v1/bank_transactions/#{txn.id}", headers: headers
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for another org" do
      other_org     = create(:organization)
      other_account = create(:bank_account, organization: other_org)
      other_txn     = create(:bank_transaction, organization: other_org, bank_account: other_account)
      get "/api/v1/bank_transactions/#{other_txn.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/bank_transactions/:id/ignore" do
    it "marks the transaction as ignored" do
      post "/api/v1/bank_transactions/#{txn.id}/ignore", headers: headers
      expect(response).to have_http_status(:ok)
      expect(txn.reload.status).to eq("ignored")
    end
  end

  describe "POST /api/v1/bank_transactions/:id/retry_match" do
    it "returns 200 and re-runs matcher" do
      post "/api/v1/bank_transactions/#{txn.id}/retry_match", headers: headers
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/bank_transactions/:id/confirm_match" do
    let(:customer) { create(:customer, organization: org, branch: branch) }
    let(:invoice) do
      create(:sales_invoice,
             organization: org,
             customer:     customer,
             grand_total:  5000,
             status:       :issued)
    end

    it "creates a payment and marks the transaction matched" do
      post "/api/v1/bank_transactions/#{txn.id}/confirm_match",
           params:  { allocations: [{ invoice_id: invoice.id, amount: 5000 }] },
           headers: headers
      expect(response).to have_http_status(:ok)
      expect(txn.reload.status).to eq("matched")
    end

    it "returns 422 if allocation exceeds amount" do
      post "/api/v1/bank_transactions/#{txn.id}/confirm_match",
           params:  { allocations: [{ invoice_id: invoice.id, amount: 99_999 }] },
           headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
