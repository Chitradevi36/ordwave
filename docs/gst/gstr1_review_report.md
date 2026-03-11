# GSTR-1 Implementation Review Report
**Reviewed**: March 11, 2026  
**Reviewed by**: Automated Architecture Audit  
**Status**: Production-partial — working but missing production-grade hardening

---

## 1. Data Model Inventory

### What Exists

| Model | Key Fields | Notes |
|---|---|---|
| `SalesInvoice` | invoice_number, invoice_date, status, subtotal, tax_total, grand_total, irn, einvoice_status | Statuses: draft/issued/partially_paid/paid/void |
| `SalesInvoiceLine` | qty, unit_price, taxable_value, hsn_code, gst_rate, cgst_rate/amount, sgst_rate/amount, igst_rate/amount, tax_amount, cess_rate/amount | Full tax breakdown exists per line |
| `CreditNote` | credit_note_number, status(draft/issued/voided), subtotal, tax_total, total | No invoice reference field (applied_to_invoice_id exists) |
| `CreditNoteLine` | qty, unit_price, gst_rate, tax_amount, line_total, hsn_code | No explicit cgst/sgst/igst split on line (only total tax) |
| `PurchaseInvoice` | invoice_number, invoice_date, status(draft/posted/cancelled), supplier_gstin, place_of_supply, is_reverse_charge, rcm_tax_amount | Strong model |
| `PurchaseInvoiceLine` | qty, unit_price, tax_rate, tax_amount, line_total, hsn_sac_code_id | No explicit cgst/sgst/igst split |
| `Customer` | gstin, addresses (billing state) | Unique index on org+gstin |
| `Supplier` | gstin, name | Full GSTIN validation |
| `Branch` | state, state_code | state_code indexed |
| `Organization` | gst_number, state | GSTIN validated on model |
| `HsnSacCode` | code, gst_rate, cgst_rate, sgst_rate, igst_rate, cess_rate, cess_type | Full cess support exists |
| `EwaybillRequest` | from_state, to_state | Not connected to GST return |
| `SupplierDebitNote` | status, subtotal, tax_total, total | Not yet mapped to GSTR-1 |

### What is Missing

| Model | Status |
|---|---|
| `FinancialYear` | **MISSING** — no FY canonical source |
| `GstReturnPeriod` | **MISSING** — no period lifecycle tracking |
| `GstReturnSnapshot` | **MISSING** — no immutable snapshot |
| `GstReconciliationIssue` | **MISSING** — no issue tracking |
| `Gst2bImport` | **MISSING** — no 2B import |
| `Gst2bImportLine` | **MISSING** — no import line |

---

## 2. Existing GSTR-1 Sources

### Service Layer
- `Gst::Gstr1ExportService` — orchestrator, fetches invoices + credit notes, classifies, validates
- `Gst::Gstr1::SectionClassifier` — BFS section routing (B2B/B2CL/B2CS/CDNR/CDNUR)
- `Gst::Gstr1::SummaryBuilder` — human-readable preview hash
- `Gst::Gstr1::JsonBuilder` — GST portal upload JSON (fp, gstin, b2b, b2cl, b2cs, cdnr, cdnur, hsn, doc_issue)
- `Gst::Gstr1::Validator` — structural validation

### Controller
- `Api::V1::Compliance::Gstr1Controller#preview` — GET `/api/v1/compliance/gstr1/preview`
- `Api::V1::Compliance::Gstr1Controller#export` — GET `/api/v1/compliance/gstr1/export`
- `Api::V1::Compliance::Gstr1Controller#export_records` — GET `/api/v1/compliance/gstr1/export_records`

### UI
- `web/app/compliance/gstr1/page.tsx` — Full UI with B2B/B2C/CDNR/HSN tabs, summary cards, JSON download

### Invoice Statuses Included
- `issued`, `partially_paid`, `paid` ✅ All finalized statuses included

### Credit Note Statuses Included
- `issued` only — void and draft excluded ✅

---

## 3. Grouping Logic Review

| Section | Implemented | Notes |
|---|---|---|
| B2B | ✅ Grouped by customer GSTIN | Correct |
| B2CL | ✅ Inter-state unregistered > ₹2.5L | Correct |
| B2CS | ✅ All other unregistered | Aggregated by POS+rate+sply_ty |
| CDNR | ✅ Credit note to registered | Grouped by customer GSTIN |
| CDNUR | ✅ Credit note to unregistered | Aggregated totals |
| HSN Summary | ✅ Basic HSN aggregation | Works but misses UQC from prod |
| EXP | ❌ **MISSING** | No export invoice handling |
| NIL/Exempt | ❌ **MISSING** | Not classified or surfaced |
| Non-GST | ❌ **MISSING** | Not surfaced |
| Doc Summary | ✅ Basic document count in JSON | Incomplete |
| Amendments | ❌ **MISSING** | No amendment tracking |

---

## 4. Tax Computation Review

