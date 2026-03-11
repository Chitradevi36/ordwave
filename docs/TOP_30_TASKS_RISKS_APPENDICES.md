# OrdWave — Top 30 Priority Tasks, Risks & Appendices

> **Date**: March 9, 2026  
> **Status**: Active development — Phase 8 complete, production-hardening in progress  
> **Stack**: Rails 7.1 API · Next.js 14 · Flutter (Dart) · PostgreSQL · Redis · Sidekiq

---

## Part 1 — Top 30 Priority Tasks

Tasks are ranked by impact × urgency. Each maps to a Phase and owner layer.

| # | Task | Phase | Layer | Priority | Status |
|---|------|-------|-------|----------|--------|
| 1 | Sales Order → Submit → Approve state machine with Pundit guards | 3 | Backend | 🔴 Critical | Done |
| 2 | Credit engine: per-customer limit enforcement on order submit | 3 | Backend | 🔴 Critical | Done |
| 3 | Offline-first sync: delta pull + conflict-safe push from Flutter | 7 | Mobile | 🔴 Critical | Done |
| 4 | Delivery trip lifecycle: dispatch → en-route → stop → delivered | 4 | Backend | 🔴 Critical | Done |
| 5 | Sales Invoice PDF generation + GST line-item breakdown | 5 | Backend | 🔴 Critical | Done |
| 6 | Payment allocation against open invoices + credit notes | 5 | Backend | 🔴 Critical | Done |
| 7 | Role-based sidebar + route guards (Owner / Manager / Salesman / Warehouse / Delivery) | 1 | Web | 🔴 Critical | Done |
| 8 | Flutter offline order creation with Drift queue + background sync | 7 | Mobile | 🔴 Critical | Done |
| 9 | Return request QC workflow → credit note auto-issue | 5 | Backend | 🔴 Critical | Done |
| 10 | Scheme engine: evaluate conditions + apply rewards at order level | 2 | Backend | 🔴 Critical | Done |
| 11 | Beat planning: schedule retailers to salesman routes | 2 | Web + Backend | 🟠 High | Done |
| 12 | Pick list generation from confirmed orders + warehouse fulfillment UI | 4 | Web + Backend | 🟠 High | Done |
| 13 | Tally realtime agent: bidirectional sync (push VOC + pull receipts) | 8 | Backend | 🟠 High | Done |
| 14 | Multi-branch inventory transfers with dispatch / receive flow | 4 | Backend | 🟠 High | Done |
| 15 | Onboarding 11-step wizard with phase indicator + skip support | 1 | Web | 🟠 High | Done |
| 16 | E-invoice + E-waybill IRN generation (GST compliance) | 5 | Backend | 🟠 High | Done |
| 17 | Mobile: quick-collect payment with offline queue | 7 | Mobile | 🟠 High | Done |
| 18 | Mobile: success overlay animation on order submit + payment collect | 8 | Mobile | 🟠 High | Done |
| 19 | Dashboard KPI tiles: revenue, orders, outstanding, collections today | 6 | Web | 🟡 Medium | Done |
| 20 | Supplier debit notes + purchase invoice reconciliation | 5 | Backend | 🟡 Medium | Done |
| 21 | Approval workflows: credit limit change requests + order holds | 3 | Backend + Web | 🟡 Medium | Done |
| 22 | Notification delivery: in-app + FCM push for key events | 6 | Backend + Mobile | 🟡 Medium | Done |
| 23 | Compliance module: KYC document upload per customer | 2 | Web + Backend | 🟡 Medium | Done |
| 24 | Reports: sales summary, collection efficiency, beat coverage | 6 | Web + Backend | 🟡 Medium | Done |
| 25 | Price list assignment: customer tier → price inheritance | 2 | Backend | 🟡 Medium | Done |
| 26 | App icon + native splash screen config for Flutter build | 8 | Mobile | 🟡 Medium | Done |
| 27 | OlSpacing constants + consistent card/screen padding system | 8 | Mobile | 🔵 Low | Done |
| 28 | Webhook endpoints: outbound event delivery to third parties | 6 | Backend | 🔵 Low | Done |
| 29 | Stock reservation on order confirm + release on cancel/deliver | 4 | Backend | 🔵 Low | Done |
| 30 | Advance payment SKUs + prepayment balance tracking | 3 | Backend | 🔵 Low | Done |

