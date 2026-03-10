# Plan: Sales Navigation & Sidebar Redesign

## Diagnosis — Before State

### A. Current UX Problems (with code evidence)

| Symptom | Root Cause |
|---|---|
| 9 top-level nav items with identical visual weight | `WORKSPACE_NAV` has no visual priority — Dashboard sits alongside Accounting as equals |
| Sales flow is invisible | `/orders`, `/approvals`, `/collections`, `/returns` are ALL separate top-level URL trees with no visible parent-child relationship |
| Active state is too subtle | `bg-accent/15` + `w-0.5` left bar is easy to miss on a dark `#1B4332` sidebar |
| Finance group is overloaded | The `finance` matcher catches `/collections`, `/sales-invoices`, `/credit-notes`, `/advance-payments`, `/payments`, `/compliance`, `/supplier-debit-notes` — 7 distinct subsystems under one word |
| "Operations" is ambiguous | Matches `/delivery`, `/returns`, `/inventory/transfers` — these are conceptually different jobs |
| No sub-navigation renders | When "Sales" is active and you're in `/orders`, there's zero way to navigate to `/approvals` without going back to sidebar — no workspace sub-nav exists |
| No flow signal | Nothing communicates the order lifecycle: Draft → Approved → Dispatched → Invoiced → Collected |
| Badge only on Sales | Only one badge exists (pending approvals) — on-hold orders, overdue collections have no signal |

---

## B–D. New Information Architecture

### B. Proposed top-level sidebar (8 items)

```
Dashboard            ← ungrouped, always first
────────────────────────── SELL
Sales                ← workspace anchor (covers the full sell → collect lifecycle)
Customers            ← account + territory coverage
────────────────────────── MOVE
Delivery             ← trips, dispatch, exceptions (operational, driver-facing)
Inventory            ← stock, products, catalog, purchases
────────────────────────── ACCOUNT
Finance              ← invoices, credit notes, GST/compliance, accounting
Reports              ← insights renamed; analytics-only reads
────────────────────────── (ungrouped, bottom)
Settings             ← always last; never in FINANCE group
```

**Why 8 not 9:**
- Catalog disappears as top-level → products live under Inventory sub-nav (warehouse staff domain)
- Accounting collapses under Finance sub-nav (accountant domain)
- Insights renamed Reports (clearer intent)
- Settings added explicitly as 8th (was missing from current sidebar config — accessible only via user menu footer)

### C. Sales workspace sub-navigation (7 items in lifecycle order)

These replace ad-hoc links and communicate the order lifecycle as a progression:

| Sub-nav item | Route | Badge | Lifecycle stage |
|---|---|---|---|
| Overview | `/sales` | — | Sales KPIs home |
| Orders | `/orders` | On-hold count (amber) | Active order management |
| Approvals | `/approvals` | Pending count (red) | Approval gate |
| Dispatch Ready | `/operations/pick-lists` | Count (blue) | Pre-trip stage |
| Invoiced | `/sales-invoices` | — | Post-delivery billing |
| Collections | `/collections` | Overdue count (red) | Payment recovery |
| Returns | `/returns` | Open count (amber) | Revenue leakage |

**Why Schemes is removed from Sales sub-nav:** Schemes and pricing are *configuration*, not operational flow. They belong in Catalog / Inventory sub-nav or a Settings context, not the daily Sales workspace.

### D. Other workspace sub-navigations

**Customers sub-nav:**
- All Customers `/customers`
- Routes `/routes`
- Beats `/beats`
- Credit Limits `/approvals/credit-limits`

**Delivery sub-nav:**
- Trips `/delivery`
- Exceptions `/delivery/exceptions`
- Rejections `/delivery/rejections`

**Inventory sub-nav:**
- Stock `/inventory/stock`
- Products `/products`
- Categories `/products/categories`
- Transfers `/inventory/transfers`
- Adjustments `/inventory/adjustments`
- Purchases `/purchases/invoices`

**Finance sub-nav:**
- Sales Invoices `/sales-invoices`
- Credit Notes `/credit-notes`
- Payments `/collections`
- GST/Compliance `/compliance/gstr1`
- Accounting `/accounting`

---

## E. Why Each Item Belongs Where

