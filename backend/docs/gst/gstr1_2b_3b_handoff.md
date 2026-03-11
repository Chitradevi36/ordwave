# GST Return Engine — Handoff Documentation

## Overview

This document covers the complete GST return engine implemented across the following phases:
- GSTR-1 hardening (period awareness, snapshots, locking)
- GSTR-2B import, parsing, and matching
- GSTR-3B computation from books
- Reconciliation engine
- Financial year lifecycle management

---

## Architecture Summary

```
Gst::Support::FinancialYearResolver    → creates/finds FinancialYear per org
Gst::Support::ReturnPeriodResolver     → creates/finds GstReturnPeriod
Gst::Gstr1::Generator                  → orchestrates GSTR-1 + saves snapshot
Gst::Gstr1ExportService                → core GSTR-1 pipeline (unchanged)
Gst::Gstr2b::Parser                    → parses portal JSON into line hashes
Gst::Gstr2b::MatchingEngine            → reconciles lines vs PurchaseInvoices
Gst::Gstr2b::Importer                  → full 2B import flow (orchestrator)
Gst::Gstr3b::Builder                   → builds 3B tables from sales/purchase books
Gst::Reconciliation::Engine            → period-level reconciliation audit
```

---

## Domain Models

| Model | Table | Purpose |
|---|---|---|
| `FinancialYear` | `financial_years` | FY record, open/locked/closed/archived lifecycle |
| `GstReturnPeriod` | `gst_return_periods` | Monthly filing period per return type |
| `GstReturnSnapshot` | `gst_return_snapshots` | Immutable versioned snapshot of a computed return |
| `Gst2bImport` | `gst2b_imports` | GSTR-2B file import header |
| `Gst2bImportLine` | `gst2b_import_lines` | Individual invoice row from 2B |
| `GstReconciliationIssue` | `gst_reconciliation_issues` | Single compliance problem |

---

## API Endpoints

### Financial Years

| Method | Path | Description |
|---|---|---|
| `GET`  | `/api/v1/financial_years` | List all FYs for org |
| `GET`  | `/api/v1/financial_years/:id` | FY detail with periods |
| `POST` | `/api/v1/financial_years` | Find or create FY for month+year |
| `POST` | `/api/v1/financial_years/:id/lock_gst` | Lock GST for FY |
| `POST` | `/api/v1/financial_years/:id/close` | Close FY (checklist enforced) |
| `GET`  | `/api/v1/financial_years/:id/checklist` | Closing checklist |

### GST Return Periods

| Method | Path | Description |
|---|---|---|
| `GET`  | `/api/v1/compliance/gst_periods` | List periods (filterable) |
| `GET`  | `/api/v1/compliance/gst_periods/:id` | Period + snapshots |
| `POST` | `/api/v1/compliance/gst_periods/:id/lock` | Lock period |
| `POST` | `/api/v1/compliance/gst_periods/:id/file` | Mark as filed |
| `POST` | `/api/v1/compliance/gst_periods/:id/reopen` | Reopen locked/filed |

### GSTR-1

| Method | Path | Description |
|---|---|---|
| `GET`  | `/api/v1/compliance/gstr1/preview` | Human-readable preview |
| `GET`  | `/api/v1/compliance/gstr1/export`  | Portal JSON file download |
| `POST` | `/api/v1/compliance/gstr1/generate` | Period-aware generate + snapshot |

### GSTR-2B

| Method | Path | Description |
|---|---|---|
| `GET`  | `/api/v1/compliance/gstr2b/imports` | List imports |
| `POST` | `/api/v1/compliance/gstr2b/import`  | Upload + process 2B JSON |
| `GET`  | `/api/v1/compliance/gstr2b/imports/:id` | Import detail |
| `GET`  | `/api/v1/compliance/gstr2b/imports/:id/lines` | Paginated lines |

### GSTR-3B

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/v1/compliance/gstr3b/generate` | Compute 3B from books |
| `GET`  | `/api/v1/compliance/gstr3b/show`     | Latest 3B snapshot |

### Reconciliation

| Method | Path | Description |
|---|---|---|
| `GET`  | `/api/v1/compliance/reconciliation/issues` | List issues |
| `GET`  | `/api/v1/compliance/reconciliation/summary` | Severity+type summary |
| `POST` | `/api/v1/compliance/reconciliation/run` | Run engine for period |
| `POST` | `/api/v1/compliance/reconciliation/issues/:id/resolve` | Resolve issue |
| `POST` | `/api/v1/compliance/reconciliation/issues/:id/acknowledge` | Acknowledge |
| `POST` | `/api/v1/compliance/reconciliation/issues/:id/ignore` | Ignore with reason |

---

## GSTR-2B Import Flow

```
POST /api/v1/compliance/gstr2b/import
  ↓
Gst::Gstr2b::Importer
  ├─ Validate GSTIN + period
  ├─ Create Gst2bImport (status: uploaded)
  ├─ Check for duplicates (SHA256 of payload)
  ├─ Gst::Gstr2b::Parser.call(payload)
  │   ├─ Parse b2b, b2ba, cdn, cdna, isd, impg, impgsez sections
  │   └─ Returns normalized line hashes (match_status: 'pending')
  ├─ Bulk insert Gst2bImportLine records
  └─ Gst::Gstr2b::MatchingEngine.run!
      ├─ Tier 1: exact invoice number match (confidence 1.0)
      ├─ Tier 2: fuzzy normalized number (confidence 0.90)
      ├─ Tier 3: amount + date tolerance (confidence 0.70)
      ├─ Creates GstReconciliationIssue for tax_mismatch / missing_in_books
      └─ Marks Gst2bImport as completed
