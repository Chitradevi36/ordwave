# OrdWave — UI/UX Revamp: Modules 1–8

## Module 1: Dashboard

**Page purpose:** Executive cockpit showing business health, operational urgency, and next actions.
**Who uses it:** Owner (daily, multiple times), Branch Manager (daily), Accountant (daily), Warehouse (hourly).
**Key decision:** "What needs my attention right now?"

**Current UX problem:** Shows KPI cards + charts but no urgency signals. No alerts panel. Same layout for all roles. Activity feed absent. Feels like a reporting page, not a command center.

**Desired perception:** "My business is running smoothly — or here's exactly what needs my attention."

**Visual hierarchy:**
- **Primary:** Alert cards row (items needing action — count badges, clickable)
- **Secondary:** KPI metric cards (revenue, orders, collections, outstanding)
- **Tertiary:** Charts (sales trend, order pipeline) + top overdue table

**Layout blueprint:**
1. Greeting bar: "Good morning, Rajesh · Mon 10 Mar · Hyderabad Branch" + branch switcher
2. Alert row: `[3 Pending Approvals] [5 Overdue Collections ₹2.4L] [2 Failed Deliveries] [4 Low Stock Items]` — each clickable, danger/warning colored
3. KPI cards: Revenue Today, Revenue MTD, Outstanding AR, Overdue %, Orders Today, Collections Today — with sparkline trends and ↑↓ change indicators
4. Two-column: Left = Sales trend (7d/30d toggle), Right = Order pipeline funnel (submitted→approved→dispatched→delivered)
5. Two-column: Left = Top 5 overdue customers table (name, amount, days overdue), Right = Recent activity feed (last 20 events with actor + timestamp)

**UI components needed:** `MetricCard` (with sparkline), `AlertActionCard`, `ActivityFeedItem`, `GreetingBar`, `SalesTrendChart` (exists — enhance with toggle)

**Microcopy improvements:**
- Page subtitle: "Your business at a glance — focus on what needs attention first"
- Empty state: "Welcome to OrdWave! Complete your setup checklist to start seeing real-time business insights here."
- Alert labels: "5 collections overdue by ₹2.4L" not "5 overdue"

**Role-based variation:**
| Role | Sees first | Hidden | Collapsed |
|---|---|---|---|
| Owner | Alerts + Revenue KPIs + All charts | Nothing | Warehouse section |
| Branch Manager | Alerts (approvals/exceptions) + Ops KPIs | Revenue, Billing | Finance charts |
| Accountant | Finance alerts + Outstanding AR + Ageing chart | Inventory, Delivery | Sales trend |
| Warehouse | Pick queue + dispatch queue + low stock | Finance, Collections | All charts |
| Sales Rep | N/A (mobile-first — see beat plan) | — | — |
| Driver | N/A (mobile-only — see trip) | — | — |

**Backend/UI signals needed:**
- API: `/api/v1/dashboard/alerts` — aggregated counts for approvals, overdue, exceptions, low stock
- API: `/api/v1/dashboard/kpis` — metric values with trend data
- WebSocket or 30s polling for real-time alert updates

**Acceptance criteria:**
- Alert cards load within 1s, show real counts from API
- Clicking an alert navigates to filtered list (e.g., clicking "5 Overdue" → `/collections?status=overdue`)
- KPI cards show percentage change vs yesterday/last period
- Activity feed shows real last 20 events from audit_logs
- Branch switcher changes all KPIs instantly without page reload
- Empty state with onboarding checklist shown when account < 7 days old

**Design direction:** Enterprise command center. Think Stripe Dashboard or SAP Fiori Launchpad — not a chart gallery.

---

## Module 2: Approvals Inbox

**Page purpose:** Single screen to review and act on all items requiring managerial approval.
**Who uses it:** Branch Manager (multiple times daily), Owner (daily review).
**Key decision:** "Approve or reject this request, and why?"

**Current UX problem:** Only shows credit limit change requests (326 lines). No unified inbox. Order holds, stock adjustments, and payment reversals are scattered across different pages.