- **Collections in both Sales sub-nav AND Finance sub-nav:** Sales reps use Collections to track who owes them (operational). Accountants use it to post receipts (financial). Both are valid; the same URLs but different entry contexts. The same route renders for both; role filtering at the page level handles the difference.
- **Returns in Sales not Operations:** Returns are a revenue event (short-shipment, damage claim), not a logistics event. Sales rep initiates a return. Driver confirms it. Operationally it resolves in the Sales workspace.
- **Settings at top-level not in a group:** Settings is not a functional workspace — it's infrastructure. Grouping it under FINANCE or ADMIN creates confusion. It belongs at the bottom, full stop.
- **Dispatch Ready in Sales sub-nav pointing to `/operations/pick-lists`:** Sales reps need visibility that their approved orders have been picked and are ready for delivery. This is a read-only view for sales — the same URL that warehouse staff use operationally.

---

## F. Visual Hierarchy Rules

### Typography

```
Group header:       text-[9px] font-semibold uppercase tracking-[0.14em] text-primary-500/70
Top-level nav item: text-[13px] font-medium           (inactive)
                    text-[13px] font-semibold          (active)
Sub-nav item:       text-[12px] font-medium            (inactive)
                    text-[12px] font-semibold           (active)
```

### Spacing

```
Group header:       mt-5 mb-1 px-3 (first group: mt-2)
Top-level item:     px-3 py-2 (h ~36px)
Sub-nav items:      ml-3 border-l border-primary-700 pl-3 py-1.5 — visually indented
Divider between groups: hidden when collapsed (w-full h-px bg-primary-700/50 mx-2)
```

### Active state — IMPROVED

Current `w-0.5` bar is physically 2px and hard to perceive. Propose `w-[3px]`:

```
// Top-level active:
"bg-accent/20 text-white font-semibold"
// Active left bar:
"absolute left-0 top-1/2 -translate-y-1/2 w-[3px] h-5 rounded-r bg-accent"
// Active icon:
"text-accent"

// Top-level inactive:
"text-primary-300 hover:bg-white/5 hover:text-primary-100"
// Inactive icon:
"text-primary-400 group-hover:text-primary-200"
```

Key change: active state shows **white text** (not accent-colored text) — this passes contrast on the `#1B4332` background. The accent color is reserved for the left bar and icon, creating a 2-signal active indicator.

### Sub-nav active

```
// Active:
"text-accent font-medium"
// indicator: left-edge dot: "absolute left-[-1px] w-[3px] h-3.5 rounded-r bg-accent"

// Inactive:
"text-primary-400 hover:text-primary-200"
```

### Icon style
- Size: `h-[18px] w-[18px]` for top-level (current), `h-[15px] w-[15px]` for sub-nav items
- Style: Lucide outline only, no filled variants
- See Section L for proposed icon assignments

### Group headers
- When expanded: render label text
- When collapsed: render `w-4 h-px bg-primary-700/60 mx-auto` — a single centered hairline, not full width
- First group has no top margin

### Badges

```
// Urgent (pending approvals, overdue):
h-4 min-w-[18px] rounded-full bg-danger text-[10px] font-bold text-white px-1

// Warning (on-hold, open returns):
h-4 min-w-[18px] rounded-full bg-warning/90 text-[10px] font-bold text-white px-1

// Informational (ready to dispatch):
h-4 min-w-[18px] rounded-full bg-accent/20 text-[10px] font-semibold text-accent px-1
```

### CTA placement
- The `+ Create` button stays in the TopBar (right side, accent-colored)
- Do NOT put a CTA inside the sidebar (disrupts scanning rhythm)
- The `+ Create` dropdown already has role-filtered items — this is the right pattern
- Consider adding keyboard shortcut hint `⌘K` visually in the button label on desktop

---

## G. Role-Based Navigation

**Owner / Admin** — sees everything:
```
Dashboard | Sales (all 7 sub-items) | Customers | Delivery | Inventory | Finance | Reports | Settings
```

**Branch Manager:**
```
Dashboard | Sales (Orders, Approvals, Dispatch Ready, Collections, Returns) | Customers | Delivery | Inventory | Finance (Sales Invoices, Credit Notes, Payments) | Reports
// Hides: Finance > Accounting, Finance > GST (accountant role), Settings (limited)
```

**Sales Rep:**
```
Dashboard | Sales (Overview, Orders, Approvals, Dispatch Ready, Collections, Returns) | Customers (All Customers, Routes, Beats)
// Hides: Delivery detail management, Inventory edit actions, Finance entirely, Reports, Settings
// Sales Invoices visible as READ-ONLY sub-item of Sales (Invoiced tab)
```

