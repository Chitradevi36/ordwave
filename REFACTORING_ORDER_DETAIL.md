## Order Detail Page Refactoring Guide

### Architecture Overview

The refactored Order Detail page transforms from a **database-centric record view** into a **decision-focused operational workspace** using a 4-layer structure:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. ORDER HERO HEADER (Single source of truth)              │
│    - Order Number, Customer, Branch                         │
│    - Status, Credit Decision (visual badges)                │
│    - Total Amount (large, prominent)                        │
│    - Contextual Primary Actions (submit, approve, etc.)     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. ORDER LIFECYCLE TRACKER (Visual progress)               │
│    - 8-stage lifecycle: Draft → Paid                        │
│    - Completed stages highlighted                           │
│    - Timestamps on hover                                    │
│    - Failed states (Rejected/Cancelled) shown clearly       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. NEXT ACTION BANNER (Contextual guidance)                │
│    - Auto-detect current blockers                           │
│    - Suggest next step (Submit, Approve, Invoice, etc.)    │
│    - Links to related actions                               │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. TABBED CONTENT AREA (No duplication)                    │
│    - Overview (Operational Snapshot, Commercial, Amounts)  │
│    - Lines (Full order line items table)                    │
│    - Fulfillment (Picking, Dispatch, Delivery logistics)   │
│    - Credit & Finance (Decisions, payments, invoicing)     │
│    - Timeline (Audit trail of all events)                   │
│    - Documents (PDFs, invoices, PODs)                       │
└─────────────────────────────────────────────────────────────┘
```

### New Components

#### 1. **OrderHero** (`order-hero.tsx`)
The page header that replaces all repetitive headers.

**Props:**
```tsx
interface OrderHeroProps {
  orderNumber: string;
  customerName: string;
  branch: string;
  status: string;
  creditDecision: string | null;
  totalAmount: number;
  actions: Array<{ label: string; onClick: () => void; variant? }>;
}
```

**Usage:**
```tsx
<OrderHero
  orderNumber={order.order_number}
  customerName={order.customer.name}
  branch={order.branch.name}
  status={order.status}
  creditDecision={order.credit_decision}
  totalAmount={order.total_amount}
  actions={[
    { label: "Generate Invoice", onClick: handleGenInvoice },
    { label: "Record Payment", onClick: handlePayment, variant: "default" },
  ]}
