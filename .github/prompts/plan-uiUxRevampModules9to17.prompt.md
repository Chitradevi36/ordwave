# OrdWave — UI/UX Revamp: Modules 9–17

## Module 9: Delivery Trip Detail — Exceptions & POD

**Page purpose:** Resolve delivery exceptions and verify proof of delivery for a single trip.
**Who uses it:** Branch Manager (exception resolution), Warehouse (returns intake), Accountant (to reconcile).
**Key decision:** "What went wrong and how do we resolve it?"

**Current UX problem:** Exceptions are a separate page listing (`/delivery/exceptions`). No deep link between trip detail and its exceptions. POD data (photos, signatures) exists but is hard to access. No resolution workflow.

**Desired perception:** "I can see the exact problem, the context, and resolve it in two clicks."

**Layout blueprint:**
1. Exception card per failed stop:
   - **Why:** Reason badge (Customer closed, Quantity mismatch, Payment refused, Wrong address, Item damaged)
   - **What:** Items affected + quantities + value
   - **Evidence:** POD photos/signature thumbnail gallery — click to enlarge
   - **Resolution actions:** [Create Return] [Create Credit Note] [Reschedule Delivery] [Override — Mark Delivered] [Escalate to Manager]
   - Audit footer: "Reported by Sanjay (Driver) at 2:34 PM · GPS: <map link>"
2. Resolution history: shows who resolved, when, what action taken

**UI components needed:** `ExceptionCard`, `PODGallery`, `ResolutionActions`

**Acceptance criteria:**
- Each exception shows inline resolution actions — no navigation to other pages
- "Create Return" pre-fills with the exception's items
- "Create Credit Note" pre-fills with customer + value from exception
- POD photos open in fullscreen gallery overlay
- Resolved exceptions show checkmark + actor + timestamp
- GPS coordinates link to Google Maps

**Design direction:** Amazon delivery exception workflow — clear, structured, action-oriented.

---

## Module 10: Warehouse & Pick Lists

**Page purpose:** Warehouse team's action center for picking, packing, and dispatching orders.
**Who uses it:** Warehouse Staff (exclusive — this is their primary screen).
**Key decision:** "What do I need to pick next? Which orders are ready for dispatch?"

**Current UX problem:** No dedicated warehouse page exists. Warehouse staff use the orders list and delivery trips, which aren't optimized for their workflow.

**Desired perception:** "Here's exactly what I need to pick and pack, in the right sequence."

**Layout blueprint:**
1. PageHeader: "Warehouse" + subtitle "Pick, pack, and dispatch orders efficiently"
2. KPI strip: Pick Queue (count), Ready to Dispatch (count), Dispatched Today (count), Active Trips (count)
3. Tabs: `Pick Queue | Ready to Dispatch | Dispatched Today`
4. Pick Queue: aggregated pick list view grouped by product
   - Product | Unit | Total Qty Needed | Locations (shelf/bin) | Orders Containing
   - Within each product row, expand to see which orders need how many units
   - Batch pick mode: "Pick all units for products A, B, C — then distribute to orders"
5. Ready to Dispatch tab: grouped by trip
   - Trip # + Driver → list of orders packed + total items/value
   - Actions: [Mark Dispatched] [Print Waybill] [View Details]
6. Dispatched Today tab: summary of completed dispatches

**Acceptance criteria:**
- Pick list aggregates same products across orders (batch picking)
- Print-friendly pick list layout (A4, no chrome)
- Dispatching updates order statuses and creates delivery trip in one action
- Barcode scanning support (input field auto-focused for scanner)

**Design direction:** Amazon warehouse fulfillment screen. Task-oriented, minimal chrome, scannable layout.

---

## Module 11: Products (Catalog)

**Page purpose:** Manage the product catalog with pricing, stock levels, and product variants.
**Who uses it:** Owner (catalog management), Branch Manager (local pricing), Warehouse (stock reference).
**Key decision:** "Is my catalog complete? What are the prices? What's in stock?"

**Current UX problem:** 542 lines list + 917 lines detail. Has DataTable with search/filters. No image thumbnails in list. No stock level indicator in list. No bulk actions for pricing.

**Desired perception:** "My catalog is organized, priced correctly, and I can see stock at a glance."

**Visual hierarchy:**
- **Primary:** Product name + thumbnail + selling price
- **Secondary:** Stock level indicator (in stock / low / out)
- **Tertiary:** HSN code, tax rate, MRP, category