**Warehouse Staff:**
```
Dashboard | Delivery (Trips, Dispatch Ready, Exceptions) | Inventory (Stock, Products, Transfers, Adjustments, Purchases)
// Hides: Sales, Customers, Finance, Reports, Settings
```

**Accountant:**
```
Dashboard | Finance (all 5 sub-items) | Reports | Settings (limited)
// Can see Sales Invoices and Collections but not order management
```

**Driver:**
```
Dashboard | Delivery (Trips assigned to them only) | Customers (Routes, Beats for their area)
// Most restricted role
```

**Implementation:** Extend `WorkspaceNavItem` to add `subItems?: SubNavItem[]` array. Each `SubNavItem` can have its own `rolesAllowed`. The sidebar renders sub-items only when the parent is active. Role filtering happens in a new `filterSubNavForRole(subItems, role)` helper.

---

## H. Recommended Default Sales Landing Page

**Current:** `/sales/page.tsx` exists but is sparse (single `page.tsx`).

**Proposed `/sales` page:**

Split into 3 zones:

1. **Top strip (KPISummaryStrip):** Today's orders, Pending approvals, On-hold orders, Outstanding collections — with delta vs yesterday
2. **Middle: Lifecycle pipeline** — horizontal card-based funnel: Draft → Submitted → Approved → Dispatched → Invoiced → Collected. Each stage is a clickable chip with count and value.
3. **Bottom: Two-column grid:**
   - Left: "Needs your attention" — orders on hold, overdue collections, open returns (role-aware alerts)
   - Right: "Recent activity" — last 10 order actions + inline quick-approve button for Sales Reps

This page should be the default landing for roles: owner, admin, manager, sales_rep. For warehouse_staff, redirect to `/delivery`. For accountant, redirect to `/finance`.

---

## I. Implementation-Ready UI Specs

**File changes required:**

1. `web/components/layout/nav.config.ts` — Add `subItems` to `WorkspaceNavItem`, define `SubNavItem` type, update all 8 top-level nav items with sub-items arrays, update `NAV_GROUPS` to `"sell" | "move" | "account"`, add Settings to `WORKSPACE_NAV`

2. `web/components/layout/sidebar.tsx` — Rebuild `NavItem` to support collapsible sub-items (`ChevronDown` expand toggle), update active state CSS, update group header spacing

3. **New file:** `web/components/layout/sales-subnav.tsx` — Horizontal workspace sub-nav (optional progressive enhancement; renders above page content when inside a workspace)

4. `web/components/layout/app-shell.tsx` — No changes needed IF sub-nav renders inside sidebar; minor change to render `SalesSubnav` as a sticky horizontal bar above `<main>` content if that approach is chosen

5. `web/app/sales/page.tsx` — Rebuild as the Sales workspace Overview

---

## J. Component Structure

### `nav.config.ts` — new types

```ts
export interface SubNavItem {
  key: string;
  label: string;
  href: string;
  matchers: string[];
  rolesAllowed?: UserRole[];
  badge?: "danger" | "warning" | "info";    // badge color token
  badgeDataKey?: string;                     // key into a badge-count map (e.g. "pendingApprovals")
}

export interface WorkspaceNavItem {
  key: string;
  label: string;
  href: string;
  icon: LucideIcon;
  matchers: string[];
  rolesAllowed?: UserRole[];
  group?: string;
  subItems?: SubNavItem[];                  // ← new
}
```

### `AppSidebar` (renamed from `Sidebar`)
- Same collapse/expand behavior
- Pass a `badgeCounts: Record<string, number>` prop down to all `NavItem`s
- This map is fetched once at the top level (e.g. `useSidebarBadges()` hook that hits a single `/api/sidebar/counts` endpoint)

### `SidebarSection`

```tsx
// Props: label, collapsed, children
// Renders group header + nav items list
// className on root: "space-y-0.5"
// Group header: text-[9px] uppercase tracking-widest text-primary-500/70 px-3 mb-1 mt-5
```

### `SidebarItem` (new NavItem interface)

