# OrderLane Pro — Phase 7: Mobile Flutter Offline Experience Polish

## Goal
Offline-first experience is robust, reliable, and delightful. Sync conflicts handled gracefully. Performance optimized.

**Duration:** ~1.5 weeks

## Modules Touched
- Sync Engine (major enhancement)
- Offline Data Layer (enhancement)
- Conflict Resolution (NEW)
- Performance Optimization (mobile)
- Error Recovery (mobile)
- UX Polish (mobile)

---

## No New Backend Tasks
(All APIs already built in Phases 0-6. This phase focuses on mobile-side polish.)

Only minor backend adjustments if discovered during testing:
- Add `conflict_resolution` field to sync push response if needed
- Ensure all entity endpoints support `If-Modified-Since` header for cache validation

---

## Mobile (Flutter) Tasks

### M7.1 — Robust Sync Engine
Enhance the sync engine built in Phase 3:

**Sync Priority Queue:**
```dart
enum SyncPriority { critical, high, normal, low }

// critical: Payments, delivery completions (money/fulfillment)
// high: Orders, visit logs (business operations)
// normal: Return requests, collection schedule updates
// low: Profile updates, preferences
```

**Retry Logic:**
```dart
class SyncEngine {
  static const maxRetries = 5;
  static const backoffBase = Duration(seconds: 2);
  
  Future<SyncResult> processQueue() async {
    final pending = await _db.getPendingOperations(orderBy: 'priority ASC, created_at ASC');
    
    for (final op in pending) {
      try {
        final result = await _pushOperation(op);
        if (result.isSuccess) {
          await _markCompleted(op, result.serverId);
        } else if (result.isConflict) {
          await _handleConflict(op, result);
        }
      } catch (e) {
        op.retryCount++;
        if (op.retryCount >= maxRetries) {
          op.status = SyncStatus.failed;
          // Surface to user in sync center
        } else {
          op.nextRetryAt = DateTime.now().add(backoffBase * pow(2, op.retryCount));
        }
        await _db.updateOperation(op);
      }
    }
  }
}
```

**Batch pushing optimization:**
- Group pending operations by entity type
- Push in batches of up to 10 operations per API call
- Reduces API calls from N to N/10

### M7.2 — Conflict Resolution UI
When server returns conflict (e.g., price changed, customer credit updated):

**Auto-resolvable conflicts (silent):**
- Customer data updated (name, address) → silently accept server version
- Product price changed → update local cache, recalculate affected pending orders
- Beat schedule changed → update local schedule

**User-resolvable conflicts:**
- Order submitted but customer now blocked:
  - Show dialog: "Customer credit was blocked after you created this order. Cancel order or request override?"
  - Options: "Cancel Order" | "Request Override"
  
- Order submitted but product price changed:
  - Show dialog: "Prices updated since this order was created. Review updated totals?"
  - Shows: old total vs new total
  - Options: "Accept New Prices" | "Cancel Order"

- Payment amount exceeds outstanding (customer paid on web too):
  - Show dialog: "Outstanding for {customer} is now ₹{new_amount}. Your ₹{payment_amount} exceeds it. Adjust?"
  - Options: "Send as Advance" | "Adjust Amount" | "Cancel"

**Conflict resolution service:**
```dart
class ConflictResolver {
  Future<ConflictAction> resolve(SyncConflict conflict) async {
    if (conflict.isAutoResolvable) {
      return _autoResolve(conflict);
    }
    
    // Show bottom sheet with conflict detail and options
    final action = await showConflictDialog(conflict);
    return action;
  }
}
```

### M7.3 — Optimistic UI Updates
- When user creates order offline, immediately show it in order list with "Pending" badge
- When user collects payment, immediately update customer outstanding in local DB
- When user completes delivery stop, immediately update trip progress bar
- On sync success → remove pending badge, update with server data (order number, etc.)
- On sync failure → show error badge with tap to see details

### M7.4 — Performance Optimizations

**Lazy loading with pagination:**
- Retailer list: Load 20 at a time, infinite scroll from local DB
- Product picker: Load by category, search indexes on name + SKU
- Order list: Load 20 at a time with sort by date DESC

**Image caching:**
- Product images: Cache on first load, serve from disk
- POD photos: Compress to 500KB max, save to app-specific storage
- Clear old images (>30 days) in background maintenance job

**Database indexes (Drift):**
```dart
// Add composite indexes for common queries
@TableIndex(name: 'idx_retailers_search', columns: {#name, #code})
@TableIndex(name: 'idx_products_search', columns: {#name, #sku})
@TableIndex(name: 'idx_orders_customer_date', columns: {#customerId, #createdAt})
@TableIndex(name: 'idx_pending_ops_priority', columns: {#priority, #createdAt})
```

**Memory management:**
- Dispose controllers and streams properly in all screens
- Use `AutoDispose` Riverpod providers where appropriate
- Limit in-memory cached data to last 7 days

