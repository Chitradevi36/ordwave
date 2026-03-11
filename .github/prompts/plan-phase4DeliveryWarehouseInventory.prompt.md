# OrdWave — Phase 4: Delivery + Warehouse + Inventory

## Goal
Complete delivery lifecycle on mobile. Warehouse workflows on web. Inventory management enhanced.

**Duration:** ~2 weeks

## Modules Touched
- Delivery Trips (web enhancement + mobile build)
- Trip Stops (mobile build)
- POD Capture (mobile build)
- Returns at Delivery (mobile build)
- Inventory (web enhancement)
- Stock Transfers (web enhancement)
- Warehouse Dashboard (web enhancement)

---

## Backend Tasks

### B4.1 — Enhance Trip Stop Completion for Offline
Update `Delivery::CompleteStopService` to accept offline-friendly payload:
```ruby
# Accept:
# - idempotency_key (prevent double-processing)
# - delivered_lines: [{ product_id, qty_delivered }]
# - rejections: [{ product_id, qty_rejected, reason_code, condition }]
# - proof: { type: 'photo'|'signature'|'otp', data: base64_or_digest }
# - exception_code (for failed stops)
# - completed_at (device timestamp for audit trail)
```

### B4.2 — Auto-Create Return Request from Delivery Rejections
After stop completion with partial delivery:
- Automatically create a `ReturnRequest` (source_type: 'delivery') with `ReturnLine` records from `DeliveryRejection` records
- Status: `submitted` (skip draft for delivery-time returns)
- Notify warehouse staff for QC

### B4.3 — Auto-Generate Invoice on Delivery
When `credit_policy.auto_invoice_trigger` is `'on_delivery'`:
- After stop marked as delivered or partial_delivery
- Call `Invoice::GenerateFromDeliveryService` (already exists)
- Only invoice for delivered quantities
- Queue `GenerateInvoicePdfJob`
- Create notification for accountant

### B4.4 — Trip Summary Endpoint
```ruby
# GET /api/v1/delivery_trips/:id/summary
# Returns:
# {
#   total_stops: 5,
#   delivered: 3,
#   partial: 1,
#   failed: 1,
#   total_order_value: 125000,
#   delivered_value: 98000,
#   cash_collected: 15000,
#   returns_value: 5000,
#   exceptions: [{ stop_id, customer_name, exception_code }]
# }
```

### B4.5 — Inventory Low-Stock Alert Notification
Create background job (scheduled nightly or on stock change):
```ruby
class CheckLowStockJob < ApplicationJob
  queue_as :low
  
  def perform(organization_id)
    org = Organization.find(organization_id)
    low_stock_items = InventoryLevel.where(organization: org)
      .where('qty_on_hand <= min_qty_threshold')
      .where('min_qty_threshold > 0')
      .includes(:product, :branch)
    
    return if low_stock_items.empty?
    
    # Notify warehouse staff and managers
    recipients = org.memberships.active
      .joins(:role).where(roles: { name: %w[warehouse_staff manager owner admin] })
      .map(&:user).uniq
    
    Notifications::CreateService.new(
      organization: org,
      recipients: recipients,
      actor: nil,
      notifiable: nil,
      type: 'stock_low',
      title: "#{low_stock_items.count} items below stock threshold",
      body: low_stock_items.limit(5).map { |il| "#{il.product.name}: #{il.qty_on_hand} #{il.product.units_of_measure.symbol}" }.join(', '),
      deep_link: '/inventory/stock?filter=low_stock',
      severity: 'medium'
    ).call
  end
end
```

---

## Web Tasks

### W4.1 — Build Warehouse Dashboard Enhancement
Enhance `WarehouseView` component:
- **Orders to Pick** card: Count of pending pick lists → links to `/operations` pick lists tab
- **Trips Ready to Dispatch** card: Count of planned trips → links to `/delivery?status=planned`
- **Incoming Transfers** card: Count of dispatched transfers targeting this branch → links to `/inventory/transfers?direction=incoming`
- **Low Stock** card: Count of products below threshold → links to `/inventory/stock?filter=low_stock`
- **Today's Movements** summary: In (X units) | Out (Y units) | Adjusted (Z units)

### W4.2 — Enhance Delivery Trip Detail
- Add **trip progress tracker** at top: visual bar showing 3/5 stops completed
- For each stop row: add status chip, customer name, order total, delivered value, exception badge
- Add **exception panel**: collapsible section listing all failed/partial stops with exception codes
- Add **trip summary section**: Total value, delivered value, returns value, cash collected
- Add **"Complete Trip" button** (auto-completes trip when all stops resolved)

### W4.3 — Inventory Stock Heatmap
- New view toggle on `/inventory/stock`: List (current) ↔ Heatmap
- Heatmap: Grid of products (rows) × branches (columns)
- Cell color: Green (>2× threshold), Yellow (1-2× threshold), Red (<1× threshold), Gray (no threshold set)
- Click cell → shows exact qty + threshold

### W4.4 — Enhance Stock Transfer Detail
- `/inventory/transfers/[id]` page improvements:
- Per-line receive workflow:
  - For each transfer line: qty_dispatched, qty_received (editable input), qty_damaged (editable)
  - "Receive All" bulk button
  - "Receive Line" per-line button
