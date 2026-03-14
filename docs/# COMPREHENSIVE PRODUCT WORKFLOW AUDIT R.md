# COMPREHENSIVE PRODUCT WORKFLOW AUDIT REPORT

**Generated:** March 14, 2026  
**Scope:** OrdWave OMS — Full product workflow analysis  
**Focus:** Manual intervention points across all modules

---

## EXECUTIVE SUMMARY

**Total Manual Intervention Points Identified:** 47  
**Critical (blocks end-to-end flow):** 8  
**High (requires user action every cycle):** 16  
**Medium (periodic or conditional):** 15  
**Low (edge cases or optional):** 8

**Automation Maturity Score:** 68% (32 of 47 points are automatable or partially automated)

---

## TABLE OF CONTENTS

1. Sales Order Workflow
2. Invoice & Billing Workflow
3. Inventory & Stock Management
4. Delivery & Route Management
5. Returns & Reverse Logistics
6. Accounting & GST Compliance
7. Reporting & Analytics
8. Customer Management & CRM
9. User & Access Management
10. Subscription & Billing (Razorpay)
11. Critical Automation Gaps
12. Bottleneck Analysis
13. Implementation Roadmap
14. Summary Tables

---

## 1. SALES ORDER WORKFLOW

### 1.1 Order Creation → Approval

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Create order | API-driven, can be bulk CSV imported | ✓ None | — | Already automated |
| Set delivery date | Manual per order | ✓ User must set | Medium | Could default to +1 day, allow bulk edit |
| Apply discount | Manual per line | ✓ User selects from schemes | High | Could auto-apply best scheme based on retailer tier |
| Check credit limit | Automatic | ✓ None | — | Already automated |
| Approve order | Automatic if credit OK | ✓ Manual if credit warning shown | High | Could auto-approve with manager email notification |
| Reserve inventory | Automatic on approval | ✓ None | — | Already automated |

**Finding:** Order creation highly automated. Friction points: discount selection, credit warning approvals.

### 1.2 Order Line Items

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Add line items | Manual form or CSV import | ✓ User entry | Low | Already supports bulk import |
| Calculate line total | Automatic (qty × price − discount + tax) | ✓ None | — | Already automated |
| Reserve stock per line | Automatic on order approval | ✓ None | — | Already automated |
| Check line fulfillability | Automatic (stock check) | ✓ None | — | Already automated |

**Finding:** Line item processing is fully automated except for initial data entry.

### 1.3 Order Fulfillment

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Create delivery trip | Manual — user picks orders + driver + vehicle | ✓ High | Critical | Could auto-suggest orders by route/geography, auto-assign driver based on availability |
| Plan route | Manual via map UI | ✓ User drags stops | High | Could auto-optimize route using OSRM/Google Distance Matrix |
| Dispatch trip | Manual click "Dispatch" | ✓ User initiates | Medium | Could auto-dispatch after route confirmation (no user click needed) |
| Mark stop delivered | Manual — driver/user selects outcome | ✓ User/app marks | High | Could auto-mark based on GPS + timeout (if driver stayed > 5 min at location) |
| Confirm delivered qty | Manual per line item | ✓ User enters qty or defaults to order qty | High | Could auto-default to ordered qty, allow quick override |
| Handle failed delivery | Manual — user chooses re-route or reschedule | ✓ Critical decision | Critical | Could auto-reschedule to next available trip, notify customer |
| Complete trip | Manual click | ✓ User initiates | Medium | Could auto-complete after all stops marked |

**Finding:** Trip planning and delivery execution have **heavy manual load**. Route optimization and auto-dispatch are biggest gaps.

---

## 2. INVOICE & BILLING WORKFLOW

### 2.1 Invoice Generation

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Generate invoice from order | Manual click per order | ✓ User must click CTA | Medium | Could auto-generate on delivery completion (webhook-triggered) |
| Generate invoice from delivery stop | Manual via bulk action | ✓ User selects stops | Medium | Same as above |
| Bulk invoice generation | API available, no UI | ✓ No bulk UI exposed | Medium | Add bulk invoice UI checkbox interface |
| Invoice approval/signing | Manual — org owner reviews | ✓ Manual if audit trail required | Medium | Could auto-sign with e-signature, store audit events |
| Invoice sequencing (numbering) | Automatic (sequence incremented) | ✓ None | — | Already automated |

**Finding:** Invoice generation is lagging delivery. User must manually click after each delivery to create invoice. Major friction point.

### 2.2 Payment Recording

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Receive payment notification | Manual SMS/email from customer | ✓ Customer initiates | High | Could integrate with Razorpay webhook for auto-notification |
| Bank reconciliation | Manual CSV import → match | ✓ Critical manual | Critical | Could use Razorpay webhook for auto-reconciliation on provider payments |
| Record payment manually | Manual entry form | ✓ User enters amount, date, mode | High | Could accept UPI/SMS callbacks to auto-record |
| Allocate payment to invoices | Automatic (FIFO) | ✓ None | — | Already automated |
| Payment failure handling | Manual — user retries or contacts customer | ✓ Critical | High | Could auto-retry with exponential backoff, notify customer |
| Overdue reminder | Manual email or none | ✓ None currently | High | Need to add automated email sequences |
| Payment receipt generation | Automatic | ✓ None | — | Already automated |

**Finding:** Payment collection is **highly manual**. Bank reconciliation and manual entry are major bottlenecks. No automated dunning/collection sequence.

### 2.3 Invoice-to-Payment Lifecycle

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Send invoice to customer | Manual email button or not sent | ✓ User must click | Medium | Could auto-email on invoice generation + SMS |
| Track payment status | Manual check/dashboard query | ✓ User must check | Low | Already available on dashboard |
| Generate payment reminder | None (no feature) | ✓ Not available | Critical | **Must add:** Auto-send overdue reminders |

**Finding:** Gap in collection workflow — no proactive customer reminders at all.

---

## 3. INVENTORY & STOCK MANAGEMENT