```tsx
// Props: item: WorkspaceNavItem, collapsed, badgeCounts, onClose
// Internal state: subExpanded (bool), auto-expanded when isActive
// When item.subItems exists AND !collapsed:
//   renders ChevronDown (rotates 180° when expanded) after label
//   renders sub-items list below with AnimateHeight or max-h transition
// Sub-items: border-l border-primary-700/50 ml-4 pl-0 space-y-0.5 mt-0.5
```

### `SidebarBadge`

```tsx
// Props: count: number, variant: "danger" | "warning" | "info"
// variant → bg-danger | bg-warning/90 | bg-accent/20 + text-accent
// Renders nothing when count === 0
// "99+" truncation when count > 99
```

### `WorkspaceHeader` (top of sidebar)

```tsx
// Props: collapsed
// Height: h-14 (matches TopBar)
// Expanded: logo mark + "Orderlane" wordmark, collapse toggle button
// Collapsed: logo mark only, collapse toggle underneath
// Logo mark: 28×28 rounded bg-accent/20 text-accent monogram OR SVG logo
```

### `SalesSubnav` (horizontal bar — optional approach)

```tsx
// Props: activeHref: string
// Sticky: sticky top-16 z-20 (below TopBar at h-16)
// Height: h-10
// Background: bg-background border-b border-border
// Items: horizontal scroll, gap-1
// Each item: px-3 py-1.5 text-xs font-medium rounded-md
//   Active:   bg-primary/8 text-primary font-semibold
//   Inactive: text-text-secondary hover:text-text-primary hover:bg-background-subtle
// Badge: inline SidebarBadge after label
// Renders only when pathname matches any Sales workspace matcher
```

### `QuickActionsBar` (the TopBar's Create section — already exists, enhance)

```tsx
// Enhance the existing CreateDropdown with:
// 1. Keyboard shortcut hint: ⌘N on desktop
// 2. Group CREATE_ACTIONS by category (SALES / INVENTORY / etc.)
// 3. Show 2-3 "pinned" quick actions as icon-only buttons before the + Create button
//    e.g. "New Order" icon pill (role-filtered) — because the most common action
//    should be 1-click not 2-click
```

---

## K. Sample Navigation Config JSON

