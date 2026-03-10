# OrderLane Pro — Backend/Domain Implementation Plan

## 6. Backend/Domain Implementation Plan

### 6.1 Domain Consistency Fixes

- Standardize terminology: `Customer` everywhere (not "Retailer" in some places)
- Rename product from "OmniDist OMS" to "OrderLane Pro" consistently across all seed data, emails, branded strings
- Deprecate `return_records` table — add migration to link existing data to `return_requests`, then remove model
- Add missing FK from `delivery_rejections` → `return_requests` (so delivery-time returns feed into the RMA pipeline)

### 6.2 New Models Needed

| Model | Purpose | Fields |
|---|---|---|
| `Notification` | In-app notification for all roles | `belongs_to :organization, :user (recipient), :actor (User)`. Polymorphic `notifiable`. Fields: title, body, deep_link_url, notification_type (enum: order_submitted, order_approved, order_rejected, delivery_completed, delivery_failed, payment_confirmed, payment_reversed, stock_low, credit_blocked, transfer_received, limit_change_requested, limit_change_decided, return_submitted, credit_note_issued, beat_assigned, invoice_generated), read_at (datetime, nullable), dismissed_at. Scopes: unread, for_role, recent, by_type |
| `CollectionSchedule` | Planned collection visits | `belongs_to :organization, :branch, :customer, :assigned_to (User)`. Fields: scheduled_date, amount_expected, status (enum: planned/completed/partial/skipped/rescheduled), notes, completed_payment_id (FK, nullable), rescheduled_to (date, nullable). Scopes: for_date, for_user, upcoming, overdue |
| `PickList` | Warehouse picking worksheet | `belongs_to :organization, :branch, :sales_order`. Status: pending/in_progress/completed. `has_many :pick_list_items`. Fields: started_at, completed_at, picker_id (User FK, nullable). Created automatically when order approved |
| `PickListItem` | Individual line in pick list | `belongs_to :pick_list, :product`. Fields: qty_requested, qty_picked (default 0), bin_location (string, nullable), picked_at (datetime, nullable) |
| `SyncOperation` | Server-side sync tracking for mobile | Fields: device_id, user_id, organization_id, operation_type (enum: create/update/delete), entity_type, entity_id (nullable — null for creates), idempotency_key (unique), payload (JSONB), status (enum: received/processing/succeeded/failed/conflict), conflict_data (JSONB, nullable), error_message, processed_at, created_at |

### 6.3 State Machines (Explicit Transitions)

#### SalesOrder
```
draft → submitted → {on_hold, approved, rejected} → dispatched → {delivered, partial_delivery, cancelled}

Transitions:
  submit!
    guard: lines.any? && lines.all?(&:valid?)
    action: run credit check → set credit_decision + credit_snapshot
    trigger: create Notification for branch manager
    
  approve!
    guard: current_user.manager_or_above?
    action: reserve inventory, create pick list
    trigger: create Notification for creator + warehouse
    
  hold!
    guard: current_user.manager_or_above?
    action: set hold_reason
    trigger: create Notification for creator
    
  reject!
    guard: current_user.manager_or_above?
    action: set reject_reason, release any reservations
    trigger: create Notification for creator
    
  dispatch!
    guard: delivery_trip.present? && delivery_trip.dispatched?
    action: move stock from reserved → dispatched
    
  deliver!
    guard: all trip stops for this order resolved
    action: update delivered_qty on lines, trigger auto-invoice if configured
    trigger: create Notification for accountant
    
  cancel!
    guard: status.in?(%w[draft submitted on_hold approved])
    action: release reservations, void any draft invoices
    trigger: create Notification for creator
```

#### DeliveryTrip
```
draft → planned → dispatched → {completed, cancelled}

Transitions:
  plan!
    guard: stops.any? && driver.present?
    
  dispatch!
    guard: vehicle.present?
    action: create stock movements (reserved → dispatched) for all order lines
    trigger: create Notification for driver
    
  complete!
    guard: all stops resolved (delivered/partial/failed/skipped)
    action: calculate trip summary totals
    
  cancel!
    guard: status.in?(%w[draft planned])
    action: release stock reservations for all undelivered orders
```