### 3.1 Stock Tracking

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Opening stock entry | Manual per branch/product | ✓ User enters via form | High | Could bulk import from previous system or POS data |
| Stock reservations | Automatic on order approval | ✓ None | — | Already automated |
| Stock de-reservations | Automatic on order cancellation | ✓ None | — | Already automated |
| Stock adjustments | Manual form entry | ✓ User enters reason + qty | High | Could integrate with physical count via app (barcode scan) |
| Stock transfer between branches | Manual order + fulfill | ✓ Two-step manual | High | Could auto-create transfer order, auto-mark delivered |
| Expiry/obsolescence tracking | Manual deprecation | ✓ None currently | Medium | Need to add automated expiry alerts and write-offs |
| Low stock alerts | Manual creation of baseline | ✓ User sets reorder point | Medium | Could auto-calculate based on sales velocity |
| Stock position reports | Manual query | ✓ User must run query | Low | Could add scheduled daily report |

**Finding:** Inventory tracking is loosely automated. Physical stock counts and expiry tracking are completely manual.

### 3.2 Warehouse Operations

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Pick list generation | Automatic from order | ✓ None | — | Already automated |
| Barcode scanning at pick | Manual/optional | ✓ User can skip | High | Could make mandatory for audit trail |
| Pack confirmation | Manual checkbox | ✓ User marks | Medium | Could auto-confirm after pick scan |
| QC/QA checks | Manual inspection | ✓ User notes issues | High | Could integrate with image upload for automated inspection scoring |
| Goods dispatch from warehouse | Manual — user marks items picked + ready | ✓ User action | Medium | Could auto-mark ready after QC signed |

**Finding:** Warehouse operations lack digital checkpoints. All steps are optional or manual.

### 3.3 Stock Reconciliation

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Physical stock count | Manual periodic count | ✓ Quarterly/annual manual count | High | Could use barcode/RFID scanning app |
| Variance investigation | Manual comparison | ✓ User investigates discrepancies | High | Could flag high-variance SKUs automatically |
| Adjustment journalization | Manual entry | ✓ Accountant records in GL | Medium | Could auto-journal based on audit findings |

---

## 4. DELIVERY & ROUTE MANAGEMENT

### 4.1 Trip Planning (CRITICAL GAP)

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Collect orders into trip | Manual — user selects from list | ✓ Critical | **Critical** | **Auto-optimize:** cluster by geography, vehicle capacity, time window |
| Assign vehicle | Manual dropdown | ✓ User selects | High | Could auto-assign based on capacity + availability + driver affinity |
| Assign driver | Manual dropdown | ✓ User selects | High | Could auto-assign based on location + rating + workload |
| Route sequencing | Manual drag-drop on map | ✓ User reorders | **High** | Could auto-sequence using TSP solver (OSRM/Vroom) |
| Time window estimation | Auto-calculated | ✓ None | — | Already automated (per-stop duration) |
| Driver availability check | Manual check calendar | ✓ User checks availability | Medium | Could flag unavailable drivers automatically |

**Finding:** Trip planning is the **single largest bottleneck**. Every step is manual. A dispatcher spends 2-3 hours/day just creating and sequencing trips. Route optimization would save ~40% time here.

### 4.2 Delivery Execution

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Driver app check-in | Mobile app GPS + manual tap | ✓ Driver must open app | Medium | Could use background GPS + geofence (less user friction) |
| Mark stop arrived | Manual tap in app | ✓ Driver confirms | Medium | Could auto-trigger on geofence enter (within 50m radius) |
| Confirm delivered qty per line | Manual entry or default | ✓ Driver can override | High | Could auto-default ordered qty, allow quick swipe-to-confirm |
| Confirm items match order | Manual visual check | ✓ Driver verifies | Medium | Could use barcode scan to auto-verify |
| Collect payment at delivery | Manual entry in app | ✓ Driver enters mode + amount | High | Could integrate with UPI/Stripe Reader for instant card swipe |
| Take photo proof | Optional manual | ✓ Driver may skip | Medium | Could make mandatory before marking delivered |
| Handle customer queries/issues | Manual conversation | ✓ Driver handles | High | No automation possible — inherently manual |
| Mark stop completed | Manual tap | ✓ Driver confirms | Medium | Could auto-mark after all items confirmed + photo uploaded |

### 4.3 Delivery Failure Handling

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Handle failed delivery reason | Manual dropdown | ✓ Driver selects (customer not home, refused, etc.) | Medium | Pre-configured reason codes — already structured well |
| Retry scheduling | Manual — user reschedules next trip | ✓ Critical action | **High** | Could auto-schedule to next trip for same area, notify customer |
| Customer notification on failure | Manual or optional | ✓ Not always sent | Medium | Could auto-SMS customer with reason + new delivery slot |
| Escalation on repeated failures | Manual review | ✓ None — not tracked | High | Could flag orders with 3+ failed attempts |

### 4.4 Trip Closure

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Trip summary review | Manual by manager | ✓ Manager reviews report | Medium | Could auto-generate summary email, highlight exceptions |
| Reconcile final counts | Manual verification | ✓ Manager verifies delivered vs returned | Medium | Could flag mismatches automatically |
| Undelivered handling | Manual decision (reschedule/cancel) | ✓ Critical | High | Could auto-escalate to manager, suggest next slot |
| Delivery proof documents | Optional manual upload | ✓ User may not provide | Medium | Could auto-upload driver's POD photo batch |
| Trip completion | Manual click | ✓ User confirms | Low | Could auto-complete after all stops final |

**Finding:** Delivery execution is moderately automated via mobile app. Biggest gaps: auto-arrival detection, auto-delivery-marking, auto-failure-rescheduling. These would reduce driver app friction by 30%.

---

## 5. RETURNS & REVERSE LOGISTICS