```json
{
  "navGroups": [
    { "key": "sell",    "label": "SELL"    },
    { "key": "move",    "label": "MOVE"    },
    { "key": "account", "label": "ACCOUNT" }
  ],
  "workspaceNav": [
    {
      "key": "dashboard",
      "label": "Dashboard",
      "href": "/dashboard",
      "icon": "LayoutDashboard",
      "matchers": ["/dashboard"],
      "group": null
    },
    {
      "key": "sales",
      "label": "Sales",
      "href": "/sales",
      "icon": "ShoppingCart",
      "matchers": ["/sales", "/orders", "/approvals", "/schemes", "/collections", "/returns", "/sales-invoices", "/operations/pick-lists"],
      "group": "sell",
      "rolesAllowed": ["owner", "admin", "manager", "sales_rep", "accountant"],
      "subItems": [
        { "key": "sales-overview",  "label": "Overview",       "href": "/sales",                  "matchers": ["/sales"]                    },
        { "key": "orders",          "label": "Orders",         "href": "/orders",                 "matchers": ["/orders"],                   "badge": "warning",  "badgeDataKey": "onHoldOrders"    },
        { "key": "approvals",       "label": "Approvals",      "href": "/approvals",              "matchers": ["/approvals"],                "badge": "danger",   "badgeDataKey": "pendingApprovals" },
        { "key": "dispatch-ready",  "label": "Dispatch Ready", "href": "/operations/pick-lists",  "matchers": ["/operations/pick-lists"],    "badge": "info",     "badgeDataKey": "readyToDispatch", "rolesAllowed": ["owner", "admin", "manager", "sales_rep", "warehouse_staff"] },
        { "key": "invoiced",        "label": "Invoiced",       "href": "/sales-invoices",         "matchers": ["/sales-invoices"]           },
        { "key": "collections",     "label": "Collections",    "href": "/collections",            "matchers": ["/collections"],              "badge": "danger",   "badgeDataKey": "overdueCollections" },
        { "key": "returns",         "label": "Returns",        "href": "/returns",                "matchers": ["/returns"],                  "badge": "warning",  "badgeDataKey": "openReturns"     }
      ]
    },
    {
      "key": "customers",
      "label": "Customers",
      "href": "/customers",
      "icon": "Users",
      "matchers": ["/customers", "/routes", "/beats"],
      "group": "sell",
      "rolesAllowed": ["owner", "admin", "manager", "sales_rep", "driver"],
      "subItems": [
        { "key": "all-customers",  "label": "All Customers", "href": "/customers",               "matchers": ["/customers"]               },
        { "key": "routes",         "label": "Routes",        "href": "/routes",                  "matchers": ["/routes"]                  },
        { "key": "beats",          "label": "Beats",         "href": "/beats",                   "matchers": ["/beats"]                   },
        { "key": "credit-limits",  "label": "Credit Limits", "href": "/approvals/credit-limits", "matchers": ["/approvals/credit-limits"] }
      ]
    },
    {
      "key": "delivery",
      "label": "Delivery",
      "href": "/delivery",
      "icon": "Truck",
      "matchers": ["/delivery", "/operations"],
      "group": "move",
      "rolesAllowed": ["owner", "admin", "manager", "driver", "warehouse_staff"],
      "subItems": [
        { "key": "trips",       "label": "Trips",      "href": "/delivery",            "matchers": ["/delivery"]            },
        { "key": "exceptions",  "label": "Exceptions", "href": "/delivery/exceptions", "matchers": ["/delivery/exceptions"] },
        { "key": "rejections",  "label": "Rejections", "href": "/delivery/rejections", "matchers": ["/delivery/rejections"] }
      ]
    },
    {
      "key": "inventory",
      "label": "Inventory",
      "href": "/inventory/stock",
      "icon": "Package",
      "matchers": ["/inventory", "/products", "/suppliers", "/purchases"],
      "group": "move",
      "rolesAllowed": ["owner", "admin", "manager", "warehouse_staff"],
      "subItems": [
        { "key": "stock",     "label": "Stock",     "href": "/inventory/stock",    "matchers": ["/inventory/stock", "/inventory/adjustments", "/inventory/transfers"] },
        { "key": "products",  "label": "Products",  "href": "/products",           "matchers": ["/products"]        },
        { "key": "purchases", "label": "Purchases", "href": "/purchases/invoices", "matchers": ["/purchases"]       },
        { "key": "suppliers", "label": "Suppliers", "href": "/suppliers",          "matchers": ["/suppliers"]       }
      ]
    },
    {
      "key": "finance",
      "label": "Finance",
      "href": "/finance",
      "icon": "Landmark",
      "matchers": ["/finance", "/credit-notes", "/compliance", "/accounting", "/advance-payments", "/supplier-debit-notes"],
      "group": "account",
      "rolesAllowed": ["owner", "admin", "manager", "accountant"],
      "subItems": [
        { "key": "sales-invoices-fin", "label": "Sales Invoices", "href": "/sales-invoices",   "matchers": ["/sales-invoices"] },
        { "key": "credit-notes",       "label": "Credit Notes",   "href": "/credit-notes",     "matchers": ["/credit-notes"]   },
        { "key": "payments",           "label": "Payments",       "href": "/collections",      "matchers": ["/collections"]    },
        { "key": "gst",                "label": "GST / GSTR1",    "href": "/compliance/gstr1", "matchers": ["/compliance"]     },
        { "key": "accounting",         "label": "Accounting",     "href": "/accounting",       "matchers": ["/accounting"]     }
      ]
    },
    {
      "key": "reports",
      "label": "Reports",
      "href": "/insights",
      "icon": "BarChart2",
      "matchers": ["/insights", "/reports"],
      "group": "account",
      "rolesAllowed": ["owner", "admin", "manager", "accountant"]
    },
    {
      "key": "settings",
      "label": "Settings",
      "href": "/settings",
      "icon": "SlidersHorizontal",
      "matchers": ["/settings"],
      "group": null,
      "rolesAllowed": ["owner", "admin", "manager", "accountant"]
    }
  ]
}
```

---

## L. Recommended Sidebar Labels and Icons

