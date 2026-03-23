# Detailed Plan for Missing GA Events Implementation

Based on your OrdWave app, here's a comprehensive implementation plan for all missing GA events.

## Phase 1: High Priority Events (Week 1)

### 1.1 Order Management Events

**File:** `web/lib/analytics/events.ts` (CREATE NEW)

```typescript
// filepath: web/lib/analytics/events.ts
import { gtagEvent } from './ga';

export const orderEvents = {
  create: (orderId: string, customerName: string, totalValue: number, itemCount: number) => {
    gtagEvent('create_order', {
      transaction_id: orderId,
      value: totalValue,
      currency: 'INR',
      items_count: itemCount,
      customer_name: customerName,
    });
  },

  view: (orderId: string, status: string, totalValue: number) => {
    gtagEvent('view_item', {
      item_id: orderId,
      item_name: `Order ${orderId}`,
      item_category: 'order',
      status: status,
      value: totalValue,
      currency: 'INR',
    });
  },

  update: (orderId: string, fromStatus: string, toStatus: string) => {
    gtagEvent('update_order', {
      order_id: orderId,
      from_status: fromStatus,
      to_status: toStatus,
      timestamp: new Date().toISOString(),
    });
  },

  search: (searchQuery: string, resultsCount: number) => {
    gtagEvent('search', {
      search_term: searchQuery,
      results_count: resultsCount,
      search_category: 'orders',
    });
  },

  delete: (orderId: string, reason: string) => {
    gtagEvent('delete_order', {
      order_id: orderId,
      reason: reason,
      timestamp: new Date().toISOString(),
    });
  },

  export: (format: string, recordCount: number, dateRange: string) => {
    gtagEvent('export_data', {
      export_type: 'orders',
      export_format: format, // 'pdf', 'csv', 'excel'
      record_count: recordCount,
      date_range: dateRange,
    });
  },
};
```

**Implementation Locations:**

- **File:** `web/app/orders/page.tsx` 
  - On page load: `orderEvents.view()`
  - On search: `orderEvents.search(searchQuery, results.length)`
  - On export click: `orderEvents.export(format, count, dateRange)`

- **File:** `web/app/orders/[id]/page.tsx`
  - On page load: `orderEvents.view(orderId, status, totalValue)`
  - On status update: `orderEvents.update(orderId, oldStatus, newStatus)`

- **File:** `web/app/orders/create/page.tsx`
  - On successful creation: `orderEvents.create(orderId, customerName, value, itemCount)`

---

### 1.2 Billing Events (Complete Missing Ones)

**File:** `web/lib/analytics/events.ts` (ADD TO EXISTING)

```typescript
export const billingEvents = {
  viewPlans: (plans: Array<{plan: string; price: number; name: string}>) => {
    gtagEvent('view_item_list', {
      item_list_id: 'billing_plans',
      item_list_name: 'Subscription Plans',
      items: plans.map(p => ({
        item_id: p.plan,
        item_name: p.name,
        price: p.price,
        currency: 'INR',
      })),
    });
  },

  upgradePlan: (fromPlan: string, toPlan: string, price: number) => {
    gtagEvent('upgrade_plan', {
      from_plan: fromPlan,
      to_plan: toPlan,
      value: price,
      currency: 'INR',
      timestamp: new Date().toISOString(),
    });
  },

  downgradePlan: (fromPlan: string, toPlan: string) => {
    gtagEvent('downgrade_plan', {
      from_plan: fromPlan,
      to_plan: toPlan,
      timestamp: new Date().toISOString(),
    });
  },

  cancelSubscription: (plan: string, reason: string, daysActive: number) => {
    gtagEvent('cancel_subscription', {
      plan: plan,
      cancellation_reason: reason,
      subscription_duration_days: daysActive,
      cancelled_at: new Date().toISOString(),
    });
  },

  viewInvoice: (invoiceId: string, amount: number, dueDate: string) => {
    gtagEvent('view_invoice', {
      invoice_id: invoiceId,
      amount: amount,
      currency: 'INR',
      due_date: dueDate,
    });
  },

  downloadInvoice: (invoiceId: string, format: string) => {
    gtagEvent('download_invoice', {
      invoice_id: invoiceId,
      format: format, // 'pdf', 'csv'
    });
  },
};
```