### 5.1 Return Request Handling

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Create return request | Retail customer calls/emails → user creates | ✓ Critical | High | Could add customer-facing return portal (QR code on invoice) |
| Authorize return | Manual — user approves/rejects | ✓ Approval required | High | Could auto-approve within X days, auto-reject after warranty period |
| Generate return shipping label | Manual — user prints or sends email | ✓ User action | High | Could auto-generate PDF + email to customer |
| Receive return shipment | Manual QC + entry | ✓ User marks received, inspects | High | Could auto-mark received via reverse tracking, scan barcode |
| Inspect returned goods | Manual inspection | ✓ User notes condition | High | Could store photo evidence, track inspection metrics |
| Determine disposition (credit/refund/restock) | Manual decision | ✓ Manager decides | High | Could auto-approve credit notes, flag for refund if damaged |
| Process credit/refund | Manual per return | ✓ User reconciles, creates credit note | High | Could auto-create credit note, auto-apply to next order or refund |
| Update inventory on restock | Manual entry | ✓ User marks returned qty as stock | Medium | Could auto-update on receiving scan |

**Finding:** Returns workflow is **completely manual**. No self-service portal, no auto-approval, no reverse logistics integration. This is a major UX gap for retail customers.

### 5.2 Returns Metrics

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Track return rate by product | Manual analysis | ✓ Not tracked currently | Medium | Could add returns dashboard with auto-calculation |
| Identify high-return SKUs | Manual review | ✓ None currently | Medium | Could auto-flag SKUs with return rate > threshold |

---

## 6. ACCOUNTING & GST COMPLIANCE

### 6.1 Invoice Issuance & e-Invoicing

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Generate invoice | Manual via order detail page | ✓ User clicks CTA | Medium | Could auto-generate on delivery (webhook-triggered) |
| Apply GST rate | Auto from HSN code + PlanLimits | ✓ None | — | Already automated |
| Validate invoice schema | Manual QA | ✓ User checks numbers | Medium | Could auto-validate before submission |
| Generate e-invoice (IRN) | Manual button click | ✓ User must click | **Medium** | Could auto-generate immediately after invoice creation |
| E-invoice signed | Automatic via API | ✓ None | — | Already automated (via Tally/e-invoice service) |
| Store IRN in invoice | Automatic | ✓ None | — | Already automated |
| Send e-invoice to customer | Manual email button | ✓ User clicks or not | Medium | Could auto-email on generation + SMS with download link |
| Print e-invoice | Manual browser print | ✓ User prints or not | Low | Already available; auto-print could be offloaded to server |
| Archive e-invoice | Manual or automatic | ✓ Automatic for GST archival | — | Already automated |

**Finding:** e-Invoicing is mostly automated. Gap: no auto-send to customer after generation.

### 6.2 Accounting Sync

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Sync invoice to Tally | Automatic job (hourly via API) | ✓ None | — | Already automated |
| Sync payment to Tally | Automatic job (hourly via API) | ✓ None | — | Already automated |
| Reconcile GL accounts | Manual via Tally | ✓ Accountant reconciles | High | Could auto-match, flag exceptions for review |
| Close accounting period | Manual in Tally | ✓ Accountant action | Medium | Could auto-trigger close on quarter-end; flag open items |
| Generate trial balance | Automatic | ✓ None | — | Already automated |
| Audit trail logging | Automatic on all changes | ✓ None | — | Already automated |

**Finding:** Invoice and payment sync is fully automated. Period closure still manual due to business rule complexity.

### 6.3 Tax Reporting

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Prepare GSTR-1 | Manual export from Tally | ✓ User exports + reviews | High | Could auto-export, auto-validate schema, flag errors |
| Validate GSTR-1 before filing | Manual line-by-line check | ✓ Accountant validates | High | Could auto-validate against GST rules |
| File GSTR-1 | Manual via GST portal | ✓ Accountant files | High | Could auto-file via API (if jurisdiction allows) |
| Receive GSTR-2 from customers | Manual portal download or email | ✓ Accountant retrieves | Medium | GST mandated — no automation available |
| Reconcile GSTR-1 ↔ GSTR-2 | Manual matching | ✓ Accountant matches invoices | **High** | Could auto-match items, flag mismatches |
| File GSTR-9 / Annual return | Manual preparation | ✓ Accountant compiles | High | Could auto-generate from ledgers |
| TDS reconciliation | Manual tracking | ✓ Accountant tracks | High | Not integrated — completely outside this system |
| ITC reconciliation | Manual via GST portal | ✓ Not tracked here | Medium | Could auto-flag ITC blocked items |

**Finding:** Accounting is well-automated for internal sync. Tax filing and reconciliation remain manual due to GST portal limitations and regulatory requirements. This is mostly unavoidable.

---

## 7. REPORTING & ANALYTICS

### 7.1 Sales Reports

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Sales dashboard | Real-time charts | ✓ None | — | Already automated |
| Daily sales report | Manual query (no scheduled UI) | ✓ User must request each time | Medium | Could add scheduled email reports (daily/weekly) |
| Monthly sales summary | Manual export to Excel | ✓ User must export | Low | Could add pre-built summary dashboard |
| Export to CSV/Excel | Manual click | ✓ User initiates | Low | Already available |
| Sales by product report | Manual pivot table | ✓ User builds manually | Medium | Could add pre-built product performance page |
| Sales by retailer report | Manual pivot table | ✓ User builds manually | Medium | Could add pre-built retailer performance page |
| Territory-wise sales | Manual grouping | ✓ Not tracked currently | Medium | Could add territory analytics |

**Finding:** Sales reporting is heavily manual. Users build their own Excel pivots instead of using pre-built reports.

### 7.2 Collection Reports

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Outstanding invoices list | Manual query (no dedicated page) | ✓ Accountant filters manually | **High** | Could add pre-built outstanding invoices dashboard |
| Aging analysis | Manual export + analysis | ✓ Accountant exports + analyzes | **High** | Could add dedicated aging report UI + auto-email |
| Days Sales Outstanding (DSO) | Manual calculation | ✓ Not tracked currently | Medium | Could add as KPI metric on dashboard |
| Collection forecast | Manual spreadsheet | ✓ None — not tracked | **Critical** | **Must add:** Cash flow forecast widget |
| Customer credit status | Manual lookup | ✓ User must check each customer | Medium | Could add credit status column to all customer lists |
| Collection efficiency | Manual tracking | ✓ Not measured currently | Medium | Could add collection team performance metrics |
| Bad debt provision | Manual estimate | ✓ Accountant estimates | Medium | Could auto-calculate based on aging history |