- Status timeline showing: Created → Dispatched (date) → Received (date)
- Movement history linked from this transfer

### W4.5 — Movement History Per Product
- On product detail page, add "Stock Movements" tab
- Table: Date | Type | Qty | Direction | Reference | Branch
- Filterable by movement type, date range, branch
- Links to source documents (order, transfer, adjustment, purchase invoice)

---

## Mobile (Flutter) Tasks

### M4.1 — Build Trip List Screen (Driver)
- Shows driver's trips (today's or all)
- Tab bar: Today | All
- Trip card: trip #, date, stop count, progress bar, status chip
- "Start Trip" button on first pending trip
- Pull-to-refresh

### M4.2 — Build Trip Detail Screen
- Trip header: trip #, status, vehicle, date
- Visual progress bar: X/N stops completed
- Scrollable stop list using `OlStopCard`:
  - Sequence number
  - Retailer name + address (truncated)
  - Order value (₹)
  - Status chip (pending/delivered/partial/failed/skipped)
  - Tap → Stop Detail
- Sticky bottom: "Navigate to Next Stop" button → opens device maps or shows address
- "Complete Trip" button (visible when all stops resolved)

### M4.3 — Build Stop Detail Screen
- **Header:** Retailer name, address (tap to open maps), phone (tap to call)
- **Order lines:** Product | Qty | Amount — scrollable table
- **Action buttons (large, full-width):**
  - 🟢 "Delivered" (mark full delivery)
  - 🟡 "Partial Delivery" (opens per-line qty editor)
  - 🔴 "Failed" (opens exception picker)
  - ⏭ "Skip" (opens reason picker)
- All actions lead to POD capture (except Skip)

### M4.4 — Build Partial Delivery Flow
- Shows order lines with editable `qty_delivered` per line
- Pre-filled with ordered qty, user adjusts down
- Lines with qty difference automatically flagged as returns
- For returned items: reason code picker (damaged, expired, refused, wrong, quality)
- Summary: "Delivering 8 of 10 items. Returning 2 items."
- Proceed to POD capture

### M4.5 — Build POD Capture Screen
- Tab-like selection: 📷 Photo | ✍ Signature | 🔢 OTP | 🔓 Override
- **Photo:** Camera opens, single tap capture, auto-compress to <500KB, preview
- **Signature:** Full-screen `OlSignaturePad`, clear/redo, "Done" button
- **OTP:** Large 4-digit input field, customer types code on driver's phone. Verify against pre-loaded hash
- **Override:** Enter manager PIN/password → audit logged as override
- After POD → Confirmation: "Stop #3 completed — Delivered" with green check animation
- Auto-advance to next pending stop

### M4.6 — Build Returns at Delivery Flow
- During partial delivery, for rejected items:
  - Product name + qty_rejected (auto-calculated)
  - Reason code picker: Damaged | Expired | Wrong Product | Quality Issue | Customer Refused
  - Condition: Resalable | Damaged | Expired
  - Optional: photo of damaged goods
- All saved locally in `delivery_rejections` Drift table
- Queued for sync → creates DeliveryRejection + auto ReturnRequest on server

### M4.7 — Build Cash Collection at Delivery
- After delivery completion, optional prompt: "Collect cash for this order?"
- If yes → Quick collect flow prefilled with customer and order amount
- Simple: amount (pre-filled with order total), mode (default: cash), reference (optional)
- Saved locally, queued for sync as payment

### M4.8 — Offline Delivery Support
- All trip data (stops, order lines) cached in Drift on trip assignment
- Delivery outcomes (complete, partial, failed, skip) saved locally immediately
- POD photos saved to app local storage (not external)
- Sync queue processes delivery operations when online
- Idempotency key per stop completion prevents doubles

---

## Migrations Needed
- None (pick_lists created in Phase 3)

## API Changes
- Enhanced: Trip stop completion with offline-friendly payload
- New: `GET /api/v1/delivery_trips/:id/summary`
- Enhanced: Auto-create return request from delivery rejections

## Acceptance Criteria
- [ ] Warehouse dashboard shows pick lists, dispatch queue, incoming transfers, low stock
- [ ] Delivery trip detail shows progress tracker and exception panel
- [ ] Inventory heatmap view works
- [ ] Stock transfer detail allows per-line receiving
- [ ] Product detail shows stock movement history
- [ ] Flutter: Driver sees trip list → trip detail → stop list
- [ ] Flutter: Driver can mark stop as delivered with photo POD
- [ ] Flutter: Driver can do partial delivery with per-line qty editing
- [ ] Flutter: Driver can mark stop as failed with exception code
- [ ] Flutter: Returns captured during partial delivery
- [ ] Flutter: Cash collection prompt after delivery
- [ ] Flutter: All delivery actions work offline and sync correctly

## Demo Scenarios Enabled After This Phase
- **Full delivery flow on mobile:** Driver Muthu sees trip with 5 stops → delivers to first stop → captures signature → partial delivery at second stop (2 bags damaged, returned) → third stop failed (customer closed) → collects ₹15,000 cash → all syncs when back at warehouse
- **Warehouse workflow on web:** Kumar processes pick list → confirms dispatch → trip goes to dispatched → monitors progress as driver updates
- **Inventory visibility:** Manager sees stock heatmap → identifies branch with critical rice stock → creates transfer from surplus branch