/>
```

**Replaces:** All mentions of order_number, status, totals in headers

---

#### 2. **OrderLifecycle** (`order-lifecycle.tsx`)
Visual 8-stage lifecycle tracker (Draft → Paid).

**Props:**
```tsx
interface OrderLifecycleProps {
  status: string;
  createdAt: string;
  submittedAt: string | null;
  approvedAt: string | null;
  dispatchedAt?: string | null;
  deliveredAt?: string | null;
  invoicedAt?: string | null;
  paidAt?: string | null;
  cancelledAt?: string | null;
  rejectedAt?: string | null;
  cancellationReason?: string | null;
}
```

**Key features:**
- Auto-detects current stage from `status` field
- Shows completed stages in green ✓
- Shows current stage with progress indicator
- Shows failed states (red X) for rejected/cancelled
- Timestamps on hover (no inline clutter)
- Scrolls horizontally on mobile

**Replaces:** StatusTimeline component (now 8 stages instead of 4)

---

#### 3. **NextActionBanner** (`next-action-banner.tsx`)
Contextual guidance on what to do next.

**Props:**
```tsx
interface NextActionBannerProps {
  status: string;
  creditDecision: string | null;
  invoicedAt?: string | null;
  paidAt?: string | null;
  creditReasons?: string[] | null;
  deliveredAt?: string | null;
  onAction?: (action: string) => void;
}
```

**Example scenarios:**
- `Draft` → "Draft Order Ready — Review and submit"
- `Credit: Blocked` → "Credit Blocked — Request approval"
- `Delivered, Not Invoiced` → "Ready to Invoice"
- `Invoice Generated, Not Paid` → "Payment Pending"

**Replaces:** No direct replacement (new feature)

---

#### 4. **OperationalSnapshot** (`order-overview-cards.tsx`)
High-value operational information (no duplication).

**Props:**
```tsx
interface OperationalSnapshotProps {
  orderedAt: string;
  expectedDelivery: string | null;
  dispatchTrip?: string | null;
  sourceChannel?: string;
  salesRep?: string;
}
```

**Replaces:** Order Info card (now only operational fields, no status/totals)

---

#### 5. **CommercialContext** (`order-overview-cards.tsx`)
Customer and routing information.

**Props:**
```tsx
interface CommercialContextProps {
  retailer: string;
  billingParty?: string;
  shippingAddress?: string;
  route?: string;
  pricingPolicy?: string;
  creditResult?: string;
}
```

**Replaces:** Parties card (now includes route, pricing policy, credit)

---

#### 6. **AmountBreakdown** (`order-overview-cards.tsx`)
Single-source-of-truth for all amounts.

**Props:**
```tsx
interface AmountBreakdownProps {
  subtotal: number;
  discount: number;
  taxableValue?: number;
  gstAmount?: number;
  roundOff?: number;
  grandTotal: number;
  invoiceAmount?: number;
  paidAmount?: number;
  outstandingAmount?: number;
}
```

**Replaces:** Financials card (order amounts + invoice tracking)

---

#### 7. **OrderLinesTable** (`order-lines-table.tsx`)
Full order line items with product and financial details.

**Props:**
```tsx
interface OrderLinesTableProps {
  lines: OrderLineItem[];
  onViewProduct?: (productId: number) => void;
  onEditLine?: (lineId: number) => void;
  editable?: boolean;
}
```

**Columns:**
- Product (name + SKU)
- HSN/SAC
- Quantity
- Unit Price
- Discount %
- GST Rate
- Line Total
- Actions (View Product, Edit Line if editable)

**Footer:**
- Subtotal
- Discount total
- GST total

**Replaces:** LinesTab (now a self-contained card)

---

#### 8. **FulfillmentPanel** (`order-fulfillment-panel.tsx`)
Warehouse picking + dispatch + delivery logistics.

**Props:**
```tsx
interface FulfillmentPanelProps {
  pickStatus?: "pending_pick" | "picked" | "pick_confirmed";
  pickedAt?: string | null;
  pickedByName?: string;
  pickConfirmedAt?: string | null;
  pickConfirmedByName?: string;
  tripId?: string | null;
  driverName?: string;
  vehicleNumber?: string;
  dispatchTime?: string | null;
  deliveredTime?: string | null;
  deliveryPodUrl?: string | null;
  onViewTrip?: (tripId: string) => void;
  onDownloadPod?: () => void;
}
```

**Sections:**
1. Warehouse Picking (status badge, times, owner names)
2. Dispatch & Delivery (trip link, driver, vehicle, times, POD download)

**Replaces:** No direct replacement (new consolidated panel)

---

#### 9. **CreditFinancePanel** (`order-finance-panel.tsx`)
Credit decisions + payment tracking.

**Props:**
```tsx
interface CreditFinancePanelProps {
  creditDecision?: string | null;
  creditReasons?: string[] | null;
  creditLimit?: number;
  outstandingAtOrder?: number;
  creditSnapshot?: Record<string, number | string>;
  invoiceAmount?: number;
  paidAmount?: number;
  outstandingAmount?: number;
  onRecordPayment?: () => void;
  onGenerateInvoice?: () => void;
  onCreateCreditNote?: () => void;
  onViewInvoice?: () => void;
}
```

**Sections:**
1. Credit Decision (icon + label + reasons)
2. Credit Metrics (limit, outstanding, snapshot)
3. Payment Status (invoice, paid, outstanding)
4. Action buttons (Record Payment, Generate Invoice, etc.)

**Replaces:** CreditTab (consolidated with action buttons)

---

#### 10. **DocumentsPanel** (`order-documents-panel.tsx`)
Related documents with download/preview.

**Props:**
```tsx
interface DocumentsPanelProps {
  documents: DocumentItem[];
  onDownload?: (docId: string) => void;
  onPreview?: (docId: string) => void;
}

interface DocumentItem {
  id: string;
  type: "order" | "invoice" | "pod" | "credit_note";
  name: string;
  url?: string;
  createdAt?: string;
}
```

**Document types:**
- Sales Order PDF
- Invoice
- Delivery POD
- Credit Note

**Replaces:** No direct replacement (new feature)

---

### Integration Steps

#### Step 1: Import Components
```tsx
import { OrderHero } from "@/components/orders/order-hero";
import { OrderLifecycle } from "@/components/orders/order-lifecycle";
import { NextActionBanner } from "@/components/orders/next-action-banner";
import { OperationalSnapshot, CommercialContext, AmountBreakdown } from "@/components/orders/order-overview-cards";
import { OrderLinesTable } from "@/components/orders/order-lines-table";
import { FulfillmentPanel } from "@/components/orders/order-fulfillment-panel";
import { CreditFinancePanel } from "@/components/orders/order-finance-panel";
import { DocumentsPanel } from "@/components/orders/order-documents-panel";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
```

#### Step 2: Replace PageHeader
```tsx
// BEFORE
<PageHeader
  title={order.order_number}
  description={`${order.customer.name} · ${order.branch.name}`}
  actions={[...]}