**Implementation Locations:**

- **File:** `web/app/settings/billing/page.tsx` (Update)
  - On page load: `billingEvents.viewPlans(allPlans)`
  - On upgrade success: `billingEvents.upgradePlan(oldPlan, newPlan, price)`
  - On cancel success: `billingEvents.cancelSubscription(plan, reason, daysActive)`

---

## Phase 2: Medium Priority Events (Week 2)

### 2.1 Dispatch/Delivery Events

**File:** `web/lib/analytics/events.ts` (ADD)

```typescript
export const dispatchEvents = {
  create: (dispatchId: string, orderCount: number, totalValue: number, vehicleType: string) => {
    gtagEvent('create_dispatch', {
      dispatch_id: dispatchId,
      orders_count: orderCount,
      value: totalValue,
      currency: 'INR',
      vehicle_type: vehicleType,
      created_at: new Date().toISOString(),
    });
  },

  view: (dispatchId: string, status: string, ordersCount: number) => {
    gtagEvent('view_dispatch', {
      dispatch_id: dispatchId,
      status: status,
      orders_count: ordersCount,
    });
  },

  updateStatus: (dispatchId: string, fromStatus: string, toStatus: string) => {
    gtagEvent('update_dispatch_status', {
      dispatch_id: dispatchId,
      from_status: fromStatus,
      to_status: toStatus,
      updated_at: new Date().toISOString(),
    });
  },

  complete: (dispatchId: string, ordersDelivered: number, totalValue: number, deliveryTime: number) => {
    gtagEvent('delivery_completed', {
      dispatch_id: dispatchId,
      orders_delivered: ordersDelivered,
      value: totalValue,
      currency: 'INR',
      delivery_time_hours: deliveryTime,
      completed_at: new Date().toISOString(),
    });
  },

  failed: (dispatchId: string, reason: string, ordersAffected: number) => {
    gtagEvent('delivery_failed', {
      dispatch_id: dispatchId,
      failure_reason: reason,
      orders_affected: ordersAffected,
      failed_at: new Date().toISOString(),
    });
  },

  updateCoordinates: (dispatchId: string, lat: number, lng: number) => {
    gtagEvent('dispatch_location_updated', {
      dispatch_id: dispatchId,
      latitude: lat,
      longitude: lng,
      updated_at: new Date().toISOString(),
    });
  },
};
```

**Implementation Locations:**

- **File:** `web/app/dispatch/page.tsx`
  - On page load: Show all dispatches
  - On create button click: `dispatchEvents.create(...)`

- **File:** `web/app/dispatch/[id]/page.tsx`
  - On page load: `dispatchEvents.view(dispatchId, status, ordersCount)`
  - On status change: `dispatchEvents.updateStatus(...)`
  - On completion: `dispatchEvents.complete(...)`

- **File:** `web/app/dispatch/live-tracking/page.tsx` (if exists)
  - On location update: `dispatchEvents.updateCoordinates(...)`

---

### 2.2 Collections/Finance Events

**File:** `web/lib/analytics/events.ts` (ADD)

```typescript
export const collectionEvents = {
  recordPayment: (paymentId: string, amount: number, method: string, orderId: string) => {
    gtagEvent('record_payment', {
      payment_id: paymentId,
      value: amount,
      currency: 'INR',
      payment_method: method, // 'cash', 'check', 'bank_transfer', 'upi'
      order_id: orderId,
      recorded_at: new Date().toISOString(),
    });
  },

  generateInvoice: (invoiceId: string, amount: number, customerId: string, orderId: string) => {
    gtagEvent('generate_invoice', {
      invoice_id: invoiceId,
      value: amount,
      currency: 'INR',
      customer_id: customerId,
      order_id: orderId,
      generated_at: new Date().toISOString(),
    });
  },

  completeCollection: (collectionId: string, totalAmount: number, paymentsCount: number, collectorName: string) => {
    gtagEvent('collection_completed', {
      collection_id: collectionId,
      value: totalAmount,
      currency: 'INR',
      payments_count: paymentsCount,
      collector_name: collectorName,
      completed_at: new Date().toISOString(),
    });
  },

  recordCreditTransaction: (transactionId: string, orderId: string, amount: number, type: 'debit' | 'credit') => {
    gtagEvent('credit_transaction', {
      transaction_id: transactionId,
      order_id: orderId,
      value: amount,
      currency: 'INR',
      transaction_type: type,
      timestamp: new Date().toISOString(),
    });
  },

  generateFinanceReport: (reportType: string, dateRange: string, recordCount: number) => {
    gtagEvent('generate_report', {
      report_type: reportType, // 'collections', 'outstanding', 'cash_flow'
      date_range: dateRange,
      record_count: recordCount,
      generated_at: new Date().toISOString(),
    });
  },
};
```

