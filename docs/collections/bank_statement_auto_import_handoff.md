# Bank Statement Auto-Import — Developer Handoff

> Audience: Backend engineers onboarding to this feature or picking it up for further development.

---

## 1. What Was Built

A full bank statement auto-import and reconciliation pipeline including:

- **File ingestion**: CSV, XLSX (.xlsx + .xls), and text-based PDF statement uploads
- **Background processing**: `ProcessBankStatementImportJob` (Sidekiq) parses, deduplicates, and matches
- **Rule-based matching**: 7 matching rules ranked by confidence; auto-posts ≥ 95 score matches
- **Finance review UI hooks**: `suggested` transactions surfaced via API for human confirmation
- **Dashboard API**: Aggregated stats endpoint at `GET /api/v1/bank_transactions/dashboard`
- **Full spec coverage**: request specs, job spec, service specs, model specs, factories

---

## 2. Setup: Installing New Gems

Two gems were added to `Gemfile`:

```ruby
gem "roo",        "~> 2.10"   # XLSX / XLS parsing
gem "pdf-reader", "~> 2.12"   # PDF text extraction
```

Run in the `backend/` directory:

```bash
cd backend
bundle install
```

If using Docker:

```bash
docker compose run --rm api bundle install
```

---

## 3. Running the Full Test Suite for This Feature

```bash
cd backend

# All bank reconciliation specs
bundle exec rspec spec/models/bank_transaction_spec.rb \
               spec/services/bank_reconciliation/ \
               spec/jobs/process_bank_statement_import_job_spec.rb \
               spec/requests/api/v1/bank_accounts_spec.rb \
               spec/requests/api/v1/bank_statement_imports_spec.rb \
               spec/requests/api/v1/bank_transactions_spec.rb

# Quick smoke: just the request specs
bundle exec rspec spec/requests/api/v1/bank_accounts_spec.rb \
               spec/requests/api/v1/bank_statement_imports_spec.rb
```

---

## 4. Loading Demo Seed Data

The demo seed file creates a bank account, a statement import record, and 4 sample
transactions (one per matching scenario) for the existing "Arya Rice Distributors" org.

**Pre-requisite**: `db/seeds.rb` must have been run first so that `org`, `branch`,
`admin`, `customers`, and `seed_invoices` variables exist.

```bash
# Load the full seed chain (seeds.rb already calls or you can load directly):
cd backend
bin/rails db:seed

# Or load only the reconciliation demo in a Rails console:
bin/rails c
> load Rails.root.join("db/seeds_bank_reconciliation.rb")
```

After loading you should see 5 print lines confirming TXN-1 through TXN-4 creation
plus the TXN-5 duplicate note.

---

## 5. Manual End-to-End Test (API)

### Step 1 — Obtain a JWT
```bash
POST /api/v1/auth/login
{ "email": "admin@aryarice.in", "password": "Password@123" }
# → { "token": "<jwt>", "organization_id": <id> }
```

### Step 2 — Create or confirm a bank account
```bash
GET /api/v1/bank_accounts
# Returns active accounts. Note an id for use below.
```

### Step 3 — Upload a statement file
```bash
curl -X POST https://your-api-host/api/v1/bank_statement_imports \
  -H "Authorization: Bearer <jwt>" \
  -H "X-Organization-Id: <org_id>" \
  -F "bank_account_id=<account_id>" \
  -F "file=@/path/to/hdfc_march_2026.csv"
# → 202 Accepted  { "id": <import_id>, "status": "uploaded" }
```

### Step 4 — Poll import status
```bash
GET /api/v1/bank_statement_imports/<import_id>
# status transitions: uploaded → processing → completed / failed
# Keys: new_rows_count, duplicate_rows_count, failed_rows_count
```

### Step 5 — Review unmatched / suggested transactions
```bash
GET /api/v1/bank_transactions?status=suggested
GET /api/v1/bank_transactions?status=unmatched
```

### Step 6 — Confirm a suggested match
```bash
POST /api/v1/bank_transactions/<txn_id>/confirm_match
{ "allocations": [{ "invoice_id": <id>, "amount": 3352.38 }] }
```

### Step 7 — Check dashboard stats
```bash
GET /api/v1/bank_transactions/dashboard
# Returns: total_credits_imported, total_amount_imported, per-status counts
```

---

## 6. Sample CSV Format

The default CSV parser expects one of these header row formats:

```
Date,Description,Debit,Credit,Balance
Txn Date,Narration,Withdrawal Amt.,Deposit Amt.,Closing Balance
Date,Details,Withdrawals (Dr),Deposits (Cr),Balance
```

Rows with a `Credit` / `Deposit` value become `direction: credit`; rows with only a
`Debit` / `Withdrawal` value become `direction: debit`. Rows missing a date or having
no debit/credit value are skipped (counted in `failed_rows_count`).

---

## 7. Known Limitations

