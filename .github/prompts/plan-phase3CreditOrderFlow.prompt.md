# OrderLane Pro — Phase 3: Credit + Order Flow Completion

## Goal
Complete order lifecycle from mobile and web, with credit checks. Warehouse sees pick lists. Delta sync enables offline order creation.

**Duration:** ~2 weeks

## Modules Touched
- Sales Orders (web enhancement + mobile build)
- Credit Engine (mobile integration)
- Pick Lists (NEW — backend + web)
- Schemes (order integration)
- Delta Sync API (NEW — backend)
- Offline Order Queue (mobile build)

---

## Backend Tasks

### B3.1 — Create PickList Model + Migration
```ruby
create_table :pick_lists do |t|
  t.references :organization, null: false, foreign_key: true
  t.references :branch, null: false, foreign_key: true
  t.references :sales_order, null: false, foreign_key: true
  t.references :picker, foreign_key: { to_table: :users }
  t.string :status, null: false, default: 'pending'
  t.datetime :started_at
  t.datetime :completed_at
  t.timestamps
end

create_table :pick_list_items do |t|
  t.references :pick_list, null: false, foreign_key: true
  t.references :product, null: false, foreign_key: true
  t.integer :qty_requested, null: false
  t.integer :qty_picked, default: 0
  t.string :bin_location
  t.datetime :picked_at
  t.timestamps
end

add_index :pick_lists, [:organization_id, :status]
add_index :pick_list_items, [:pick_list_id, :product_id], unique: true
```

### B3.2 — PickList Auto-Creation in ApproveOrderService
When an order is approved, automatically create a pick list:
```ruby
# In Orders::ApproveOrderService, after status transition
pick_list = PickList.create!(
  organization: order.organization,
  branch: order.branch,
  sales_order: order,
  status: 'pending'
)

order.lines.each do |line|
  pick_list.pick_list_items.create!(
    product: line.product,
    qty_requested: line.qty
  )
end
```

### B3.3 — PickList Controller + Endpoints
```ruby
# GET    /api/v1/pick_lists                  — list (filterable: status, branch_id)
# GET    /api/v1/pick_lists/:id              — show with items
# POST   /api/v1/pick_lists/:id/start        — mark in_progress, set picker
# PATCH  /api/v1/pick_lists/:id/items/:item_id — update qty_picked
# POST   /api/v1/pick_lists/:id/complete     — mark completed (validates all items picked)
```

### B3.4 — Delta Sync API
```ruby
# GET /api/v1/sync/delta
# Params: since (ISO8601), entity_types (comma-separated: customers,products,price_list_items)
#
# Response:
# {
#   data: {
#     customers: { upserted: [...], deleted_ids: [...] },
#     products: { upserted: [...], deleted_ids: [...] },
#     price_list_items: { upserted: [...], deleted_ids: [...] }
#   },
#   meta: {
#     server_time: "2026-03-09T12:00:00Z",
#     has_more: false,
#     counts: { customers: 5, products: 2, price_list_items: 10 }
#   }
# }

class Api::V1::SyncController < Api::V1::BaseController
  def delta
    since = params[:since] ? Time.parse(params[:since]) : 1.year.ago
    entity_types = (params[:entity_types] || 'customers,products').split(',')
    
    data = {}
    entity_types.each do |type|
      case type
      when 'customers'
        scope = policy_scope(Customer).where(organization: current_organization)
        data[:customers] = {
          upserted: scope.where('updated_at > ?', since).as_json(only: [...]),
          deleted_ids: scope.only_deleted.where('deleted_at > ?', since).pluck(:id)
        }
      when 'products'
        scope = current_organization.products
        data[:products] = {
          upserted: scope.where('updated_at > ?', since).as_json(only: [...]),
          deleted_ids: scope.only_deleted.where('deleted_at > ?', since).pluck(:id)
        }
      when 'price_list_items'
        # Return items from active price lists for this branch
        active_list_ids = current_organization.price_lists.active.pluck(:id)
        data[:price_list_items] = {
          upserted: PriceListItem.where(price_list_id: active_list_ids).where('updated_at > ?', since).as_json(only: [...]),
          deleted_ids: []
        }
      end
    end
    
    render_success(data, meta: { server_time: Time.current.iso8601, has_more: false })
  end
end
```