**Implementation Locations:**

- **File:** `web/app/finance/collections/page.tsx`
  - On record payment: `collectionEvents.recordPayment(...)`
  - On complete collection: `collectionEvents.completeCollection(...)`

- **File:** `web/app/finance/invoices/page.tsx`
  - On generate invoice: `collectionEvents.generateInvoice(...)`
  - On view invoice: Track via billing events

- **File:** `web/app/finance/credit/page.tsx`
  - On credit transaction: `collectionEvents.recordCreditTransaction(...)`

- **File:** `web/app/finance/reports/page.tsx`
  - On generate report: `collectionEvents.generateFinanceReport(...)`

---

### 2.3 Product/Inventory Events

**File:** `web/lib/analytics/events.ts` (ADD)

```typescript
export const inventoryEvents = {
  viewProducts: (productsCount: number, categories: string[]) => {
    gtagEvent('view_item_list', {
      item_list_id: 'product_catalog',
      item_list_name: 'Product Inventory',
      item_count: productsCount,
      categories: categories,
    });
  },

  searchProducts: (searchQuery: string, resultsCount: number, category: string) => {
    gtagEvent('search', {
      search_term: searchQuery,
      results_count: resultsCount,
      search_category: category || 'all',
    });
  },

  filterProducts: (filters: Record<string, any>, resultsCount: number) => {
    gtagEvent('filter_products', {
      filters_applied: Object.keys(filters).join(','),
      results_count: resultsCount,
      filtered_at: new Date().toISOString(),
    });
  },

  updateInventory: (productId: string, productName: string, oldQty: number, newQty: number) => {
    gtagEvent('update_inventory', {
      product_id: productId,
      product_name: productName,
      old_quantity: oldQty,
      new_quantity: newQty,
      quantity_change: newQty - oldQty,
      updated_at: new Date().toISOString(),
    });
  },

  lowStockAlert: (productId: string, productName: string, currentStockLevel: number, minimumLevel: number) => {
    gtagEvent('low_stock_alert', {
      product_id: productId,
      product_name: productName,
      current_stock: currentStockLevel,
      minimum_level: minimumLevel,
      triggered_at: new Date().toISOString(),
    });
  },
};
```

**Implementation Locations:**

- **File:** `web/app/inventory/page.tsx`
  - On page load: `inventoryEvents.viewProducts(count, categories)`
  - On search: `inventoryEvents.searchProducts(query, results, category)`
  - On filter: `inventoryEvents.filterProducts(filters, results)`

- **File:** `web/app/inventory/[id]/edit/page.tsx`
  - On quantity update: `inventoryEvents.updateInventory(...)`
  - If low stock: `inventoryEvents.lowStockAlert(...)`

---

## Phase 3: Low Priority Events (Week 3)

### 3.1 User Engagement Events

**File:** `web/lib/analytics/events.ts` (ADD)

