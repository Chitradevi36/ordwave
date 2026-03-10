# Plan: Supplier & Purchase Invoice UI Overhaul

**Summary:** The current pages work but lack visual hierarchy — list pages have no contextual metrics, the invoice form is cramped, supplier detail buries the most-used tab (Purchase Invoices) last, and there's no overdue awareness anywhere. The enhancements focus on clarity, less clutter, and fewer clicks to accomplish common tasks.

---

## Steps

### 1. Suppliers list — `web/app/suppliers/page.tsx`
- Add 3 stat cards at the top: **Total**, **Active**, **Blacklisted** (computed from `totalCount` + status-filtered counts via a secondary API call)
- Add `credit_limit` column to the table
- Show a map-pin icon next to city/state in location column
- Replace raw `<select>` status filter with styled pill toggles (like the invoice list's tab bar)

### 2. Supplier detail — `web/app/suppliers/[id]/page.tsx`
- Reorder tabs: **Overview → Purchase Invoices → Products → Activity** (invoices is the most-visited)
- Add a stats strip below the page header: **Total Invoices**, **Total Purchased (₹)**, **Outstanding (₹)** — fetched from the existing invoices tab data
- Replace `window.prompt()` on delete with a proper `<Modal>` confirmation (same pattern as `CancelModal`)
- Add click-to-call (`tel:`) and click-to-email (`mailto:`) icon buttons in the Overview tab next to phone/email fields
- Add a GST lookup link (hyperlink to GST portal) next to GSTIN field

### 3. Purchase Invoice list — `web/app/purchases/invoices/page.tsx`
- Add **overdue badge logic**: when `status === 'posted'` and `due_date < today`, show an `Overdue` danger badge instead of `Posted` in the table, plus an **Overdue** status tab
- Add a `₹ Total` summary bar at the bottom showing sum of the current page's `grand_total`
- Label the date inputs with "From" / "To" text labels so they're not just bare date pickers
- Fix pagination to match suppliers page style (left: "Page X of Y", right: Prev/Next buttons)

### 4. Purchase Invoice form — `web/app/purchases/invoices/_components/purchase-invoice-form.tsx`
- **Auto-fill due date**: when supplier is selected, fetch supplier's `payment_terms_days` and auto-compute `due_date = invoice_date + payment_terms_days`
- **Sticky footer bar**: move the grand total + Save/Cancel buttons into a sticky `bottom-0` bar so they're always visible while scrolling through many line items
- **Line notes toggle**: add a small `+` expand per line row that reveals a notes input below it, keeping the main table clean
- **Supplier products hint**: after selecting a supplier, show a subtle "This supplier carries X products" link that pre-filters the product dropdown to only that supplier's products

### 5. Purchase Invoice detail — `web/app/purchases/invoices/[id]/page.tsx`
- Add a **"Post Invoice"** button for `draft` invoices (calls `POST /api/v1/purchase_invoices/:id/post`)
- Show an **overdue warning banner** (`bg-amber-50 border-amber-200`) when status is `posted` and `due_date < today`
- Show stock movement direction with colored chips (IN = green, OUT = red) in the Stock Movements tab

---

## Verification
- Load `/suppliers` → stat cards show correct counts, credit limit visible in table
- Open a supplier → tabs in new order, stats strip showing correct totals
- Create a new invoice, select a supplier with `payment_terms_days = 30` → due date auto-fills to `invoice_date + 30`
- Create invoice with 5+ line items → totals footer stays sticky at bottom of viewport
- Open a posted invoice with a past due date → amber overdue banner appears
- Open a draft invoice → "Post Invoice" button visible next to "Edit"

---

## Decisions
- Auto-fill due date uses already-loaded suppliers list (no extra API call — `payment_terms_days` is in the supplier object)
- Supplier products hint (step 4) filters the existing product dropdown client-side using `supplier_products` data — no new API needed
- Overdue detection is purely client-side date comparison — no backend change required