---

## Part 2 — Risk Matrix

| ID | Risk | Likelihood | Impact | Severity | Mitigation |
|----|------|-----------|--------|----------|------------|
| R1 | **Offline sync conflicts**: Two salesmen edit the same retailer record offline | High | High | 🔴 Critical | Timestamp-based last-write-wins + `sync_version` conflict flag surfaced in UI |
| R2 | **GST compliance breakage**: IRN API schema change from NIC/IRP | Medium | High | 🔴 Critical | Abstract IRN calls behind `EinvoiceService`; version-pin the NIC sandbox endpoint |
| R3 | **Credit engine bypass**: salesman submits order via direct API skipping policy | Medium | High | 🔴 Critical | Pundit policy enforces credit check regardless of path; test with spec coverage |
| R4 | **Tally agent key leak**: agent API key stored in plaintext config file on Windows | High | High | 🔴 Critical | Store `api_key_digest` (bcrypt) server-side; agent reads key from OS credential store |
| R5 | **Multi-tenant data leak**: missing `organization_id` scope on a query | Medium | Critical | 🔴 Critical | `ApplicationRecord` default scope policy + RSpec shared examples for every controller |
| R6 | **Sidekiq job starvation**: delivery proof image uploads block order-confirm queue | Medium | Medium | 🟠 High | Separate Sidekiq queues: `critical > default > uploads`; set queue weights |
| R7 | **Flutter Drift schema migration failure**: schema version mismatch on device upgrade | Low | High | 🟠 High | Always provide `MigrationStrategy` with `onUpgrade`; test with `verifyDatabase()` in CI |
| R8 | **Firebase FCM token rotation**: stale tokens cause silent push failures | High | Medium | 🟠 High | `DeviceToken` model tracks `last_used_at`; purge tokens older than 30 days in cron |
| R9 | **Price list gap**: customer has no assigned price list at order time | Medium | Medium | 🟡 Medium | `OrderPricingService` falls back to `standard` list; surfaces warning in order UI |
| R10 | **PDF memory spike**: bulk invoice generation OOM on Heroku dynos | Low | Medium | 🟡 Medium | Generate PDFs in background job with Sidekiq; stream to S3 Active Storage attachment |
| R11 | **e-waybill vehicle number missing**: delivery trip without assigned vehicle blocks generation | Medium | Low | 🟡 Medium | Validate vehicle assignment before e-waybill action; UI warns in trip detail |
| R12 | **Next.js 14 App Router hydration errors**: server/client component mismatch | Medium | Low | 🔵 Low | Mark all data-fetching components `"use client"` or use Server Components consistently |
| R13 | **JWT token not revoked on logout**: mobile client reuses cached token | Medium | Low | 🔵 Low | `JwtDenylist` table; `DELETE /auth/logout` adds JTI to denylist |

---

## Part 3 — Refactoring Cautions

These are areas where the codebase has known technical debt or fragility. Address before scaling.

### 3.1 Backend