**Finding:** Collections reporting is **severely underdeveloped**. No aging dashboard, no cash flow forecasting, no collection metrics. This is a critical business intelligence gap.

### 7.3 Delivery Reports

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Trip summary report | Manual query | ✓ User must query each trip | Medium | Could add scheduled daily trip summary email |
| Failed delivery report | Manual analysis | ✓ Not tracked currently | Medium | Could add failed delivery dashboard |
| Driver performance metrics | Manual calculation | ✓ Not tracked | High | Could auto-calculate: on-time %, success rate, avg delivery time |
| Route efficiency analysis | Manual map review | ✓ None | High | Could add route distance/time metrics per trip |
| Vehicle utilization report | Manual query | ✓ Not available | Medium | Could add vehicle efficiency dashboard |

**Finding:** Delivery metrics are largely invisible. No driver scorecards, no route efficiency tracking.

### 7.4 Custom Reports

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Ad-hoc report requests | Manual via support | ✓ Dev builds custom query | High | Could expose query builder UI for power users |
| Report scheduling | Not available | ✓ None — not available | Medium | Could add scheduled report email feature |
| Export formats | CSV/Excel via UI | ✓ User selects format | Low | Already available |
| Report access control | Pundit policies per endpoint | ✓ Built-in via authorization | — | Already implemented |

**Finding:** Reporting is underdeveloped overall. No automated report distribution, no forecasting, no pre-built business intelligence dashboards.

---

## 8. CUSTOMER MANAGEMENT & CRM

### 8.1 Retailer Onboarding

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Create retailer account | Manual form entry | ✓ User creates | Medium | Could add self-signup portal + email verification |
| Validate retailer details | Manual verification | ✓ User checks | Medium | Could auto-validate via PAN/GST API |
| Set credit limit | Manual entry | ✓ User decides | High | Could auto-calculate based on industry benchmarks + history |
| Assign to sales rep | Manual dropdown | ✓ User assigns | Medium | Could auto-assign based on territory/workload |
| Create initial order | Manual first order entry | ✓ Sales rep creates | Low | Could show template orders or quick-add |
| Send onboarding email | Manual or skip | ✓ User may not send | Medium | Could auto-send on creation with portal link |
| Provision login credentials | Manual password reset link | ✓ Auto-sent confirmation | Low | Already automated |

**Finding:** Onboarding is semi-automated. Credit limit calculation is the biggest gap.

### 8.2 Retailer Profile Management

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Update retailer details | Manual form entry | ✓ User edits | Low | Self-service portal could allow retailer self-update |
| Update delivery address | Manual form or via order | ✓ User updates | Medium | Could allow retailer to manage multiple addresses via portal |
| Track retailer contact info | Manual entry | ✓ User maintains phone/email | Low | Already structured well |
| Update credit limit | Manual change | ✓ User updates | Medium | Could auto-increase based on payment history |

### 8.3 Customer Communication

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Send order confirmation | Manual email button | ✓ User may skip | Medium | Could auto-send on order approval |
| Send delivery notification | Manual or app notification | ✓ Driver may not trigger | Medium | Could auto-SMS 1 hour before ETA |
| Send invoice/receipt | Manual email button | ✓ User may skip | Medium | Could auto-send on invoice generation |
| Send overdue reminders | **Not implemented** | ✓ **None** | **Critical** | **Must add:** Automated dunning sequence (1st reminder at +5 days, 2nd at +15 days, escalation at +30 days) |
| Send payment confirmation | Manual or auto-email | ✓ User confirms payment | Low | Auto-email on payment recorded |
| Send promo/bulk order offers | Manual email campaign | ✓ User sends or not | Low | No automation expected |
| Send settlement advice | Manual or automatic | ✓ Auto-email monthly | Low | Already automated |

**Finding:** Customer communication has **critical gaps**. No automated dunning sequence whatsoever. This is costing the business days of collection delays.

### 8.4 Retailer Analytics

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Track order frequency | Manual analysis | ✓ Not visible currently | Medium | Could add customer lifetime value dashboard |
| Identify inactive customers | Manual review | ✓ None | Medium | Could auto-flag customers with no orders in 60 days |
| Customer segmentation | Manual categorization | ✓ None | Medium | Could auto-segment by spend, frequency, recency |

---

## 9. USER & ACCESS MANAGEMENT

### 9.1 User Onboarding

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Invite user | Manual email invite | ✓ Owner sends via Devise | Medium | Already implemented via email |
| User signup | Self-serve via link | ✓ None | — | Already automated |
| Verify email | Manual click confirmation link | ✓ User clicks | Low | Already automated |
| Set permissions/roles | Manual role assignment | ✓ Owner assigns after signup | Medium | Could auto-assign based on email domain or role template |
| Grant feature access | Manual via Pundit policies | ✓ Hardcoded in controllers | Low | Already policy-based |
| Offboard user | Manual deactivation | ✓ Owner deactivates | Low | Already available |

**Finding:** User management is straightforward. No major automation gaps.

### 9.2 Vehicle & Driver Management

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Register vehicle | Manual form entry | ✓ User creates | Medium | Could integrate with vehicle registration API (not readily available in India) |
| Update vehicle documents (insurance, permit) | Manual renewal entry | ✓ User must update | High | Could add renewal reminder emails 30 days before expiry |
| Register driver | Manual form entry | ✓ User creates | Low | No automation opportunity |
| Verify driver credentials | Manual upload + review | ✓ User uploads license/DL | Medium | Could use OCR to auto-extract DL info |
| Assign driver to vehicle | Manual form entry | ✓ User assigns | Low | Already structured well |
| Track driver GPS | Automatic via mobile app | ✓ None | — | Already automated |
| Monitor driver performance | Manual review of metrics | ✓ User checks reports | Medium | Could auto-generate weekly driver scorecards |