**Desired perception:** "Everything waiting for my decision is here, sorted by urgency."

**Visual hierarchy:**
- **Primary:** Action buttons (Approve/Reject) — always visible per card
- **Secondary:** Request summary (who, what, when, how much)
- **Tertiary:** Reasoning/context (why it triggered, historical context)

**Layout blueprint:**
1. PageHeader: "Approvals" + subtitle "Review and decide on pending requests" + badge count
2. Alert banner (conditional): "3 requests older than 24h — these may be blocking operations"
3. Tab bar: `All (12) | Orders on Hold (5) | Credit Limits (3) | Stock Adjustments (2) | Payment Reversals (2)`
4. Card list (not table): Each card = `ApprovalCard` with:
   - Left: entity icon + type badge (order/credit/stock/payment)
   - Center: summary (e.g., "Rajesh requested credit limit increase from ₹50K to ₹1L for ABC Mart")
   - Context row: "Current outstanding: ₹32K · Last 3 payments on time · Customer since Jan 2024"
   - Right: Approve (green) + Reject (red) buttons + expand for reason field
   - Age indicator: "2h ago" / "⚠️ 3d ago" with warning color if > 24h
5. Bulk approve bar (bottom sticky): "Select items → Approve All Selected"

**UI components needed:** `ApprovalCard` (new shared component), `BulkActionBar`

**Microcopy improvements:**
- Subtitle: "Review and decide on pending requests — your team is waiting"
- Age warning: "This request has been waiting 3 days — it may be delaying operations"
- Empty state: "All caught up! No pending approvals."
- Rejection reason placeholder: "Brief reason for rejection (visible to requestor)…"

**Backend/UI signals needed:**
- API: Unified endpoint `/api/v1/approvals` aggregating orders (status: on_hold), credit limit requests (pending), stock adjustments (pending_approval), payment reversals (pending_approval)
- WebSocket or polling for real-time count updates
- `created_at` for age calculation

**Acceptance criteria:**
- Unified inbox shows all 4 approval types
- One-click approve works without page navigation
- Reject requires a reason (text field expands inline)
- Bulk approve available for low-risk items
- Tab counts update after action without page reload
- Items > 24h old show amber warning
- Items > 72h old show red urgent indicator

**Design direction:** Linear-style inbox with action-first cards. Not a table — each item is a decision card.

---

## Module 3: Retailers (Customer List)

**Page purpose:** CRM view of all retailers/customers with credit health at a glance.
**Who uses it:** Owner (weekly review), Branch Manager (daily), Sales Rep (daily — own customers), Accountant (for credit/collection context).
**Key decision:** "Which customers need attention? Who's overdue? Who can I sell to safely?"

**Current UX problem:** 620 lines. Has saved views and credit usage bars — better than most pages. But no summary KPIs, no risk flagging in the list, no quick actions from list.

**Desired perception:** "My entire customer portfolio health in one view."

**Visual hierarchy:**
- **Primary:** Customer name + outstanding amount + credit utilization bar
- **Secondary:** Status badge + risk flags (overdue, on hold, watchlist)
- **Tertiary:** Contact info, last order date, location

**Layout blueprint:**
1. PageHeader: "Retailers" + subtitle "Your customer portfolio — manage relationships and credit" + [Add Retailer] primary CTA
2. KPI strip: Total Customers, Active, On Credit Hold, Total Outstanding (₹), Total Overdue (₹)
3. Alert banner (conditional): "12 customers are overdue by more than 30 days — total ₹5.2L at risk"
4. Saved views tabs + search + status filter + credit risk filter dropdown (All / At Risk / On Hold / Healthy)
5. DataTable with columns:
   - Customer (name + code + last order date)
   - Credit Usage (CreditUsageBar — ₹32K/₹50K + % bar)
   - Outstanding (₹ amount, red if overdue days > 0)
   - Risk Flags (badges: 🔴 Hold | ⚠️ Watchlist | 🟠 Collect First)
   - Last Order (date + "14d ago" relative)
   - Location (city, state)
   - Quick actions: [Create Order] [Record Payment] [View]
