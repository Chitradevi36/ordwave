# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BankAccounts", type: :request do
  # ── Helpers ──────────────────────────────────────────────────────────────────
  def generate_jwt_for(user)
    JWT.encode(
      { sub: user.id, exp: 1.hour.from_now.to_i },
      Rails.application.secret_key_base,
      "HS256"
    )
  end

  def auth_headers(user = owner)
    {
      "Authorization"     => "Bearer #{generate_jwt_for(user)}",
      "X-Organization-Id" => org.id.to_s,
      "Content-Type"      => "application/json"
    }
  end

  def json_body
    JSON.parse(response.body)
  end

  # ── Shared Setup ─────────────────────────────────────────────────────────────
  let(:org)    { create(:organization) }
  let(:branch) { create(:branch, organization: org) }

  def find_or_create_role(name)
    Role.find_by(name: name) || create(:role, name: name)
  end

  def create_user_with_role(role_name)
    user = create(:user)
    role = find_or_create_role(role_name)
    create(:membership, user: user, organization: org, branch: branch, role: role, active: true)
    user
  end

  let(:owner) { create_user_with_role("owner") }

  let!(:bank_account) do
    create(:bank_account,
           organization: org,
           branch:       branch,
           bank_name:    "HDFC Bank",
           account_name: "Arya Rice Distributors",
           account_number_masked: "••••9876",
           status:       "active")
  end

  # ── GET /api/v1/bank_accounts ─────────────────────────────────────────────
  describe "GET /api/v1/bank_accounts" do
    it "returns 200 and lists active bank accounts for the org" do
      get "/api/v1/bank_accounts", headers: auth_headers
      expect(response).to have_http_status(:ok)
    end

    it "returns only accounts belonging to the current org" do
      other_org     = create(:organization)
      other_branch  = create(:branch, organization: other_org)
      _other_acct   = create(:bank_account, organization: other_org, branch: other_branch)

      get "/api/v1/bank_accounts", headers: auth_headers
      ids = json_body.map { |a| a["id"] }
      expect(ids).to include(bank_account.id)
      expect(ids.size).to eq(1)
    end

    it "excludes inactive accounts" do
      create(:bank_account, organization: org, status: "inactive")

      get "/api/v1/bank_accounts", headers: auth_headers
      ids = json_body.map { |a| a["id"] }
      expect(ids).to eq([bank_account.id])
    end

    it "requires authentication" do
      get "/api/v1/bank_accounts"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ── GET /api/v1/bank_accounts/:id ────────────────────────────────────────
  describe "GET /api/v1/bank_accounts/:id" do
    it "returns 200 and the bank account" do
      get "/api/v1/bank_accounts/#{bank_account.id}", headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(json_body["id"]).to eq(bank_account.id)
    end

    it "returns 404 for an account in another org" do
      other_org    = create(:organization)
      other_branch = create(:branch, organization: other_org)
      other_acct   = create(:bank_account, organization: other_org, branch: other_branch)

      get "/api/v1/bank_accounts/#{other_acct.id}", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for a non-existent id" do
      get "/api/v1/bank_accounts/0", headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── POST /api/v1/bank_accounts ────────────────────────────────────────────
  describe "POST /api/v1/bank_accounts" do
    # NOTE: controller permits `account_holder_name` but the model column is
    # `account_name`. Until the controller param list is aligned to model
    # columns, this test documents the expected interface.
    let(:valid_params) do
      {
        bank_account: {
          bank_name:             "Axis Bank",
          account_holder_name:   "Test Distributor Pvt Ltd",
          account_number_masked: "••••5555",
          ifsc:                  "UTIB0001234",
          status:                "active"
        }
      }
    end

    it "returns 201 when params are valid" do
      post "/api/v1/bank_accounts",
           params:  valid_params.to_json,
           headers: auth_headers
      expect(response).to have_http_status(:created)
    end

    it "returns 422 when bank_name is missing" do
      params = valid_params.deep_dup
      params[:bank_account].delete(:bank_name)

      post "/api/v1/bank_accounts",
           params:  params.to_json,
           headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_body["errors"]).to be_present
    end

    it "requires authentication" do
      post "/api/v1/bank_accounts", params: valid_params.to_json,
           headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ── PATCH /api/v1/bank_accounts/:id ──────────────────────────────────────
  describe "PATCH /api/v1/bank_accounts/:id" do
    it "updates and returns 200" do
      patch "/api/v1/bank_accounts/#{bank_account.id}",
            params:  { bank_account: { status: "inactive" } }.to_json,
            headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(bank_account.reload.status).to eq("inactive")
    end

    it "returns 404 when updating another org's account" do
      other_org   = create(:organization)
      other_acct  = create(:bank_account, organization: other_org)

      patch "/api/v1/bank_accounts/#{other_acct.id}",
            params:  { bank_account: { status: "inactive" } }.to_json,
            headers: auth_headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