### B3.5 — Batch Push API for Mobile Operations
```ruby
# POST /api/v1/sync/push
# Body: { operations: [{ idempotency_key, entity_type, operation, payload }, ...] }
#
# Response:
# { results: [{ idempotency_key, status: "success"|"conflict"|"error", server_id?, error_message? }, ...] }

class Api::V1::SyncController < Api::V1::BaseController
  def push
    results = params[:operations].map do |op|
      process_sync_operation(op)
    end
    render_success(results: results)
  end
  
  private
  
  def process_sync_operation(op)
    # Check idempotency — if already processed, return existing result
    existing = SyncOperation.find_by(idempotency_key: op[:idempotency_key])
    return existing_result(existing) if existing&.succeeded?
    
    case "#{op[:entity_type]}.#{op[:operation]}"
    when 'order.create'
      order = Orders::DraftUpsertService.new(current_user, current_organization, op[:payload].merge(idempotency_key: op[:idempotency_key])).call
      Orders::SubmitOrderService.new(current_user, order).call if op[:payload][:auto_submit]
      { idempotency_key: op[:idempotency_key], status: 'success', server_id: order.id }
    when 'payment.create'
      # Similar pattern
    when 'visit.checkin'
      # Similar pattern
    end
  rescue => e
    { idempotency_key: op[:idempotency_key], status: 'error', error_message: e.message }
  end
end
```

### B3.6 — Enhance from_mobile Order Endpoint
The existing `POST /api/v1/sales_orders/from_mobile` should:
- Accept idempotency_key
- Return credit decision in response body
- Include scheme application details
- Return created order with all line details

---

## Web Tasks

### W3.1 — Add Kanban View Toggle for Orders
- Add toggle button on orders list page: List view (current) ↔ Board view
- Board view: columns for each status (Draft | Submitted | On Hold | Approved | Dispatched | Delivered)
- Cards show: order #, customer, amount, date, time since status change
- Drag-and-drop not needed initially — click to view detail

### W3.2 — Enhance Order Detail with Visual Timeline
- Replace current audit table tab with `StatusTimeline` component
- Shows: Draft → Submitted (by Rajan, 9:15 AM) → Approved (by Priya, 9:30 AM) → Dispatched (10:00 AM) → Delivered (11:30 AM)
- Include credit decision event with decision type and snapshot
- Include scheme application event if schemes applied

### W3.3 — Add Actions on Order Detail
- "Generate Invoice" button on delivered orders (calls `POST /api/v1/sales_invoices/generate_from_order`)
- "Create Delivery Trip" quick action on approved orders (pre-fills trip creation with this order)
- "Refresh Prices" button on draft orders

### W3.4 — Build Pick List View for Warehouse Dashboard
- Add "Pick Lists" tab in Operations workspace
- Table: Pick List # | Order # | Customer | Items | Status | Picker | Actions
- Click → Pick list detail with item checklist
- "Start Picking" button → assigns current user as picker, moves to in_progress
- Per-item: checkbox + qty_picked input
- "Complete" button → validates all items picked

### W3.5 — Scheme Applied Summary on Order Detail
- Add "Applied Schemes" section showing:
  - Scheme name + type
  - Discount/freebie details
  - Savings amount
- Only visible if `scheme_snapshot` is present on the order

---

## Mobile (Flutter) Tasks

### M3.1 — Build New Order Flow
**Screen 1: Select Retailer**
- Search from local Drift DB (instant results)
- Recent customers section (last 5 ordered from)
- Each result shows: name, outstanding, credit status chip
- Tap to select → navigate to product picker

**Screen 2: Product Picker**
- Category filter (horizontal scrollable chips from local DB)
- Search bar (searches product name, SKU from local DB)
- "From Last Order" button → loads previous order's products with quantities
- Product list: product name, SKU, unit, price (from cached price list), stock badge
- Add button with quantity stepper (+/- buttons, 48dp tap targets)
- Running cart total at bottom of screen
- "Review Cart (N items)" sticky bottom button

**Screen 3: Cart Review**
- Editable line items: product, qty (editable stepper), unit price (read-only), line total
- Swipe-to-remove item
- Scheme applications shown if applicable (green badge: "Buy 5 Get 1 Free applied")
- Summary: Subtotal → Discount → GST → Grand Total
- "Submit Order" primary button

**Screen 4: Credit Check Result**
- Auto-runs against cached credit data OR live API call (if online)
- **OK (green screen):**
  - ✓ icon + "Credit Approved"
  - Available credit: ₹35,000
  - "Submit Order" button
  - Success → Order confirmation with order number
  