6. Bottom bar: "Showing 25 of 342 · Total Outstanding: ₹18.5L"

**Microcopy improvements:**
- Subtitle: "Your customer portfolio — manage relationships, credit, and collections"
- Credit usage bar tooltip: "₹32,000 of ₹50,000 limit used (64%) · ₹8,000 overdue by 22 days"
- Empty state: "No retailers yet. Add your first retailer to start taking orders."
- Risk column header tooltip: "Risk flags are set based on your credit policy. Hold = orders blocked. Watchlist = manual review suggested."

**Role-based variation:**
| Role | Sees | Hidden |
|---|---|---|
| Owner | All customers, all columns | Nothing |
| Branch Manager | Branch customers, all columns | Other branches |
| Sales Rep | Own customers only | Credit limit, credit policy actions |
| Accountant | All customers, credit-focused columns | Add/Edit customer |

**Acceptance criteria:**
- KPI strip loads < 500ms
- Credit usage bars with color coding (green < 70%, amber 70-90%, red > 90%)
- Risk flags visible in list without expanding row
- "Create Order" quick action opens order form pre-filled with customer
- Overdue amounts show in red with days count
- Bulk import retains existing functionality
- Saved views work with new filters

**Design direction:** Stripe's customer list meets a CRM health dashboard. Credit-first visual emphasis.

---

## Module 4: Retailer Profile (Customer Detail)

**Page purpose:** Complete 360° view of a retailer: credit health, order history, payment history, contacts, addresses.
**Who uses it:** Branch Manager (when reviewing a customer), Sales Rep (before visiting), Accountant (for collection follow-up).
**Key decision:** "Is this customer healthy? Should I extend credit? What's their payment pattern?"

**Current UX problem:** 1,372 lines — the largest page. Has tabs (details, credit, orders, contacts, addresses) but no summary banner. Credit account is a tab you have to click into. No payment history tab. No timeline.

**Desired perception:** "Everything I need to know about this customer, starting with what matters most."

**Visual hierarchy:**
- **Primary:** Credit status banner (outstanding, limit, overdue, flags) — always visible in header
- **Secondary:** Quick stats strip (total orders, total revenue, avg order value, last payment)
- **Tertiary:** Tabs with order/payment/visit history

**Layout blueprint:**
1. Breadcrumb: Retailers > ABC Mart
2. PageHeader: "ABC Mart" + code badge `ABM-001` + status badge `Active` + action buttons [Edit] [Create Order] [Record Payment]
3. **CreditBanner** (always visible, not in a tab):
   ```
   ┌────────────────────────────────────────────────────────────┐
   │ 🟢 Credit Healthy                                         │
   │ Outstanding: ₹32,000 / ₹50,000 (64%)  │ Overdue: ₹0      │
   │ Last payment: 5 days ago               │ Avg pay: 18 days  │
   │ ███████████████░░░░░░░░ 64%                               │
   └────────────────────────────────────────────────────────────┘
   ```
   Variant when overdue: red border, "⚠️ ₹8,000 overdue by 22 days — collection recommended"
4. Stats strip: [Total Orders: 47] [Lifetime Revenue: ₹8.2L] [Avg Order: ₹17,400] [Payment Score: 85/100]
5. Reordered tabs: **Overview | Orders | Payments | Credit Account | Contacts | Addresses | Activity Timeline**
6. Overview tab: contact info + address + notes + risk flags — enhanced with clickable phone/email
7. **Activity Timeline tab** (new): unified feed of all orders, payments, credit changes, visits — visual timeline component

**UI components needed:** `CreditBanner` (shared), `SummaryStrip`, `ActivityTimeline`, `PaymentScore` gauge

