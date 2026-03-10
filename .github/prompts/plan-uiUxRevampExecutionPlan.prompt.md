# OrderLane Pro — UI/UX Revamp: Interaction Design, Role Matrix & Execution Plan

---

## Part 5: Interaction Design Rules

These rules apply globally to every module. Enforce them as design constraints.

### 5.1 Default CTA Placement

| Context | Primary CTA position | Style |
|---|---|---|
| List page | PageHeader, top right | Solid green button |
| Detail page | PageHeader, top right, contextual to status | Solid green or amber |
| Form page | Sticky bottom bar, right-aligned | Solid green [Save] + Outline [Cancel] |
| Modal/Drawer | Footer, right-aligned | Solid primary + Outline secondary |
| Inline action | Row-level, right side | Ghost button or icon button |
| Bulk action | Sticky bottom bar, visible when items selected | Solid primary |

### 5.2 Modal vs Drawer vs Full Page

| Complexity | Pattern | Examples |
|---|---|---|
| Quick input (1-3 fields) | **Modal** (centered, max 480px) | Record payment, adjust stock, change status |
| Medium form (4-8 fields) | **Drawer** (right side panel, 480-640px) | Create return, schedule visit, edit contact |
| Complex form (>8 fields, multi-section) | **Full page** | Create order, create purchase invoice, create product |
| Detail view | **Full page** | Order detail, customer profile |
| Confirmation | **Modal** (small, 360px) | Delete confirmation, post invoice, approve |

### 5.3 Row-Level Quick Actions

- Maximum 3 visible icon buttons per row (most common actions)
- Additional actions in `…` overflow menu
- Priority order: View (eye icon), Primary action (contextual), Secondary action
- Destructive actions (Delete, Void) always in overflow menu, never as visible buttons
- On hover: show full action labels as tooltips

### 5.4 Keyboard Shortcuts (Future Phase)

| Shortcut | Action |
|---|---|
| `Cmd/Ctrl + K` | Global search |
| `Cmd/Ctrl + N` | New (context-aware: new order on orders page, new product on products page) |
| `Cmd/Ctrl + /` | Show keyboard shortcut help |
| `Esc` | Close modal/drawer |
| `Enter` in modal | Confirm primary action |
| `↑↓` in tables | Navigate rows |
| `Space` on table row | Toggle selection |

### 5.5 Loading & Empty States

| State | Pattern |
|---|---|
| **First load** | Skeleton loader matching layout structure (not spinner) |
| **Empty (no data ever)** | Illustration + headline + description + primary CTA |
| **Empty (filtered)** | "No results match your filters" + [Clear Filters] button |
| **Error** | Alert banner with retry + description + support link |
| **Partial load** | KPI strip loads independently from table (progressive) |

### 5.6 Notification & Feedback Patterns

| Action | Feedback |
|---|---|
| Create/Save success | Toast notification (bottom-right, auto-dismiss 4s): "Order #ORD-047 created" |
| Delete/Void | Confirmation modal before action → toast after success |
| Error | Toast notification (bottom-right, persistent until dismissed, red) |
| Background process | Toast with progress: "Generating 12 invoices… (8/12)" |
| Validation error | Inline field error + scroll to first invalid field |

### 5.7 Table Design Standards

- **Default page size:** 25 rows (configurable: 10/25/50/100)
- **Sticky header:** Table header sticks on scroll
- **Row height:** Comfortable (48px min) — not compact by default
- **Hover state:** Light gray background on row hover
- **Selection:** Checkbox column (first), header checkbox for select all
- **Sorting:** Click column header to sort, arrow indicator for direction
- **Column resizing:** Drag column borders (save preference to localStorage)
- **Monospace:** Order numbers, invoice numbers, amounts in monospace or tabular-nums font
- **Amount alignment:** Right-aligned, ₹ prefix, Indian number formatting (₹1,23,456)
- **Date format:** "10 Mar 2026" (DD MMM YYYY) — no ambiguous formats

