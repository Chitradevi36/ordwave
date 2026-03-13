# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BankStatementImports", type: :request do
  # ── Helpers ──────────────────────────────────────────────────────────────────
  def generate_jwt_for(user)
    JWT.encode(
      { sub: user.id, exp: 1.hour.from_now.to_i },
      Rails.application.secret_key_base,
      "HS256"
    )
  end

  def json_headers(user = owner)
    {
      "Authorization"     => "Bearer #{generate_jwt_for(user)}",
      "X-Organization-Id" => org.id.to_s,
      "Content-Type"      => "application/json"
    }
  end

  # Multipart headers for file upload (no Content-Type — Rack sets it automatically)
  def upload_headers(user = owner)
    {
      "Authorization"     => "Bearer #{generate_jwt_for(user)}",
      "X-Organization-Id" => org.id.to_s
    }
  end

  def json_body
    JSON.parse(response.body)
  end

  # A minimal valid bank statement CSV
  SAMPLE_CSV = <<~CSV
    Date,Description,Debit,Credit,Balance
    01/03/2026,UPI/CR/RAJU STORES,,5000.00,50000.00
    02/03/2026,NEFT/DR/SUPPLIER PAY,2000.00,,48000.00
  CSV

  def sample_csv_upload(filename: "statement.csv")
    Rack::Test::UploadedFile.new(
      StringIO.new(SAMPLE_CSV),
      "text/csv",
      original_filename: filename
    )
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
    create(:bank_account, organization: org, branch: branch)
  end

  let!(:import) do
    create(:bank_statement_import,
           organization: org,
           bank_account: bank_account,
           uploaded_by:  owner)
  end

  # ── GET /api/v1/bank_statement_imports ───────────────────────────────────
  describe "GET /api/v1/bank_statement_imports" do
    it "returns 200 and lists imports for the org" do
      get "/api/v1/bank_statement_imports", headers: json_headers
      expect(response).to have_http_status(:ok)
    end

    it "paginates results" do
      create_list(:bank_statement_import, 3, organization: org, bank_account: bank_account,
                  uploaded_by: owner)

      get "/api/v1/bank_statement_imports?per_page=2", headers: json_headers
      # response body may be an array or a hash with data key
      ids = json_body.is_a?(Array) ? json_body.pluck("id") : json_body["data"].pluck("id")
      expect(ids.size).to be <= 2
    end

    it "does not return imports from another org" do
      other_org    = create(:organization)
      other_branch = create(:branch, organization: other_org)
      other_acct   = create(:bank_account, organization: other_org, branch: other_branch)
      other_user   = create(:user)
      create(:bank_statement_import, organization: other_org, bank_account: other_acct,
             uploaded_by: other_user)

      get "/api/v1/bank_statement_imports", headers: json_headers
      own_ids = [import.id]
      returned_ids = json_body.is_a?(Array) ? json_body.pluck("id") : json_body["data"].pluck("id")
      returned_ids.each { |id| expect(own_ids).to include(id) }
    end

    it "requires authentication" do
      get "/api/v1/bank_statement_imports"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ── GET /api/v1/bank_statement_imports/:id ───────────────────────────────
  describe "GET /api/v1/bank_statement_imports/:id" do
    it "returns 200 and the import record" do
      get "/api/v1/bank_statement_imports/#{import.id}", headers: json_headers
      expect(response).to have_http_status(:ok)
      expect(json_body["id"]).to eq(import.id)
    end

    it "returns 404 for another org's import" do
      other_org    = create(:organization)
      other_branch = create(:branch, organization: other_org)
      other_acct   = create(:bank_account, organization: other_org, branch: other_branch)
      other_user   = create(:user)
      other_import = create(:bank_statement_import, organization: other_org,
                            bank_account: other_acct, uploaded_by: other_user)

      get "/api/v1/bank_statement_imports/#{other_import.id}", headers: json_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  # ── POST /api/v1/bank_statement_imports ──────────────────────────────────
  describe "POST /api/v1/bank_statement_imports" do
    before do
      # Prevent the background job from actually executing during request spec
      allow(ProcessBankStatementImportJob).to receive(:perform_later)
    end

    it "returns 202 accepted and enqueues the processing job" do
      post "/api/v1/bank_statement_imports",
           params:  { bank_account_id: bank_account.id, file: sample_csv_upload },
           headers: upload_headers

      expect(response).to have_http_status(:accepted)
      expect(ProcessBankStatementImportJob).to have_received(:perform_later)
    end

    it "stores the import with status=uploaded" do
      post "/api/v1/bank_statement_imports",
           params:  { bank_account_id: bank_account.id, file: sample_csv_upload },
           headers: upload_headers

      expect(response).to have_http_status(:accepted)
      created_id = json_body["id"]
      created    = BankStatementImport.find(created_id)
      expect(created.status).to eq("uploaded")
      expect(created.bank_account_id).to eq(bank_account.id)
      expect(created.organization_id).to eq(org.id)
    end

    it "detects csv source_type from file extension" do
      post "/api/v1/bank_statement_imports",
           params:  { bank_account_id: bank_account.id,
                      file: sample_csv_upload(filename: "march_statement.csv") },
           headers: upload_headers

      created_id = json_body["id"]
      expect(BankStatementImport.find(created_id).source_type).to eq("csv")
    end

    it "detects xlsx source_type from file extension" do
      xlsx_file = Rack::Test::UploadedFile.new(
        StringIO.new("fake xlsx bytes"),
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        original_filename: "statement.xlsx"
      )

      post "/api/v1/bank_statement_imports",
           params:  { bank_account_id: bank_account.id, file: xlsx_file },
           headers: upload_headers

      created_id = json_body["id"]
      expect(BankStatementImport.find(created_id).source_type).to eq("xlsx")
    end

    it "returns 422 when no file is provided" do
      post "/api/v1/bank_statement_imports",
           params:  { bank_account_id: bank_account.id },
           headers: upload_headers
      expect(response.status).to be_in([400, 422])
    end

    it "returns 404 when bank_account_id belongs to another org" do
      other_org   = create(:organization)
      other_acct  = create(:bank_account, organization: other_org)

      post "/api/v1/bank_statement_imports",
           params:  { bank_account_id: other_acct.id, file: sample_csv_upload },
           headers: upload_headers
      expect(response).to have_http_status(:not_found)
    end

    it "requires authentication" do
      post "/api/v1/bank_statement_imports",
           params: { bank_account_id: bank_account.id, file: sample_csv_upload }
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