**Layout blueprint (list):**
1. PageHeader: "Products" + subtitle "Your catalog — manage products, pricing, and inventory" + [Add Product] + [Bulk Import]
2. KPI strip: Total Products, Active, Low Stock, Out of Stock, Categories
3. View toggle: [List] [Grid] — grid shows larger thumbnails
4. Search + category filter + stock status filter (All / In Stock / Low Stock / Out of Stock)
5. DataTable:
   - Image (thumbnail 40x40) + Name + Code
   - Category (badge)
   - MRP (₹) + Selling Price (₹)
   - Stock: visual indicator `🟢 In Stock (245)` or `🟠 Low (12)` or `🔴 Out (0)`
   - Tax Rate (%)
   - Actions: [Edit] [View] [Duplicate]
6. Bulk actions: [Update Pricing] [Change Category] [Enable/Disable] when items selected

**Layout blueprint (detail):**
1. Product hero: large image gallery + product name + code + category badge
2. Pricing section: MRP, selling price, discount %, tax rate, HSN code — editable inline
3. Stock section: current stock level + stock movements chart (last 30d)
4. Variants tab (if applicable): size/color/unit variants table
5. Sales data: units sold (last 30d), revenue, top customers buying this product

**Acceptance criteria:**
- Product thumbnails visible in list view (40x40, fallback to initials)
- Stock status color-coded in list (green/amber/red)
- Grid view available for visual browsing
- Bulk pricing update for selected products
- Product detail shows stock movement mini-chart
- Duplicate product creates a copy with "(Copy)" suffix

**Design direction:** Shopify products page. Visual, manageable, with stock health signals.

---

## Module 12: HSN / SAC Codes

**Page purpose:** Manage tax classification codes for products (HSN for goods, SAC for services).
**Who uses it:** Owner/Accountant (setup and compliance).
**Key decision:** "Are all products correctly classified for GST compliance?"

**Current UX problem:** Simple CRUD list. No compliance check. No indication of which products are using which codes.

**Desired perception:** "Tax classification is correct and complete — no compliance gaps."

**Layout blueprint:**
1. PageHeader: "HSN / SAC Codes" + subtitle "Tax classification for GST compliance"
2. Alert banner (conditional): "14 products have no HSN code assigned — this may cause invoice issues"
3. DataTable: Code | Description | Tax Rate (%) | Products Using (count, clickable) | Actions [Edit] [Delete]
4. Search + rate filter
5. [Add HSN Code] + [Bulk Import from Government CSV]

**Acceptance criteria:**
- "Products Using" count links to filtered product list
- Alert banner shows when products have no HSN code assigned
- Bulk import from standard HSN CSV format
- Deletion blocked if products are using the code (show toast with count)

**Design direction:** Minimal CRUD with compliance alerting. Keep it simple.

---

## Module 13: Suppliers

**Page purpose:** Manage supplier/vendor relationships for purchase ordering.
**Who uses it:** Owner (vendor management), Branch Manager (local sourcing), Accountant (payables).
**Key decision:** "Who do I buy from? What's my payables exposure?"

**Current UX problem:** 270 lines list + 624 lines detail. Very basic — no payables summary, no credit limit tracking from supplier side, no purchase history summary.

**Desired perception:** "My entire supplier network with spending and payables at a glance."

**Visual hierarchy:**
- **Primary:** Supplier name + total payable outstanding
- **Secondary:** Last purchase date + payment terms
- **Tertiary:** Contact info, location, GSTIN

**Layout blueprint (list):**
1. PageHeader: "Suppliers" + subtitle "Manage vendors and track payables" + [Add Supplier]
2. KPI strip: Total Suppliers, Active, Total Payables Outstanding (₹), Overdue Payables (₹)
3. DataTable:
   - Supplier (name + code)
   - Contact (phone, clickable)
   - Outstanding (₹ amount, red if overdue)
   - Last Purchase (date + relative)
   - Payment Terms (e.g., "Net 30")
   - Status (Active/Inactive badge)
   - Quick actions: [Create Purchase Invoice] [Record Payment] [View]

**Layout blueprint (detail):**
1. PageHeader: supplier name + status + [Edit] [Create Purchase Invoice] [Record Payment]
2. Summary strip: Total Purchases (₹), Outstanding (₹), Overdue (₹), Avg Payment Days
3. Tabs: **Details | Purchase History | Payments | Products Supplied**
4. Details tab: contact info (clickable phone/email), address, GSTIN, bank details, payment terms
5. Purchase History tab: list of purchase invoices with status/amount
6. Payments tab: payments made with method/date/amount
7. Products Supplied tab: link to products from this supplier with last purchase price

**Acceptance criteria:**
- Outstanding amounts in list are color-coded (red if overdue)
- Quick actions work from list (no navigation needed for common tasks)
- Phone numbers are clickable `tel:` links
- Products Supplied tab shows last purchase price for comparison
- GSTIN links to verification portal

