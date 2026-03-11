# OrdWave — Enterprise UI/UX Revamp: Global Framework

> Transform a functional admin panel into a clear, action-first, role-aware enterprise OMS that communicates operational meaning at a glance.

---

## Part 1: Global Anti-Patterns ("Why It Feels Like an Admin Panel")

### What's wrong today across all 109 pages

| Anti-pattern | Where it shows up | Why it hurts |
|---|---|---|
| **Flat table with no summary layer** | Orders, Customers, Suppliers, Invoices, Collections, Inventory — every list page | User must mentally aggregate what the table shows. No business context above the table. |
| **Equal visual weight everywhere** | Every page has same-weight PageHeader → filters → DataTable | Nothing looks urgent, important, or time-sensitive. |
| **Generic page titles with no business subtitle** | "Purchase Invoices", "Customers", "Products" — no explanation of purpose | A new user can't tell what this page helps them *do*. |
| **No urgency differentiation** | Overdue invoices, credit-blocked customers, failed deliveries all look the same as normal rows | Operational issues hide in noise. |
| **Identical buttons everywhere** | Add/Create buttons all look the same; no primary vs secondary action distinction | No clear "what should I do next?" signal. |
| **No KPI/summary strip on detail pages** | Order detail, Customer detail, Supplier detail — jump straight to tabs | User has to mentally compute totals, outstanding, overdue. |
| **Forms without guidance** | Purchase Invoice form, Order form — bare input grids | No helper text, no "why", no progressive disclosure. |
| **No empty state storytelling** | Many pages show "No X found." | Missed onboarding/activation opportunity. Doesn't explain what to do. |
| **Status badges with no business meaning** | "Draft", "Posted", "Active" — technical labels | "Awaiting approval", "Ready to collect", "Payment overdue 15d" — business labels missing. |
| **No contextual quick actions** | Must navigate away to take related actions | E.g., can't create an order from a customer detail page, can't record payment from invoice detail. |
| **Comments/sections use code dividers** | `// ── Step 2: Business Setup ──` style comments | Not a user issue, but indicates low component extraction; pages are monolithic 500-1300 line files. |

---

## Part 2: Global Visual Hierarchy Framework

### Information Layers (apply to every page)

```
Layer 1 — PAGE HERO (first 100px)
  Page title + business subtitle + primary CTA
  Role: Instantly answers "what is this page and what can I do?"

Layer 2 — OPERATIONAL SUMMARY (next 80px)
  KPI strip / metric cards / alert banner
  Role: Answers "what is the current state of this area?"

Layer 3 — FILTERS & SEGMENTATION (next 48px)
  Status tabs + search + date range + contextual dropdowns
  Role: Answers "how do I narrow down to what I need?"

Layer 4 — PRIMARY CONTENT (remaining viewport)
  DataTable / Cards / Kanban / Timeline
  Role: The actual data, with row-level urgency indicators

Layer 5 — CONTEXTUAL ACTIONS (floating / sticky)
  Sticky footer bar on forms, row-level quick actions, FAB on mobile
  Role: Answers "what action should I take on this item?"
```

### Page Template System

**Template A — List Page** (Orders, Customers, Invoices, Suppliers, etc.)
```
┌─────────────────────────────────────────────────┐
│ PageHeader: Title + subtitle + primary CTA      │  ← Layer 1
├─────────────────────────────────────────────────┤
│ KPI Strip: 4-5 metric cards (count/amount)      │  ← Layer 2
├─────────────────────────────────────────────────┤
│ Alert Banner (conditional): overdue / blocked   │  ← Layer 2b
├─────────────────────────────────────────────────┤
│ Status Tabs │ Search │ Filters │ Clear          │  ← Layer 3
├─────────────────────────────────────────────────┤
│ DataTable with status chips, row actions, sort  │  ← Layer 4
│   ... rows with urgency indicators ...          │
├─────────────────────────────────────────────────┤
│ Pagination: Page X of Y │ Prev │ Next           │
│ Summary bar: Total ₹X across Y items           │  ← Layer 5
└─────────────────────────────────────────────────┘
```

**Template B — Detail Page** (Order [id], Customer [id], Invoice [id], etc.)
```
┌─────────────────────────────────────────────────┐
│ Breadcrumbs: Module > Item Name                  │
├─────────────────────────────────────────────────┤
│ PageHeader: Entity name + ID badge + status     │  ← Layer 1
│ Action buttons: primary action + secondary btns │
├─────────────────────────────────────────────────┤
│ Summary Strip: 4 key metrics (total/paid/due)   │  ← Layer 2
├─────────────────────────────────────────────────┤
│ Alert Banner: overdue / credit issue / exception│  ← Layer 2b
├─────────────────────────────────────────────────┤
│ Tabs: Overview │ Lines │ Payments │ Timeline    │  ← Layer 3-4
│ ┌─────────────────────────────────────────────┐ │
│ │ Tab content area                            │ │
│ └─────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────┤
│ Related Quick Actions: "Create Payment" etc.    │  ← Layer 5
└─────────────────────────────────────────────────┘
```

