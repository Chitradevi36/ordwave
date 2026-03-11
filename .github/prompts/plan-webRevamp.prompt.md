# OrdWave — Web App Revamp Plan

## 4. Web App Revamp Plan

### 4.1 App Shell Revamp

**Current:** AppShell with sidebar + topbar + breadcrumbs. Sidebar has 9 workspace hubs. TopBar has org/branch switchers, create dropdown, command palette, notifications (mock), user menu.

**Target changes:**
- Add `middleware.ts` for server-side auth guard (redirect unauthenticated to `/login`, redirect no-org to `/onboarding`)
- Add `error.tsx`, `loading.tsx`, `not-found.tsx` boundary files at app root and key route segments
- Wire NotificationsPanel to real `/api/v1/notifications` API
- Add notification badge count on bell icon
- Add "Approvals" badge count on Sales workspace for managers
- Activate all workspace tabs in `workspace.config.ts`
- Add role-based workspace filtering (already partially done)

**Components affected:**
- `web/app/layout.tsx`
- `web/app/middleware.ts` (new)
- `web/app/error.tsx` (new)
- `web/app/loading.tsx` (new)
- `web/app/not-found.tsx` (new)
- `web/components/layout/sidebar.tsx`
- `web/components/layout/top-bar.tsx`
- `web/components/global/NotificationsPanel.tsx`
- `web/components/workspace/workspace.config.ts`

### 4.2 Owner Dashboard

**Purpose:** Executive overview of business health.
**Persona:** Owner, Admin.
**KPIs:** Revenue Today, Revenue MTD, Outstanding AR, Overdue %, Orders Today, Collections Today, Active Trips.
**Page sections:**
1. KPI cards row (6-8 metric cards with sparkline trends)
2. Alerts panel — credit blocks, failed deliveries, low stock, payment reversals
3. Sales trend chart (7d/30d toggle)
4. Order pipeline by status (horizontal bar or funnel)
5. Top 5 overdue customers table
6. Recent activity feed (latest orders, payments, deliveries)

**Top 3 actions:** View Approvals, Export Daily Report, Switch Branch
**Status badges:** Alert count on Approvals, Overdue count
**Filters:** Branch selector, Date range
**Empty state:** "Welcome! Complete your onboarding checklist to start seeing data here."
**Error state:** "Dashboard failed to load. Retry." with retry button
**Loading state:** Skeleton cards + shimmer chart placeholders
**Audit/timeline:** Activity feed shows last 20 system events

**Current status:** Partially implemented — has KPI cards, sales trend, order status chart. **Needs:** real-time alerts panel, overdue customers table, activity feed.

### 4.3 Manager Dashboard

**Purpose:** Branch operations control center.
**Persona:** Branch Manager.
**KPIs:** Pending Approvals, Active Trips, Orders Today, Low Stock Items, Team Online.
**Page sections:**
1. Action-required cards (approvals count, exceptions count) — click to navigate
2. Today's trips status (X dispatched, Y completed, Z exceptions)
3. Order funnel (submitted → approved → dispatched → delivered)
4. Inventory alerts (items below threshold)

**Top 3 actions:** Approve Order, Create Trip, Auto-Create Trips
**Empty state:** "No pending actions. Your branch is running smoothly."
**Current status:** Shows same view as Owner. **Needs:** dedicated manager layout focused on operational actions.

### 4.4 Accountant Dashboard

**Purpose:** Financial control center.
**Persona:** Accountant.
**Page sections:**
1. Outstanding AR by ageing bucket (current / 1-14d / 15-29d / 30-59d / 60d+) — stacked bar
2. Today's collections (amount + count)
3. Pending invoices (delivered orders without invoices)
4. Unapplied credit notes
5. Tally sync status (last sync time, pending records, errors)

**Top 3 actions:** Record Payment, Generate Invoice, Export to Tally
**Current status:** `AccountantView` component exists but basic. **Needs:** ageing breakdown chart, sync status panel, pending invoices list.

### 4.5 Warehouse Dashboard

**Purpose:** Pick/pack/dispatch operations.
**Persona:** Warehouse Staff.
**Page sections:**
1. Orders to pick (approved, not dispatched) — sortable by priority/age
2. Trips ready to dispatch (planned, vehicle+driver assigned)
3. Incoming transfers (dispatched toward this branch)
4. Low-stock alerts with reorder suggestions

**Top 3 actions:** Start Pick List, Confirm Dispatch, Receive Transfer
**Current status:** `WarehouseView` component exists but basic. **Needs:** pick list integration, incoming transfer alerts.

### 4.6 Delivery Operations Dashboard

**Purpose:** Trip monitoring and exception management.
**Persona:** Manager, Owner.
**Page sections:**
1. Live trip status — dispatched trips with stop progress % bar
2. Exceptions requiring attention (failed/partial stops)
3. Today's completed vs remaining stops
4. Driver availability (assigned/unassigned)