**Design direction:** Mirror the retailer profile structure for consistency. Payables-focused.

---

## Module 14: Purchase Invoices

**Page purpose:** Create and manage purchase invoices from suppliers — the payables ledger.
**Who uses it:** Owner (review), Branch Manager (create on receive), Accountant (reconciliation).
**Key decision:** "What do I owe? What's overdue? Which invoices need posting?"

**Current UX problem:** 268 lines list + 465 lines detail + 436 lines form. Functional but lacks overdue detection, summary metrics, and visual status pipeline. No "Post" action for draft→posted workflow.

**Desired perception:** "My payables are organized, I know what's due, and posting is a clear workflow."

**Visual hierarchy:**
- **Primary:** Invoice amount + status badge + due date urgency
- **Secondary:** Supplier name + invoice date
- **Tertiary:** Items, reference number

**Layout blueprint (list):**
1. PageHeader: "Purchase Invoices" + subtitle "Track vendor invoices, manage payables" + [Create Invoice]
2. KPI strip: Total Invoices, Draft (count), Posted (count), Total Payable (₹), Overdue (₹)
3. Alert banner: "3 invoices are overdue — total ₹45,000. Prioritize payments to avoid vendor issues."
4. Status tabs: `All | Draft | Posted | Paid | Overdue | Cancelled`
5. DataTable:
   - Invoice # + Date
   - Supplier (name)
   - Amount (₹, bold)
   - Due Date + **Overdue indicator**: "⚠️ 12d overdue" in red, or "Due in 5d" in default
   - Status badge
   - Payment Status: Unpaid / Partial / Paid
   - Actions: [Post] (if draft) [Record Payment] [View]

**Layout blueprint (form):**
1. Two-column header: Supplier dropdown (auto-fill terms + products) + Invoice date + Reference #
2. Due date: auto-calculated from supplier payment terms but editable
3. Line items table: Product (searchable dropdown) | Qty | Rate | Tax | Total + [Add Line]
4. Totals section: Subtotal + Tax + Total (sticky on right)
5. Notes/memo text area
6. Sticky footer: [Save as Draft] [Post Invoice] — Post requires confirmation modal
7. "Supplier products hint": when supplier selected, show "This supplier has supplied: Product A, Product B, Product C" — quick-add buttons

**Layout blueprint (detail):**
1. PageHeader: "PI-2024-0023" + status badge + [Post] (if draft) [Record Payment] [Print] [Void]
2. Overdue banner (conditional): "This invoice is 12 days overdue. Due date was 28 Feb 2026. Outstanding: ₹45,000."
3. Summary strip: Subtotal | Tax | Total | Paid | Balance Due
4. Supplier info card: name, GSTIN, address
5. Line items table: product, qty, rate, tax, total
6. Payment history: list of payments made against this invoice
7. Stock movements: items received into inventory from this invoice (green "↑ Received" chips)

**Acceptance criteria:**
- Overdue detection calculated from `due_date` vs `Date.now()`
- "Post" action transitions draft → posted (confirmed via modal)
- Auto-calculated due date from supplier payment terms
- Line items with supplier-specific product hints
- Payment history section shows related payments
- Stock movement shows inventory impact (received items)
- Sticky footer on form prevents losing context while scrolling

**Design direction:** Zoho Books purchase invoice meets QuickBooks payables. Clear status pipeline, overdue urgency.

---

## Module 15: Sales Invoices

**Page purpose:** Create and manage outgoing sales invoices to customers — the receivables counterpart.
**Who uses it:** Accountant (exclusive — invoice generation), Owner (review), Branch Manager (occasional).
**Key decision:** "Which delivered orders need invoicing? Which invoices are unpaid?"

**Current UX problem:** 328 lines list + 931 lines detail/form. Functional but no connection to delivery: no "Generate from Order" quick workflow. No ageing view.

**Desired perception:** "Orders are converted to invoices seamlessly, and I track every rupee outstanding."

**Layout blueprint (list):**
1. PageHeader: "Sales Invoices" + subtitle "Billing and receivables management" + [Create Invoice] + [Generate from Orders]
2. KPI strip: Total Invoices, Generated Today, Total Receivable (₹), Overdue (₹), Avg DSO
3. Alert: "5 delivered orders from the last 7 days have no invoice generated"
4. Status tabs: `All | Draft | Sent | Paid | Partially Paid | Overdue | Cancelled`
5. DataTable:
   - Invoice # + Date
   - Customer (name)
   - Order # (linked)
   - Amount (₹) + Paid (₹) + Balance (₹)
   - Due Date + overdue indicator
   - Status badge
   - Actions: [Send] [Record Payment] [Download PDF] [View]
