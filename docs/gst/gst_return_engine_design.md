# GST Return Engine — Architecture Design
**Version**: 1.0  
**Date**: March 11, 2026

---

## 1. Design Philosophy

The GST return engine is built on three principles:

1. **Immutability after filing** — once a return period is generated and filed, its data must never silently change. Computed snapshots are frozen records, not views over live invoices.
2. **Composable domain services** — each return type (GSTR-1, GSTR-2B, GSTR-3B) has its own builder namespace. The orchestration layer ties them to periods.
3. **Financial Year as canonical source** — all GST periods, accounting periods, and return groupings derive from a `FinancialYear` record. No ad-hoc date ranges in return logic.

---

## 2. Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         UI / API                            │
│  /compliance/gstr1   /compliance/gstr2b   /compliance/gstr3b│
└──────────────┬──────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────┐
│               Controller Layer (api/v1/gst/)                 │
│  FinancialYearsController   GstPeriodsController             │
│  Gstr1Controller  Gstr2bController  Gstr3bController         │
└──────────────┬──────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────┐
│              Orchestration / Domain Services                  │
│                                                              │
│  Gst::FinancialYears::Resolver                               │
│    └── resolves/creates FinancialYear for any date           │
│                                                              │
│  Gst::ReturnPeriods::Creator                                 │
│    └── ensures GstReturnPeriod exists for org+month+type     │
│                                                              │
│  Gst::Gstr1::Generator                (REPLACES ExportService)│
│    ├── pre-validate via Validator                            │
│    ├── classify via SectionClassifier                        │
│    ├── build via SummaryBuilder / JsonBuilder                │
│    └── freeze into GstReturnSnapshot                         │
│                                                              │
│  Gst::Gstr2b::Importer                                       │
│    ├── parse via Parser (JSON/CSV)                           │
│    ├── normalize into Gst2bImportLine                        │
│    └── match via MatchingEngine against PurchaseInvoice      │
│                                                              │
│  Gst::Gstr3b::Builder                                        │
│    ├── aggregate outward from GSTR-1 snapshot                │
│    ├── aggregate ITC from PurchaseInvoice + 2B import        │
│    └── freeze into GstReturnSnapshot                         │
│                                                              │
│  Gst::Reconciliation::Engine                                 │
│    ├── compare books outward vs GSTR-1 snapshot              │
│    ├── compare books ITC vs 2B imported ITC                  │
│    └── surface GstReconciliationIssue records                │
└──────────────┬──────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────┐
│                      Data Models                             │
│                                                              │
│  FinancialYear         GstReturnPeriod    GstReturnSnapshot  │
│  Gst2bImport           Gst2bImportLine    GstReconciliationIssue│
│  Gstr1ExportRecord (legacy — migrate to GstReturnPeriod)     │
│                                                              │
│  SalesInvoice   CreditNote   PurchaseInvoice   Supplier       │
│  Customer       Branch        Organization      HsnSacCode    │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Domain Objects

### 3.1 FinancialYear
The canonical fiscal period for an organization. All return periods must fall within a financial year.

- One active FY per organization at a time
- Default: April 1 → March 31 (India)
- Statuses: `open` → `locked` → `closed` → `archived`
- Locking GST (`gst_locked_at`) prevents new import/generation for past periods
- Locking books (`books_locked_at`) prevents invoice create/edit for the full year

### 3.2 GstReturnPeriod
A monthly GST filing slot for a specific return type (gstr1 / gstr3b / gstr2b_import).

Lifecycle: `draft` → `generated` → `reviewed` → `locked` → `filed`

Rules:
- Unique per `(organization_id, branch_id, financial_year_id, month, return_type)`
- Period boundaries derived from `FinancialYear`
- `locked?` blocks invoice editing for the period
- `filed?` is the final immutable state

### 3.3 GstReturnSnapshot
An immutable computed result for a return period. Multiple versions can exist before filing; only one filed version can exist.

- Never mutated after creation
- `section_key` identifies the GSTR-1 section (b2b, b2cl, b2cs, etc.) or GSTR-3B section (table3_1, table4, etc.)
- `source_hash` computed from input invoice IDs + amounts — detects drift
- `snapshot_hash` computed from payload — verifies integrity

### 3.4 Gst2bImport + Gst2bImportLine
Header + lines for a GSTR-2B file uploaded by user.

- `Gst2bImport` tracks the import job and its parse status
- `Gst2bImportLine` stores each invoice row with match status against books
- Match statuses: `matched / partial_match / multiple_candidates / missing_in_books / missing_in_2b / tax_mismatch / gstin_mismatch / date_mismatch / ignored`

### 3.5 GstReconciliationIssue
Tracks each identified discrepancy between books and portal data.