| Key | Label | Icon (Lucide) | Rationale |
|---|---|---|---|
| dashboard | Dashboard | `LayoutDashboard` | Standard, universally understood |
| sales | Sales | `ShoppingCart` | Transactional; recognizable |
| customers | Customers | `Users` | People/accounts — correct |
| delivery | Delivery | `Truck` | Physical logistics |
| inventory | Inventory | `Package` | Replace `Layers` — Package is more concrete |
| finance | Finance | `Landmark` | Replace `DollarSign` — Landmark reads "institution" for B2B |
| reports | Reports | `BarChart2` | Analytics; rename "Insights" → "Reports" (clearer) |
| settings | Settings | `SlidersHorizontal` | Replace gear — gear reads "developer"; sliders reads "configuration" |
| **Sub-items:** | | | |
| sales-overview | Overview | `LayoutDashboard` | Home/summary |
| orders | Orders | `ClipboardList` | Order list |
| approvals | Approvals | `CheckSquare` | Decision gate |
| dispatch-ready | Dispatch Ready | `PackageCheck` | Fulfillment ready state |
| invoiced | Invoiced | `FileText` | Document / billing |
| collections | Collections | `Wallet` | Payment |
| returns | Returns | `RotateCcw` | Reversal |

---

## M. UX Copy Improvements

| Current label | Problem | Proposed label | Why |
|---|---|---|---|
| Sales | Vague — is this a section or an action? | **Sales** (keep) | Acceptable; clarity comes from sub-nav |
| Operations | Sounds like an IT/admin area | **Delivery** | Delivery is what people call the daily job |
| Finance | Overloaded — 7 subsystems | **Finance** (with honest sub-nav) | Fine once sub-nav is visible |
| Insights | Analytics-speak | **Reports** | More operational; floor managers say "can I see the report?" |
| Accounting | Correct but overlaps Finance | **Accounting** (as Finance sub-item) | Move it inside Finance, not top-level |
| Catalog | Dev/product jargon | **Products** (top-level sub-nav item inside Inventory) | Business users say "products" not "catalog" |
| Beats | Jargon (India-specific sales territory) | **Beats** (keep with tooltip "Sales territory coverage") | Audience knows the term; tooltip helps onboarding |
| Collections | Finance-speak | **Collections** in Sales = "Payment follow-up"; in Finance = "Payments" | Rename within each context |
| Approvals | Generic | **Approvals** (keep, already clear) | OK |
| Credit Limits | Under Approvals currently | **Credit Limits** (Customers sub-nav item) | Belongs to customer management, not billing |

---

## Before vs After Critique

**Before:** 9 flat items with equal visual weight → user must memorize which section contains which workflow. Sales reps must jump between Sales, Finance, and Operations to do one day's work. The sidebar communicates *categories*, not *jobs*.

**After:** 8 items where 5 are workspace launchers with sub-item support. The Sales workspace contains everything a sales rep touches in one day without leaving the Sales section. The sidebar communicates *jobs*, not *categories*. The active workspace is visually committed (bold text, accent bar), and sub-items show exactly where you are in the flow.

---

## Implementation Notes

### Decisions
- **Chose accordion sub-items in sidebar over horizontal sub-nav strip:** The accordion keeps everything in one navigation system — no split attention between sidebar and a secondary bar. The horizontal strip is a viable alternative but adds layout complexity (sticky z-index stacking, scroll behavior on mobile). The accordion can be added progressively to the existing `NavItem` component.
- **Chose to keep `subItems` in config (data-driven) not hardcoded in JSX:** Allows role filtering to work with the same `filterNavForRole` helper without bespoke per-workspace logic.
- **Chose `Landmark` over `DollarSign` for Finance:** `DollarSign` reads "pricing" in B2B SaaS. `Landmark` reads "institutional finance" — correct for invoicing/compliance context.
- **Collections appears in both Sales and Finance sub-navs:** Same URL, different entry point. This intentional duplication removes the "which section owns Collections?" confusion. Role filtering ensures Sales Reps see it in Sales; Accountants see it in Finance.
- **Settings removed from NAV_GROUPS:** Currently Settings is not even in `WORKSPACE_NAV` — users access it only via the user footer menu. Adding it as the last nav item (ungrouped, after all groups) gives discoverability without clutter.

### Verification Checklist
1. Run `node ./node_modules/typescript/bin/tsc --noEmit` — must stay at current 16 pre-existing errors, no new ones
2. For each role (owner, sales_rep, accountant, warehouse_staff, driver): confirm sidebar renders only permitted items
3. Verify `isActiveRoute` correctly resolves sub-item matchers (e.g. being on `/orders/123` still lights up Sales parent AND Orders sub-item)
4. Verify badge counts load without blocking navigation render (use `Suspense`-safe pattern: badge counts should be fetched independently, not block SSR)
5. Verify collapsed sidebar still works — sub-items do not render when collapsed, parent tooltip shows full label