| Area | Issue | Safe Refactor Approach |
|------|-------|----------------------|
| `SalesOrder` model | Growing god object — state machine, pricing, validation, delivery, invoice all in one model | Extract `OrderPricingDecorator`, `OrderSubmitService`, separate concerns into `app/services/orders/` |
| `PaymentsController` | `allocate` action contains allocation logic inline — hard to test | Move to `PaymentAllocationService` (already partially done); remove controller logic |
| `ApplicationRecord` scoping | `current_tenant` relies on `Current.organization` thread-local — fails in background jobs | Always pass `organization:` explicitly in Sidekiq jobs; never rely on `Current` in workers |
| DB seed files | `seeds.rb` and `seeds_payments.rb` contain hardcoded IDs — breaks on fresh installs | Use `find_or_create_by` and slug-based lookups; eliminate numeric ID assumptions |
| `AuditLog` actor | Many `AuditLog.create!` calls in services lack `actor:` — raises validation error | Audit all service calls; pass `actor: Current.user` or create a `SystemUser` sentinel |
| Route explosion | `routes.rb` is 467 lines — difficult to maintain | Split into `config/routes/` partials using `draw :resource_name` DSL |

### 3.2 Web (Next.js)

| Area | Issue | Safe Refactor Approach |
|------|-------|----------------------|
| `lib/api.ts` | All API calls are flat functions — no retry, no cancellation, no error normalization | Wrap with `apiClient` class using Axios interceptors; centralize error handling |
| Page-level data fetching | Many pages use `useEffect` + `useState` for data — causes waterfall loading | Migrate to React Query (`@tanstack/react-query`) for cache + stale-while-revalidate |
| `components/ui/` | Duplicated button variants across multiple files | Consolidate into a single `Button.tsx` with `variant` prop |
| Tailwind class sprawl | 40+ class strings on single elements inline — unreadable | Extract to `cva` (class-variance-authority) component variants |
| `onboarding/page.tsx` | 11-step wizard as a single 800-line component | Split each step into its own `Step{N}Form.tsx` component with shared `useOnboardingForm` hook |

### 3.3 Mobile (Flutter)

| Area | Issue | Safe Refactor Approach |
|------|-------|----------------------|
| `QuickCollectScreen` | Provider listen block > 50 lines inline — hard to test | Extract into named handler function; move side-effect logic out of `ref.listen` |
| Drift DB schema | Tables added incrementally — no `SchemaVersion` constant | Add `AppDatabase.schemaVersion` constant; all migrations must reference it |
| `OrdersNotifier` | Handles both remote fetch AND offline queue management — two responsibilities | Split into `RemoteOrdersNotifier` + `OfflineQueueNotifier` |
| Hard-coded base URL | `ApiClient` reads `String baseUrl = "https://..."` from a const — breaks staging | Read from `flutter_config` or `--dart-define=BASE_URL=...` at build time |

---

## Part 4 — Top 10 UX Improvements

Ranked by user-facing impact for the demo and early-adopter release.

| # | Improvement | Screen(s) | Status |
|---|-------------|-----------|--------|
| 1 | **Inline credit warning on order form** — shows available limit, blocks submit when exceeded | Order Create | Done |
| 2 | **5-phase onboarding step indicator** with named phases and skip buttons | Onboarding | Done |
| 3 | **Success overlay animation** on order submit and payment collect | Cart Review, Quick Collect | Done |
| 4 | **Beat plan day-view calendar** — salesman sees today's retailers in visit order | Beats | Done |
| 5 | **Delivery trip live progress bar** — stops completed / total with ETA | Delivery | Done |
| 6 | **Customer timeline** — unified order, payment, and return history in one scrollable feed | Customer Detail | Done |
| 7 | **Offline indicator banner** — amber banner when Flutter app is offline with queue count | All mobile screens | Done |
| 8 | **PDF preview drawer** — invoice PDF opens in right-side drawer without leaving page | Sales Invoices | In progress |
| 9 | **Bulk action toolbar** — select multiple orders/products for batch approve / export | Orders, Products | Planned |
| 10 | **Global search** — unified ⌘K search across customers, products, orders | All web pages | Planned |

---

## Part 5 — Top 10 Backend Improvements