**Microcopy improvements:**
- Credit banner label: "Credit Status" with "What does this mean?" info tooltip
- Overdue warning: "₹8,000 is 22 days overdue. Consider scheduling a collection visit."
- Payment score tooltip: "Based on last 6 months: on-time rate, average payment days, returned cheque count"
- Empty orders tab: "No orders yet. Create the first order for this customer."

**Acceptance criteria:**
- CreditBanner loads above tabs, never scrolls off screen (sticky)
- Credit utilization bar matches web/mobile color semantics (green/amber/red)
- "Create Order" button pre-fills customer in order form
- "Record Payment" opens ActionDrawer (side panel) with customer pre-filled
- Activity timeline shows chronological events with icons per type
- Phone numbers are clickable `tel:` links
- GSTIN links to GST verification portal

**Design direction:** Shopify customer profile meets credit dashboard. The credit banner is the hero — always visible.

---

## Module 5: Orders Pipeline (List)

**Page purpose:** Track all orders through their lifecycle — from submitted to delivered.
**Who uses it:** Branch Manager (hourly), Owner (daily), Sales Rep (own orders, multiple times daily).
**Key decision:** "Which orders need processing? Any stuck/on-hold? What's today's order volume?"

**Current UX problem:** 1,145 lines. Has status tabs, search, date filters, metrics, CSV export — the most feature-rich list page. But metrics are generic. No kanban option. No SLA indicator showing how long orders wait. No visual pipeline.

**Desired perception:** "My order pipeline is flowing — or here's exactly where orders are stuck."

