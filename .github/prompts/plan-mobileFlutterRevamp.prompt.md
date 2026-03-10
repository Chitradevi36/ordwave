# OrderLane Pro — Mobile Flutter Revamp Plan

## 5. Mobile Flutter Revamp Plan

### 5.1 Architecture Decision

**Abandon React Native app.** Build Flutter app as the canonical mobile app using the already-selected architecture:
- **Riverpod** — state management
- **GoRouter** — navigation
- **Dio** — HTTP client
- **Drift** — local SQLite for offline
- **Freezed** — immutable models / code generation
- **WorkManager** — background sync
- **flutter_secure_storage** — token storage
- **connectivity_plus** — network state detection

The RN `mobile/` folder should be archived. Port its 8 screens' logic as reference.

### 5.2 Project Structure

```
mobile_flutter/lib/
├── main.dart
├── app.dart                          # MaterialApp + GoRouter + Riverpod scope
├── core/
│   ├── theme/
│   │   ├── app_theme.dart            # ThemeData with OrderLane tokens
│   │   ├── colors.dart               # Brand color constants
│   │   └── typography.dart           # Text styles
│   ├── network/
│   │   ├── api_client.dart           # Dio setup with interceptors
│   │   ├── auth_interceptor.dart     # JWT token injection
│   │   └── connectivity_service.dart # Network status provider
│   ├── storage/
│   │   ├── secure_storage.dart       # Token storage
│   │   └── preferences.dart          # App preferences
│   ├── sync/
│   │   ├── sync_engine.dart          # Background sync orchestrator
│   │   ├── sync_queue.dart           # Pending operations queue
│   │   ├── delta_sync.dart           # Pull delta from server
│   │   └── conflict_resolver.dart    # Conflict detection + resolution
│   ├── database/
│   │   ├── app_database.dart         # Drift database definition
│   │   ├── app_database.g.dart       # Generated
│   │   ├── tables/                   # Drift table definitions
│   │   └── daos/                     # Data access objects
│   └── utils/
│       ├── currency.dart             # ₹ formatting
│       ├── date.dart                 # Date/time helpers
│       └── validators.dart           # Input validators
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── auth_api.dart
│   │   ├── domain/
│   │   │   └── auth_state.dart
│   │   ├── presentation/
│   │   │   ├── login_screen.dart
│   │   │   └── splash_screen.dart
│   │   └── providers/
│   │       └── auth_provider.dart
│   ├── home/
│   │   ├── presentation/
│   │   │   ├── sales_rep_home.dart
│   │   │   ├── driver_home.dart
│   │   │   └── home_screen.dart      # Routes to role-specific home
│   │   └── providers/
│   │       └── dashboard_provider.dart
│   ├── retailers/
│   │   ├── data/
│   │   │   ├── retailer_repository.dart
│   │   │   └── retailer_api.dart
│   │   ├── domain/
│   │   │   └── retailer.dart         # Freezed model
│   │   ├── presentation/
│   │   │   ├── retailer_list_screen.dart
│   │   │   ├── retailer_search_screen.dart
│   │   │   └── retailer_profile_screen.dart
│   │   └── providers/
│   │       └── retailer_provider.dart
│   ├── orders/
│   │   ├── data/
│   │   │   ├── order_repository.dart
│   │   │   └── order_api.dart
│   │   ├── domain/
│   │   │   ├── order.dart
│   │   │   ├── order_line.dart
│   │   │   └── cart.dart
│   │   ├── presentation/
│   │   │   ├── new_order_screen.dart
│   │   │   ├── product_picker_screen.dart
│   │   │   ├── cart_screen.dart
│   │   │   ├── credit_check_screen.dart
│   │   │   ├── order_confirmation_screen.dart
│   │   │   └── order_list_screen.dart
│   │   └── providers/
│   │       ├── order_provider.dart
│   │       └── cart_provider.dart
│   ├── collections/
│   │   ├── data/
│   │   │   ├── payment_repository.dart
│   │   │   └── payment_api.dart
│   │   ├── domain/
│   │   │   └── payment.dart
│   │   ├── presentation/
│   │   │   ├── quick_collect_screen.dart
│   │   │   ├── collection_schedule_screen.dart
│   │   │   └── collection_list_screen.dart
│   │   └── providers/
│   │       └── collection_provider.dart
│   ├── delivery/
│   │   ├── data/
│   │   │   ├── trip_repository.dart
│   │   │   └── trip_api.dart
│   │   ├── domain/
│   │   │   ├── trip.dart
│   │   │   └── trip_stop.dart
│   │   ├── presentation/
│   │   │   ├── trip_list_screen.dart
│   │   │   ├── trip_detail_screen.dart
│   │   │   ├── stop_detail_screen.dart
│   │   │   ├── pod_capture_screen.dart
│   │   │   └── returns_capture_screen.dart
│   │   └── providers/
│   │       └── delivery_provider.dart
│   ├── beats/
│   │   ├── data/
│   │   │   └── beat_repository.dart
│   │   ├── domain/
│   │   │   └── beat_schedule.dart
│   │   ├── presentation/
│   │   │   ├── beat_plan_screen.dart
│   │   │   └── checkin_screen.dart
│   │   └── providers/
│   │       └── beat_provider.dart
│   ├── notifications/
│   │   ├── presentation/
│   │   │   └── notification_center_screen.dart
│   │   └── providers/
│   │       └── notification_provider.dart
│   ├── sync/
│   │   ├── presentation/
│   │   │   └── sync_center_screen.dart
│   │   └── providers/
│   │       └── sync_provider.dart
│   └── settings/
│       └── presentation/
│           └── settings_screen.dart
└── shared/
    └── widgets/
        ├── ol_app_bar.dart
        ├── ol_button.dart
        ├── ol_card.dart
        ├── ol_status_chip.dart
        ├── ol_list_item.dart
        ├── ol_text_field.dart
        ├── ol_amount_input.dart
        ├── ol_bottom_sheet.dart
        ├── ol_sync_badge.dart
        ├── ol_credit_banner.dart
        ├── ol_empty_state.dart
        ├── ol_product_card.dart
        ├── ol_stop_card.dart
        ├── ol_signature_pad.dart
        └── ol_loading_shimmer.dart
```