#### TripStop
```
pending → {delivered, partial_delivery, failed, skipped}

Transitions:
  deliver!
    guard: delivery_proof.present? || override with reason
    action: set delivered_qty = ordered_qty on all lines
    trigger: auto-generate invoice if credit_policy.auto_invoice_trigger
    
  partial_deliver!
    guard: delivery_proof.present?, per-line delivered_qty specified
    action: update delivered_qty per line, create delivery_rejections for shortfall
    trigger: auto-generate invoice for delivered portion
    
  fail!
    guard: exception_code.present?
    action: set exception_code, optional photo/notes
    trigger: create Notification for manager
    
  skip!
    guard: skip_reason.present?
```

#### Payment
```
draft → confirmed → reversed

Transitions:
  confirm!
    guard: amount > 0, customer.present?
    action: run FIFO allocator (allocate to oldest outstanding invoices), create advance if excess, sync credit account balance
    trigger: create Notification for accountant, send webhook
    
  reverse!
    guard: current_user.manager_or_above?, reason.present?
    action: reverse all allocations, re-open invoice outstanding amounts, reverse any advance payments, sync credit account
    trigger: create Notification for manager + accountant, create audit log with reason
```

#### SalesInvoice
```
draft → issued → {partially_paid, paid, void}

Transitions:
  issue!
    guard: lines.any?, amounts calculated
    action: generate invoice_number, calculate GST split, queue PDF generation, queue e-invoice if applicable
    trigger: create Notification for accountant
    
  void!
    guard: current_user.manager_or_above?, reason.present?, outstanding_amount == total (not partially paid)
    action: void invoice, adjust credit account
    trigger: create audit log with reason
    
  (partially_paid and paid are auto-transitioned by payment allocation)
```

#### ReturnRequest
```
draft → submitted → qc_in_progress → qc_completed → credit_note_issued → closed

Transitions:
  submit!
    guard: lines.any?
    action: validate line quantities
    trigger: create Notification for warehouse (QC)
    
  start_qc!
    guard: current_user.warehouse_or_above?
    
  complete_qc!
    guard: all lines have QC items
    action: calculate resalable/damaged/expired totals
    trigger: create Notification for accountant (ready for CN)
    
  issue_credit_note!  [handled by CreditNotes::IssueFromReturn service]
    action: create credit note from QC-approved items, create stock movements for resalable items, create supplier debit note for return-to-supplier items
    trigger: create Notification for accountant
```

#### StockTransfer
```
draft → dispatched → {partially_received, received, cancelled}

Transitions:
  dispatch!
    guard: lines.any?, source branch has stock
    action: deduct from source branch inventory, create stock movements
    trigger: create Notification for destination branch warehouse
    
  receive!  (per-line or bulk)
    guard: dispatched?
    action: add to destination branch inventory, record damaged qty
    trigger: create Notification for source branch
    
  cancel!
    guard: status.in?(%w[draft])
    action: release source inventory if dispatched
```

### 6.4 Policies/Permissions Matrix