**Top 3 actions:** Auto-Create Trips, View Exceptions, Assign Driver
**Current status:** Delivery hub page exists. **Needs:** real-time trip progress view, exception panel.

### 4.7 Retailer List + Detail

**Current state:** `customers/page.tsx` (607 lines) — saved views, search, bulk import, credit usage bars. `customers/[id]/page.tsx` (1,084 lines) — tabs for details, credit, orders, contacts, addresses.

**Target additions:**
- Add "Risk flags" section (collection_first, watchlist, hold_required badges) prominently in detail header
- Add payment history tab
- Add "Last visited" and "Next scheduled visit" in header meta
- Add quick action: "Create Order for This Customer" button in header
- Add outstanding summary banner at top of detail page (total outstanding, overdue, last payment date, last order date)
- Better credit account visualization (gauge chart for utilization %)
- Add customer timeline/activity feed tab (all orders, payments, visits, credit changes)

**Component reuse:** CreditBanner (reusable across customer list, detail, order creation)

### 4.8 Orders Kanban/List/Detail

**Current state:** `orders/page.tsx` (963 lines) — status tabs, search, date filters, metrics, CSV export. `orders/[id]/page.tsx` (954 lines) — tabs with lines, lifecycle/audit trail, credit decision modal, status actions.

**Target additions:**
- Add kanban view toggle (list view vs board view by status columns)
- Add "Processing SLA" indicator (time since submitted → awaiting action)
- Add scheme applied summary section on order detail
- Improve lifecycle tab with visual stepped timeline (not just audit table)
- Add "Generate Invoice" action on delivered orders
- Add "Create Delivery Trip" quick action from approved orders list
- Add order value breakdown: subtotal, discount, tax, total — currently flat `total`

### 4.9 Approvals Inbox

**Current state:** `approvals/credit-limits/page.tsx` (326 lines) — only credit limit change requests.

**Target:** Unified approval inbox aggregating:
- Credit limit change requests (existing)
- Orders on hold awaiting approval (pull from `SalesOrder.where(status: :on_hold)`)
- Stock adjustment approvals (new — for high-value adjustments)
- Payment reversal confirmations (new — require manager approval)

**Page layout:**
1. Tab bar: All | Orders | Credit Limits | Adjustments | Reversals
2. Each item: card with summary, requestor, timestamp, one-click Approve/Reject + reason field
3. Bulk approve for low-risk items

**Component reuse:** ApprovalCard (shared component)

### 4.10 Credit Control Screens

**Current state:** Credit account view on customer detail, credit policy settings page, credit limit change requests page.

**Target additions:**
- Dedicated Credit Risk dashboard page (under Insights → Credit Risk — already exists but enhance)
- Credit portfolio view: all customers sorted by risk bucket (current/mild/moderate/serious/critical) with totals
- Bulk hold/unhold actions for critical-bucket customers
- Credit limit change history timeline per customer
- Visual overdue ageing chart per customer (bar chart showing amounts by bucket)

### 4.11 Products and Pricing

**Current state:** `products/page.tsx` (542 lines) with sub-nav to categories, UoM, price lists. Price list detail page with items.

**Target additions:**
- Move HSN/SAC master management from `/settings/hsn-codes` to Catalog workspace
- Price list comparison view (side-by-side of standard vs promo prices for all products)
- Retail price vs your price margin indicator per product
- Bulk price update tool (upload CSV of new prices)
- Product detail page with pricing history, stock levels across branches, recent order history

### 4.12 Suppliers + Purchase Invoices

**Current state:** `suppliers/page.tsx` (270 lines), `purchases/invoices/page.tsx`.

**Target additions:**
- Supplier payables summary (total owed to each supplier — aggregate from posted purchase invoices)
- Purchase invoice → stock impact visualization (which products were stocked, which branch)
- Supplier debit note creation workflow from return QC results

### 4.13 Inventory + Transfers

**Current state:** `inventory/stock/page.tsx`, `inventory/transfers/page.tsx`, `inventory/adjustments/new/page.tsx`.

**Target additions:**
- Stock level heatmap (green/yellow/red grid by product × branch based on threshold)
- Transfer detail page with line-by-line receive workflow (mark qty received per product, note damaged)
- Movement history timeline per product (filterable by movement type)
- Low-stock alert configuration per product (set custom threshold)
- Branch-wise availability comparison table

### 4.14 Delivery Trips + Exceptions

**Current state:** `delivery/page.tsx` (470 lines) with auto-create modal. `delivery/[id]/page.tsx` trip detail.