6. [Generate from Orders] button opens modal: shows delivered orders without invoices → select → bulk generate

**Layout blueprint (detail):**
1. Invoice header: company info, customer info, GSTIN, invoice # + date + due date
2. Line items table: matches standard invoice format
3. Payment history section
4. Actions: [Send via Email/WhatsApp] [Record Payment] [Create Credit Note] [Download PDF] [Print]

**Acceptance criteria:**
- "Generate from Orders" shows delivered orders with no linked invoice
- Bulk invoice generation creates one invoice per order
- "Send" action offers Email + WhatsApp channels
- PDF download follows GST-compliant invoice format
- Overdue invoices highlighted in list
- Customer credit account updated in real-time on payment

**Design direction:** Stripe invoicing meets Indian GST compliance. Clean, professional, action-oriented.

---

## Module 16: Credit Notes

**Page purpose:** Issue credit adjustments to customers for returns, overcharges, or goodwill gestures.
**Who uses it:** Accountant (create + post), Owner (approve high-value), Branch Manager (review).
**Key decision:** "Issue credit for this return/issue and link to the original invoice."

**Current UX problem:** Basic CRUD at ~400 lines. No link to returns/exceptions. No approval workflow for high-value notes.

**Desired perception:** "Credit notes trace back to the reason (return/exception) and adjust the customer ledger correctly."

**Layout blueprint:**
1. PageHeader: "Credit Notes" + subtitle "Issue credits for returns, adjustments, and corrections" + [Create Credit Note]
2. KPI strip: Total Credit Notes, Pending Approval (count), Total Value (₹), MTD (₹)
3. DataTable:
   - CN # + Date
   - Customer (linked to profile)
   - Related Invoice # (linked)
   - Reason (badge: Return / Damage / Overcharge / Goodwill)
   - Amount (₹)
   - Status (Pending Approval / Approved / Applied)
   - Actions: [Approve] [Apply to Invoice] [View]
4. Form: Supplier dropdown → linked invoice dropdown → reason category → line items (auto-filled from return if linked) → amount → notes

**Acceptance criteria:**
- Credit notes link to source invoice and optionally to a return
- "Create from Return" auto-fills items + quantities + values
- High-value notes (configurable threshold) require approval
- Applied credit notes reduce customer outstanding
- Reason category is required (standardized list)

**Design direction:** Minimal, auditable. Every credit note has a clear paper trail.

---

## Module 17: Payments & Collections

**Page purpose:** Record and track all payments received from customers.
**Who uses it:** Accountant (daily), Sales Rep (field collection recording), Branch Manager (review collections).
**Key decision:** "What was collected? Against which invoices? Any bounced payments?"

**Current UX problem:** ~641 lines for collections, ~449 for page. Has a functional table but no summary dashboard. No reconciliation view. No bank/cash/cheque breakdown.

**Desired perception:** "Every payment is recorded, allocated, and reconciled — no loose ends."

**Visual hierarchy:**
- **Primary:** Collection amount + method badge + allocation status
- **Secondary:** Customer + date + reference
- **Tertiary:** Linked invoices

**Layout blueprint:**
1. PageHeader: "Payments & Collections" + subtitle "Track every rupee collected — by channel, customer, and period" + [Record Payment]
2. KPI strip: Collected Today (₹), Collected MTD (₹), Unallocated (₹), Bounced (₹, red)
3. Method filter pills: `All | Cash | Cheque | UPI | Bank Transfer | Credit Adjustment`
4. Alert (conditional): "₹12,000 in payments are unallocated — allocate to invoices for accurate receivables"
5. DataTable:
   - Payment # + Date
   - Customer (name)
   - Amount (₹)
   - Method (badge with icon: 💵 Cash, 📄 Cheque, 📱 UPI, 🏦 Bank)
   - Allocated (₹ of ₹ total) — shows if fully/partially allocated
   - Status (Received / Bounced / Reversed)
   - Actions: [Allocate to Invoice] [Reverse] [View Receipt]
6. Form: customer dropdown → amount → method → reference → invoice allocation (checkbox table: select invoices and amount per invoice)

**Acceptance criteria:**
- Payment allocation: user can split one payment across multiple invoices
- Unallocated payments highlighted with amber indicator
- Bounced cheque workflow: mark as bounced → reverses customer credit → shows in alerts
- "Record Payment" from customer profile pre-fills customer
- Cash/cheque/UPI breakdown visible in KPI strip or as filter pills
- Receipt generation for customer (PDF/WhatsApp send)

**Design direction:** Banking transaction register meets Zoho payments. Every payment has an allocation story.
