# Bank Statement Auto-Import — Codebase Review

> Prepared: 2026-03-12  
> Reviewer: GitHub Copilot (Senior Rails Architect mode)  
> Scope: Phase 1 — Bank Statement Upload Auto-Import

---

## 1. Executive Summary

**This feature is ~80% already built.** All core Rails models, migrations, controllers, services, matching rules, background job, serializers, and policies exist. The frontend page, components, and API hooks are in place. The primary gaps are: four interface bugs causing runtime failures, no XLSX/PDF parser, two missing matching rules, no import dashboard endpoint, and missing specs/documentation.

---

## 2. Existing Core Domain Models

### Tenant / Org Scope
| Model | File | Relevant Fields |
|-------|------|-----------------|
| `Organization` | `app/models/organization.rb` | `id`, `name`, `plan` — all banking scoped by org |
| `Branch` | `app/models/branch.rb` | `org_id`, `code` — BankAccount optionally belongs to branch |
| `User` | `app/models/user.rb` | linked for `uploaded_by`, `reviewed_by` |

### Customer / Party
| Model | File | Relevant Fields |
|-------|------|-----------------|
| `Customer` | `app/models/customer.rb` | `code`, `trade_name`, `gstin`, `phone`, `organization_id` |
| `CustomerAlias` | `app/models/customer_alias.rb` | alternate names — can improve matching |

### Invoice / Finance
| Model | File | Relevant Fields |
|-------|------|-----------------|
| `SalesInvoice` | `app/models/sales_invoice.rb` | `invoice_number`, `grand_total`, `outstanding_amount`, `status`, `customer_id`, `due_date` |
| `Payment` | `app/models/payment.rb` | `payment_number`, `amount`, `payment_mode`, `received_date`, `reference_number`, `created_by_id`, `customer_id` |
| `PaymentAllocation` | `app/models/payment_allocation.rb` | `payment_id`, `sales_invoice_id`, `allocated_amount` |
| `AdvancePayment` | `app/models/advance_payment.rb` | `customer_id`, `source_payment_id`, `amount`, `notes` |
| `CreditNote` | `app/models/credit_note.rb` | applicable de-allocation |

### Banking (all exist, all migrated)
| Model | File | Status |
|-------|------|--------|
| `BankAccount` | `app/models/bank_account.rb` | ✅ Complete |
| `BankStatementImport` | `app/models/bank_statement_import.rb` | ✅ Complete, minor field mismatches |
| `BankTransaction` | `app/models/bank_transaction.rb` | ✅ Complete |
| `BankTransactionMatch` | `app/models/bank_transaction_match.rb` | ✅ Complete |
| `ExpectedPaymentReference` | `app/models/expected_payment_reference.rb` | ✅ Used by PaymentInstructionsService |

### Audit
| Model | File |
|-------|------|
| `AuditLog` | `app/models/audit_log.rb` |
| `Auditable` concern | `app/models/concerns/auditable.rb` |

`BankTransaction` already `include Auditable` — every status change is logged automatically.

---

## 3. Schema Review — Banking Tables

### `bank_accounts`
```
id, organization_id, branch_id, bank_name, account_name,
account_number_masked, account_number_full, ifsc, status, timestamps
```
Indexes: org, branch, status. ✅ Complete.

### `bank_statement_imports`
```
id, organization_id, bank_account_id, uploaded_by_id, file_name,
source_type, status, rows_count, processed_rows_count, new_rows_count,
duplicate_rows_count, failed_rows_count, error_message, timestamps
```
Indexes: org, bank_account, status, uploaded_by. ✅ Complete.  
⚠️ **Missing:** `source_type` enum does not include `xlsx` or `pdf` (current: csv/manual/api).

### `bank_transactions`
```
id, organization_id, bank_account_id, bank_statement_import_id,
txn_date, amount, direction, utr_number, reference_number, payer_name,
narration, normalized_narration, raw_row_json, match_meta, status,
match_score, match_rule, matched_customer_id, matched_invoice_id,
matched_payment_id, reviewed_by_id, review_notes, processed_at,
idempotency_key, timestamps
```
Indexes: org, bank_account, import, status, txn_date, utr_number, amount, idempotency_key (unique). ✅ Complete.