### M7.5 — Offline Indicator UX
- **App bar indicator:**
  - Online: No indicator (clean state)
  - Offline: Red banner below app bar: "You're offline — changes will sync when connected"
  - Syncing: Blue banner with progress: "Syncing... 3 operations remaining"
  - Sync complete: Green banner (auto-dismisses after 2 seconds): "All changes synced ✓"

- **Per-entity sync badges:**
  - ⏳ Pending sync (yellow clock icon)
  - ✓ Synced (green check — only shows briefly)
  - ⚠ Sync failed (red warning — tap for details)
  - 🔄 Syncing now (rotating icon)

- **Network change detection:**
```dart
class ConnectivityService {
  final Connectivity _connectivity;
  
  Stream<ConnectivityStatus> get statusStream =>
    _connectivity.onConnectivityChanged.map((result) {
      if (result == ConnectivityResult.none) return ConnectivityStatus.offline;
      return ConnectivityStatus.online;
    });
    
  void onConnectionRestored() {
    // Trigger sync engine
    SyncEngine.instance.processQueue();
  }
}
```

### M7.6 — Empty States for All Screens
Add proper empty state widgets for:

| Screen | Empty State Message | Action |
|--------|-------------------|--------|
| Retailer List | "No retailers found" | "Sync Now" button |
| Product Picker | "No products in this category" | "Try a different category" |
| Order List | "No orders yet" | "Create your first order" button |
| Trip List | "No trips assigned" | "Contact your manager" |
| Collection Schedule | "No collections scheduled" | "Sync for latest schedule" |
| Notifications | "All caught up!" | (just illustration) |
| Beat Plan | "No beat plan for today" | "Contact your manager" |
| Sync Center | "Everything is in sync ✓" | (green check illustration) |

Each empty state: Illustration (SVG/Lottie) + prominent text + optional CTA button

### M7.7 — Data Freshness Indicators
- On screens that show cached data, display freshness indicator:
  - "Updated just now" (< 1 min)
  - "Updated 5 min ago" (1-59 min)
  - "Updated 2 hours ago" (1-24 hours) — amber warning
  - "Last synced yesterday" (> 24 hours) — red warning + "Sync Now" button
- Pull-to-refresh on all list screens → forces delta sync for that entity

### M7.8 — Crash Recovery
- On app restart after crash, check for:
  - Incomplete orders (cart state saved in Drift) → "Resume your order to Sri Lakshmi Stores?"
  - In-progress delivery (stop was being completed) → "You were completing delivery to Sri Lakshmi. Continue?"
  - Pending sync queue → auto-trigger sync
- Use `Riverpod`'s state persistence for critical flows

### M7.9 — Accessibility Enhancements
- All interactive elements: minimum 48dp touch target
- All icons: semantic labels for screen readers
- All amount fields: accessibilityLabel includes full text ("Rupees 12,000")
- Bottom navigation: large-text friendly (5 items max)
- Color contrast: all text meets WCAG AA (4.5:1 ratio)
- Test with TalkBack (Android) and VoiceOver (iOS)

---

## Migrations Needed
- None

## API Changes
- Minor: Add `conflict_resolution` field to sync push response if needed
- Minor: Support `If-Modified-Since` header on entity endpoints

## Acceptance Criteria
- [ ] Sync engine processes queue with priority ordering and exponential backoff
- [ ] Failed syncs show in sync center with retry option
- [ ] Max 5 retries, then fails with user notification
- [ ] Price conflict during offline order → user prompted to accept or cancel
- [ ] Customer blocked during offline order → user prompted to cancel or override request
- [ ] Optimistic UI: orders appear immediately in list, updated after sync
- [ ] Offline indicator banner shows correctly in all states (online/offline/syncing/synced)
- [ ] Per-entity sync badges render correctly
- [ ] All screens have proper empty states with illustrations
- [ ] Data freshness indicator shows on all list screens
- [ ] App recovers gracefully from crashes with state preserved
- [ ] All touch targets ≥ 48dp
- [ ] Performance: retailer search returns results in < 100ms from local DB
- [ ] Performance: order creation flow completes in < 3 seconds including credit check

## Demo Scenarios Enabled After This Phase
- **Offline reliability demo:** Sales rep downloads data → airplane mode → creates 3 orders, collects 2 payments, visits 4 customers → goes online → all 9 operations sync in 5 seconds with green badges → server confirms all
- **Conflict handling:** Another user blocks customer's credit while sales rep is offline with pending order → sync detects conflict → shows clear dialog → sales rep cancels order or requests override
- **Data freshness:** Sales rep visits customer profile → sees "Updated 3 hours ago" amber warning → pulls to refresh → data updates including new outstanding balance
- **Crash recovery:** App crashes mid-order → sales rep reopens → "Resume your order?" → continues from cart review screen