| Area | Limitation | Workaround / Planned Fix |
|------|-----------|--------------------------|
| PDF parsing | Only text-based PDFs work. Scanned/image PDFs return a clear error: *"This PDF appears to be scanned…"* | Phase 2: OCR via Tesseract or a third-party API |
| XLSX column detection | Parser assumes `Date`, `Description`, `Debit`, `Credit` columns in row 1. Custom layouts will fail silently. | Add a format-profile config per bank |
| PDF multi-line narrations | Long narrations split across lines may be partially captured | Post-process with multi-line merge heuristic |
| Matcher scope | `ExactAmountSingleOpenInvoiceRule` scans ALL outstanding invoices for the org — may be slow for orgs with 10k+ open invoices | Add a date-range pre-filter |
| Auto-post race condition | If two identical statements are uploaded simultaneously, both jobs may attempt to post the same auto-matched transactions | Add `with_advisory_lock` around PostingService call |

---

## 8. File & Directory Map

```
backend/
  app/
    controllers/api/v1/
      bank_accounts_controller.rb          ← CRUD for bank accounts
      bank_statement_imports_controller.rb ← Upload + list imports
      bank_transactions_controller.rb      ← List, review, confirm, dashboard
    jobs/
      process_bank_statement_import_job.rb ← Sidekiq job (orchestrator)
    models/
      bank_account.rb
      bank_statement_import.rb
      bank_transaction.rb
      bank_transaction_match.rb
    queries/bank_reconciliation/
      import_dashboard_query.rb            ← Dashboard aggregation (NEW)
    serializers/
      bank_account_serializer.rb
      bank_statement_import_serializer.rb
      bank_transaction_serializer.rb
      bank_transaction_match_serializer.rb
    services/bank_reconciliation/
      csv_import_service.rb
      xlsx_import_service.rb               ← NEW (roo gem)
      pdf_import_service.rb                ← NEW (pdf-reader gem)
      file_dispatcher.rb                   ← NEW (routes by source_type)
      matcher.rb                           ← UPDATED (7 rules)
      narration_normalizer.rb
      row_parser.rb
      posting_service.rb
      payment_instructions_service.rb
      rules/
        exact_invoice_number_rule.rb
        exact_retailer_code_rule.rb
        exact_reference_rule.rb
        retailer_alias_and_amount_rule.rb
        exact_amount_customer_name_rule.rb ← NEW
        multi_invoice_same_customer_rule.rb ← NEW
        exact_amount_single_open_invoice_rule.rb
  db/
    seeds_bank_reconciliation.rb           ← NEW demo seed data
  spec/
    factories.rb                           ← UPDATED (4 new factories)
    jobs/
      process_bank_statement_import_job_spec.rb ← NEW
    requests/api/v1/
      bank_accounts_spec.rb               ← NEW
      bank_statement_imports_spec.rb      ← NEW
      bank_transactions_spec.rb           ← EXISTS
    services/bank_reconciliation/
      csv_import_service_spec.rb          ← NEW
      matcher_spec.rb                     ← EXISTS
      posting_service_spec.rb             ← EXISTS
      narration_normalizer_spec.rb        ← EXISTS
docs/collections/
  bank_statement_auto_import_review.md    ← Codebase review + bug report
  bank_statement_auto_import_design.md    ← Architecture + API reference
  bank_statement_auto_import_handoff.md   ← This file
```

---

## 9. Bugs Fixed During This Sprint

| # | Location | Bug | Fix |
|---|----------|-----|-----|
| 1 | `BankStatementImportsController#create` | `imported_by:` (non-existent param) | Changed to `uploaded_by: Current.user` |
| 2 | `BankStatementImportsController#create` | `import.file.attach` (wrong attachment name) | Changed to `import.csv_file.attach` |
| 3 | `BankStatementImportsController#create` | `original_filename:` (not a column) | Changed to `file_name: csv_file.original_filename` |
| 4a | `ProcessBankStatementImportJob#perform` | Called `CsvImportService` directly — ignores XLSX/PDF | Now routes via `FileDispatcher` |
| 4b | `ProcessBankStatementImportJob#perform` | Summary key names `[:new_rows]` didn't match service output `[:new]` | Keys aligned across job and all import services |
| 4c | `ProcessBankStatementImportJob#perform` | `import.mark_failed!(message: e.message)` — wrong keyword | Changed to positional `import.mark_failed!(e.message)` |

---

## 10. Open Tasks / Future Work

- [ ] **Frontend reconciliation UI** — table showing `suggested` / `unmatched` transactions with confirm/ignore actions
- [ ] **OCR for scanned PDFs** — integrate Tesseract or AWS Textract in `PdfImportService`
- [ ] **XLSX column profile config** — per-bank column mapping JSON stored in `BankAccount`
- [ ] **Email notification** — notify uploader when import transitions to `completed` or `failed`
- [ ] **Bulk ignore / bulk confirm** — batch actions on the transactions list
- [ ] **Re-upload support** — allow re-uploading a corrected file for a failed import
- [ ] **Audit log entries** — `BankTransaction` already `include Auditable`; verify events fire on `matched` / `reversed` transitions
- [ ] **Controller param alignment** — `BankAccountsController` permits `account_holder_name` but model column is `account_name`; align params or add `alias_attribute`