**Visual hierarchy:**
- **Primary:** Status tabs with counts (the pipeline stages)
- **Secondary:** KPI strip (today's orders, total value, avg processing time)
- **Tertiary:** DataTable with urgency indicators per row

**Layout blueprint:**
1. PageHeader: "Orders" + subtitle "Track orders from submission to delivery" + [New Order] CTA + [Export CSV]
2. KPI strip: Orders Today (count), Total Value (₹), On Hold (count, amber), Avg Processing Time (hours)
3. Alert banner (conditional): "3 orders have been on hold for >24h — they may need approval"
4. View toggle: [List View] [Kanban Board] — top right
5. Status tabs: `All (45) | Submitted (8) | Approved (12) | Dispatched (15) | Delivered (10) | On Hold (3) | Cancelled (2)`
6. Search + date range + customer dropdown
7. DataTable with enhanced columns:
   - Order # (monospace, clickable) + date
   - Customer (name + credit status dot: 🟢🟠🔴)
   - Items (count) + Value (₹, bold)
   - Status (badge) + **Processing SLA** (e.g., "⚡ 2h" or "⚠️ 26h" if waiting > 24h)
   - Branch
   - Quick actions: [Approve] [Dispatch] [View] — contextual per status
8. Kanban alternative: columns = Submitted | Approved | Dispatched | Delivered — visual cards

**Microcopy improvements:**
- Subtitle: "Track orders from submission to delivery — process what needs attention first"
- SLA column tooltip: "Time since this order was submitted. Target: < 4h for approval."
- On Hold tab: "These orders are blocked by credit policy and need manual approval"
- Kanban empty column: "No orders at this stage right now"

**Role-based variation:**
| Role | Default view | Quick actions visible |
|---|---|---|
| Branch Manager | All, On Hold tab highlighted if count > 0 | Approve, Reject, Dispatch |
| Owner | All, overview | All |
| Sales Rep | Own orders only | View only |
| Accountant | Delivered tab (for invoicing) | Generate Invoice |

**Acceptance criteria:**
- Kanban view toggle works without page reload
- SLA timer shows live elapsed time since `submitted_at`
- On Hold count badge on tab turns red when > 0
- Quick approve from list (no navigation needed)
- Customer credit status dot visible in list (green/amber/red based on credit utilization)
- CSV export includes all visible columns

**Design direction:** Linear issue tracker pipeline meets Shopify orders list. SLA timer is the key differentiator.

---

## Module 6: Order Detail

**Page purpose:** Complete view of a single order — lines, pricing, credit decision, lifecycle, and related actions.
**Who uses it:** Branch Manager (to approve/act), Accountant (to invoice), Warehouse (to pick).
**Key decision:** "Should I approve this? What's the credit situation? Is this ready to dispatch?"

**Current UX problem:** 1,186 lines. Has tabs (lines, lifecycle, credit decision modal). Lifecycle tab is a table, not a visual timeline. No summary banner. Status actions are scattered.

**Desired perception:** "I can see exactly what this order is, its value, its credit impact, and what to do next."

**Visual hierarchy:**
- **Primary:** Status badge + primary action button (varies by status: Approve / Dispatch / Generate Invoice)
- **Secondary:** Summary strip (order total, paid, outstanding, items count)
- **Tertiary:** Line items table + lifecycle timeline

**Layout blueprint:**
1. Breadcrumb: Orders > ORD-2024-0047
2. PageHeader: "ORD-2024-0047" + status badge + age ("submitted 2h ago") + actions:
   - Status `submitted`: [Approve] primary, [Reject] danger, [Edit] outline
   - Status `approved`: [Create Delivery Trip] primary, [Edit] outline
   - Status `delivered`: [Generate Invoice] primary
   - Status `on_hold`: [Approve After Review] primary + credit warning banner
3. **Summary strip:**
   ```
   Subtotal: ₹12,400 │ Discount: ₹620 │ Tax (GST): ₹2,108 │ Total: ₹13,888 │ Paid: ₹0 │ Outstanding: ₹13,888
   ```
4. Credit impact banner (if on hold):
   ```
   ⚠️ Credit Check Failed — This order would push ABC Mart's outstanding to ₹63,888 (128% of ₹50,000 limit).
   Current overdue: ₹8,000 (22 days). Action required: Approve with override or Reject.
   ```
5. Tabs: **Lines | Payment History | Lifecycle | Scheme Applied**
6. Lines tab: product table with qty, unit price, discount, tax, line total
7. Lifecycle tab: **StatusTimeline** component (visual stepped timeline with actors, timestamps, reasons)
   ```
   ● Submitted — Rajesh (Sales Rep) · 10 Mar 2026, 09:15 AM
   ● Credit Check — Auto · 10 Mar 2026, 09:15 AM → On Hold (exceeds limit)
   ○ Approval — Awaiting manager action
   ○ Dispatch
   ○ Delivery
   ```
8. Scheme Applied section: which schemes/discounts were auto-applied, savings breakdown

**UI components needed:** `StatusTimeline` (shared), `SummaryStrip`, `CreditImpactBanner`, `OrderValueBreakdown`

**Acceptance criteria:**
- Primary action button changes based on order status
- Credit impact banner shows exact numbers (current outstanding + this order's total vs limit)
- StatusTimeline renders as visual steps, not a raw audit table
- "Generate Invoice" action available on delivered orders
- Order value breakdown shows subtotal → discount → tax → total (not just flat total)

**Design direction:** Stripe payment detail page. Clear summary, timeline, contextual actions.

---

## Module 7: Credit Engine

**Page purpose:** Portfolio-level view of credit risk across all customers.
**Who uses it:** Owner (weekly review), Accountant (daily), Branch Manager (operational decisions).
**Key decision:** "Which customers are risky? Should I tighten/loosen credit? Where is my money stuck?"

**Current UX problem:** Credit views exist on customer detail + credit limit approvals page + basic credit risk insights page. No unified credit dashboard showing portfolio health.

**Desired perception:** "I can see my entire receivables portfolio health and take action on risky accounts."

**Visual hierarchy:**
- **Primary:** Ageing chart (horizontal stacked bar by bucket — current/1-14d/15-29d/30-59d/60d+)
- **Secondary:** Risk bucket summary cards (count + amount per bucket)
- **Tertiary:** Customer-level risk table with actions

**Layout blueprint:**
1. PageHeader: "Credit & Receivables" + subtitle "Monitor credit health and manage risk across your customer portfolio"
2. KPI strip: Total AR (₹), Current (₹), Overdue (₹), Overdue %, Avg DSO (days)
3. **AgeingChart** component: horizontal stacked bar showing amount by bucket, color-coded green→amber→red
4. Risk bucket cards: `Current (₹8.2L) | 1-14d (₹2.1L) | 15-29d (₹1.4L) | 30-59d (₹0.8L) | 60d+ (₹0.3L)` — each clickable to filter table below
5. Customer risk table: sorted by overdue amount desc
   - Customer | Outstanding | Overdue | Days | Credit Util % | Risk Level | Actions [Hold] [Schedule Collection] [Adjust Limit]
6. Bulk actions: [Hold All Critical] [Export Ageing Report]

**UI components needed:** `AgeingChart` (shared), `RiskBucketCard`, `CreditPortfolioTable`

**Acceptance criteria:**
- Ageing chart renders within 1s
- Clicking a bucket filters the table to that overdue range
- Bulk hold available for critical-bucket customers
- "Schedule Collection" opens collection schedule pre-filled with customer + overdue amount
- Export produces formatted Excel with ageing buckets

**Design direction:** Banking-grade risk dashboard. Zoho Books receivables view meets Bloomberg terminal clarity.

---

## Module 8: Delivery Trips (List + Detail)

**Page purpose:** Monitor all delivery trips — dispatched, in progress, completed, with exceptions.
**Who uses it:** Branch Manager (hourly — track deliveries), Warehouse (dispatch planning), Owner (daily overview).
**Key decision:** "Are deliveries on track? Any exceptions? Which trips need dispatching?"

**Current UX problem:** 470 lines list, 1,026 lines detail. Basic list with auto-create modal. No trip progress visualization. Exceptions buried in separate page.

**Desired perception:** "I can see every trip's real-time progress and quickly handle problems."

**Visual hierarchy (list):**
- **Primary:** Trip progress bars (stops completed / total)
- **Secondary:** Exception count per trip (red indicator)
- **Tertiary:** Driver, vehicle, value, date

**Layout blueprint (list):**
1. PageHeader: "Delivery Trips" + subtitle "Monitor dispatches, track progress, and resolve exceptions" + [Create Trip] + [Auto-Create Trips]
2. KPI strip: Active Trips, Stops Completed Today, Exceptions Open, Total Value Dispatched (₹)
3. Alert banner: "2 trips have unresolved exceptions — click to review"
4. Status tabs: `All | Planned | Dispatched | In Progress | Completed | With Exceptions`
5. DataTable with:
   - Trip # + Date
   - Driver + Vehicle
   - Progress: `[████████░░] 8/10 stops` — visual bar
   - Value (₹)
   - Exceptions (count, red if > 0)
   - Status badge
   - Quick actions: [Dispatch] [View Stops] [View Exceptions]

**Layout blueprint (detail):**
1. PageHeader: "Trip #DT-047" + status + driver/vehicle info + actions [Dispatch] [Complete]
2. Summary strip: Stops (8/10 done), Value (₹48,000), Collected (₹12,000), Returns (₹2,400), Exceptions (1)
3. **ProgressTracker**: horizontal step bar showing each stop status (✓ Delivered, ● Current, ○ Pending, ✗ Failed)
4. Stops list: card per stop with:
   - Sequence # + Customer name + address
   - Items count + Value + Status badge
   - Exception details (if any) with resolution actions inline [Retry] [Skip] [Escalate]
   - POD info: signature captured, photo, timestamp
5. Timeline tab: chronological events (dispatched, stop 1 delivered, stop 2 failed, etc.)

**Acceptance criteria:**
- Progress bar renders per trip showing stops completed vs total
- Exception count column is red when > 0
- "With Exceptions" tab filters to trips having unresolved exceptions
- Auto-create trips modal shows preview before creating
- Completed trips show final summary (delivered ₹X, collected ₹Y, returned ₹Z)
- ProgressTracker on detail page updates as stops are completed

**Design direction:** Fleet management meets Uber trip tracking. Visual progress is the hero element.
