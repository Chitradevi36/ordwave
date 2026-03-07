# OrderLane Pro — Full Improvement Roadmap

OrderLane Pro is a **well-architected FMCG distribution SaaS** with a solid backend (Rails 7.1, full domain coverage), a modern web frontend (Next.js 14), and a skeletal mobile app. The core B2B sales cycle — onboarding → orders → invoicing → payments → delivery — is functionally complete. The gaps fall into four buckets: compliance risk, unfinished wiring of existing schema, mobile app build-out, and monetization infrastructure.

---

## TIER 1 — Critical / Compliance (must fix before scaling)

**Steps**

1. ~~**Wire the e-Invoice (IRP) integration**~~ ✅ — `EinvoiceJob`, `Gst::EinvoiceService`, `POST /api/v1/sales_invoices/:id/einvoice` all wired. `alias_method :gst_summary, :tax_breakup` added to model. Policy gate `einvoice?` added. **UI:** `InvoiceDetail` type extended with IRN fields; "Generate e-Invoice" button + inline IRN/ACK/QR card on invoice detail page.

2. ~~**Add GSTIN format validation on the backend**~~ ✅ — Already present on both `Customer` and `Supplier` models (full 15-char regex, `allow_blank: true`). `Organization.gst_number` also validated. **UI:** `CustomerForm`, `supplier-form`, and `add-organization-modal` all have matching GSTIN regex inline validation.

3. ~~**Activate plan/subscription enforcement**~~ ✅ — `PlanLimits` service created (`app/services/plan_limits.rb`). Limits: starter (1 branch / 5 users), growth (5 / 25, exports + analytics), enterprise (unlimited). `enforce_branch_limit!` in `BranchesController#create`; `enforce_user_limit!` in `UsersController#create` + `#invite`; `enforce_feature!(:exports)` in `ExportsController#create`. `rescue_from PlanLimits::PlanLimitError` → HTTP 402 in `BaseController`. `GET /api/v1/organizations/:id/plan_info` endpoint added. **UI:** `usePlanInfo` hook; `UpgradeBannerListener` component (amber full-width banner with upgrade CTA) added to `ClientProviders`; Axios 402 interceptor emits `plan:limit_exceeded` custom DOM event.

---

## TIER 2 — High Business Value (fills major functional gaps)

**Steps**

4. **Build the AP (Accounts Payable) module** — `purchase_invoices` exist with full lifecycle, but there is no `purchase_payments` model, no AP aging, and no supplier pay-out route. Add: `purchase_payments` table, `PurchasePaymentsController`, AP aging on the analytics page, and supplier ledger view. This closes the procurement loop.

5. **Merge the two return systems** — `return_records` (delivery-time lightweight returns) and `return_requests` (full RMA + QC + credit note) are disconnected. Add a `return_record_id` FK on `return_requests` so a delivery-time return can be escalated to a full RMA. Prevents dual-counting of returned inventory in stock movements.

6. **Build the unified Approvals queue** — `web/app/approvals/` page exists but there is no `GET /api/v1/approvals/pending` backend route. Create a single endpoint that aggregates: `sales_orders` (on_hold), `credit_limit_change_requests` (pending), `return_requests` (submitted), and `stock_transfers` (pending). Display count badges in the sidebar nav.

7. **Advance Payments web UI** — `advance_payments` controller and service are complete but there is no web page for it. Add `web/app/finance/advance-payments/` with balance view, apply-to-invoice action, and refund flow.

8. **Stock Transfers web UI** — `stock_transfers` controller is complete but no corresponding web page exists. Add `web/app/inventory/transfers/` with draft → dispatch → receive workflow UI.

9. **Webhooks + Exports web UI** — Both backend modules are complete (`webhook_endpoints`, `exports` controllers with full CRUD) but have no management UI. Add `web/app/settings/webhooks/` and `web/app/settings/exports/` pages.

---

## TIER 3 — Mobile App Build-out

The mobile app has 8 screens (Login, Home, Customers, CustomerDetail, DeliveryTrips, TripDetail, CompleteStop, Settings). All the following are missing:

**Steps**

10. **SFA Visit Workflow** — Add `BeatsScreen`, `VisitCheckInScreen`, `VisitCheckOutScreen` connecting to the existing `/beats`, `/visits` APIs. This is the primary daily-use flow for field reps.

11. **Mobile Order Creation** — Add `NewOrderScreen` and `OrderDetailScreen` using the mobile-optimized `POST /api/v1/sales_orders/mobile` endpoint that already exists.