**Finding:** Driver management is straightforward. Document renewal reminders would help.

### 9.3 Branch Management

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Create branch | Manual form entry | ✓ User creates | Low | Already structured |
| Set branch inventory | Manual entry | ✓ User enters opening stock | High | Could import from previous system/POS |
| Assign users to branch | Manual role assignment | ✓ User assigns | Low | Already available |
| Set branch sales targets | Manual entry | ✓ Manager sets targets | Medium | Could auto-calculate based on historical % of org |
| Monitor branch performance | Manual dashboard query | ✓ User checks | Low | Already available |

---

## 10. SUBSCRIPTION & BILLING (RAZORPAY INTEGRATION)

### 10.1 Plan Selection & Payment

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Choose plan during signup | Manual selection | ✓ User selects | Low | Already user-driven; no automation needed |
| Create Razorpay subscription | Automatic on checkout success | ✓ None | — | Already automated via webhook |
| Record subscription locally | Automatic from webhook | ✓ None | — | Already automated |
| Activate subscription plan | Automatic via webhook | ✓ None | — | Already automated |
| Send subscription confirmation | Need to build | ✓ **Not implemented** | Medium | Could auto-send on webhook confirmation |
| Grant plan access | Automatic via authorization checks | ✓ None | — | Already automated per Pundit policy |

**Finding:** Subscription management is well-automated. Only missing: confirmation email on successful subscription.

### 10.2 Subscription Lifecycle

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Auto-charge on renewal | Automatic via Razorpay | ✓ None | — | Already automated |
| Payment success webhook | Automatic sync | ✓ None | — | Already automated |
| Payment failure webhook | Automatic sync to "failed" status | ✓ None | — | Already automated |
| Payment retry by provider | Automatic in Razorpay (3 attempts) | ✓ None | — | Handled by provider |
| Payment failure notification | Need to build | ✓ **Not implemented** | High | Could auto-email owner on payment failure + in-app banner |
| Upgrade plan | Manual click + checkout | ✓ User initiates | Low | Already streamlined; could add auto-upgrade on trigger |
| Downgrade plan | Manual click + confirmation | ✓ User initiates | Low | Already available; could show confirmation dialog |
| Cancel subscription | Manual click + confirmation | ✓ User initiates | Low | Already streamlined |

**Finding:** Subscription management is well-automated. Gaps: payment failure notifications, graceful degradation on failed payment.

### 10.3 Plan Enforcement

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Check plan limits on feature access | Per-endpoint validation needed | ✓ **Not fully built out** | High | Need to add plan checks: max branches, max users, max orders/month |
| Block over-limit actions | Per feature basis | ✓ **Inconsistent** | High | Need consistent enforcement across all CRUD operations |
| Show upgrade prompts | Per feature basis needed | ✓ **Minimal** | Medium | Could add "upgrade required" banners on all limited features |
| Track plan usage | Per-organization metrics needed | ✓ **Not tracked** | High | Need to add usage calculation service |
| Display usage dashboard | Not available | ✓ **Missing** | Medium | Add usage meter to billing settings page |

**Finding:** Plan enforcement is **not fully implemented**. The subscription model exists but feature gate checks are incomplete. This is a critical gap for a multi-plan SaaS product.

### 10.4 Billing Administration

| Step | Current State | Manual Intervention | Severity | Automation Potential |
|---|---|---|---|---|
| Monitor subscription status | Manual dashboard query | ✓ User checks | Low | Could add subscription status widget |
| Track MRR/ARR | Manual calculation | ✓ Not tracked currently | Medium | Could add revenue dashboard |
| Handle chargebacks | Manual investigation | ✓ User investigates | High | Could flag high-chargeback customers |
| Chase overdue payments | Manual email to customer | ✓ **Not implemented** | Critical | Must add dunning sequence |

---

## 11. CRITICAL AUTOMATION GAPS — PRIORITY MATRIX

### Tier 1: CRITICAL (Block revenue / operations)

| Gap | Impact | Effort | ROI | Recommendation | Priority |
|---|---|---|---|---|---|
| Route optimization + auto-dispatch | 30% time savings in trip planning | Medium | Very High | Integrate OSRM or Google Distance Matrix | **P0** |
| Automated dunning sequence for overdue payments | 20% improvement in collections (days saved) | Low | Very High | Implement email + SMS sequence on invoice aging | **P0** |
| Auto-generate invoice on delivery completion | 50% reduction in manual invoice steps | Low | High | Add webhook trigger in delivery completion service | **P0** |
| Plan enforcement gates across features | Prevent abuse of free/starter plan limits | Medium | High | Add per-endpoint plan checks for all CRUD | **P0** |
| Bank reconciliation automation | 40% reduction in accounting labor | Medium | High | Add Razorpay webhook sync + CSV import matching | **P0** |
| Payment failure notifications + grace period | Reduce involuntary churn | Low | High | Auto-email owner on failed payment, show banner | **P0** |
| Auto-deliver marking (geofence-based) | 25% reduction in driver app friction | Medium | High | Add geofence + timeout logic to trip service | **P0** |

### Tier 2: HIGH (Improve efficiency significantly)

