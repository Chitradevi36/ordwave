# OrdWave — Executive Summary & Gap Analysis

## 1. Executive Summary

**OrdWave** (also referred to as OmniDist OMS) is a B2B distribution SaaS targeting Indian FMCG distributors. The repo is a monorepo with three layers: a **Rails 7.1 API backend** (surprisingly complete — 73 models, 54 controllers, 155+ services, 51 policies, 53 DB tables), a **Next.js 14 web app** (95 pages, role-based nav, workspace-hub architecture), and **two mobile apps** — a React Native/Expo app (~25% complete, 8 screens, no offline) and a Flutter skeleton (0% implementation, only dependency resolution done).

**What's strong:** The backend domain model is remarkably comprehensive — sales orders, credit engine, GST compliance, returns with QC, FIFO payment allocation, inventory ledger with immutable stock movements, schemes engine, beat/SFA, accounting integration (Tally), e-invoicing, and webhook infrastructure all exist. The web app has 95 pages with role-based dashboards and a workspace-hub navigation pattern.

**What's missing or broken:**
- **Mobile Flutter app has zero code** — only resolved dependencies
- **React Native app** has no navigation system, no offline support, no state management, only 8 screens (login, home, customers, delivery)
- **No order creation on mobile** — the single most critical field workflow
- **No payment collection on mobile** — sales reps and drivers can't collect
- **No offline-first capability anywhere** — headline feature is unimplemented
- **Notifications panel uses hardcoded mock data** — no real notification system
- **Web has no middleware-level auth** guards — all client-side
- **No error/loading boundary files** in Next.js
- **Role name mismatch** between frontend (`accounts`, `warehouse`) and backend (`accountant`, `warehouse_staff`)
- **Two disconnected return systems** (`return_records` from delivery, `return_requests` for RMA)
- **Product naming chaos** — repo is `orderlane_pro`, docs say "OmniDist OMS", seeds use `@riceoms.dev`
- **No collection scheduling** model/API exists
- **No real notification/alert infrastructure** — `DeviceToken` model exists but no notification model for in-app alerts
- **Missing web pages** for: advance payments, stock transfers detail, webhooks management, audit log viewer, approval queue

**Recommended strategy:** Abandon React Native, build the Flutter app as the canonical mobile app. Focus the first 3 phases on solidifying backend domain gaps, building the Flutter foundation, and completing the web workspace experience. Then systematically build out the order→delivery→payment→returns cycle across all three layers.

---

## 2. Current Repo Gap Analysis

### 2.1 Already Good

| Area | Assessment |
|---|---|
| **Database schema** | 53 tables, well-normalized, proper foreign keys, check constraints on financial fields, immutable stock_movements, GIN indexes on JSONB columns |
| **Credit engine** | Full credit account model with overdue buckets, ageing, hold/block logic, limit change requests with approval, collection-first flag, prepayment SKUs |
| **Sales order lifecycle** | Draft→submitted→on_hold/approved→dispatched→delivered/partial/cancelled with credit snapshot, scheme snapshot, idempotency keys |
| **Payment FIFO allocation** | `FifoAllocator` service properly allocates to oldest invoices first, creates advance payments when excess |
| **GST compliance** | HSN/SAC codes, CGST/SGST/IGST split, cess, reverse charge, e-invoice (IRP), e-way bill, GSTR-1 export |
| **Returns QC pipeline** | Return request → QC items (resalable/damaged/expired/discounted/return-to-supplier) → credit note + supplier debit note |
| **Inventory immutable ledger** | 17 movement types, `ReadOnlyRecord` enforcement, direction-based deltas, polymorphic references |
| **Audit logging** | 80+ action types, JSONB changes_data, actor tracking, reason field |
| **Pundit authorization** | 51 policy files with `UserContext(user, org)` pattern, role + membership checks |
| **Scheme engine** | 4 scheme types, budget tracking, priority/exclusivity, weekday targeting, condition/reward DSL |
| **Web workspace architecture** | 9 workspace hubs with role-filtered navigation, command palette (Cmd+K), breadcrumbs |
| **Design system foundation** | Deep green brand, CVA variants, Radix primitives, reusable DataTable/Badge/Modal/EmptyState |
| **Accounting integration** | Tally agent architecture with heartbeat, polling, bidirectional sync, batch exports |
| **Service object pattern** | 155+ services with clear single-responsibility, no business logic in controllers |

### 2.2 Missing