**Template C — Form Page** (New Order, New Invoice, New Supplier, etc.)
```
┌─────────────────────────────────────────────────┐
│ PageHeader: "New X" + cancel link                │  ← Layer 1
├─────────────────────────────────────────────────┤
│ Section Card 1: Primary fields with labels      │
│  Helper text beneath each field                  │
├─────────────────────────────────────────────────┤
│ Section Card 2: Line items table (if applicable)│
│  Auto-fill hints, product picker                │
├─────────────────────────────────────────────────┤
│ ▓▓▓▓ Sticky Footer Bar ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │  ← Layer 5
│ │ Totals summary │        Cancel │ Save │       │
└─────────────────────────────────────────────────┘
```

**Template D — Dashboard Page**
```
┌─────────────────────────────────────────────────┐
│ Greeting: "Good morning, {name}" + date + branch│  ← Layer 1
├─────────────────────────────────────────────────┤
│ Alert Cards: items requiring attention (count)  │  ← Layer 2
│ [3 Approvals] [5 Overdue] [2 Low Stock]         │
├──────────────────────┬──────────────────────────┤
│ KPI Metric Cards     │  Quick Actions            │  ← Layer 3
│ Revenue / Orders /   │  [Create Order]           │
│ Collections / AR     │  [Record Payment]         │
├──────────────────────┴──────────────────────────┤
│ Charts: Sales Trend + Order Pipeline             │  ← Layer 4
├─────────────────────────────────────────────────┤
│ Tables: Top Overdue + Recent Activity            │  ← Layer 5
└─────────────────────────────────────────────────┘
```

---

## Part 3: Design Token Recommendations

### Typography Hierarchy (enforce across all pages)

| Element | Tailwind Classes | When to use |
|---|---|---|
| Page Title | `text-2xl font-bold text-text-primary` | PageHeader title |
| Page Subtitle | `text-sm text-text-secondary` | Below page title — *always add this* |
| Section Title | `text-lg font-semibold text-text-primary` | Card headers, section starts |
| Metric Value | `text-2xl font-bold text-text-primary` | KPI card numbers |
| Metric Label | `text-xs font-medium text-text-secondary uppercase tracking-wide` | KPI card labels |
| Table Header | `text-xs font-medium text-text-secondary uppercase tracking-wide` | DataTable thead |
| Table Cell Primary | `text-sm font-medium text-text-primary` | Name, invoice #, amount |
| Table Cell Secondary | `text-sm text-text-secondary` | Date, code, supporting info |
| Helper Text | `text-xs text-text-secondary` | Below form fields |
| Alert Text | `text-sm` with variant color | Alert/banner content |

### Color Semantics (strict enforcement)

| Semantic | Tailwind bg/text | Use for |
|---|---|---|
| **Success / Complete** | `bg-emerald-50 text-emerald-700` / badge `success` | Active, Delivered, Paid, Approved, Synced |
| **Warning / Attention** | `bg-amber-50 text-amber-700` / badge `warning` | Pending, On Hold, Partial, Submitted |
| **Danger / Urgent** | `bg-red-50 text-red-700` / badge `danger` | Overdue, Blocked, Failed, Rejected, Cancelled |
| **Info / In-progress** | `bg-blue-50 text-blue-700` / badge `default` | Dispatched, In Progress, Processing |
| **Neutral / Draft** | `bg-gray-100 text-gray-600` / badge `secondary` | Draft, Inactive, Not started |
| **Primary / Brand** | `bg-primary text-white` | Primary CTA, sidebar, brand elements |

### Card Hierarchy

| Card Type | Style | Use for |
|---|---|---|
| **Metric Card** | `border border-border bg-white p-4 rounded-lg` with icon left, value right | KPI strips on dashboards and list pages |
| **Alert Card** | `border-l-4 border-{severity} bg-{severity}/5 p-4 rounded-lg` | Overdue warnings, credit blocks, exceptions |
| **Content Card** | `border border-border bg-white rounded-lg` with CardHeader/Content | Form sections, tab panels, detail sections |
| **Action Card** | `border-2 border-dashed border-border hover:border-primary p-4 rounded-lg cursor-pointer` | Empty state CTAs, add-new prompts |

### Badge Style Rules

| State | Badge | Extra indicator |
|---|---|---|
| Overdue | `danger` + dot | Red text showing "15d overdue" |
| Credit Blocked | `danger` + icon `Ban` | Red banner at top of customer/order |
| On Hold | `warning` + icon `Clock` | Yellow banner + "Awaiting approval" |
| Ready for action | `success` + pulsing dot | Green shimmer animation |
| Synced from mobile | `default` + icon `Smartphone` | Subtle tag "via mobile" |