---

## Part 6: Role-Based Visibility Matrix

This matrix defines which modules each role can access and which elements are hidden/modified.

### Sidebar Navigation per Role

| Module | Owner | Branch Mgr | Sales Rep | Driver | Warehouse | Accountant |
|---|---|---|---|---|---|---|
| Dashboard | ✅ Full | ✅ Ops focus | ❌ (mobile) | ❌ (mobile) | ✅ Warehouse | ✅ Finance |
| Approvals | ✅ View | ✅ Act | ❌ | ❌ | ❌ | ❌ |
| Retailers | ✅ All | ✅ Branch | ✅ Own | ❌ | ❌ | ✅ Credit focus |
| Orders | ✅ All | ✅ All | ✅ Own | ❌ | ✅ Pick queue | ✅ Invoicing |
| Delivery | ✅ All | ✅ All | ❌ | ✅ Own trips | ✅ Dispatch | ❌ |
| Products | ✅ Full CRUD | ✅ View+Edit | ❌ | ❌ | ✅ View | ❌ |
| Inventory | ✅ All | ✅ Branch | ❌ | ❌ | ✅ Full | ❌ |
| Suppliers | ✅ Full CRUD | ✅ View | ❌ | ❌ | ❌ | ✅ Payables |
| Purchase Inv. | ✅ All | ✅ Create+View | ❌ | ❌ | ❌ | ✅ Full |
| Sales Inv. | ✅ All | ✅ View | ❌ | ❌ | ❌ | ✅ Full |
| Credit Notes | ✅ Approve | ✅ View | ❌ | ❌ | ❌ | ✅ Create |
| Collections | ✅ All | ✅ All | ✅ Own | ❌ | ❌ | ✅ All |
| Returns | ✅ All | ✅ All | ❌ | ❌ | ✅ Receive | ✅ Credit notes |
| Reports | ✅ All | ✅ Ops reports | ❌ | ❌ | ✅ Inventory | ✅ Finance |
| Settings | ✅ Full | ✅ Branch only | ❌ | ❌ | ❌ | ❌ |
| Users | ✅ Full | ❌ | ❌ | ❌ | ❌ | ❌ |

### Sidebar Group Organization

```
Owner:
  ├─ Dashboard
  ├─ Approvals (badge count)
  ├─ Operations
  │   ├─ Orders
  │   ├─ Delivery
  │   └─ Returns
  ├─ Catalog
  │   ├─ Products
  │   ├─ HSN/SAC
  │   ├─ Pricing
  │   └─ Schemes
  ├─ Customers
  │   ├─ Retailers
  │   └─ Collection Schedule
  ├─ Finance
  │   ├─ Sales Invoices
  │   ├─ Payments & Collections
  │   ├─ Credit Notes
  │   └─ Credit & Receivables
  ├─ Procurement
  │   ├─ Suppliers
  │   └─ Purchase Invoices
  ├─ Inventory
  │   ├─ Stock Levels
  │   └─ Stock Transfers
  ├─ Reports & Insights
  └─ Settings
      ├─ Business Profile
      ├─ Team
      ├─ Billing
      └─ Configuration

Warehouse Staff:
  ├─ Dashboard (pick queue focus)
  ├─ Pick & Pack
  ├─ Dispatch
  ├─ Inventory
  │   ├─ Stock Levels
  │   └─ Stock Transfers
  ├─ Returns (receive)
  └─ Reports (inventory only)
```

---

## Part 7: Top 20 UI Quick Fixes (Do First)

These are highest-impact, lowest-effort changes that can be implemented independently.