| Check | Status | Notes |
|---|---|---|
| Intra-state = CGST + SGST | ✅ | SalesInvoiceLine has explicit fields |
| Inter-state = IGST | ✅ | SalesInvoiceLine has explicit fields |
| HSN on every line | ⚠️ | `hsn_code` nullable on invoice line |
| Tax split on credit notes | ⚠️ | CreditNoteLine only has `tax_amount` total — no cgst/sgst/igst split |
| Discount treatment | ✅ | `taxable_value` stored post-discount |
| Round-off | ✅ | `round_off` field on invoice |
| Cess support | ✅ | cess_rate/amount on invoice lines, HsnSacCode master |
| Reverse charge flag | ✅ | `is_reverse_charge` + `rcm_tax_amount` on purchase invoice |
| Place of supply logic | ✅ | SectionClassifier handles GSTIN → address → branch fallback |
| GSTIN validation | ✅ | Regex validation on Supplier + Customer + Organization |
| Taxable value accuracy | ✅ | Stored per line |

### Critical Gaps
1. **CreditNoteLine missing cgst_amount/sgst_amount/igst_amount** — tax split is inferred at export time based on inter/intra state, not stored on line. Risk: wrong split if customer/branch changes after note issuance.
2. **HSN code nullable on sales invoice lines** — can submit portal JSON with missing HSN, which will fail GSTN validation.
3. **No place_of_supply field on SalesInvoice** — derived every time from customer GSTIN/address. OK for current flow but brittle.

---

## 5. Missing/Incomplete Flow Review

### 🔴 Missing — High Priority
| Item | Gap |
|---|---|
| Financial Year canonical source | No FY model. Period boundaries not enforced. |
| GstReturnPeriod lifecycle | No draft→generated→reviewed→locked→filed tracking |
| Snapshot/freeze mechanism | Exports are computed from mutable invoices each time. Filed returns can silently change if invoices mutate. |
| GST period lock | No lock on invoice create/edit after return filed |
| GSTR-2B import | No model, no parser, no matching engine |
| GSTR-3B builder | No 3B computation. UI shows "Coming Soon" |
| Reconciliation | No books vs 2B vs 3B comparison |
| Filing audit log | Only Gstr1ExportRecord saved — no status transitions logged |
| Amendment tracking | After filing, changed invoice creates amendment candidate. Not implemented. |

### 🟡 Weak — Medium Priority
| Item | Gap |
|---|---|
| NIL/exempt supply | Not classified, not exported, blank in return |
| EXP (export invoices) | Not handled |
| Customer GSTIN pre-validation | Validator checks format but not activeness |
| Duplicate invoice number within period | Not checked |
| HSN mandatory enforcement | Not enforced at export |
| POS stored on invoice | Derived dynamically — should be stamped at invoice issuance |
| Tax split on credit note lines | Only total stored — split inferred |
| Filing notes / CA workflow | Not present |
| Mismatch drilldown UI | Not present |
| GSTIN completeness check | Validator warns but export allows blank-GSTIN B2B |
| ITC risk badge | Not present |

### 🟢 Deferred — Low Priority
| Item | Notes |
|---|---|
| Composition scheme | Small distributors only; add later |
| SEZ supply | Add as EXP variant later |
| Deemed exports | FMCG distributors rarely need this |
| E-commerce operator TCS | Future |
| Annual return GSTR-9 | Post-filing aggregate |
| Direct API filing to GSTN | Infrastructure investment; keep UI export for now |

---

## 6. What is Strong

1. **SectionClassifier** — clean single-responsibility class, canonical STATE_CODE_MAP, correct B2CL threshold
2. **Invoice data model** — comprehensive line-level tax fields (cgst/sgst/igst amounts stored, cess support)
3. **JSON builder** — produces portal-compatible structure (fp, gstin, b2b, b2cl, b2cs, cdnr, cdnur, hsn, doc_issue)
4. **Validator** — warns on missing GSTIN, invalid HSN, date boundary issues
5. **UI** — tabs working, summary cards, auto-fetch, download working
6. **Audit record** — Gstr1ExportRecord captures section counts and totals

## 7. What is Risky

1. **No snapshot freeze** — filing a return, then editing an invoice for that period, will cause GSTR-1 preview to silently show different numbers than what was filed. **This is the highest compliance risk.**
2. **No period lock** — anyone can edit/void a settled invoice in a filed period
3. **Credit note tax split inferred at runtime** — if customer changes GSTIN after CN issuance, wrong tax appears in CDNR
4. **No 2B matching** — ITC discrepancy only discovered at assessment, not at month-end
5. **B2CS tally** — no deduplication check; if same unregistered customer has same-rate invoices across multiple sessions, aggregation depends solely on place_of_supply derivation, which can produce '00' with current data

---

## 8. Recommended Roadmap

### Now (Sprint 1)
1. FinancialYear model + migration + resolver service
2. GstReturnPeriod model + migration
3. GstReturnSnapshot model + migration (immutable)
4. GSTR-1 snapshot-based generation tied to GstReturnPeriod
5. Period lock + reopen API
6. GSTR-1 pre-validation hardening (NIL/exempt flag, HSN presence)

### Next (Sprint 2)
1. Gst2bImport + Gst2bImportLine models + migrations
2. GSTR-2B JSON parser (pluggable format)
3. Auto-match engine against purchase invoices
4. GstReconciliationIssue model
5. Reconciliation summary API

### After (Sprint 3)
1. GSTR-3B computation from books
2. 3B variance report (books vs 1 vs 2B)
3. Period closing checklist
4. CA review workflow tags (reviewed/approved/filed)
5. Amendment candidate tracker

---