- **HOLD (amber screen):**
  - ⚠ icon + "Order requires manager approval"
  - Reason: "Overdue ₹5,000 (15 days)"
  - Two buttons: "Submit Anyway (will need approval)" | "Collect First"
  - Collect First → navigates to Quick Collect prefilled with customer
  
- **BLOCKED (red screen):**
  - ✕ icon + "Credit Blocked"
  - Reason: "Overdue ₹25,000 (45 days). Requires collection of ₹X before ordering."
  - Two buttons: "Collect Now" | "Call Manager"
  - Cannot submit order — must collect or get manager override

### M3.2 — Build Cart Provider (Riverpod)
```dart
// Cart state managed via Riverpod
// Persists to Drift for offline recovery (if app crashes mid-cart)
@riverpod
class CartNotifier extends _$CartNotifier {
  @override
  Cart build() => Cart.empty();
  
  void addProduct(Product product, int qty, double price);
  void updateQty(int productId, int qty);
  void removeProduct(int productId);
  void clearCart();
  Cart applySchemes(List<SchemeApplication> schemes);
  Future<CreditCheckResult> submitOrder();
}
```

### M3.3 — Implement Offline Order Queue
- When order submitted offline:
  1. Validate locally (customer, products, amounts)
  2. Save to `pending_orders` Drift table
  3. Add to `pending_operations` sync queue
  4. Show confirmation: "Order queued — will sync when online" with green check
  5. Assign temporary local order number (prefixed with `L-`)
  
- When online:
  1. Sync engine picks up pending operation
  2. Calls `POST /api/v1/sync/push` with order payload + idempotency_key
  3. On success: update local order with server ID and order number
  4. On conflict: mark as "needs review" — surface in sync center

### M3.4 — Build Order List Screen
- Tab bar: All | Pending Sync | Submitted | Approved | Delivered
- Each order card: order #, customer name, amount, date, status chip, sync badge
- Pending sync orders show yellow clock icon
- Tap → order detail (read-only summary)

### M3.5 — Implement Background Sync
- Set up WorkManager for periodic sync (every 15 minutes)
- Trigger sync on connectivity change (offline → online)
- Sync process:
  1. Push: Process pending operations queue (FIFO)
  2. Pull: Delta sync for customers, products, price lists
  3. Update sync metadata timestamps
- Show sync progress in app bar badge

---

## Migrations Needed
1. `create_pick_lists` — pick_lists + pick_list_items tables
2. `create_sync_operations` — server-side sync tracking table

## API Changes
- New: `GET/POST /api/v1/pick_lists`, `POST /start`, `POST /complete`, `PATCH /items/:id`
- New: `GET /api/v1/sync/delta`
- New: `POST /api/v1/sync/push`
- Enhanced: `POST /api/v1/sales_orders/from_mobile` (idempotency, credit response)

## Acceptance Criteria
- [ ] Approving an order auto-creates a pick list
- [ ] Warehouse staff can view, start, and complete pick lists on web
- [ ] Order detail shows visual timeline instead of audit table
- [ ] Kanban view toggle works on orders page
- [ ] "Generate Invoice" action available on delivered orders
- [ ] Flutter: Sales rep can create a complete order (retailer → products → cart → credit check → submit)
- [ ] Flutter: Order creation works offline — saved to local DB, queued for sync
- [ ] Flutter: Credit check shows OK/HOLD/BLOCKED with appropriate UX
- [ ] Flutter: Sync engine pushes offline orders when connectivity returns
- [ ] Flutter: Delta sync pulls updated customers/products on background schedule
- [ ] Order list on mobile shows sync status per order

## Demo Scenarios Enabled After This Phase
- **Complete order flow on mobile:** Sales rep Rajan searches "Sri Lakshmi Stores" → adds 10 bags rice → reviews cart → credit check OK → submits → order #1247 created
- **Offline order:** Rajan goes offline → creates order → sees "Queued" badge → goes online → order syncs → badge turns green
- **Credit hold:** Rajan tries to order for overdue customer → sees amber HOLD screen → chooses "Collect First" → redirected to collection
- **Warehouse flow:** Kumar sees "3 orders to pick" → starts pick list → checks off items → completes → order ready for dispatch
- **Manager timeline:** Priya views order #1247 detail → sees full visual timeline from draft to delivery