| # | Improvement | Domain | Status |
|---|-------------|--------|--------|
| 1 | **Pundit policies complete** for all 50+ controllers — no unprotected action | Auth | Done |
| 2 | **Tally bidirectional sync** — push vouchers + receive receipts via agent | Accounting | Done |
| 3 | **Scheme evaluation engine** — slab-based discounts, freebie rules, combo offers | Pricing | Done |
| 4 | **Credit state machine** — blocked / overlimit / prepayment enforced at order time | Credit | Done |
| 5 | **e-Invoice + e-Waybill IRN pipeline** via NIC sandbox integration | GST Compliance | Done |
| 6 | **Delta sync endpoint** — clients receive only changed records since `last_synced_at` | Sync | Done |
| 7 | **AuditLog coverage** — all destructive actions (cancel, void, block) emit audit entries | Observability | Partial |
| 8 | **Background job queue separation** — `critical/default/uploads/reports` with weights | Infrastructure | Planned |
| 9 | **Request-level DB query budget** — rack middleware to halt N+1 runaway queries in staging | Performance | Planned |
| 10 | **Soft-delete across all models** — use `discard` gem for restorable archiving | Data Integrity | Planned |

---

## Part 6 — Top 10 Mobile Improvements

| # | Improvement | Feature Area | Status |
|---|-------------|-------------|--------|
| 1 | **Offline order submission queue** — Drift-backed queue with WorkManager background sync | Orders | Done |
| 2 | **Quick collect with offline support** — optimistic local write, syncs when connected | Collections | Done |
| 3 | **Success animation overlay** — pure Flutter checkmark animation, no Lottie dependency | UX Polish | Done |
| 4 | **App icon + native splash** — brand green `#1B4332` adaptive icon, configured via pubspec | Build | Done |
| 5 | **OlSpacing constants** — canon spacing system; `edge=16`, `cardGap=12`, `sectionGap=24` | Design System | Done |
| 6 | **FCM push notification handler** — deep-link routing on tap from background/terminated | Notifications | Done |
| 7 | **Connectivity banner** — live `connectivity_plus` stream driving amber offline badge | UX | Done |
| 8 | **Beat visit checkin/checkout** — GPS-tagged arrival + departure with photo proof | SFA | Done |
| 9 | **Retailer credit summary card** — outstanding balance + limit on customer profile | CRM | Done |
| 10 | **Per-screen skeleton loaders** — replace blank screens during API fetch with shimmer | UX Polish | Planned |

---

## Appendix A — Full Tech Stack

### Backend

| Component | Technology | Version |
|-----------|-----------|---------|
| Language | Ruby | 3.2.x |
| Framework | Rails (API-only) | 7.1.6 |
| Database | PostgreSQL | 14+ |
| Cache / Queue | Redis | 7+ |
| Background Jobs | Sidekiq | 7.x |
| Authentication | Devise + devise-jwt | 4.9 / 0.11 |
| Authorization | Pundit | 2.3 |
| File Storage | ActiveStorage → S3 / MinIO | Rails built-in |
| CORS | rack-cors | latest |
| PDF Generation | Prawn / WickedPDF | TBD |
| GST / IRN | NIC e-Invoice API (sandbox) | v1.03 |
| Containerization | Docker + docker-compose | latest |

### Web App

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Next.js (App Router) | 14.x |
| Language | TypeScript | 5.x |
| Styling | Tailwind CSS | 3.x |
| HTTP Client | Axios | 1.x |
| Icons | Lucide React | latest |
| Charts | Recharts | 2.x |
| Tables | TanStack Table | 8.x |
| Forms | React Hook Form + Zod | latest |
| State | React Context + useState | built-in |

### Mobile (Flutter)

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Flutter | 3.x (SDK ≥3.4) |
| Language | Dart | 3.x |
| State Management | Riverpod + riverpod_annotation | 2.6.x |
| Navigation | go_router | 14.x |
| HTTP | Dio | 5.9.x |
| Local DB | Drift (SQLite) | 2.28.x |
| Secure Storage | flutter_secure_storage | 9.x |
| Background Sync | WorkManager | 0.5.x |
| Push Notifications | FCM + flutter_local_notifications | 3.13 / 17.x |
| Connectivity | connectivity_plus | 6.x |
| Code Generation | Freezed + build_runner | 2.5.x |
| App Icon / Splash | flutter_launcher_icons + flutter_native_splash | 0.14 / 2.4 |

