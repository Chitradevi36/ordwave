# OrdWave — UI/UX Revamp: Modules 18–25

## Module 18: Collection Schedule

**Page purpose:** Plan and track collection visits — which customers need field collection and when.
**Who uses it:** Sales Rep (own schedule), Branch Manager (monitor collection activity), Accountant (track progress).
**Key decision:** "Where should sales reps go today to collect money?"

**Current UX problem:** Exists in basic form. No map view. No integration with beat plans. No collection efficiency metrics.

**Desired perception:** "Today's collection plan is clear, optimized, and trackable in real-time."

**Layout blueprint:**
1. PageHeader: "Collection Schedule" + subtitle "Plan and track field collection visits" + [Schedule Collection Visit]
2. KPI strip: Scheduled Today (count), Completed (count), Collected Today (₹), Target (₹), Completion %
3. View toggle: [Calendar] [List] [Map] — map shows customer pins with collection amounts
4. Calendar view: week calendar with collection visits as cards (customer + amount + rep name)
5. List view: DataTable with columns:
   - Date + Time
   - Customer (name + address)
   - Expected Amount (₹)
   - Sales Rep
   - Status (Scheduled / In Progress / Completed / Missed)
   - Actual Collected (₹) — filled after collection
   - Actions: [Record Payment] [Reschedule] [Mark Missed]
6. Map view: Google Maps with customer markers colored by overdue severity + rep route

**Acceptance criteria:**
- Map view shows customer pins with collection amounts (red=high priority, amber=medium, green=low)
- "Record Payment" from schedule creates payment + marks visit complete
- Missed visits are auto-flagged at end of day
- Sales rep sees only own schedule on mobile
- Branch manager sees all reps' schedules
- Collection efficiency metric: collected ₹ / target ₹ as percentage

**Design direction:** Field service scheduling (Salesforce Field Service Lightning style) adapted for collection routes.

---

## Module 19: Inventory (Stock Levels)

**Page purpose:** Real-time view of stock levels across products and branches/warehouses.
**Who uses it:** Warehouse (primary — multiple times daily), Branch Manager (stock decisions), Owner (inventory value).
**Key decision:** "What's in stock? What's running low? Do I need to reorder?"

**Current UX problem:** 588 lines list + 802 lines detail. Has stock data but no reorder point alerts. No stock movement history visualization. No valuation summary.

**Desired perception:** "Stock levels are visible, alerts fire before stockouts, and I can trace every movement."

**Visual hierarchy:**
- **Primary:** Product + current stock qty + stock status indicator
- **Secondary:** Reorder level alert + last movement date
- **Tertiary:** Valuation, average cost, branch breakdown

**Layout blueprint (list):**
1. PageHeader: "Inventory" + subtitle "Real-time stock levels and movement tracking" + [Stock Adjustment] + [Transfer Stock]
2. KPI strip: Total SKUs, In Stock, Low Stock (amber), Out of Stock (red), Inventory Value (₹)
3. Alert: "14 products are below reorder level — create purchase invoices to replenish"
4. Search + category filter + stock status filter (All / In Stock / Low / Out of Stock)
5. DataTable:
   - Product (thumbnail + name + code)
   - Current Stock (qty, color-coded)
   - Reorder Level + **Status**: `🟢 OK` / `🟠 Below Reorder (12 remaining, reorder at 20)` / `🔴 Out of Stock`
   - Last Movement (date + type: Purchase/Sale/Transfer/Adjustment)
   - Avg Cost (₹) + Total Value (₹)
   - Actions: [View Movements] [Adjust Stock] [Create Purchase Invoice]
6. Bottom: "Total Inventory Value: ₹12,45,000"

**Layout blueprint (detail):**
1. Product header: image + name + code + current stock qty (large number)
2. Stock by branch/warehouse table (if multi-branch)
3. **Stock movement chart**: line chart showing stock level over time (last 30/60/90 days)
4. Movement history table: date, type (purchase/sale/transfer/adjustment), qty (+/-), reference, actor

**Acceptance criteria:**
- Stock status is color-coded (green/amber/red) based on reorder level
- Reorder alert counts products below their defined reorder point
- "Create Purchase Invoice" pre-fills with product + suggested qty (reorder point - current stock)
- Stock movement chart shows visual trend
- Stock adjustments require a reason (Damage, Theft, Expiry, Count Correction, Other)
- Branch-level stock breakdown visible on detail page

**Design direction:** TradeGecko/Cin7 inventory dashboard. Stock health at a glance with movement traceability.

---

## Module 20: Stock Transfers

**Page purpose:** Transfer stock between branches/warehouses.
**Who uses it:** Branch Manager (request/approve), Warehouse (execute), Owner (review).
**Key decision:** "Which branch needs stock and which has excess? Transfer efficiently."

**Current UX problem:** May exist as basic page. No transfer request workflow. No in-transit tracking.

**Desired perception:** "Stock moves between branches with clear tracking and receipt confirmation."