### `bank_transaction_matches`
```
id, bank_transaction_id, customer_id, sales_invoice_id, score,
rule_code, explanation (jsonb), selected, timestamps
```
Indexes: txn, customer, sales_invoice, rule_code, selected. ✅ Complete.

---

## 4. Existing Services — bank_reconciliation/

| Service | Purpose | Status |
|---------|---------|--------|
| `CsvImportService` | Parse CSV → BankTransaction rows | ✅ Functional. Bug: accepts `csv_data:` string but job passes `file_path:` |
| `RowParser` | Parse one CSV row into typed struct | ✅ Complete |
| `NarrationNormalizer` | Clean narration, extract invoice/UTR/code tokens | ✅ Complete |
| `Matcher` | Orchestrate all rules, persist candidates, update txn status | ✅ Complete |
| `PostingService` | Create Payment + PaymentAllocations + AdvancePayment | ✅ Complete |
| `PaymentInstructionsService` | Generate payment instructions / ExpectedPaymentReferences | ✅ Complete |
| `rules/exact_invoice_number_rule` | Score 100 — invoice number found in narration | ✅ |
| `rules/exact_retailer_code_rule` | Score 97 — retailer code found in narration | ✅ |
| `rules/exact_reference_rule` | Score 98 — UTR/reference seen in ExpectedPaymentReference | ✅ |
| `rules/retailer_alias_and_amount_rule` | Score 85 — alias name + amount match | ✅ |
| `rules/exact_amount_single_open_invoice_rule` | Score 90/50 — amount matches exactly one open invoice | ✅ |

**Missing rules:**
- `rules/multi_invoice_same_customer_rule` — multi-invoice combination adds up to amount
- `rules/exact_amount_customer_name_rule` — customer name in narration + amount match

---

## 5. Existing Controllers

All three controllers exist and are complete:
- `Api::V1::BankAccountsController` — index/show/create/update
- `Api::V1::BankStatementImportsController` — index/show/create
- `Api::V1::BankTransactionsController` — index/show/confirm_match/mark_as_advance/ignore/retry_match

---

## 6. Existing Routes

```ruby
resources :bank_accounts,          only: %i[index show create update]
resources :bank_statement_imports,  only: %i[index show create]
resources :bank_transactions,       only: %i[index show] do
  member do
    post :confirm_match
    post :mark_as_advance
    post :ignore
    post :retry_match
  end
end
```
✅ Complete. Missing: import dashboard summary endpoint.

---

## 7. Existing Frontend

| File | Purpose | Status |
|------|---------|--------|
| `web/app/bank-reconciliation/page.tsx` | Main tabbed queue UI | ✅ Exists |
| `web/components/bank-reconciliation/ReviewDrawer.tsx` | Confirm/reject drawer | ✅ Exists |
| `web/components/bank-reconciliation/ImportScreen.tsx` | File upload screen | ✅ Exists |
| `web/lib/api/hooks/useBankTransactions.ts` | SWR hook for transactions | ✅ Exists |
| `web/lib/api/hooks/useBankStatementImports.ts` | SWR hook for imports | ✅ Exists |

---

## 8. Bug Report — Interface Mismatches

These bugs would cause runtime failures on first import attempt:

### Bug 1 — Controller attribute name mismatch
**File:** `app/controllers/api/v1/bank_statement_imports_controller.rb`  
**Problem:** `BankStatementImport.new(imported_by: Current.user)` — column is `uploaded_by_id`.  
**Fix:** Change to `uploaded_by: Current.user`.

### Bug 2 — Controller file attachment name mismatch
**File:** `app/controllers/api/v1/bank_statement_imports_controller.rb`  
**Problem:** `import.file.attach(csv_file)` — attachment is declared `has_one_attached :csv_file`.  
**Fix:** Change to `import.csv_file.attach(csv_file)`.

### Bug 3 — Controller `original_filename` is not a column
**File:** `app/controllers/api/v1/bank_statement_imports_controller.rb`  
**Problem:** `original_filename: csv_file.original_filename` — schema column is `file_name`.  
**Fix:** Change to `file_name: csv_file.original_filename`.

