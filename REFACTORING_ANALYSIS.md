## Order Detail Page Current State Analysis

### What Exists (1185 lines)

**Current Components:**
- `PageHeader` with dynamic action buttons (line 944-1001)
- Status badges + credit badges + total (inline after header) (line 1003-1015)
- On-hold banner, submitted banner, blocked banner (alerts) (line 1017-1058)
- `StatusTimeline` (4 stages: Draft → Submitted → Approved → Delivered) (line 1060)
- Tabs structure (6 tabs: Overview, Lines, Credit Check, Schemes, Journey, Activity)

**Sub-components (Tab Contents):**
1. **OverviewTab** (lines 160-200) — 3 cards
   - Order Info: order_number, status, delivery_date, notes, created, submitted, approved, cancelled, pick_status
   - Parties: customer, branch, created_by
   - Financials: gross total, discount, net total

2. **LinesTab** (lines 250-290) — Table with columns
   - SKU, Product, Qty, Unit Price, Disc %, GST %, Line Total, Source

3. **CreditTab** (lines 380-430) — Decision banner + metrics card
   - Decision (icon + label + reasons)
   - Credit Metrics (all snapshot fields)

4. **SchemesTab** (lines 290-350) — Scheme details
   - Scheme name, type, discount
   - Free items table

5. **LifecycleTab** (imported, separate file) — Extended journey tracking
6. **TimelineTab** (lines 500-620) — Audit trail with changes
   - Grouped by day
   - Expandable changes details

**Key Helper Functions:**
- `fmtINR()`, `fmtDate()`, `fmtDateTime()`
- `Row()` component for label-value pairs
- `PickStatusBadge()` for pick status display

**Modals:**
- ApproveModal/RejectModal
- CancelModal  
- HoldModal
- EditModal (limited — delivery_date + notes only)
- CreditDecisionModal (imported)

**API Endpoints Used:**
- GET `/api/v1/sales_orders/{id}`
- POST `/api/v1/sales_orders/{id}/submit`
- POST `/api/v1/sales_orders/{id}/refresh_price`
- POST `/api/v1/sales_orders/{id}/approve`
- POST `/api/v1/sales_orders/{id}/cancel`
- POST `/api/v1/sales_orders/{id}/hold`
- POST `/api/v1/sales_orders/{id}/pick`
- POST `/api/v1/sales_orders/{id}/confirm_pick`
- POST `/api/v1/sales_invoices/generate_from_order`

---

### Duplication Issues Identified

| Data Point | Current Locations | Issue |
|------------|-------------------|-------|
| Order Number | PageHeader title + Order Info card | Repeated |
| Status | PageHeader description (implied) + badge after header + Order Info card | Repeated 2x |
| Total Amount | Dynamic badge after header + inline | Repeated |
| Customer Name | PageHeader description + Parties card | Repeated |
| Branch | PageHeader description + Parties card | Repeated |
| Delivery Date | Order Info card + timeline stages | Repeated |
| Approved At | Order Info card + timeline | Scanned |
| Submitted At | Order Info card + timeline | Scanned |
| Credit Decision | Inline badge + CreditTab | Repeated |
| Pick Status | Order Info (conditional) + OrderDetail.pick_status | Scattered |

---

### New Components Ready

**Pre-built components in `/web/components/orders/`:**

1. **order-hero.tsx** — Single header replacing PageHeader + badges
2. **order-lifecycle.tsx** — 8-stage lifecycle replacing StatusTimeline
3. **next-action-banner.tsx** — New contextual guidance (no replacement)
4. **order-overview-cards.tsx** — 3 cards: Operational, Commercial, AmountBreakdown (replacing OverviewTab)
5. **order-lines-table.tsx** — Self-contained lines (replacing LinesTab)
6. **order-fulfillment-panel.tsx** — New consolidated logistics panel (no direct replacement, needed for new Fulfillment tab)
7. **order-finance-panel.tsx** — Consolidated credit + payment (replacing CreditTab logic)
8. **order-documents-panel.tsx** — Document listing (new tab, needed for Documents tab)

---

## Refactoring Strategy

### Phase 1: Head (1-2 hours)
**Goal:** Replace top navigation and status display

**Actions:**
1. Import OrderHero, OrderLifecycle, NextActionBanner
2. Remove: PageHeader (line 944)
3. Remove: Status/credit/total badges (line 1003)
4. Remove: Status banners (on_hold, submitted, blocked) (lines 1017-1058)
5. Remove: StatusTimeline (line 1060)
6. Add: OrderHero with order identity + primary actions
7. Add: OrderLifecycle with timestamps
8. Add: NextActionBanner with contextual guidance

**Before:**
```
PageHeader (title + description + many buttons)
    ↓
Status/Credit/Total badges
    ↓
Banners (on-hold, submitted, blocked)
    ↓
StatusTimeline (4 stages)
    ↓
Tabs
```

**After:**
```
OrderHero (order # + customer + status + credit + total + primary buttons)
    ↓
OrderLifecycle (8-stage pipeline with timestamps)
    ↓
NextActionBanner (contextual "what to do next")
    ↓
Tabs (only content, no status info)
```

---

### Phase 2: Tabs (2-3 hours)
**Goal:** Restructure tabs with new components

**Tab Mapping:**

| NEW Tab | Content | Components |
|---------|---------|------------|
| **Overview** | Operational, Commercial, Amount Breakdown | OperationalSnapshot + CommercialContext + AmountBreakdown |
| **Lines** | Order line items table | OrderLinesTable |
| **Fulfillment** | Picking, dispatch, delivery | FulfillmentPanel |
| **Credit & Finance** | Credit decision, payment tracking | CreditFinancePanel |
| **Timeline** | Audit trail (same as activity) | Reuse existing TimelineTab |
| **Documents** | Order PDF, Invoice, POD, Credit Notes | DocumentsPanel |