| Module | Status |
|---|---|
| **Mobile Flutter app** | 0% implemented — skeleton only |
| **Order creation on any mobile** | Not implemented — the #1 field workflow |
| **Payment/collection on mobile** | Not implemented |
| **Offline queue + sync** | Not implemented anywhere |
| **Collection scheduling** | No model, no API, no UI — referenced in FRD but nonexistent |
| **In-app notification model** | No `Notification` table — only `DeviceToken` for push. `NotificationsPanel` on web uses mock data |
| **Approval queue** | No dedicated approval inbox — credit limit requests exist but no unified approval workflow for orders, adjustments, etc. |
| **Purchase orders** | Only purchase invoices — no PO-before-receipt workflow |
| **Warehouse picking/packing** | No pick list generation, no bin/location tracking |
| **Batch/lot + expiry tracking on inventory** | Only on return lines, not on `inventory_levels` or `stock_movements` |
| **Sales targets/quotas** | No model or tracking |
| **Web error/loading boundaries** | No `error.tsx`, `loading.tsx`, or `not-found.tsx` files |
| **Server-side auth middleware** | No `middleware.ts` — all auth is client-side |
| **Web tests** | Zero test files in web/ |
| **i18n** | All strings hardcoded English |

### 2.3 Inconsistent

| Issue | Details |
|---|---|
| **Product naming** | Repo: `orderlane_pro`, docs: "OmniDist OMS", seeds: `@riceoms.dev`, sidebar: "OrdWave" |
| **Role names** | Backend: `accountant`, `warehouse_staff`. Frontend nav config: `accountant`, `warehouse_staff` (correct). But some seed/prompt docs reference `accounts`, `warehouse` |
| **API call patterns in web** | Some pages use React Query hooks (`useDashboardData`, `useOrders`), most use raw `fetch()` with `useState` — inconsistent data fetching |
| **Base URL inconsistency in RN app** | LoginScreen uses `localhost:3000`, other screens use `localhost:3001` |
| **Two return systems** | `return_records` (legacy, per trip-stop) and `return_requests` (full RMA workflow) — not linked, risk of double-counting |
| **Terminology** | "Customer" in backend/API, "Retailer" in onboarding docs, "Outlet" in some UI copy |
| **Workspace tabs** | Only `sales` workspace has active tabs in `workspace.config.ts` — all others are commented out |

### 2.4 Risky

| Risk | Impact |
|---|---|
| **No offline mobile = no field adoption** | Sales reps in rural India have unreliable networks. Without offline-first, the product cannot serve its target market |
| **No mobile order creation = no value proposition** | The primary daily action (placing orders) cannot be done from the field |
| **Two mobile codebases** | RN app has working screens but wrong architecture. Flutter app has right architecture but zero code. Migration path unclear |
| **Client-side-only auth** | Any page can be accessed by directly navigating to the URL. No server-side session validation |
| **No notification backbone** | Users have no way to know about orders needing approval, overdue payments, low stock, or failed deliveries |
| **Missing collection scheduling** | Accounts users can't plan their collection runs |
| **No conflict resolution for mobile sync** | When offline-first is built, there's no strategy for handling conflicting edits |

### 2.5 High-Value Quick Wins

1. **Fix workspace tabs** — uncomment and activate all workspace tabs in `workspace.config.ts`
2. **Add `Notification` model + API** — simple polymorphic model with unread/read, role-based targeting, deep link URL
3. **Wire NotificationsPanel to real API** instead of mock data
4. **Add Next.js `middleware.ts`** for server-side auth redirect
5. **Add `error.tsx` + `loading.tsx`** boundary files for error recovery
6. **Standardize API fetching** — convert remaining raw `fetch()` pages to React Query hooks
7. **Add approval inbox page** — aggregate credit limit requests, order holds, and adjustment approvals into one screen
8. **Deprecate `return_records`** — migrate to unified `return_requests` system
9. **Add advance payments page** to web Finance section
10. **Seed a complete demo dataset** — full org with realistic retailers, products, orders, trips, payments, returns across all states

### 2.6 Major Revamp Areas

1. **Flutter mobile app** — Build from scratch: auth, role-based home, retailer lookup, order creation, collection, delivery, offline sync
2. **Notification infrastructure** — Model, service, domain event triggers, push delivery, in-app panel, deep links
3. **Collection scheduling** — Model, API, web calendar, mobile task list
4. **Offline-first architecture** — Drift local DB, sync queue, conflict resolution, delta sync API
5. **Approval workflow** — Unified `ApprovalRequest` model or approval inbox aggregating all pending decisions
6. **Web data fetching standardization** — All pages to React Query with proper loading/error/empty states
7. **Dashboard KPIs** — Real computed metrics from backend (not client-side aggregation)