### 5.3 Sales Rep Experience

#### Home Screen (Sales Rep)
- **User goal:** See today's plan and progress at a glance
- **Layout:** Greeting ("Good morning, Rajan") + KPI row (visits done/total, orders today ₹, collections today ₹) + today's beat list (scrollable cards) + FAB for "New Order"
- **Offline behavior:** Fully cached from last sync. Shows stale data warning if >2hrs since sync
- **Sync indicator:** Top bar shows "Synced 5m ago" or amber "2 pending" badge
- **Validation:** None on home screen
- **Success feedback:** KPI cards update after sync completes
- **Failure recovery:** Pull-to-refresh triggers manual sync
- **One-hand usability:** FAB at bottom-right, KPI cards at top, scrollable list below
- **Sunlight readability:** High-contrast white cards on subtle green background, bold numbers

#### Beat Plan Screen
- **User goal:** See today's retailer visit sequence and progress
- **Layout:** Date header + scrollable list of retailers in beat sequence. Each card shows: retailer name, channel badge, outstanding amount, credit status chip, last visit date. Green check overlay for visited retailers
- **Sticky actions:** "Check In" button on each unvisited retailer card
- **Offline behavior:** Cached beat schedule + retailer data. Check-in saved locally
- **Sync indicators:** Pending check-ins show yellow clock icon
- **Validation:** GPS must be enabled for check-in (show prompt if disabled)
- **Success feedback:** Card transitions to "visited" state with green check animation
- **Failure recovery:** Failed GPS capture → manual check-in with "GPS unavailable" flag
- **One-hand usability:** Vertical scroll, large tap targets, swipe-to-skip

#### Retailer Profile Screen
- **User goal:** See customer details + credit status before creating order
- **Layout:** Header card (name, channel, tier, credit status badge), Outstanding summary bar (₹ outstanding / ₹ limit with utilization gauge), Quick info grid (last order, last payment, last visit, overdue days), Contacts section (tap to call), Addresses section
- **Sticky actions:** Bottom bar with "New Order" + "Quick Collect" buttons
- **Offline behavior:** Cached retailer data with stale indicator
- **Trust actions:** Outstanding, last payment, last order, credit status immediately visible — builds sales rep trust in data accuracy

#### New Order Flow
- **Step 1: Select Retailer**
  - Search with recent/favorites section
  - Each result shows credit status chip + outstanding
  - Tap to select → advance to products
  
- **Step 2: Add Products**
  - Category filter tabs (horizontal scroll)
  - Search bar
  - "Recent orders" shortcut button → loads last order's products
  - Product cards: name, SKU, unit, price, stock availability badge
  - Qty input: +/- stepper buttons (large 48dp targets)
  - Running cart total at bottom
  