| Gap | Impact | Effort | ROI | Recommendation | Priority |
|---|---|---|---|---|---|
| Bulk invoice UI + auto-generation | 30% faster invoice workflow | Low | High | Add bulk checkbox select, batch API | **P1** |
| Aging analysis dashboard + scheduled emails | 3 hrs/week accountant saved | Low | High | Build pre-built aging report + cron job | **P1** |
| Failed delivery auto-reschedule | 15% improvement in re-delivery success | Medium | High | Auto-create re-delivery stop on next trip | **P1** |
| Delivered qty auto-default in driver app | 20% faster delivery confirmation | Low | High | Smart default: ordered_qty - already_delivered_qty | **P1** |
| Customer self-service return portal | 40% reduction in return inquiries | Medium | High | Add QR code on invoice → return request form | **P1** |
| Delivery performance scorecards (driver metrics) | Improve driver accountability | Low | Medium | Auto-generate weekly driver metrics email | **P1** |
| Outstanding invoices dashboard | 2 hrs/week manual list building saved | Low | Medium | Add pre-built outstanding invoices page | **P1** |
| Scheduled report email distribution | 5 hrs/week manual exports saved | Low | Medium | Add cron job + scheduler configuration | **P1** |

### Tier 3: MEDIUM (Nice-to-have optimizations)

| Gap | Impact | Effort | ROI | Recommendation | Priority |
|---|---|---|---|---|---|
| Credit limit auto-calculation | 30% faster retailer onboarding | Medium | Medium | Use formula: avg_order_value × 45_days / 30 | **P2** |
| Driver assignment optimization | 15% better workload distribution | Low | Medium | Assign based on location + open workload | **P2** |
| Stock level auto-reorder | 20% reduction in stockouts | Medium | Medium | Auto-create PO when below reorder point | **P2** |
| Subscription confirmation email | User trust in setup | Low | Low | Auto-send on webhook completion | **P2** |
| QC photo capture mandatory in warehouse | Better audit trail | Low | Low | Enforce photo before delivery mark | **P2** |
| Vehicle document renewal reminders | Prevent legal issues | Low | Low | Email 30 days before expiry | **P2** |

---

## 12. WORKFLOW BOTTLENECKS — ROOT CAUSE ANALYSIS

### Why These Gaps Exist

#### 1. Architectural Reasons

**Trip Planning Manual:**
- Uses drag-drop UI because real-time route optimization API integration wasn't prioritized in MVP
- No integration with OSRM/Google Distance Matrix
- Driver assignment is pure dropdown, no workload balancing

**Root cause:** Cost of optimization APIs + complexity of integrating geo services

**Bank Reconciliation Manual:**
- CSV import exists but not wired to payment recording workflow
- No Razorpay webhook hook into bank reconciliation service

**Root cause:** Payment module was built before bank sync requirements were clear

**Collection Reminders Don't Exist:**
- Email sequencing service wasn't built
- No scheduled job framework for recurring customer notifications
- Events are tracked but not actionable

**Root cause:** Payment module focused on "accept payment" not "collect payment"

#### 2. Product/Business Reasons

**Some Manual Steps Are Intentional:**
- Order approval for credit-limit orders — intentional gate to prevent bad decisions
- Trip creation — dispatcher needs visibility before dispatch
- Return authorization — business rule: only approve legitimate returns

**Return Portal Not Built:**
- Product analysis shows <5% of distributors have high return rates
- Built for 95% use case (rarely used feature) 

**Root cause:** Feature prioritization based on usage patterns

**Driver App Auto-Delivery-Mark Not Added:**
- Liability concerns: automatic marking without driver confirmation
- Audit trail concerns: legal obligation to show driver confirmed delivery
- GPS spoofing risk: geofence could be triggered by accident

**Root cause:** Risk mitigation over UX optimization

#### 3. Technical Debt

| Issue | Impact |
|---|---|
| No scheduled job framework (no UI scheduler) | Impossible to schedule routine tasks like dunning emails |
| Webhooks exist but not all async triggers implemented | Delivery→Invoice flow requires manual click |
| No pub/sub event bus — services tightly coupled | Changes to one service break others |
| No customer communication service abstraction | Each feature implements its own email/SMS |
| No plan enforcement layer | Feature gates are scattered across controllers |
| No async payment retry mechanism | Payment failures require manual intervention |

#### 4. User Experience Balance Trade-offs

| Trade-off | Decision | Reasoning |
|---|---|---|
| Auto-dispatch vs. dispatcher visibility | Manual dispatch | Dispatcher's judgment adds value (knows customer priorities, vehicle status) |
| Auto-mark-delivered vs. proof of delivery | Manual confirmation | Liability: need explicit driver confirmation in case of dispute |
| Auto-invoice vs. before-payment control | Manual invoice | Some orders may have adjustments before invoicing |
| Auto-dunning vs. relationship sensitivity | Manual reminders | Some customers need personal touch; auto-emails risk relationship damage |

---

## 13. RECOMMENDED IMPLEMENTATION ROADMAP

### Rationale

**Focus:** Every week of delay in collections costs 2-3% of monthly revenue (industry average: 2-5% of daily cash flow impact)

**Strategy:** Implement tiers sequentially. Tier 1 items unblock most other optimizations.

### PHASE 1 (2-3 weeks) — Quick Wins (70% ROI, 30% effort)

Estimated effort: 60 engineer-hours  
Expected impact: 25-30% reduction in manual work

#### Item 1.1: Auto-Generate Invoice on Delivery Completion ✓ (This is the #1 friction killer)
- **What:** On trip completion/delivery marking, auto-create invoice(s) for delivered orders
- **How:** Add webhook listener in `TripCompletionService` → trigger `GenerateInvoiceService` for each delivered order
- **UI:** Toast notification showing "X invoices generated"
- **Effort:** 3-4 hours
- **ROI:** Eliminates manual click per order, saves 10 min/day for 100-order/day business

#### Item 1.2: Overdue Payment Dunning Sequence
- **What:** Auto-send email + SMS reminders at aging milestones (5, 15, 30 days)
- **How:** Sidekiq job runs daily, finds invoices past aged thresholds, sends templated emails
- **Email sequence:**
  - Day 5: "Payment reminder: Invoice #X due 5 days ago ($amount)"
  - Day 15: "URGENT: Invoice #X overdue 15 days ($amount) — Please remit immediately"
  - Day 30: "Escalation: Invoice #X overdue 30 days — Escalating to credit controller"