**Removals:**
- Delete old OverviewTab (lines 160-200) + Row() helper
- Delete old LinesTab (lines 250-290)
- Delete old CreditTab (lines 380-430)
- Delete old SchemesTab (lines 290-350)
- Delete old TimelineTab (replace with DocumentsPanel?)
- Keep LifecycleTab (rename journey → timeline)

**Tabs configuration:**
```tsx
const tabItems = [
  {
    value: "overview",
    label: "Overview",
    content: <OverviewSection order={order} />
  },
  {
    value: "lines",
    label: `Lines (${order.lines.length})`,
    content: <OrderLinesTable lines={order.lines} />
  },
  {
    value: "fulfillment",
    label: "Fulfillment",
    content: <FulfillmentPanel {...fulfillmentProps} />
  },
  {
    value: "credit",
    label: "Credit & Finance",
    content: <CreditFinancePanel {...creditProps} />
  },
  {
    value: "timeline",
    label: "Timeline",
    content: <LifecycleTab orderId={order.id} token={token} orgId={orgId} />
  },
  {
    value: "documents",
    label: "Documents",
    content: <DocumentsPanel {...documentProps} />
  }
];
```

---

### Phase 3: Data Mapping (1 hour)
**Goal:** Map OrderDetail API response to component props

**Required Data Fetching:**
- Current: Only calls `/api/v1/sales_orders/{id}`
- Missing: Trip data, Invoice data, Payment data, Documents
- Decision: Can fetch on demand OR in parallel with order fetch

**New Data Structure Needed:**
```tsx
interface FullOrderView {
  order: OrderDetail          // existing
  trip?: TripInfo             // from /trips/{id} or embedded
  invoice?: InvoiceInfo       // from /invoices?order_id= or embedded
  payment?: PaymentInfo       // from /payments?invoice_id= or embedded
  documents: DocumentItem[]   // generated list
}
```

---

### Phase 4: Action Buttons (1 hour)
**Goal:** Wire up actions from OrderHero + NextActionBanner

**Action Mapping (from modals):**
```
Submit            → handleSubmit()
Generate Invoice  → handleGenerateInvoice()
Record Payment    → setPaymentModal(true)
Cancel Order      → setCancelModal(true)
Approve/Reject    → setApproveModal(true)
Put on Hold       → setHoldModal(true)
Mark as Picked    → handlePick()
Confirm Pick      → handleConfirmPick()
Refresh Prices    → handleRefreshPrice()
Edit (full)       → router.push edit page
Edit (logistics)  → openLimitedEdit()
Create Trip       → router.push trip creation
```

**Modals to Keep:**
- ApproveModal (line 1065)
- CancelModal (line 1115)
- HoldModal (line 1140)
- EditModal (line 1165)
- CreditDecisionModal (line 1195)

---

### Phase 5: Cleanup (30 mins)
**Goal:** Remove old helpers and components

**Delete:**
- `OverviewTab()` function
- `LinesTab()` function
- `CreditTab()` function
- `SchemesTab()` function
- `StatusTimeline()` function
- `TimelineTab()` function
- `Row()` helper (use components' own Row if needed)
- `PickStatusBadge()` (move to FulfillmentPanel if needed)
- Constants: `PICK_STATUS_CONFIG`, `CREDIT_ICON`, `ACTION_LABEL` (move to relevant components)

---

## Implementation Checklist

- [ ] **Header refactoring**
  - [ ] Import OrderHero, OrderLifecycle, NextActionBanner
  - [ ] Replace PageHeader render with OrderHero
  - [ ] Add OrderLifecycle below hero
  - [ ] Add NextActionBanner below lifecycle
  - [ ] Remove old status/credit/total badges
  - [ ] Remove old banners (on_hold, submitted, blocked)
  - [ ] Remove old StatusTimeline

- [ ] **Tab structure**
  - [ ] Create OverviewSection wrapper component
  - [ ] Update tabItems array with new components
  - [ ] Remove old tab function definitions

- [ ] **Data mapping**
  - [ ] Identify missing data (trip, invoice, payment)
  - [ ] Decide: fetch on demand vs. parallel fetch
  - [ ] Create helper to format data for component props

- [ ] **Action handlers**
  - [ ] Wire NextActionBanner.onAction callback
  - [ ] Update OrderHero.actions array with actual handlers
  - [ ] Ensure all modals still work

- [ ] **Cleanup**
  - [ ] Delete old helper functions
  - [ ] Delete old sub-component definitions
  - [ ] Move/consolidate constants to components

- [ ] **Testing**
  - [ ] No TypeScript errors
  - [ ] All tabs load without errors
  - [ ] All action buttons clickable and functional
  - [ ] No data duplication visible
  - [ ] Modal flows still work
  - [ ] Responsive on mobile

---

## Estimated Effort

- **Phase 1 (Head):** 1-2 hours
- **Phase 2 (Tabs):** 2-3 hours
- **Phase 3 (Data):** 1 hour
- **Phase 4 (Actions):** 1 hour
- **Phase 5 (Cleanup):** 30 mins
- **Testing & fixes:** 1 hour

**Total: ~6-8 hours of focused refactoring**

---

## Next Steps

1. **Confirm scope:** Do you want me to proceed with full refactoring today?
2. **Data availability:** Should I fetch trip/invoice/payment data in parallel with order fetch, or on-demand per tab?
3. **Priorities:** Which phase should I tackle first?

The complete implementation guide is in `REFACTORING_ORDER_DETAIL.md`.