| Resource | Owner/Admin | Manager | Sales Rep | Accountant | Warehouse | Driver |
|---|---|---|---|---|---|---|
| **Customers** | CRUD | CRUD (branch) | Read + Create (own assigned) | Read (credit view only) | — | Read (own stops only) |
| **Orders** | CRUD + approve + hold + reject | CRUD + approve + hold + reject (branch) | Create + Read (own) + Cancel (own draft) | Read | Read | Read (own trip orders) |
| **Payments** | CRUD + confirm + reverse | CRUD + confirm (branch) | Create (for own customers) | CRUD + confirm | — | Create (cash at delivery) |
| **Invoices** | CRUD + issue + void | CRUD + issue (branch) | Read (own order invoices) | CRUD + issue | — | — |
| **Credit Notes** | CRUD + issue + void + apply | CRUD + issue + apply (branch) | Read | CRUD + issue + apply | — | — |
| **Inventory** | Full | Full (branch) | — | — | Full (branch) | — |
| **Stock Transfers** | Full | Full (own branch as source/dest) | — | — | Full (own branch) | — |
| **Delivery Trips** | Full | Full (branch) | Read (own orders' trips) | — | Dispatch only (branch) | Read + Complete stops (own trips) |
| **Products** | CRUD | CRUD | Read | — | Read | — |
| **Price Lists** | CRUD | CRUD | Read (effective prices) | — | — | — |
| **Suppliers** | CRUD | CRUD | — | Read | — | — |
| **Purchase Invoices** | CRUD + post | CRUD + post (branch) | — | Read | Create + Post (branch) | — |
| **Settings** | Full (org + all branches) | Branch settings only | — | — | — | — |
| **Reports** | All reports | Branch reports | Own performance only | Financial reports | Inventory reports | — |
| **Credit Accounts** | Full | Full (branch) | Read (own customers) | Read + update flags | — | — |
| **Credit Policy** | Update | Read | — | Read | — | — |
| **Notifications** | Own | Own | Own | Own | Own | Own |
| **Collection Schedules** | CRUD | CRUD (branch) | Read (own) + Complete | CRUD (branch) | — | — |
| **Pick Lists** | Read | Read (branch) | — | — | Full (branch) | — |
| **Audit Logs** | Read all | Read (branch) | — | — | — | — |

### 6.5 New API Endpoints Needed

```ruby
# Notifications
GET    /api/v1/notifications                    # list (filterable: unread, type, since)
PATCH  /api/v1/notifications/:id/read           # mark read
POST   /api/v1/notifications/read_all           # mark all read
DELETE /api/v1/notifications/:id                # dismiss

# Collection Schedules
GET    /api/v1/collection_schedules             # list (filterable: date, assigned_to, status, customer_id)
POST   /api/v1/collection_schedules             # create
PATCH  /api/v1/collection_schedules/:id         # update
POST   /api/v1/collection_schedules/:id/complete  # mark completed (links to payment)
POST   /api/v1/collection_schedules/:id/skip    # mark skipped with reason
POST   /api/v1/collection_schedules/:id/reschedule # reschedule to new date

# Pick Lists
GET    /api/v1/pick_lists                       # list (filterable: status, branch)
GET    /api/v1/pick_lists/:id                   # show with items
POST   /api/v1/pick_lists/:id/start             # mark in_progress, set picker
PATCH  /api/v1/pick_lists/:id/items/:item_id    # update qty_picked per item
POST   /api/v1/pick_lists/:id/complete          # mark completed

# Mobile Sync
GET    /api/v1/sync/delta                       # delta pull (params: since, entity_types comma-separated)
POST   /api/v1/sync/push                        # batch push of offline operations
GET    /api/v1/sync/status                      # sync health (last_activity, pending_count)

# Approval Inbox (aggregate read-only)
GET    /api/v1/approvals                        # aggregates: held orders, credit limit requests, pending adjustments
                                                 # returns: { held_orders: [...], credit_requests: [...], total_count: N }
```

### 6.6 Validation Rules by Module

| Module | Validation Rules |
|---|---|
| **Customer** | name required, code unique per org, GSTIN regex (if provided), phone 10-digit Indian, email format, credit_limit >= 0, credit_days >= 0 |
| **Product** | name required, SKU unique per org (auto-generated), category required, UoM required, HSN code required (with GST rate sync), gst_rate >= 0 |
| **SalesOrder** | customer required, at least 1 line, line qty > 0, line unit_price >= 0, total >= 0, idempotency_key unique |
| **Payment** | customer required, amount > 0, mode required, reference required for cheque/neft/rtgs/upi, reversal requires reason |
| **Invoice** | at least 1 line, line amounts match calculated GST, IRN unique if e-invoiced |
| **DeliveryTrip** | at least 1 stop, driver required for dispatch, vehicle required for dispatch |
| **StockTransfer** | source != destination branch, at least 1 line, qty_requested > 0, source has sufficient stock |
| **CreditAccount** | credit_limit >= 0, available_credit = credit_limit - current_balance (auto-calculated) |
| **PurchaseInvoice** | supplier required, at least 1 line, invoice_number unique per supplier |
| **ReturnRequest** | customer required, at least 1 line, line qty_reported > 0 |
| **CollectionSchedule** | customer required, scheduled_date required (future or today), amount_expected > 0 |

### 6.7 Audit Trail Coverage

Ensure these actions write to `audit_logs` (some already do via `Auditable` concern — verify completeness):

| Action Category | Specific Actions |
|---|---|
| **Credit decisions** | credit check at order submit (decision + snapshot), limit change request, limit change approval/rejection/counter-offer, manual hold/block/unblock, watchlist toggle, collection_first toggle |
| **Order lifecycle** | create, submit, approve, hold, reject, cancel, dispatch, deliver, partial_deliver |
| **Payment lifecycle** | create, confirm, reverse (with reason), allocation created, advance created, advance applied, advance refunded |
| **Invoice lifecycle** | create, issue, void (with reason), e-invoice generated, e-waybill generated |
| **Inventory** | adjustment (with reason), reservation, release, transfer dispatch, transfer receive, purchase invoice posting |
| **Delivery** | trip create, dispatch, stop complete (with outcome), stop fail (with exception), POD override (with reason) |
| **Return/CN** | return submit, QC start, QC complete, credit note issue, credit note apply, credit note void |
| **Settings** | credit policy change, org settings change, branch settings change, approval rule change |
| **User management** | invite sent, invite accepted, role change, deactivation, branch reassignment |
| **Retailer status** | block, unblock, deactivate, credit limit change, tier change |

### 6.8 Domain Events → Notification Triggers

| Event | Notification Recipients | Type | Urgency |
|---|---|---|---|
| Order submitted | Branch manager(s) | order_submitted | high |
| Order approved | Sales rep (creator), warehouse staff | order_approved | medium |
| Order rejected | Sales rep (creator) | order_rejected | high |
| Order on hold | Sales rep (creator) | order_held | high |
| Credit blocked at order | Sales rep, accountant(s) | credit_blocked | high |
| Delivery completed | Accountant(s) — for invoicing | delivery_completed | medium |
| Delivery failed | Manager(s) | delivery_failed | high |
| Payment confirmed | Accountant(s) | payment_confirmed | low |
| Payment reversed | Manager(s), accountant(s) | payment_reversed | high |
| Stock below threshold | Warehouse staff, manager(s) | stock_low | medium |
| Transfer dispatched | Destination branch warehouse staff | transfer_received | medium |
| Credit limit change requested | Manager(s) | limit_change_requested | medium |
| Credit limit approved/rejected | Requestor (sales rep/accountant) | limit_change_decided | medium |
| Return submitted | Warehouse staff (for QC) | return_submitted | medium |
| Credit note issued | Accountant(s) | credit_note_issued | medium |
| Beat schedule assigned | Sales rep | beat_assigned | low |
| Invoice generated | Accountant(s) | invoice_generated | low |
| Trip assigned to driver | Driver | trip_assigned | high |

### 6.9 Performance & Reliability Recommendations

1. **Eager loading audit** — Systematically add `.includes()` to all list endpoints. Priority: customers (with credit_account), orders (with lines, customer), delivery_trips (with stops), payments (with allocations). Use `bullet` gem in development to detect N+1

2. **Partial indexes** — Add for common query patterns:
   ```ruby
   add_index :sales_orders, [:organization_id, :status], where: "status IN ('submitted','on_hold','approved')", name: 'idx_active_orders'
   add_index :notifications, [:user_id, :read_at], where: "read_at IS NULL", name: 'idx_unread_notifications'
   add_index :collection_schedules, [:assigned_to_id, :scheduled_date, :status], where: "status = 'planned'", name: 'idx_upcoming_collections'
   ```

3. **Redis caching** — Cache frequently-read, rarely-changed data:
   - HSN/SAC codes (TTL 24h)
   - Units of Measure (TTL 24h)  
   - Product catalog per org (TTL 1h, invalidate on product CRUD)
   - Price list items per org (TTL 1h, invalidate on price change)
   - Role list (TTL forever — 7 fixed roles)

4. **Background jobs** — Move expensive operations off request cycle:
   - Invoice PDF generation (already async via `GenerateInvoicePdfJob`)
   - E-invoice IRP calls (already async via `EinvoiceJob`)
   - Credit account recalculation (already async via `RecalculateCreditAccountJob`)
   - **NEW:** Notification creation (batch after transaction commit)
   - **NEW:** Delta sync response generation for large datasets
   - **NEW:** Collection schedule auto-generation (weekly cron from outstanding invoices)

5. **Idempotency** — Ensure all mobile-facing create endpoints check `idempotency_key`:
   - `SalesOrder` — already has idempotency_key ✅
   - `Payment` — needs idempotency_key column + check
   - `VisitLog` — already has idempotency_key ✅
   - `TripStop` completion — already has idempotency_key ✅
   - `CollectionSchedule` completion — needs idempotency_key
   - `SyncOperation` — has idempotency_key by design ✅

6. **Delta sync endpoint design:**
   ```
   GET /api/v1/sync/delta?since=2026-03-09T10:00:00Z&entity_types=customers,products
   
   Response:
   {
     "data": {
       "customers": { "upserted": [...], "deleted_ids": [...] },
       "products": { "upserted": [...], "deleted_ids": [...] }
     },
     "meta": {
       "server_time": "2026-03-09T12:00:00Z",  // use as next 'since'
       "has_more": false,
       "counts": { "customers": 15, "products": 3 }
     }
   }
   ```
   Use `updated_at > since` for upserts, soft-delete `deleted_at > since` for deletes. Paginate with cursor if >500 records changed.