---

## Appendix B — Project Timeline

| Week | Phase | Deliverable | Target Date |
|------|-------|-------------|-------------|
| 1 | Phase 0 | Repo cleanup, shared design tokens, CI pipeline | Feb 3, 2026 |
| 2 | Phase 1 | Role-based navigation, auth flow, onboarding wizard | Feb 10, 2026 |
| 3–4 | Phase 2 | Retailer CRM, product catalogue, price lists, schemes, beats | Feb 24, 2026 |
| 5–6 | Phase 3 | Credit engine, order flow, approval workflows | Mar 10, 2026 |
| 7–8 | Phase 4 | Delivery trips, warehousing, pick lists, stock transfers | Mar 24, 2026 |
| 9–10 | Phase 5 | Payments + allocations, invoices, returns, credit notes | Apr 7, 2026 |
| 11–12 | Phase 6 | Notifications, settings, reports dashboard | Apr 18, 2026 |
| 13–14 | Phase 7 | Flutter offline architecture, sync polish, background jobs | Apr 29, 2026 |
| 15 | Phase 8 | Demo-readiness, Tally integration, production hardening | May 6, 2026 |
| 16+ | Post-launch | Feedback cycle, performance tuning, global search | TBD |

> **Current date**: March 9, 2026 — tracking to Phase 3/4 boundary on schedule.

---

## Appendix C — Module Ownership Quick Reference

| Module | Backend Controller(s) | Web Route | Mobile Feature |
|--------|----------------------|-----------|----------------|
| Auth | `auth`, `sessions`, `signup`, `passwords` | `/login`, `/signup`, `/onboarding` | `auth/` |
| Customers (CRM) | `customers`, `customer_contacts` | `/customers` | `retailers/` |
| Products | `products`, `product_categories`, `units_of_measure`, `hsn_sac_codes` | `/products`, `/catalog` | `products/` |
| Pricing | `price_lists`, `price_list_items`, `schemes` | `/pricing`, `/schemes` | — |
| Orders | `sales_orders`, `order_pricing` | `/orders` | `orders/` |
| Credit | `credit_accounts`, `credit_policies`, `credit_limit_change_requests`, `prepayment_skus` | `/approvals` | — |
| Delivery | `delivery_trips`, `trip_stops`, `stop_rejections`, `delivery_proofs` | `/delivery` | `delivery/` |
| Inventory | `inventory/balances`, `inventory/movements`, `inventory/adjustments`, `stock_transfers`, `pick_lists` | `/inventory`, `/operations` | — |
| Payments | `payments`, `advance_payments`, `payment_allocations` | `/finance`, `/collections` | `collections/` |
| Invoicing | `sales_invoices`, `credit_notes`, `purchase_invoices` | `/sales-invoices`, `/credit-notes`, `/purchases` | — |
| Returns | `return_requests` | `/returns` | — |
| Supplier | `suppliers`, `supplier_products`, `supplier_debit_notes` | `/suppliers`, `/supplier-debit-notes` | — |
| Accounting | `accounting/integrations`, `accounting/agents`, `accounting/exports` | `/accounting` | — |
| Beats / SFA | `beats`, `beat_schedules`, `visits`, `collection_schedules` | `/beats`, `/routes` | `beats/` |
| Notifications | `notifications`, `device_tokens` | `/settings` | `notifications/` |
| Compliance | `compliance/` controllers, `customer_contacts` | `/compliance` | — |
| Reports | `analytics`, `reports`, `exports` | `/insights`, `/sales`, `/finance` | — |
| Settings | `organizations`, `branches`, `memberships`, `roles`, `webhook_endpoints` | `/settings` | `settings/` |
| Sync | `sync` (delta + push) | — | `sync/` |