- Severity: `blocking / high / medium / low`
- Resolution: `open / acknowledged / resolved / ignored`
- Linked to a `GstReturnPeriod` for audit trail

---

## 4. GSTR-1 Generation Flow (New)

```
POST /api/gst/periods/:id/gstr1/generate
  │
  ├─► GstReturnPeriod.find_or_create (status: draft)
  │
  ├─► Gst::Gstr1::Generator.call(period)
  │     ├── fetch finalized invoices within period.period_start_on..period_end_on
  │     ├── run Validator → ValidationResult
  │     ├── run SectionClassifier on each invoice
  │     ├── SummaryBuilder → section summaries
  │     ├── JsonBuilder → portal JSON
  │     └── GstReturnSnapshot.create!(section_key: 'full', payload: ..., source_hash: ...)
  │
  ├─► period.update!(status: 'generated')
  │
  └─► render period + snapshot summary
```

---

## 5. GSTR-2B Import Flow

```
POST /api/gst/2b/imports
  │
  ├─► Gst2bImport.create!(status: 'uploading')
  │
  ├─► Gst::Gstr2b::ImportJob.perform_later(import.id)
  │     ├── Gst::Gstr2b::Parser.parse(file) → rows[]
  │     ├── normalize each row into Gst2bImportLine
  │     └── Gst::Gstr2b::MatchingEngine.run(import)
  │           ├── for each line: find matching PurchaseInvoice
  │           └── update line.match_status
  │
  └─► import.update!(status: 'completed')
```

---

## 6. GSTR-3B Computation Flow

```
POST /api/gst/periods/:id/gstr3b/generate
  │
  ├─► Require GSTR-1 snapshot exists for same period (outward data)
  ├─► Require GSTR-2B import exists for same period (ITC data)
  │
  ├─► Gst::Gstr3b::Builder.call(period)
  │     ├── table3_1: aggregate from GSTR-1 snapshot
  │     ├── table4: ITC from eligible PurchaseInvoice + 2B lines
  │     ├── table6: reverse charge liability
  │     └── GstReturnSnapshot.create!(section_key: 'gstr3b', ...)
  │
  └─► render 3B summary
```

---

## 7. Period Lock Rules

```
Period.locked? or Period.filed?
  └── SalesInvoice.immutable_when_gst_period_locked callback
        └── validates: invoice_date not in a locked period
        └── blocks create/update/void for that date range
  └── PurchaseInvoice.immutable_when_gst_period_locked callback
  └── CreditNote.immutable_when_gst_period_locked callback
```

Reopen flow:
- Only owner/admin can reopen a locked period
- Reopen creates `AuditLog` with reason
- Reopened period reverts to `generated` status
- Snapshot remains; new generation creates version N+1

---

## 8. Namespace Map

```
app/services/gst/
  support/
    financial_year_resolver.rb
    return_period_resolver.rb
    period_lock_checker.rb
  gstr1/
    generator.rb          ← replaces gstr1_export_service.rb orchestration
    validator.rb
    section_classifier.rb
    summary_builder.rb
    json_builder.rb
    nil_exempt_classifier.rb  ← NEW
  gstr2b/
    importer.rb
    parser.rb
    matching_engine.rb
    reconciliation_summarizer.rb
  gstr3b/
    builder.rb
    section_builder.rb    ← builds each 3B section
    variance_reporter.rb
  reconciliation/
    engine.rb
    issue_factory.rb

app/models/
  financial_year.rb
  gst_return_period.rb
  gst_return_snapshot.rb
  gst_reconciliation_issue.rb
  gst2b_import.rb
  gst2b_import_line.rb

app/controllers/api/v1/
  financial_years_controller.rb
  gst/
    periods_controller.rb
    gstr1_controller.rb   ← updated
    gstr2b_controller.rb  ← NEW
    gstr3b_controller.rb  ← NEW
    reconciliation_controller.rb ← NEW

app/policies/
  financial_year_policy.rb
  gst_return_period_policy.rb
  gst2b_import_policy.rb

app/jobs/
  gst/
    gstr2b_import_job.rb
    gstr3b_generate_job.rb
```

---

## 9. Response Format Standard

All GST engine responses follow this envelope:

```json
{
  "financial_year": { "code": "FY2025-26", "label": "2025-26", "status": "open" },
  "period": {
    "id": 1, "month": 3, "year": 2026, "return_type": "gstr1",
    "status": "generated", "period_start_on": "2026-03-01",
    "period_end_on": "2026-03-31", "display_name": "March 2026 — GSTR-1"
  },
  "summary": { ... },
  "validation": {
    "valid": true, "error_count": 0, "warning_count": 2,
    "errors": [], "warnings": [...]
  },
  "generated_at": "2026-03-11T14:30:00Z",
  "source_counts": { "invoices": 12, "credit_notes": 2 },
  "snapshot_id": 45
}
```
