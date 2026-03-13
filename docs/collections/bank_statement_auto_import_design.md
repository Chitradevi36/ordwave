# Bank Statement Auto-Import — Design Document

> Status: **Implemented** | Last updated: June 2025

---

## 1. Overview

The Bank Statement Auto-Import feature lets finance users upload HDFC (or any standard) bank statements in CSV, XLSX, or PDF format. The backend automatically parses each row, deduplicates against the existing transaction ledger, runs a rule-based matcher, and either auto-posts high-confidence matches or queues them for human review.

---

## 2. Architecture

```
Upload (CSV / XLSX / PDF)
       │
       ▼
BankStatementImportsController#create
  ├─ detect_source_type(filename)
  ├─ BankStatementImport.create!  (status: uploaded)
  └─ ProcessBankStatementImportJob.perform_later(import_id)
                                         │
                         ┌─────────────────────────────┐
                         │   ProcessBankStatementImportJob │
                         │                             │
                         │  import.start_processing!   │
                         │         │                   │
                         │         ▼                   │
                         │  FileDispatcher             │
                         │  ├─ csv  → CsvImportService │
                         │  ├─ xlsx → XlsxImportService│
                         │  └─ pdf  → PdfImportService │
                         │         │                   │
                         │         ▼                   │
                         │  NarrationNormalizer        │
                         │  BankTransaction.create!    │
                         │  (idempotency dedup)        │
                         │         │                   │
                         │         ▼                   │
                         │  import.mark_completed!     │
                         │         │                   │
                         │         ▼                   │
                         │  Matcher.call(txn, org)     │
                         │  for each :unmatched txn    │
                         │         │                   │
                         │         ▼                   │
                         │  auto_post_matched (≥95)    │
                         │  → PostingService           │
                         └─────────────────────────────┘
```

---

## 3. Database Models

### `bank_accounts`

| Column                | Type    | Notes                          |
|-----------------------|---------|--------------------------------|
| `organization_id`     | bigint  | FK, not null                   |
| `branch_id`           | bigint  | FK, optional                   |
| `bank_name`           | string  | e.g. "HDFC Bank"               |
| `account_name`        | string  | Account holder display name    |
| `account_number_masked` | string | e.g. "••••4321"              |
| `account_number_full` | string  | Encrypted/full number          |
| `ifsc`                | string  | Validated regex `[A-Z]{4}0...` |
| `status`              | string  | `active` / `inactive`          |

### `bank_statement_imports`

| Column                | Type    | Notes                                |
|-----------------------|---------|--------------------------------------|
| `organization_id`     | bigint  | FK                                   |
| `bank_account_id`     | bigint  | FK                                   |
| `uploaded_by_id`      | bigint  | FK → users                           |
| `file_name`           | string  | Original filename                    |
| `source_type`         | string  | `csv` / `xlsx` / `pdf` / `manual`    |
| `status`              | string  | `uploaded` → `processing` → `completed` / `failed` |
| `rows_count`          | integer | Total rows in file                   |
| `new_rows_count`      | integer | Net-new transactions created         |
| `duplicate_rows_count`| integer | Rows skipped (idempotency hit)       |
| `failed_rows_count`   | integer | Rows that errored                    |
| `error_message`       | text    | Set on `failed` status               |

### `bank_transactions`

| Column                | Type    | Notes                                          |
|-----------------------|---------|------------------------------------------------|
| `organization_id`     | bigint  | FK                                             |
| `bank_account_id`     | bigint  | FK                                             |
| `bank_statement_import_id` | bigint | Nullable; null for manual entries        |
| `txn_date`            | date    | Transaction date                               |
| `amount`              | decimal | 15,2 precision                                 |
| `direction`           | string  | `credit` / `debit`                             |
| `utr_number`          | string  | UTR extracted from narration                   |
| `narration`           | text    | Raw bank narration                             |
| `normalized_narration`| text    | Lowercased, punctuation-stripped form          |
| `match_meta`          | jsonb   | `{invoice_numbers, customer_codes, utr_candidates, tokens}` |
| `status`              | string  | See lifecycle diagram below                    |
| `match_score`         | decimal | 0–100; confidence of best candidate            |
| `match_rule`          | string  | Rule code of winning candidate                 |
| `idempotency_key`     | string  | SHA256(bank_account_id, date, amount, ref, narration) — unique |

### `bank_transaction_matches` (candidates)

| Column             | Type    | Notes                               |
|--------------------|---------|-------------------------------------|
| `bank_transaction_id` | bigint | FK                               |
| `customer_id`      | bigint  | FK, optional                        |
| `sales_invoice_id` | bigint  | FK, optional                        |
| `score`            | decimal | Rule-assigned confidence 0–100      |
| `rule_code`        | string  | Identifies which rule fired         |
| `explanation`      | jsonb   | Debug/audit payload per rule        |
| `selected`         | boolean | True for the winning candidate      |

---

## 4. Transaction Status Lifecycle

```
uploaded
   │
   ▼ (job starts)
processing
   │
   ├──► completed
   │        │
   │   (per transaction)
   │        │
   │    unmatched ──► suggested (80–94) ──► matched (human confirms)
   │        │                                     │
   │        └──► auto_matched (≥95) ──────────────┘
   │                  │
   │           (PostingService)
   │                  │
   │              → Payment created
   │
   └──► failed (parse error / exception)
```

Transitions also support: `ignored`, `reversed`.

---

## 5. File Parsing

### CsvImportService
- Accepts a UTF-8 string (`csv_data:`)
- Uses `CSV.parse` with header detection
- Column mappings: `Date/Txn Date`, `Description/Narration`, `Credit/Received`, `Debit`, `Reference/UTR`