### Bug 4 — Job/service parameter mismatch
**File:** `app/jobs/process_bank_statement_import_job.rb`  
**Problem (a):** `CsvImportService.call(import: import, file_path: file_path)` — service accepts `csv_data:` not `file_path:`.  
**Problem (b):** `result.summary[:new_rows]` / `[:failed_rows]` / `[:total_rows]` — service keys are `:new`, `:failed`, `:total`.  
**Problem (c):** `import.mark_failed!(message: e.message)` — `mark_failed!` takes positional string.  
**Fix:** Update service to accept file download, or have job read the file. Update summary key names. Fix positional arg.

---

## 9. What Can Be Reused Directly

| Capability | Model / Service | Notes |
|---|---|---|
| Invoice status update | `PostingService#update_invoice_status` | Already calls `invoice.update!(status: :paid / :partially_paid)` |
| Advance payment | `PostingService#handle_excess` + `AdvancePayment.create!` | Works |
| Audit trail | `include Auditable` on `BankTransaction` | Auto-logs all changes |
| Deduplicate | `BankTransaction.build_idempotency_key` + `idempotency_key` unique index | Works |
| Narration signals | `NarrationNormalizer` — invoice patterns, customer codes, UTR | Works |
| Payment creation | `Payment.create!(payment_mode: :bank_transfer, ...)` | Works |
| Policy/authorization | `BankTransactionPolicy`, `BankAccountPolicy`, `BankStatementImportPolicy` | All exist |
| Pagination | `kaminari` `page/per` pattern matching all other controllers | Works |
| ActiveStorage upload | `has_one_attached :csv_file` on BankStatementImport | Works |
| Background processing | `ProcessBankStatementImportJob` via Sidekiq | Exists, needs bug fixes |

---

## 10. What Is Partially Reusable

| Capability | Gap |
|---|---|
| `CsvImportService` | Needs to read file from ActiveStorage blob path (not raw string) |
| `BankStatementImport.SOURCE_TYPES` | Needs `xlsx`, `pdf` added |
| `BankStatementImportsController#create` | Needs source_type detection from file extension |
| Matching engine | Missing 2 rules (multi-invoice, customer-name+amount) |

---

## 11. What Is Missing

| Item | Priority |
|------|----------|
| XLSX parser (`BankReconciliation::XlsxImportService`) | High |
| PDF parser (`BankReconciliation::PdfImportService`) | Medium (Phase 1 text extraction only) |
| File dispatcher (route to CSV/XLSX/PDF by detected type) | High |
| `multi_invoice_same_customer_rule` | High |
| `exact_amount_customer_name_rule` | Medium |
| Import dashboard summary endpoint + query | Medium |
| Bank factories in `spec/factories.rb` | High (blocks all specs) |
| Service specs (CsvImportService, Matcher, PostingService, etc.) | High |
| Request specs (bank_statement_imports, bank_accounts) | High |
| Job spec | Medium |
| Seed/demo data | Low |
| `roo` gem for XLSX | High |
| `pdf-reader` gem for PDF | Medium |
| `docs/collections/bank_statement_auto_import_design.md` | Low |
| `docs/collections/bank_statement_auto_import_handoff.md` | Low |

---

## 12. Naming Conventions to Follow

- **Controllers:** `Api::V1::` namespace, inherit `BaseController`, `authorize` via Pundit, `policy_scope`, `render_success` helper, `pagination_meta`
- **Services:** PORO, `.call(...)` class method, returns `Result = Struct.new(...)`
- **Rules:** Under `BankReconciliation::Rules::`, define `Candidate` struct, `.call(txn, org)` → `Array<Candidate>`
- **Jobs:** `ApplicationJob`, `queue_as :default`, rescue → `mark_failed!`
- **Specs:** `spec/services/`, request specs in `spec/requests/api/v1/`, factories in `spec/factories.rb`
- **Models:** `include Auditable` where write actions happen, `scope :for_org`, status as string column with `STATUSES` array and `.each` predicates
- **Serializers:** `ActiveModel::Serializer` pattern, HAL-like `attributes` + `has_many`/`belongs_to`