12. **Mobile Catalog + Pricing** — Add `ProductsScreen` and `PriceListScreen`. Field reps need to check stock and price before taking orders.

13. **Mobile Payments Collection** — Add `PaymentsScreen` to record customer payments in the field. Backend is ready.

14. **Offline-first sync** — The architecture doc targets offline-first but no sync mechanism exists. Implement with WatermelonDB or React Query offline persistence. Priority queue: visits → orders → payments.

---

## TIER 4 — Technical Debt & Code Quality

**Steps**

15. **Retire `inventory_levels` legacy endpoint** — `backend/config/routes.rb` already comments it as legacy. Set a deprecation header on responses (`Deprecation: true`, `Sunset: <date>`), log usage via lograge, and remove after 90 days.

16. **Resolve Ruby version mismatch** — Gemfile specifies `ruby "3.3.0"` but 3.2.10 is in use. Pin the Gemfile to what's actually deployed or upgrade the runtime to 3.3. The `connection_pool` workaround hint suggests this is actively causing issues.

17. **Scheme condition type enforcement** — `scheme_conditions.value` is free-form JSONB with no schema. Add a JSON Schema validator in the `Scheme` model (or service) to validate condition payloads by `condition_type` at creation time.

18. **Test coverage for payments and scheme engine** — These are financially critical modules. Add `spec/services/payments/` and `spec/services/pricing/` coverage for: payment confirmation, reversal, scheme stack ranking, exclusive-scheme logic, and freebie calculation.

19. **Update onboarding API docs** — `docs/ONBOARDING_FLOW.md` references `/retailers`, `/orders`, `/onboarding/status` — none of which match actual routes (`/customers`, `/sales_orders`, `/onboarding`). Update to match actual routes before onboarding more developers.

20. **`delivery_date` precision upgrade** — `sales_orders.delivery_date` is `date` (no time). If time-slot delivery is needed, migrate to `timestamptz` and add a `delivery_slot_id` FK to a future `delivery_slots` table.

---

## TIER 5 — Growth / Platform Features

**Steps**

21. **In-app notification center** — FCM gem + `device_tokens` table exist. Add a `notifications` table (user, org, type, read_at, payload JSONB), a `NotificationsController`, and a bell-icon dropdown in the web nav. Trigger on: order status changes, credit limit approvals/rejections, delivery completion, low stock threshold breach.

22. **HSN/SAC web management UI** — Backend is complete (CRUD + bulk import + rate changes) but no web page exists. Add `web/app/catalog/hsn-codes/` for compliance teams.

23. **Scheme channel/tier filtering** — Add `customer_tier` and `customer_channel` columns to `schemes` (or as `scheme_conditions`), and enforce these filters in the pricing preview service. Currently all schemes apply to all customers unless manually condition-gated.

24. **Multi-branch analytics drill-down** — Current analytics endpoints accept `branch_id` but the web insights page has no branch switcher. Add a branch/date-range filter bar to `web/app/insights/`.

25. **Audit log UI** — `audit_logs` table is populated but there is no UI to browse it. A simple `web/app/settings/audit-log/` page with actor, action, resource, and diff viewer would be valuable for compliance and support.

---

## Verification

For each tier:
- **Tier 1:** Manual API test with Postman; check `einvoice_status` transitions; test GSTIN regex with invalid inputs
- **Tier 2:** Run existing `rspec spec/requests/` after each new controller; verify approval counts match individual resource queries
- **Tier 3:** Expo device testing; simulate offline (airplane mode) and verify queue flush on reconnect
- **Tier 4:** `bundle exec rspec` full suite; `rubocop` pass; confirm no remaining calls to legacy `/inventory_levels`
- **Tier 5:** Notification delivery via FCM test message; scheme preview endpoint with tier-filtered customers

---

## Priority Summary

| Tier | Theme | Items | Est. Effort |
|---|---|---|---|
| 1 | Compliance / Critical | 3 | ~2–3 weeks |
| 2 | High-value feature gaps | 6 | ~4–6 weeks |
| 3 | Mobile build-out | 5 | ~6–8 weeks |
| 4 | Technical debt | 6 | ~1–2 weeks (parallel) |
| 5 | Growth features | 5 | ~3–4 weeks |

**Decisions**
- e-Invoice (Tier 1, item 1) is the non-negotiable compliance fix — should be Sprint 1
- AP payments module (Tier 2, item 4) unlocks the full procurement cycle and is the biggest feature gap after compliance
- Mobile offline sync (Tier 3, item 14) is architected for but has zero implementation — needs a library decision (WatermelonDB vs. MMKV + React Query persistence) before screen work begins