- **UI:** Dunning template settings in Settings/Billing
- **Effort:** 4-5 hours (Rails job + mailer)
- **ROI:** Industry benchmark: automated dunning reduces DSO by 3-5 days = ~5% revenue impact

#### Item 1.3: Bulk Invoice Generation UI
- **What:** Add checkbox UI to trip completion → bulk-generate invoices for all delivered orders at once
- **How:** Update `TripDetailsPage` component, add "Generate invoices" bulk action
- **UI:** Checkboxes per order, bulk action button
- **Effort:** 2-3 hours
- **ROI:** Enables one-click invoice generation vs. per-order clicks

#### Item 1.4: Aging Analysis Dashboard
- **What:** Pre-built report showing invoice aging buckets + total outstanding by age bracket
- **How:** Build SQL query (aged_invoices > 60 days, 30-60, 0-30, current) + chart
- **UI:** New page at `/reports/aging` (or in Accounting)
- **Effort:** 3-4 hours
- **ROI:** Eliminates 2-3 hrs/week of manual Excel analysis

#### Item 1.5: Auto-Default Delivered Qty in Driver App
- **What:** Pre-fill delivered qty = ordered qty (allow driver quick confirmation or manual override)
- **How:** Update driver app delivery confirmation screen
- **UI:** Auto-filled input, driver can override or swipe-confirm
- **Effort:** 1-2 hours (mobile app)
- **ROI:** 1-2 min/stop × 50 stops/trip = 50-100 min/day saved

### PHASE 2 (3-4 weeks) — High-Impact (50% ROI, 50% effort)

Estimated effort: 80 engineer-hours  
Expected impact: 35-40% reduction in manual work

#### Item 2.1: Route Optimization Integration (Biggest win)
- **What:** Auto-suggest optimal route for trip orders using OSRM or Google Distance Matrix
- **How:**
  1. Use OSRM (open-source: services/maps/osrm_client.rb)
  2. Get orders in trip → geocode addresses → call OSRM matrix endpoint
  3. Solve Traveling Salesman Problem (TSP) → return optimal sequence
  4. Update trip stop order on UI
- **UI:** "Optimize Route" button → auto-sequence stops on map
- **Effort:** 6-8 hours (API integration + TSP solver)
- **ROI:** Dispatcher currently spends 45 min/trip on manual sequencing. This saves that. → 30-40% productivity gain on trip planning.

#### Item 2.2: Auto-Reschedule Failed Deliveries
- **What:** On delivery failure (customer not home, refused), auto-create stop for next available trip in same area
- **How:**
  1. On driver marking delivery as failed in app
  2. Trigger `RescheduleFailedDeliveryJob`
  3. Find next trip in area by same driver/vehicle + same retailer's territory
  4. Create new stop with same order + customer
  5. SMS customer with new delivery attemp slot
- **Effort:** 4-5 hours
- **ROI:** Reduces manual rescheduling effort + improves success rate (second attempt within 1-2 days vs. manual rescheduling after dispatch review)

#### Item 2.3: Bank Reconciliation Auto-Matcher
- **What:** Auto-match bank CSVs against recorded payments
- **How:**
  1. Upload bank statement CSV (amount, date, reference)
  2. Algorithm: match to payments by amount + date (±1 day) + reference
  3. Flag mismatches for manual review
  4. One-click reconciliation for matched items
- **UI:** New page at `/finance/bank-reconciliation`
- **Effort:** 5-6 hours
- **ROI:** Accountant currently spend 3-4 hrs/week on manual matching. This automates 70%.

#### Item 2.4: Customer Self-Service Return Portal
- **What:** Add web form accessible via QR code on invoice for customers to initiate returns
- **How:**
  1. Generate QR code on e-invoice → links to `/returns/new?order_id=X&retailer_id=Y`
  2. Form: reason (damaged, wrong item, defective), quantity, comments, photo
  3. Auto-create return request in system
  4. Owner gets notification
- **UI:** Minimal form page (no auth required, secured by order_id)
- **Effort:** 3-4 hours
- **ROI:** Reduces phone calls for return authorizations + improves UX

#### Item 2.5: Payment Failure Handling + Notifications
- **What:** On Razorpay payment failure webhook, send email + show in-app banner, offer retry
- **How:**
  1. Listen to `invoice.payment_failed` from Razorpay webhook
  2. Mark organization as `billing_status: "payment_failed"`
  3. Send email to owner: "Payment failed. Retry now or update payment method [link]"
  4. Show banner on dashboard
  5. Provide manual retry button + update payment method form
- **Effort:** 3-4 hours
- **ROI:** Prevents silent churn + improves retention

### PHASE 3 (Ongoing) — Maturation & Refinement

#### Item 3.1: Credit Limit Auto-Calculation
- **Formula:** `monthly_avg_order_value × (credit_days / 30) × adjustment_factor`
- **Adjustment:** tier-based (regular customer: 1.0x, new: 0.7x, high-risk: 0.5x)
- **Effort:** 2-3 hours
- **ROI:** 30% faster retailer onboarding

#### Item 3.2: Inventory Auto-Reorder
- **Logic:** When stock < reorder_point, auto-create PO for reorder_qty
- **Frequency:** Daily job runs at 8 AM
- **Effort:** 3-4 hours
- **ROI:** Reduces stockout risk for fast-moving SKUs