**Target additions:**
- Trip progress tracker (visual stop-by-stop progress bar: pending → delivered → completed)
- Exception panel with resolution actions (retry/skip/escalate)
- Driver & vehicle assignment dropdown in trip creation — clearer UX than current
- Trip completion summary: delivered ₹X, collected ₹Y, returns ₹Z, exceptions N

### 4.15 Invoices + Credit Notes

**Current state:** `sales-invoices/page.tsx` (293 lines), `credit-notes/page.tsx` (204 lines).

**Target additions:**
- Invoice PDF preview inline (not just download link)
- Credit note application workflow UI: select CN → select invoice → enter amount → apply
- Invoice ageing report (outstanding invoices grouped by age bucket)
- Bulk invoice generation action (generate invoices for all delivered orders without invoices)
- E-invoice status badges (pending/generated/cancelled IRN)

### 4.16 Payments + Collection Schedule

**Current state:** `collections/page.tsx` (236 lines) with create payment modal.

**Target additions:**
- **Collection schedule page** (NEW) — calendar + list view of planned collections by customer/date
  - Create schedule: select customer, date, expected amount, assign to user
  - Daily/weekly view with planned vs completed status
  - Quick action: "Collected" → opens payment creation prefilled
- Payment allocation detail view (which invoices were paid by this payment)
- Advance payment management page (list advances, apply to invoices, refund)
- Payment reversal workflow with mandatory reason and manager approval
- Collection performance chart (target vs actual by period)

### 4.17 Reports Hub

**Current state:** `insights/page.tsx` with sub-pages for sales, collections, credit risk, inventory health, beat performance, returns, schemes.

**Target additions:**
- Report hub landing page with report cards showing description + last generated date
- Export to PDF option for each report (in addition to CSV)
- Date range comparison toggle (this month vs last month, % change)
- Branch-level filtering on all reports (already partially done)
- Downloadable formatted Excel reports (not just raw CSV)

### 4.18 Team Members + Invitations

**Current state:** `users/page.tsx` (511 lines) with invitations tab.

**Target additions:**
- Role permissions matrix view (read-only reference showing what each role can do)
- Last active indicator per team member (from Devise's `last_sign_in_at`)
- Branch assignment management (reassign user to different branch)
- Bulk invite via CSV upload

### 4.19 Settings

**Current state:** `settings/page.tsx` (325 lines) with org, branch, credit policy, fleet, prepayment SKUs, HSN codes sub-pages.

**Target additions:**
- Webhook management page (CRUD on webhook endpoints, test delivery, view delivery history)
- Notification preferences (email/push/in-app toggles per event type)
- Audit log viewer (searchable table of `audit_logs` with actor, action, entity, timestamp, changes diff)
- Tax settings (GSTIN display, state code, e-invoice API config, e-way bill thresholds)
- Approval rules configuration (which actions require approval, by which roles, thresholds)

### 4.20 Shared Web Components Plan

**New reusable components to build:**

| Component | Purpose | Reuse Locations |
|---|---|---|
| `StatusTimeline` | Visual stepped event timeline | Order detail, delivery detail, return detail, payment detail |
| `CreditBanner` | Customer credit status summary (outstanding, overdue, limit, flags) | Customer detail, order creation, customer list hover |
| `ApprovalCard` | Approve/reject card with reason input | Approval inbox, credit limit requests, order holds |
| `ExceptionPanel` | Collapsible panel for exceptions with resolution actions | Delivery exceptions, return QC, sync errors |
| `SummaryBanner` | KPI summary bar for detail pages | Order detail (total/paid/outstanding), customer detail, trip detail |
| `FilterBar` | Standardized filter row (status tabs + search + date range + dropdowns) | Every list page |
| `ActionDrawer` | Right-side slide-out panel for contextual actions | Quick create payment, quick create order, bulk operations |
| `SyncStatusBadge` | synced/pending/failed indicator | Mobile-originated records on web |
| `AgeingChart` | Horizontal stacked bar for overdue buckets | Credit risk dashboard, customer detail, accountant dashboard |
| `ProgressTracker` | Step-by-step horizontal progress indicator | Order lifecycle, delivery trip, onboarding |

**Consistent status chips map (shared constant):**

```typescript
export const STATUS_VARIANTS: Record<string, BadgeVariant> = {
  draft: 'secondary',
  submitted: 'warning',
  pending: 'warning',
  on_hold: 'warning',
  approved: 'success',
  confirmed: 'success',
  rejected: 'danger',
  cancelled: 'danger',
  void: 'danger',
  dispatched: 'default',
  in_progress: 'default',
  delivered: 'success',
  completed: 'success',
  paid: 'success',
  failed: 'danger',
  reversed: 'danger',
  partial_delivery: 'warning',
  partially_paid: 'warning',
  overdue: 'danger',
  blocked: 'danger',
  active: 'success',
  inactive: 'secondary',
};
```