**Layout blueprint:**
1. PageHeader: "Stock Transfers" + subtitle "Move inventory between branches" + [Create Transfer]
2. Status tabs: `All | Draft | In Transit | Received | Cancelled`
3. DataTable:
   - Transfer # + Date
   - From Branch → To Branch
   - Items (count) + Total Qty
   - Status badge
   - Sent By / Received By
   - Actions: [Mark Dispatched] [Confirm Receipt] [View]
4. Form: From branch → To branch → product picker (shows stock at source) + qty per item → notes → [Create Draft] [Send]
5. Receipt: Receiving branch confirms quantities received (may differ from sent — discrepancy noted)

**Acceptance criteria:**
- Transfer shows available stock at source branch before adding qty
- Cannot transfer more than available stock
- Receipt confirmation allows noting discrepancies (received qty ≠ sent qty)
- Discrepancies logged for audit
- Stock levels updated at both branches after receipt confirmation

**Design direction:** Internal logistics — clean request/approve/dispatch/receive workflow.

---

## Module 21: Returns

**Page purpose:** Process product returns from customers — track reason, condition, restock decision.
**Who uses it:** Warehouse (receive returns), Branch Manager (approve), Accountant (credit note linkage).
**Key decision:** "Accept or reject this return? Restock or write off?"

**Current UX problem:** Exists but minimal. No connection to delivery exceptions. No restock/write-off decision workflow.

**Desired perception:** "Returns are processed systematically with clear disposition and financial impact."

**Layout blueprint:**
1. PageHeader: "Returns" + subtitle "Process customer returns and manage restocking" + [Create Return]
2. KPI strip: Returns MTD (count), Total Value (₹), Restocked (count), Written Off (count)
3. Status tabs: `All | Pending | Received | Inspected | Restocked | Written Off | Credit Issued`
4. DataTable:
   - Return # + Date
   - Customer
   - Order # (linked)
   - Items (count) + Value (₹)
   - Reason (badge: Damaged / Expired / Wrong Item / Quality Issue / Customer Changed Mind)
   - Disposition: Restock / Write Off / pending decision
   - Credit Note # (linked, if issued)
   - Status badge
   - Actions: [Receive] [Inspect] [Restock] [Write Off] [Create Credit Note]
5. Form: customer → order (dropdown of delivered orders) → select items + qty + reason per item + condition assessment → disposition decision

**Acceptance criteria:**
- Returns link to source order
- Each line item has its own reason + condition assessment
- Disposition decision: Restock (updates inventory +) or Write Off (records loss)
- "Create Credit Note" auto-fills from return items + values
- Returns from delivery exceptions auto-created and linked
- Reason analytics visible in dashboard (top return reasons chart)

**Design direction:** Amazon seller returns processing. Structured disposition workflow.

---

## Module 22: Reports & Insights

**Page purpose:** Analytical reports and data exports for business intelligence.
**Who uses it:** Owner (strategic review), Accountant (statutory reports), Branch Manager (operational reports).
**Key decision:** "How is the business performing? Where are the problems?"

**Current UX problem:** Basic insights page exists (~480 lines). May have some charts. No drill-down. No report scheduler. No export to Excel with formatting.

**Desired perception:** "Data-driven decisions at my fingertips — any metric, any period, drill down to details."

**Layout blueprint:**
1. PageHeader: "Reports & Insights" + subtitle "Business intelligence and analytics"
2. Report categories (card grid):
   - **Sales**: Revenue trend, Product-wise sales, Customer-wise sales, Sales rep performance
   - **Collections**: Collection efficiency, Ageing analysis, DSO trend, Cash flow forecast
   - **Inventory**: Stock movement, Reorder report, Dead stock analysis, Valuation report
   - **Operations**: Order fulfillment rate, Delivery success rate, Return rate, Exception analysis
   - **Compliance**: GST summary (GSTR-1/3B), TDS report, Outstanding receivables > 6 months
3. Each report opens as:
   - Filter bar: date range + branch + category/customer/product (contextual)
   - Visualization: chart + summary KPIs
   - Data table: detailed table below chart
   - Export: [Download Excel] [Download PDF] [Schedule Email]
4. Scheduled reports section: configure weekly/monthly email delivery

**Acceptance criteria:**
- At least 15 pre-built report templates
- Every report has date range + branch filter
- Drill-down: click a chart segment to filter the table below
- Excel export maintains formatting (headers, borders, totals)
- Scheduled reports configurable (daily/weekly/monthly email)
- GSTR reports follow standard government format

**Design direction:** Metabase/Looker-style report library. Clean, filterable, exportable.

---

## Module 23: Notifications

**Page purpose:** Centralized notification center for all system alerts and updates.
**Who uses it:** All roles.
**Key decision:** "What happened that I need to know about?"

**Current UX problem:** May exist as bell icon dropdown. No notification center page. No notification preferences.

**Desired perception:** "I'm informed about what matters and not overwhelmed by noise."