- **Step 3: Review Cart**
  - Line items with qty × price = line total
  - Scheme applications shown (if any: "Buy 5 Get 1 Free" badge)
  - Subtotal → Discount → GST → Grand Total breakdown
  - "Apply Scheme" button if eligible schemes detected
  - Editable quantities with swipe-to-remove
  
- **Step 4: Credit Check + Submit**
  - Auto-runs credit check on submit
  - **OK (green):** "Credit OK — ₹15,000 available credit" → Submit button
  - **HOLD (amber):** "Order on hold — overdue ₹5,000 (15 days). Collect first or request manager approval." → Submit Anyway + Collect Now buttons
  - **BLOCKED (red):** "Credit blocked — overdue ₹25,000 (45 days). Must collect ₹X before ordering." → Collect Now + Call Manager buttons

- **Offline behavior:** Order saved to Drift `pending_orders` table. Cart persisted locally. Visual indicator: "Queued — will sync when online" with green check icon
- **Sync indicators:** Orders list shows "Synced" / "Pending" / "Failed" per order
- **Large tap targets:** Minimum 48dp, +/- steppers 56dp, full-width submit button
- **Minimal typing:** Category/recent filters, stepper controls, no manual price entry

#### Collection Screen
- **Quick collect flow:** Select customer (search) → Enter amount (numeric keypad, ₹ prefix) → Select mode (cash/UPI/cheque/bank — icon buttons) → Add reference (optional: cheque#, UPI ref, transaction ID) → Review summary → Confirm
- **Collection schedule:** List of planned collections for today with expected amounts
- **Recent collections:** List with sync status (synced/pending/failed)
- **Offline behavior:** Saved locally, queued for sync. Shows "Pending" badge
- **Success feedback:** Green checkmark animation + "₹12,000 collected from Sri Lakshmi Stores" toast

### 5.4 Driver Experience

#### Home Screen (Driver)
- **User goal:** See today's trip at a glance
- **Layout:** Trip summary card (X stops, Y delivered, Z remaining, trip status), Progress bar, "Start Trip" large button (if not started), Stop list preview (first 3 stops), Cash collected today
- **Offline behavior:** Trip data cached. Delivery actions saved locally
- **One-hand usability:** Single primary action button, minimal scrolling

#### Trip Screen
- **User goal:** See all stops and navigate through deliveries
- **Layout:** Horizontal progress bar (3/5 stops), Scrollable stop list with status chips. Each stop card: sequence #, retailer name, address preview, order total, items count, status chip
- **Sticky actions:** "Navigate to Next Stop" button at bottom (opens maps if available, shows address if not)
- **Tap stop → Stop Detail**
- **Offline behavior:** All trip data cached locally. Delivery outcomes saved immediately to Drift

#### Stop Detail Screen
- **User goal:** Complete delivery for this stop
- **Layout:** Retailer header (name + address + phone — tap to call), Order lines table (product, qty, amount), Action buttons: "Mark Delivered" (full), "Partial Delivery", "Failed", "Skip"
- **Mark Delivered:** Captures POD → moves to next stop
- **Partial Delivery:** Edit delivered qty per line → enter reason for partial → capture POD → creates delivery rejections for remainder
- **Failed:** Select exception code (customer closed, refused, not reachable, wrong address, safety concern, vehicle breakdown, other) → optional photo → optional notes
- **Skip:** Select reason → auto-advances to next stop
- **One-hand usability:** Large outcome buttons, swipe gestures for navigation

#### POD Capture Screen
- **Methods:** Photo (camera) or Signature (signature pad) or OTP (4-digit code from customer) or Manager Override (requires manager PIN)
- **Photo:** Single-tap camera, auto-compress to <500KB, thumbnail preview
- **Signature:** Full-screen signature pad (landscape encouraged), clear/redo button
- **OTP:** Customer enters 4-digit code on driver's phone, verified locally (from trip data)
- **Offline behavior:** Photo + signature saved to local storage, queued for upload. OTP verified locally against pre-downloaded hash
- **Sunlight readability:** High contrast signature pad, large OTP digits

#### Returns at Delivery
- **During partial delivery:** Per-line return qty + reason code picker (damaged, expired, wrong product, quality issue, customer refused) + condition (resalable/damaged/expired)
- **Creates `DeliveryRejection` records locally, queued for sync**
- **Minimal typing:** Reason codes and conditions are tap-select, not free text

### 5.5 Offline Architecture

#### Local Database (Drift)
Mirror key tables for offline access:

```
Tables:
- retailers (id, name, code, channel, tier, status, credit_status, outstanding, credit_limit, ...)
- products (id, sku, name, category, unit, price, gst_rate, stock_available, ...)
- price_list_items (id, product_id, price_list_id, unit_price, min_qty, discount_pct)
- beat_schedules (id, beat_id, sales_rep_id, weekday, retailer_sequence JSON)
- delivery_trips (id, trip_number, status, driver_id, stop_count, ...)
- trip_stops (id, trip_id, sequence, retailer_id, order_id, status, ...)
- order_lines_cache (id, order_id, product_id, qty, unit_price, ...)
- sync_metadata (entity_type, last_synced_at, record_count)
```

#### Sync Queue (Drift table)
```
pending_operations:
  - id: auto-increment
  - entity_type: string (order, payment, visit_log, delivery_outcome, return)
  - operation: string (create, update, complete_stop, checkin, checkout)
  - payload_json: text (full request payload)
  - idempotency_key: string (UUID, prevents duplicates)
  - status: enum (queued, syncing, synced, failed)
  - created_at: datetime
  - retry_count: int (max 5)
  - error_message: text (nullable)
  - last_attempted_at: datetime (nullable)
```

#### Sync Engine
- **Background sync:** WorkManager periodic task (every 15 minutes) + connectivity change trigger
- **Pull (delta sync):**
  ```
  GET /api/v1/sync/delta?since={ISO8601_timestamp}&entity_types=customers,products,price_lists,beat_schedules
  ```
  Response: `{ "data": { "customers": [...], "products": [...] }, "meta": { "server_time": "..." } }`
  
- **Push (batch operations):**
  ```
  POST /api/v1/sync/push
  Body: { "operations": [{ "idempotency_key": "...", "entity_type": "order", "operation": "create", "payload": {...} }, ...] }
  ```
  Response: `{ "results": [{ "idempotency_key": "...", "status": "success", "server_id": 1234 }, { ..., "status": "conflict", "conflict_data": {...} }] }`

- **Conflict resolution:** Last-writer-wins for most entities. For orders and payments (high-value): if server returns 409 Conflict, mark operation as "needs review" and surface conflict resolution UI to user

#### Sync Center Screen
- **Shows:** Pending operations count + list, last sync time, connectivity status (online/offline badge), manual "Sync Now" button
- **Tap on pending operation:** See entity type, operation, timestamp, payload preview
- **Tap on failed operation:** See error message, Retry / Discard buttons
- **Visual states:**
  - Green check → "All synced"
  - Yellow clock + count → "3 pending operations"
  - Red exclamation → "2 operations failed — tap to review"
  - Gray wifi-off → "Offline — operations will sync when connected"

### 5.6 Reusable Mobile Components

| Component | Description | Key Properties |
|---|---|---|
| `OlAppBar` | App bar with title, subtitle, actions, offline indicator | title, subtitle, leadingAction, trailingActions, showSyncBadge |
| `OlCard` | Elevated/outlined card | variant (elevated/outlined/flat), child, onTap, padding |
| `OlStatusChip` | Colored pill matching web status colors | status, size (sm/md) |
| `OlListItem` | Row with leading, title/subtitle, trailing | leading, title, subtitle, trailing, onTap, showDivider |
| `OlButton` | Full button system | variant (primary/secondary/outline/ghost/danger), size, loading, fullWidth, icon |
| `OlTextField` | Labeled input with validation | label, hint, error, controller, keyboardType, validator |
| `OlAmountInput` | Numeric input with ₹ prefix | value, onChanged, label. Auto-formats with Indian number system |
| `OlBottomSheet` | Slide-up action sheet | title, child, actions. Handles safe area + keyboard |
| `OlSyncBadge` | synced/pending/failed indicator | syncStatus enum. Positioned in list items |
| `OlCreditBanner` | Customer credit status | creditDecision (ok/hold/blocked), outstanding, limit, overdueDays. Color-coded |
| `OlEmptyState` | Centered icon + message + action | icon, title, description, actionLabel, onAction |
| `OlProductCard` | Product with qty stepper | product, qty, onQtyChanged, price. Large +/- buttons |
| `OlStopCard` | Delivery stop summary | stop, onTap. Shows sequence, retailer, status, amount |
| `OlSignaturePad` | Signature capture | onSaved. Uses syncfusion_flutter_signaturepad |
| `OlLoadingShimmer` | Shimmer placeholder | width, height, borderRadius. Uses shimmer package |