```

---

## GSTR-1 Period-Aware Flow

```
POST /api/v1/compliance/gstr1/generate
  ↓
Gst::Gstr1::Generator.call(org, month, year)
  ├─ Gst::Support::ReturnPeriodResolver → find_or_create GstReturnPeriod
  ├─ Guard: period already filed? → return error
  ├─ Gst::Gstr1ExportService.call(period_from, period_to)
  ├─ Compute source_hash (IDs + updated_at fingerprint)
  ├─ Create GstReturnSnapshot (section_key: 'full', version++)
  └─ GstReturnPeriod#mark_generated!(source_hash, error_count, warning_count)
```

---

## Reconciliation Issue Types

| issue_type | Severity | Description |
|---|---|---|
| `missing_in_2b` | medium/high | Purchase in books not found in portal |
| `missing_in_books` | medium/high | 2B line with no matching purchase |
| `tax_mismatch` | high | Tax amounts differ by > ₹1 |
| `date_mismatch` | medium | Invoice date differs by > 15 days |
| `gstin_mismatch` | high | GSTIN doesn't match between books and portal |
| `invoice_value_mismatch` | medium | Invoice values differ significantly |
| `duplicate_invoice` | blocking | Same invoice number appears multiple times |
| `invalid_hsn` | low | HSN code format invalid |
| `missing_gstin` | medium | Supplier GSTIN blank on purchase |
| `reverse_charge_mismatch` | high | RC flag differs |
| `itc_risk` | high | Supplier with pattern of 2+ mismatches |

---

## Period Locking Rules

1. A `GstReturnPeriod` must be `generated` before it can be `locked`
2. A period must be `locked` before it can be `filed`
3. Filed periods are **reopenable** (reason required, audit logged)
4. Filed snapshots are **immutable** — `GstReturnSnapshot.is_filed = true` cannot be changed
5. `FinancialYear#gst_locked?` is a soft advisory lock (does not block period reopening by default)

---

## Running the Test Suite

```bash
# All GST engine specs
bundle exec rspec spec/models/financial_year_spec.rb \
                   spec/models/gst_return_period_spec.rb \
                   spec/services/gst/ \
                   spec/requests/api/v1/compliance/gstr2b_spec.rb

# With coverage
COVERAGE=true bundle exec rspec spec/services/gst/
```

---

## Pending / Future Work

1. **GSTR-1 amendment flow** — `b2ba`, `cdna` section generation for amended invoices
2. **GSTR-1 nil/exempt section** — Surface NIL-rated and exempt invoices in `nil_exempt` section
3. **GSTR-2B CSV format** — `Gst::Gstr2b::Parser` currently only handles JSON; add CSV variant
4. **GSTR-9 annual return builder** — aggregates all 12 monthly GSTR-1/3B snapshots
5. **ITC ledger reconciliation** — Track ITC available vs claimed across periods
6. **Filing status webhook** — POST to GST portal filing status callback when period is filed
7. **Frontend pages** — GSTR-2B import UI, GSTR-3B preview, reconciliation issues dashboard
8. **Background job threshold** — `Gstr2bImportJob` enqueued for imports > 500 rows (currently inline)

---

## Key Files Added

```
backend/app/models/
  financial_year.rb
  gst_return_period.rb
  gst_return_snapshot.rb
  gst2b_import.rb
  gst2b_import_line.rb
  gst_reconciliation_issue.rb

backend/app/services/gst/
  support/financial_year_resolver.rb
  support/return_period_resolver.rb
  gstr1/generator.rb
  gstr2b/parser.rb
  gstr2b/matching_engine.rb
  gstr2b/importer.rb
  gstr3b/builder.rb
  reconciliation/engine.rb

backend/app/controllers/api/v1/
  financial_years_controller.rb
  compliance/gst_periods_controller.rb
  compliance/gstr2b_controller.rb
  compliance/gstr3b_controller.rb
  compliance/reconciliation_controller.rb

backend/app/jobs/gst/gstr2b_import_job.rb

backend/app/policies/
  financial_year_policy.rb
  gst_return_period_policy.rb
  gst2b_import_policy.rb

backend/db/migrate/
  20260311000010_create_financial_years.rb
  20260311000011_create_gst_return_periods.rb
  20260311000012_create_gst_return_snapshots.rb
  20260311000013_create_gst2b_imports.rb
  20260311000014_create_gst2b_import_lines.rb
  20260311000015_create_gst_reconciliation_issues.rb

backend/spec/
  factories/gst_factories.rb
  models/financial_year_spec.rb
  models/gst_return_period_spec.rb
  services/gst/support/financial_year_resolver_spec.rb
  services/gst/gstr2b/parser_spec.rb
  services/gst/gstr2b/matching_engine_spec.rb
  requests/api/v1/compliance/gstr2b_spec.rb

docs/gst/
  gstr1_review_report.md
  gst_return_engine_design.md
  financial_year_design.md
  gstr1_2b_3b_handoff.md        ← this file
```