### XlsxImportService
- Uses `Roo::Spreadsheet` (`roo` gem ~> 2.10)
- Streams rows via `each_row_streaming`
- Supports `.xlsx` and `.xls` formats

### PdfImportService
- Uses `PDF::Reader` (`pdf-reader` gem ~> 2.12)
- **Text-based PDFs only** — scanned/image PDFs are not supported (returns a clear error)
- Heuristic: lines matching `DATE_PATTERN` AND containing an amount-like substring are parsed

All parsers produce a common `RowParser` output and return the standard `Result`:
```ruby
Result = Struct.new(:success?, :summary, :errors, keyword_init: true)
# summary: { new:, duplicates:, failed:, total: }
```

### Idempotency
Duplicate rows (same bank_account/date/amount/reference/narration combination) are silently skipped and counted in `duplicate_rows_count`. The unique DB index on `idempotency_key` provides a safety net.

---

## 6. Matching Rules

Rules are applied in priority order. The first rule scoring ≥ 95 ends the search (auto-match). Rules scoring 80–94 contribute candidates for human review.

| Order | Rule Class                      | Code                          | Max Score | Trigger                                    |
|-------|---------------------------------|-------------------------------|-----------|---------------------------------------------|
| 1     | `ExactInvoiceNumberRule`        | `exact_invoice_number`        | 100       | Invoice number token in narration           |
| 2     | `ExactRetailerCodeRule`         | `exact_retailer_code`         | 97        | Retailer/customer code in narration         |
| 3     | `ExactReferenceRule`            | `exact_reference`             | 98        | UTR seen in `ExpectedPaymentReference`      |
| 4     | `RetailerAliasAndAmountRule`    | `retailer_alias_and_amount`   | 85        | Alias name match + amount match             |
| 5     | `ExactAmountCustomerNameRule`   | `exact_amount_customer_name`  | 85        | Trade name tokens + amount match            |
| 6     | `MultiInvoiceSameCustomerRule`  | `multi_invoice_same_customer` | 88        | Two-to-four open invoices sum to amount     |
| 7     | `ExactAmountSingleOpenInvoiceRule` | `exact_amount_single_open`  | 90        | Unique single open invoice matches amount   |

### Confidence Bands

| Band    | Score Range | Action                              |
|---------|-------------|-------------------------------------|
| High    | ≥ 95        | `auto_matched` — PostingService runs automatically |
| Medium  | 80–94       | `suggested` — shown to finance user for review     |
| Low     | < 80        | `unmatched` — queued for manual reconciliation     |

---

## 7. Background Job

`ProcessBankStatementImportJob` (Sidekiq, queue: `default`)

1. Finds import; guards against re-processing completed/failed imports (idempotency)
2. Sets `Current.organization` for org-scoped queries
3. Calls `FileDispatcher` → parser → creates `BankTransaction` rows
4. Calls `mark_completed!` / `mark_failed!` on the import
5. Calls `Matcher.call(txn, org)` in `find_in_batches(100)` for all new `:unmatched` transactions
6. Auto-posts all `:auto_matched` transactions via `PostingService`

---

## 8. API Endpoints

| Method | Path                                          | Action                                |
|--------|-----------------------------------------------|---------------------------------------|
| GET    | `/api/v1/bank_accounts`                       | List active accounts for current org  |
| POST   | `/api/v1/bank_accounts`                       | Create a new bank account             |
| GET    | `/api/v1/bank_accounts/:id`                   | Show account details                  |
| PATCH  | `/api/v1/bank_accounts/:id`                   | Update account fields                 |
| GET    | `/api/v1/bank_statement_imports`              | List imports (paginated)              |
| POST   | `/api/v1/bank_statement_imports`              | Upload a file and enqueue processing  |
| GET    | `/api/v1/bank_statement_imports/:id`          | Show import status and row counts     |
| GET    | `/api/v1/bank_transactions`                   | List transactions (filterable by status, account) |
| GET    | `/api/v1/bank_transactions/:id`               | Show transaction with candidates      |
| GET    | `/api/v1/bank_transactions/dashboard`         | Aggregated stats by status for org    |
| POST   | `/api/v1/bank_transactions/:id/confirm_match` | Human confirms a suggested match      |
| POST   | `/api/v1/bank_transactions/:id/mark_as_advance` | Record as advance payment           |
| POST   | `/api/v1/bank_transactions/:id/ignore`        | Mark transaction as ignored           |
| POST   | `/api/v1/bank_transactions/:id/retry_match`   | Re-run matcher on a transaction       |

---

## 9. Authorization

All controllers extend `BaseController` and use Pundit:

- `policy_scope(BankAccount)` — restricts to `Current.organization`
- `authorize @import` on show/create
- Finance and owner roles have full access; read-only roles can index/show

---

## 10. Extension Points

### Adding a new matching rule
1. Create `app/services/bank_reconciliation/rules/your_rule.rb` implementing `#call(txn, org)` — returns array of `Candidate` structs
2. Append the class to the `RULES` array in `Matcher::RULES`
3. Return `[]` (not `nil`) if the rule finds no candidates

### Adding a new file format
1. Create `app/services/bank_reconciliation/your_format_import_service.rb`
2. Accept `(import:, blob_path:)` kwargs; return `Result`
3. Add a routing branch in `FileDispatcher#dispatch`
4. Add the format string to `BankStatementImport::SOURCE_TYPES`
5. Update `detect_source_type` in `BankStatementImportsController`