/>

// AFTER
<OrderHero
  orderNumber={order.order_number}
  customerName={order.customer.name}
  branch={order.branch.name}
  status={order.status}
  creditDecision={order.credit_decision}
  totalAmount={order.total_amount}
  actions={[...]}
/>
```

#### Step 3: Add Lifecycle Tracker
```tsx
<OrderLifecycle
  status={order.status}
  createdAt={order.created_at}
  submittedAt={order.submitted_at}
  approvedAt={order.approved_at}
  deliveredAt={order.delivery_date}  // or from dispatch API
  invoicedAt={order.invoiced_at}     // or from invoice API
  paidAt={order.paid_at}              // or from payment API
  cancelledAt={order.cancelled_at}
  rejectedAt={order.rejected_at}
  cancellationReason={order.cancellation_reason}
/>
```

#### Step 4: Add Next Action Banner
```tsx
<NextActionBanner
  status={order.status}
  creditDecision={order.credit_decision}
  creditReasons={order.credit_reasons}
  invoicedAt={invoiceData?.created_at}
  paidAt={paymentData?.created_at}
  deliveredAt={order.delivery_date}
  onAction={(action) => {
    if (action === "submit") handleSubmit();
    if (action === "invoice") handleGenInvoice();
    if (action === "payment") setPaymentModal(true);
    // ... etc
  }}
/>
```

#### Step 5: Restructure Tabs
```tsx
const tabItems = [
  {
    value: "overview",
    label: "Overview",
    content: (
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <OperationalSnapshot
          orderedAt={order.created_at}
          expectedDelivery={order.delivery_date}
          dispatchTrip={trip?.trip_number}
          sourceChannel={order.source_channel}
          salesRep={order.created_by?.name}
        />
        <CommercialContext
          retailer={order.customer.name}
          billingParty={order.billing_party}
          shippingAddress={order.shipping_address}
          route={order.route_name}
          pricingPolicy={order.pricing_policy}
          creditResult={order.credit_decision}
        />
        <div className="md:col-span-2">
          <AmountBreakdown
            subtotal={order.subtotal}
            discount={order.discount_amount}
            grandTotal={order.total_amount}
            invoiceAmount={invoice?.total}
            paidAmount={payment?.amount}
            outstandingAmount={outstanding}
          />
        </div>
      </div>
    ),
  },
  {
    value: "lines",
    label: `Lines (${order.lines.length})`,
    content: (
      <OrderLinesTable
        lines={order.lines}
        onViewProduct={(pid) => router.push(`/products/${pid}`)}
        onEditLine={(lid) => setEditLineModal(lid)}
        editable={order.status === "draft"}
      />
    ),
  },
  {
    value: "fulfillment",
    label: "Fulfillment",
    content: (
      <FulfillmentPanel
        pickStatus={order.pick_status}
        pickedAt={order.picked_at}
        pickedByName={order.picked_by_name}
        pickConfirmedAt={order.pick_confirmed_at}
        pickConfirmedByName={order.pick_confirmed_by_name}
        tripId={trip?.trip_number}
        driverName={trip?.driver_name}
        vehicleNumber={trip?.vehicle_number}
        dispatchTime={trip?.dispatch_time}
        deliveredTime={trip?.delivered_time}
        deliveryPodUrl={trip?.pod_url}
        onViewTrip={(tid) => router.push(`/delivery/${tid}`)}
        onDownloadPod={() => downloadPod(trip?.pod_url)}
      />
    ),
  },
  {
    value: "credit",
    label: "Credit & Finance",
    content: (
      <CreditFinancePanel
        creditDecision={order.credit_decision}
        creditReasons={order.credit_reasons}
        creditLimit={credit?.limit}
        outstandingAtOrder={credit?.outstanding_at_order}
        creditSnapshot={order.credit_snapshot}
        invoiceAmount={invoice?.total}
        paidAmount={payment?.amount}
        outstandingAmount={outstanding}
        onGenerateInvoice={() => handleGenInvoice()}
        onRecordPayment={() => setPaymentModal(true)}
        onCreateCreditNote={() => setCreditNoteModal(true)}
        onViewInvoice={() => router.push(`/invoices/${invoice?.id}`)}
      />
    ),
  },
  {
    value: "timeline",
    label: "Timeline",
    content: <TimelineTab timeline={order.timeline} />,  // Reuse existing
  },
  {
    value: "documents",
    label: "Documents",
    content: (
      <DocumentsPanel
        documents={[
          { id: order.id, type: "order", name: `${order.order_number}.pdf` },
          ...(invoice ? [{ id: invoice.id, type: "invoice", name: `INV-${invoice.id}.pdf`, createdAt: invoice.created_at }] : []),
          ...(trip?.pod_url ? [{ id: trip.id, type: "pod", name: `POD-${trip.id}.pdf` }] : []),
        ]}
        onDownload={(docId) => downloadDocument(docId)}
        onPreview={(docId) => previewDocument(docId)}
      />
    ),
  },
];