| # | Fix | Module | Effort | Impact | Key Files |
|---|---|---|---|---|---|
| 1 | Add KPI summary strip to all list pages | All lists | 4h | High | Every `page.tsx` list file |
| 2 | Add overdue detection badges to collections | Collections | 2h | High | `collections/page.tsx` |
| 3 | Standardize PageHeader with subtitle + primary CTA | All pages | 3h | High | `PageHeader` component + all pages |
| 4 | Add order processing SLA timer to orders list | Orders | 2h | High | `orders/page.tsx` |
| 5 | Create CreditBanner shared component | Shared | 3h | High | New: `components/CreditBanner.tsx` |
| 6 | Replace lifecycle table with StatusTimeline component | Order detail | 3h | Medium | `orders/[id]/page.tsx` |
| 7 | Add confirmation modals to all destructive actions | All pages | 2h | Medium | All pages with delete/void actions |
| 8 | Implement empty states with illustrations for all pages | All pages | 4h | Medium | All list pages |
| 9 | Add sticky bottom bar to all form pages | All forms | 2h | Medium | Order form, PI form, product form |
| 10 | Color-code all monetary amounts (green positive, red overdue) | All tables | 2h | Medium | DataTable cell renderer |
| 11 | Add product thumbnails to product list | Products | 1h | Low-Med | `products/page.tsx` |
| 12 | Make phone numbers clickable `tel:` links everywhere | All detail pages | 1h | Low | Customer/supplier detail pages |
| 13 | Add breadcrumbs to all detail/form pages | All | 2h | Medium | All `[id]/page.tsx` and form pages |
| 14 | Standardize date format (DD MMM YYYY) everywhere | All | 2h | Medium | Create `formatDate` utility |
| 15 | Add loading skeletons instead of spinners | All pages | 3h | Medium | All pages with data loading |
| 16 | Indian number formatting for all ₹ amounts | All | 1h | Medium | Create `formatCurrency` utility |
| 17 | Alert banners for actionable warnings on relevant pages | Dashboard, Orders, Collections | 3h | High | 5-6 pages |
| 18 | Add row-level quick actions to all DataTables | All lists | 4h | High | All list page DataTables |
| 19 | Implement toast notifications for all create/update/delete | All | 2h | Medium | Action handlers in all pages |
| 20 | Add "showing X of Y" footer to all tables | All tables | 1h | Low | DataTable component |

**Total quick fixes effort: ~46 hours**

---

## Part 8: Phased Execution Plan

### Phase 1: Foundation & Quick Wins (Weeks 1-2, ~46h)

**Goal:** Establish shared components and apply them everywhere. Immediate visual upgrade.