```typescript
export const engagementEvents = {
  viewDashboard: (dashboardType: string, userRole: string, metricsLoaded: Record<string, number>) => {
    gtagEvent('view_dashboard', {
      dashboard_type: dashboardType, // 'main', 'analytics', 'finance', 'operations'
      user_role: userRole,
      metrics_visible: Object.keys(metricsLoaded).join(','),
      loaded_at: new Date().toISOString(),
    });
  },

  exportData: (exportType: string, format: string, recordCount: number, dateRange: string) => {
    gtagEvent('export_data', {
      export_type: exportType, // 'orders', 'dispatch', 'collections', 'inventory'
      export_format: format, // 'pdf', 'csv', 'excel'
      record_count: recordCount,
      date_range: dateRange,
      exported_at: new Date().toISOString(),
    });
  },

  offlineSyncCompleted: (recordsCount: number, syncDurationSeconds: number, conflictsResolved: number) => {
    gtagEvent('offline_sync_completed', {
      records_synced: recordsCount,
      sync_duration_seconds: syncDurationSeconds,
      conflicts_resolved: conflictsResolved,
      synced_at: new Date().toISOString(),
    });
  },

  viewSettings: (settingsCategory: string) => {
    gtagEvent('view_settings', {
      settings_category: settingsCategory, // 'general', 'billing', 'users', 'integrations'
    });
  },

  updateSettings: (settingName: string, oldValue: any, newValue: any) => {
    gtagEvent('update_settings', {
      setting_name: settingName,
      old_value: String(oldValue),
      new_value: String(newValue),
      updated_at: new Date().toISOString(),
    });
  },

  contactSupport: (supportType: string, issue: string) => {
    gtagEvent('contact_support', {
      support_type: supportType, // 'chat', 'email', 'phone'
      issue_category: issue,
      contacted_at: new Date().toISOString(),
    });
  },

  reportError: (errorType: string, errorMessage: string, page: string) => {
    gtagEvent('report_error', {
      error_type: errorType,
      error_message: errorMessage.substring(0, 100), // Truncate for privacy
      page: page,
      reported_at: new Date().toISOString(),
    });
  },
};
```

**Implementation Locations:**

- **File:** `web/app/dashboard/page.tsx`
  - On page load: `engagementEvents.viewDashboard(...)`

- **File:** `web/app/settings/page.tsx`
  - On page load: `engagementEvents.viewSettings(...)`
  - On setting change: `engagementEvents.updateSettings(...)`

- **File:** `web/lib/api/hooks/useOfflineSync.ts` (if exists)
  - On sync complete: `engagementEvents.offlineSyncCompleted(...)`

- **File:** `web/components/support/ContactForm.tsx` (if exists)
  - On submit: `engagementEvents.contactSupport(...)`

- **File:** `web/lib/error-handler.ts` (CREATE if doesn't exist)
  - On error: `engagementEvents.reportError(...)`

---

## Implementation Timeline

```
Week 1 (High Priority):
├── Day 1: Create base events.ts file with orderEvents & complete billingEvents
├── Day 2: Implement order tracking in pages
├── Day 3: Test and verify order events in GA
├── Day 4: Implement billing event completions
└── Day 5: QA & bug fixes

Week 2 (Medium Priority):
├── Day 1: Create dispatchEvents
├── Day 2: Create collectionEvents
├── Day 3: Create inventoryEvents
├── Day 4: Implement all tracking in pages
└── Day 5: Cross-platform testing

Week 3 (Low Priority):
├── Day 1: Create engagementEvents
├── Day 2: Implement dashboard & settings tracking
├── Day 3: Implement error tracking
├── Day 4: Analytics QA
└── Day 5: Documentation & playbook
```

---

## Testing Checklist

For each event, verify in GA:

### 1. Real-time events
- [ ] Go to GA → Real-time → Events
- [ ] Trigger event in app
- [ ] See event appear within 2 seconds

### 2. Event parameters
- [ ] Check all params are captured correctly
- [ ] Verify currency is "INR"
- [ ] Check timestamps are valid

### 3. User properties
- [ ] Verify user_id is captured
- [ ] Check organization_id is tracked
- [ ] Confirm user_role is set

### 4. Data integrity
- [ ] No duplicate events
- [ ] All numeric values are numbers (not strings)
- [ ] No null/undefined values in key fields

---

## Deployment Checklist

After implementing each phase:

1. [ ] Code review
2. [ ] Local testing with GA debug mode
3. [ ] Staging deployment
4. [ ] GA event validation in staging
5. [ ] Production deployment
6. [ ] Monitor GA for 24 hours
7. [ ] Update GA dashboard with new events
8. [ ] Create custom reports

---

## Next Steps

1. Create `web/lib/analytics/events.ts` with Phase 1 events
2. Implement tracking in corresponding pages
3. Test events in GA real-time dashboard
4. Proceed to Phase 2 after Phase 1 validation
5. Document custom events in GA interface