**Layout blueprint:**
1. Bell icon in AppShell header: badge count of unread notifications
2. Dropdown panel (quick view): last 5 notifications → [View All]
3. Full page `/notifications`:
   - Filter pills: `All | Unread | Orders | Payments | Approvals | Inventory | System`
   - Notification list: icon + message + timestamp + read/unread dot + action link
   - Bulk actions: [Mark All Read] [Clear All]
4. Notification settings page (`/settings/notifications`):
   - Category matrix: Notification type × Channel (In-App | Email | SMS | WhatsApp)
   - Role-based defaults pre-set

**Notification types:**
- Order submitted/approved/rejected/on hold
- Payment received/bounced
- Approval required (credit limit, stock adjustment)
- Low stock alert
- Overdue collection reminder
- Delivery exception
- System: new feature, maintenance window

**Acceptance criteria:**
- Real-time bell badge count (WebSocket or polling)
- Click notification → navigates to relevant page
- Notification preferences per channel
- Unread indicator per notification
- Batch mark-as-read
- Role-based default preferences (e.g., Warehouse gets inventory alerts, not finance)

**Design direction:** GitHub notifications panel. Clean, filterable, actionable.

---

## Module 24: User Management

**Page purpose:** Manage team members — invite, assign roles, manage access, deactivate.
**Who uses it:** Owner (exclusive — user management is owner-only).
**Key decision:** "Who has access? What can they do? Who should I add/remove?"

**Current UX problem:** Basic invite/manage page. No activity log per user. No last active indicator. No permission detail view.

**Desired perception:** "My team is organized with clear roles, and I know who's active."

**Layout blueprint:**
1. PageHeader: "Team" + subtitle "Manage users, roles, and access" + [Invite User]
2. KPI strip: Total Users, Active, Inactive, Roles breakdown (Owner: 1, BM: 2, SR: 5, etc.)
3. DataTable:
   - User (avatar + name + email)
   - Role (badge, colored per role)
   - Branch (assigned branch)
   - Status (Active / Inactive / Invited — pending)
   - Last Active (relative: "2h ago" / "3d ago" / "Never" for pending invites)
   - Actions: [Edit Role] [Deactivate] [Resend Invite] [View Activity]
4. Invite modal: name + email + phone + role dropdown + branch assignment → sends invite email/SMS
5. User detail: profile info + role + permissions list + activity log (last 50 actions)

**Acceptance criteria:**
- Invite flow sends email with setup link
- Pending invites show "Invited" status with [Resend] option
- Deactivation requires confirmation + reason
- "Last Active" updates from login timestamps
- Role-based permissions visible as checklist (read-only display)
- Activity log shows last 50 actions by this user

**Design direction:** Notion/Linear team management. Simple, clear, with activity context.

---

## Module 25: Settings

**Page purpose:** Application configuration — business info, billing, preferences, integrations.
**Who uses it:** Owner (primary), Branch Manager (branch-specific settings).
**Key decision:** "How should my system behave? What are the business rules?"

**Current UX problem:** 413 lines main page + 10+ sub-setting pages. Flat list of settings categories. Navigation between sub-settings pages is unclear.

**Desired perception:** "All configuration organized logically — I can find and change any setting easily."

**Layout blueprint:**
1. PageHeader: "Settings" + subtitle "Configure your business, billing, and system preferences"
2. Left sidebar nav (within settings): categories list
3. Right content area: selected category's settings
4. Categories:
   - **Business Profile**: Company name, logo, address, GSTIN, PAN, contact info
   - **Branches**: List branches, add/edit branch, assign warehouse, assign users
   - **Billing & Subscription**: Current plan, usage, upgrade, payment method, invoices
   - **Credit Policy**: Default credit limit, auto-hold rules, overdue thresholds, approval required above ₹X
   - **Tax Configuration**: GST rates, HSN defaults, TDS settings, cess configuration
   - **Invoice Settings**: Invoice prefix, numbering, template customization, terms & conditions text
   - **Order Settings**: Auto-approval rules, minimum order value, order expiry days
   - **Delivery Settings**: Auto-create trips, trip assignment rules, POD requirements
   - **Notification Preferences**: (links to notification settings)
   - **Integrations**: Tally sync, SMS gateway, WhatsApp Business, payment gateway
   - **Import / Export**: Bulk data import (CSV), data export, backup
   - **Audit Log**: System-wide audit log (searchable, filtered by actor/action/entity)
5. Each setting: label + current value + edit control (toggle/input/dropdown) + save per section

**Acceptance criteria:**
- Settings organized with left sidebar navigation (not flat cards)
- Each section saves independently (no full-page save)
- Credit policy settings immediately affect order flow
- Invoice template preview before saving
- Audit log searchable by date range, actor, action type
- "Branches" section shows branch list with user counts per branch
- Settings changes are logged in audit log

**Design direction:** Stripe settings page. Left nav → right content pane. Clean sections, save-per-section.