| Task | Hours | Deliverables |
|---|---|---|
| Create shared components: `MetricCard`, `KPISummaryStrip`, `AlertBanner`, `StatusTimeline`, `CreditBanner`, `SummaryStrip` | 12h | 6 new shared components in `components/` |
| Standardize PageHeader across all pages (subtitle + CTA) | 4h | All pages updated |
| Add KPI strips to all list pages | 6h | All 15+ list pages |
| Implement all Top 20 quick fixes (#1-20) | 24h | 20 individual improvements |

**Milestone:** Every page has consistent header, KPI strip, and proper empty/loading states.

### Phase 2: Module Rewrites — Core Workflows (Weeks 3-6, ~96h)

**Goal:** Rewrite the 8 most important modules with full spec compliance.

| Task | Hours | Deliverables |
|---|---|---|
| Dashboard rewrite (role-based, alerts, activity feed) | 16h | Full dashboard per spec |
| Approvals inbox (unified, card-based, bulk actions) | 10h | New approvals page |
| Orders pipeline (SLA timer, kanban toggle, quick approve) | 14h | Enhanced orders list + detail |
| Customer profile rewrite (CreditBanner, timeline, tabs) | 12h | Enhanced customer detail |
| Delivery trips (progress bars, exception resolution) | 12h | Enhanced delivery list + detail |
| Payments & Collections (allocation, method filter, receipt) | 10h | Enhanced collections page |
| Credit Engine (ageing chart, risk table, portfolio view) | 10h | New credit dashboard page |
| Purchase Invoices (overdue detection, post workflow, form) | 12h | Enhanced PI list + detail + form |

**Milestone:** Core business workflows feel enterprise-grade.

### Phase 3: Extended Modules & Polish (Weeks 7-10, ~80h)

**Goal:** Complete remaining modules and polish the overall experience.

| Task | Hours | Deliverables |
|---|---|---|
| Sales Invoices (generate from orders, send channels) | 10h | Enhanced SI pages |
| Credit Notes (linked to returns, approval workflow) | 6h | Enhanced CN pages |
| Returns (disposition workflow, restock/write-off) | 8h | Enhanced returns pages |
| Products catalog (thumbnails, stock indicator, grid view) | 8h | Enhanced products pages |
| Inventory (reorder alerts, movement chart, stock adjust) | 10h | Enhanced inventory pages |
| Suppliers (payables view, purchase history) | 6h | Enhanced supplier pages |
| Collection Schedule (calendar, map, tracking) | 8h | Enhanced schedule page |
| Reports & Insights (report library, drill-down, export) | 10h | Enhanced reports page |
| Settings (sidebar nav, sections, audit log) | 8h | Enhanced settings page |
| Notifications (center page, preferences, real-time) | 6h | New notifications system |

**Milestone:** Complete product polish. Enterprise-grade across all modules.

### Total Estimated Effort

| Phase | Hours | Duration |
|---|---|---|
| Phase 1: Foundation & Quick Wins | ~46h | 2 weeks |
| Phase 2: Core Module Rewrites | ~96h | 4 weeks |
| Phase 3: Extended Modules & Polish | ~80h | 4 weeks |
| **Total** | **~222h** | **~10 weeks** |

---

## Part 9: Global Summary

### What Changes

| Metric | Before | After |
|---|---|---|
| Pages with KPI strips | 3 | 25+ |
| Pages with alert banners | 0 | 12+ |
| Status timeline components | 0 (tables) | 6+ (visual timelines) |
| Empty states with illustrations | 0 | 25+ |
| Loading skeletons | 0 | 25+ |
| Shared UI components | ~10 | ~25 |
| Pages with role-based visibility | 0 | 20+ |
| Keyboard shortcuts | 0 | 7+ |
| Modules with overdue detection | 0 | 5+ |
| Credit health visibility | 1 tab | 4 surfaces (banner, list badge, dashboard, credit engine) |
| Bulk actions available | 2 | 10+ |
| Quick actions per table row | 0-1 | 2-3 |

### Design Direction Enforcement

Every implementation MUST be reviewed against these 5 principles:

1. **Urgency first:** The most urgent item on any page is visually dominant (red/amber, top position, larger)
2. **Action-ready:** Every piece of information is accompanied by the action it enables
3. **Contextual intelligence:** Show related data together (customer + credit + orders — not in separate silos)
4. **Role-appropriate:** Each role sees what they need, hidden from what they don't
5. **Enterprise confidence:** The UI communicates professionalism and reliability through consistency, clear typography, and purposeful color usage

### Consistency Checklist (Apply to Every Module)

- [ ] PageHeader with subtitle and contextual primary CTA
- [ ] KPI summary strip (3-6 metrics)
- [ ] Alert banner for actionable warnings (conditional)
- [ ] Status tabs with counts
- [ ] DataTable with quick actions, monospace numbers, color-coded amounts
- [ ] Empty state with illustration + CTA
- [ ] Loading skeleton matching layout
- [ ] Breadcrumbs on detail and form pages
- [ ] Sticky footer on form pages
- [ ] Confirmation modal for destructive actions
- [ ] Toast feedback for all mutations
- [ ] Indian ₹ formatting with `formatCurrency`
- [ ] DD MMM YYYY date formatting with `formatDate`
- [ ] Role-based element visibility applied

---

*Generated as part of OrderLane Pro UI/UX Revamp initiative. This document should be used alongside `plan-designSystem.prompt.md`, `plan-roleBasedArchitecture.prompt.md`, and `plan-webRevamp.prompt.md` for complete implementation context.*