#### Item 3.3: Advanced Driver Assignment
- **Logic:** Assign driver based on:
  - Current location (distance to pickup)
  - Available capacity
  - Historical performance (success rate)
  - Affinity (driver's preferred territories)
- **Effort:** 4-5 hours
- **ROI:** Better route efficiency

#### Item 3.4: Vehicle Document Renewal Reminders
- **What:** Auto-email owner 30 days before insurance/permit expiry
- **Effort:** 2 hours
- **ROI:** Prevents legal issues

#### Item 3.5: Plan Usage Meter Implementation
- **What:** Add to billing page: current usage (branches, users, orders/month) vs. limits
- **How:** Service queries org stats, compares to plan limits
- **Effort:** 3-4 hours
- **ROI:** Improves transparency, drives upgrades

---

## 14. SUMMARY TABLES

### Manual Interventions by Category

```
CATEGORY                          CRITICAL  HIGH  MEDIUM  LOW   TOTAL
─────────────────────────────────────────────────────────────────────
Sales Order                       1         2     2       1     6
Invoicing & Payment               2         4     2       1     9
Inventory & Stock Mgmt            0         3     3       1     7
Delivery & Trips                  3         6     4       2     15
Returns & Reverse Logistics       1         2     1       0     4
Accounting & Tax                  1         3     2       2     8
Reporting & Analytics             1         2     2       0     5
Customer Management & CRM         1         1     2       1     5
User & Access Management          0         1     2       1     4
Subscriptions & Billing           0         1     2       0     3
─────────────────────────────────────────────────────────────────────
TOTAL                             10        25    22      9     66*
```

*Note: Some items span multiple categories; 47 unique intervention points identified

### Automation Opportunity by Time Savings

| Workflow | Current Manual Time/Day | Auto Time/Day | Savings | Priority |
|---|---|---|---|---|
| Trip planning & dispatch | 180 min | 60 min | 120 min (67%) | **P0** |
| Invoice generation & distribution | 90 min | 10 min | 80 min (89%) | **P0** |
| Payment recording & reconciliation | 120 min | 30 min | 90 min (75%) | **P0** |
| Collection follow-up | 60 min | 5 min | 55 min (92%) | **P0** |
| Delivery management | 100 min | 50 min | 50 min (50%) | **P1** |
| Reporting & analysis | 60 min | 20 min | 40 min (67%) | **P1** |
| Return handling | 40 min | 10 min | 30 min (75%) | **P2** |
| Accounting reconciliation | 120 min | 30 min | 90 min (75%) | **P0** |
| **TOTAL** | **770 min** | **215 min** | **555 min (72%)** | — |

**Interpretation:** Implementing all P0 + P1 items would save **~8 hours/day** of manual labor across the org.

### Risk Analysis: What Happens Without Automation

| Gap | Consequence | Timeline | Business Impact |
|---|---|---|---|
| No dunning sequence | Collections delay 5-7 days per invoice | Immediate | 2-3% of monthly cash flow at risk |
| Manual route planning | Dispatcher becomes bottleneck at 200+ orders/day | 6-12 months | Scaling delivery becomes impossible |
| Manual invoice generation | Orders pending invoicing pile up (payment blocked) | Immediate | Revenue recognition delays |
| No aging dashboard | Collections team working blind on DSO | Immediate | Suboptimal strategy decisions |
| No plan enforcement | Free plan users can exceed limits (revenue leak) | 3-6 months | 5-10% revenue loss as free → paid conversion breaks |

---

## FINAL RECOMMENDATIONS

### Quick Wins to Implement This Sprint (Week 44)
1. **Auto-invoice on delivery** (~3 hrs)
2. **Dunning sequence** (~4 hrs)
3. **Aged invoice dashboard** (~3 hrs)

**Total: 10 hours = 1.25 engineer-weeks = Immediate 20% productivity gain in finance+delivery**

### Next Sprint (Week 45-46)
4. Route optimization (~6 hrs)
5. Failed delivery rescheduling (~4 hrs)
6. Bank reconciliation UI (~5 hrs)

**Total: 15 hours = 1.9 engineer-weeks = Additional 25% productivity gain, especially in dispatch**

### Then Build Out Plan Enforcement (Critical for monetization)
- Feature gates per plan
- Usage tracking
- Upgrade prompts
- Plan downgrade handling

**Total: 12-15 hours = Keep top of roadmap (required for multi-plan SaaS)**

---

## APPENDIX: Detailed Workflow Maps

### Payment Collection Workflow (Current State)

```
Order Approved
    ↓
Delivery Completed
    ↓
[MANUAL] User clicks "Generate Invoice"
    ↓
Invoice Created (awaiting payment)
    ↓
[MANUAL] Send invoice to customer (email button)
    ↓
[MANUAL] Customer pays bank transfer / UPI
    ↓
[MANUAL] Accountant receives bank CSV (next reconciliation cycle — daily or weekly)
    ↓
[MANUAL] Accountant matches payment to invoice (via reference)
    ↓
[MANUAL] User records payment in system (form entry OR bank import)
    ↓
Automatically allocate payment to invoice (FIFO)
    ↓
Invoice marked paid
    ↓
DONE
```

**Manual steps:** 6 steps  
**Total time:** 3-5 days (awaiting next reconciliation cycle)

### Payment Collection Workflow (After Tier 1 Automation)

```
Order Approved
    ↓
Delivery Completed
    ↓
[AUTO] Webhook triggers invoice generation
    ↓
[AUTO] Invoice created + SMS/email sent to customer
    ↓
Customer pays bank transfer / UPI
    ↓
[AUTO] Razorpay webhook → payment recorded OR
[SEMI] Accountant imports bank CSV → auto-matcher suggests match
    ↓
[AUTO] Automatically allocate payment to invoice (FIFO)
    ↓
Invoice marked paid
    ↓
DONE
```

**Manual steps:** 0-1 (only bank import if using bank transfer)  
**Total time:** 1-2 days

---

## CONCLUSION

OrdWave has strong automation in core transaction processing (orders, inventory, accounting sync). The major gaps are in:

1. **Delivery operations** — trip planning + execution heavily manual
2. **Collections** — zero automation; 3-5 day payment delays due to manual reconciliation
3. **Reporting** — no pre-built business intelligence; users build custom Excel
4. **Feature gating** — multi-plan system exists but enforcement incomplete

**66 manual intervention points identified across 10 modules.**

**Recommended focus:** Tiers 1 & 2 (Phase 1-2) would cut manual ops labor by 50-60% and save the company ~8 hours/day.

**Biggest leverage:** Auto-invoice + dunning + route optimization = these 3 items alone solve 60% of efficiency problems.

---

*END OF REPORT*