<Tabs defaultValue="overview">
  <TabsList>
    {tabItems.map((tab) => (
      <TabsTrigger key={tab.value} value={tab.value}>
        {tab.label}
      </TabsTrigger>
    ))}
  </TabsList>
  {tabItems.map((tab) => (
    <TabsContent key={tab.value} value={tab.value}>
      {tab.content}
    </TabsContent>
  ))}
</Tabs>
```

### Removed Duplication

| Old Element | Location | Reason | Solution |
|-------------|----------|--------|----------|
| Order Number | Header + Order Info Card | Repeated | Show only in OrderHero |
| Status Badge | Header + Multiple Cards | Repeated | Show in Hero + Lifecycle |
| Totals (Amount) | Header + Financials Card | Repeated | Show only in Hero + Amount Breakdown |
| Customer Name | Header + Parties Card | Repeated | Show in Hero + Commercial Context |
| Timestamps | Multiple cards + Timeline | Scattered | Consolidate in Lifecycle + Timeline |
| Credit Decision | Multiple sections | Scattered | Single source: CreditFinancePanel |
| Delivery Date | Multiple fields | Repeated | Single source: OperationalSnapshot |

### Data Flow

```
Order API Response
        ↓
OrderDetail interface (existing)
        ↓
┌─────────────────────┐
│   OrderHero         │ ← order_number, status, credit, total
├─────────────────────┤
│ OrderLifecycle      │ ← status, timestamps
├─────────────────────┤
│ NextActionBanner    │ ← status, credit_decision, invoiced_at, paid_at
├─────────────────────┤
│ Tabs → Components   │
│ ├─ Overview         │ ← operational + commercial + amounts
│ ├─ Lines            │ ← order.lines
│ ├─ Fulfillment      │ ← pick_status, trip data
│ ├─ Credit & Finance │ ← credit_decision, invoice, payment
│ ├─ Timeline         │ ← audit events
│ └─ Documents        │ ← generated docs
└─────────────────────┘
```

### Styling Consistency

All components use:
- **Tailwind CSS** for styling
- **Lucide Icons** for iconography
- **Existing UI components**: Card, Button, Badge, Tabs, Modal
- **Consistent spacing** (gap-4, p-4, py-2, etc.)
- **Color scheme**: Success, Warning, Danger for credit states
- **Typography**: text-sm for labels, font-medium for keys, font-semibold for values

### Testing Checklist

- [ ] No order data appears in duplicate locations
- [ ] OrderHero updates when order status changes
- [ ] OrderLifecycle reflects current stage correctly
- [ ] NextActionBanner appears only for relevant states
- [ ] All tabs load without errors
- [ ] Timestamps are readable (formatted as en-IN)
- [ ] Amounts use ₹ symbol and Indian locale formatting
- [ ] Credit decision shows icon + reasons
- [ ] Actions work (Invoice, Payment, etc.)
- [ ] Page works on mobile (responsive tabs, scrollable lifecycle)

### Migration Path

**Phase 1 (This commit):**
- Create new components
- Update order detail page to use Hero, Lifecycle, Banner
- Restructure tabs with new components
- Keep existing TimelineTab for now (will refactor later)

**Phase 2 (Follow-up):**
- Refactor TimelineTab for consistency
- Add missing data fields (invoice, payment, trip)
- Integrate order action modals
- Add document generation/download

**Phase 3 (Polish):**
- Add animations between tabs
- Add loading states for async data
- Optimize re-renders
- Add print styles
