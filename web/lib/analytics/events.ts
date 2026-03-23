// ───────────────────────────────────────────────────────────────────────────
// OrdWave – GA Events Domain Library
//
// High-level event tracking functions for all major features:
// - Orders (create, view, update, search, delete, export)
// - Billing (plans, upgrades, downgrades, cancellations, invoices)
// - Dispatch (create, view, update, complete, fail, location tracking)
// - Collections (payments, invoices, transactions, finance reports)
// - Inventory (search, filter, update, low stock alerts)
// - Engagement (dashboard, settings, offline sync, support, errors)
//
// Each function wraps gtagEvent() with domain-specific logic and parameters.
// ───────────────────────────────────────────────────────────────────────────

import { gtagEvent } from "./ga";

/**
 * ORDER MANAGEMENT EVENTS
 * Track all order-related user actions across the app
 */
export const orderEvents = {
  /**
   * Fired when a new order is successfully created
   */
  create: (orderId: string, customerName: string, totalValue: number, itemCount: number) => {
    gtagEvent("create_order", {
      transaction_id: orderId,
      value: totalValue,
      currency: "INR",
      items_count: itemCount,
      customer_name: customerName,
      event_category: "business",
    });
  },

  /**
   * Fired when user views order details
   */
  view: (orderId: string, status: string, totalValue: number) => {
    gtagEvent("view_item", {
      item_id: orderId,
      item_name: `Order ${orderId}`,
      item_category: "order",
      status: status,
      value: totalValue,
      currency: "INR",
      event_category: "business",
    });
  },

  /**
   * Fired when order status changes
   */
  update: (orderId: string, fromStatus: string, toStatus: string) => {
    gtagEvent("update_order", {
      order_id: orderId,
      from_status: fromStatus,
      to_status: toStatus,
      timestamp: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when user searches for orders
   */
  search: (searchQuery: string, resultsCount: number) => {
    gtagEvent("search", {
      search_term: searchQuery,
      results_count: resultsCount,
      search_category: "orders",
      event_category: "business",
    });
  },

  /**
   * Fired when user deletes an order
   */
  delete: (orderId: string, reason: string) => {
    gtagEvent("delete_order", {
      order_id: orderId,
      reason: reason,
      timestamp: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when user exports orders
   */
  export: (format: string, recordCount: number, dateRange: string) => {
    gtagEvent("export_data", {
      export_type: "orders",
      export_format: format, // 'pdf', 'csv', 'excel'
      record_count: recordCount,
      date_range: dateRange,
      event_category: "business",
    });
  },
};

/**
 * BILLING EVENTS
 * Track subscription plans, upgrades, downgrades, cancellations, and invoices
 */
export const billingEvents = {
  /**
   * Fired when user views available subscription plans
   */
  viewPlans: (plans: Array<{ plan: string; price: number; name: string }>) => {
    gtagEvent("view_item_list", {
      item_list_id: "billing_plans",
      item_list_name: "Subscription Plans",
      items: plans.map((p) => ({
        item_id: p.plan,
        item_name: p.name,
        price: p.price,
        currency: "INR",
      })),
      event_category: "business",
    });
  },

  /**
   * Fired when user upgrades subscription plan
   */
  upgradePlan: (fromPlan: string, toPlan: string, price: number) => {
    gtagEvent("upgrade_plan", {
      from_plan: fromPlan,
      to_plan: toPlan,
      value: price,
      currency: "INR",
      timestamp: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when user downgrades subscription plan
   */
  downgradePlan: (fromPlan: string, toPlan: string) => {
    gtagEvent("downgrade_plan", {
      from_plan: fromPlan,
      to_plan: toPlan,
      timestamp: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when user cancels subscription
   */
  cancelSubscription: (plan: string, reason: string, daysActive: number) => {
    gtagEvent("cancel_subscription", {
      plan: plan,
      cancellation_reason: reason,
      subscription_duration_days: daysActive,
      cancelled_at: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when user views an invoice
   */
  viewInvoice: (invoiceId: string, amount: number, dueDate: string) => {
    gtagEvent("view_invoice", {
      invoice_id: invoiceId,
      amount: amount,
      currency: "INR",
      due_date: dueDate,
      event_category: "business",
    });
  },

  /**
   * Fired when user downloads an invoice
   */
  downloadInvoice: (invoiceId: string, format: string) => {
    gtagEvent("download_invoice", {
      invoice_id: invoiceId,
      format: format, // 'pdf', 'csv'
      event_category: "business",
    });
  },
};

/**
 * DISPATCH / DELIVERY EVENTS
 * Track dispatch creation, updates, completions, and failures
 */
export const dispatchEvents = {
  /**
   * Fired when user creates a new dispatch
   */
  create: (
    dispatchId: string,
    orderCount: number,
    totalValue: number,
    vehicleType: string
  ) => {
    gtagEvent("create_dispatch", {
      dispatch_id: dispatchId,
      orders_count: orderCount,
      value: totalValue,
      currency: "INR",
      vehicle_type: vehicleType,
      created_at: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when user views dispatch details
   */
  view: (dispatchId: string, status: string, ordersCount: number) => {
    gtagEvent("view_dispatch", {
      dispatch_id: dispatchId,
      status: status,
      orders_count: ordersCount,
      event_category: "business",
    });
  },

  /**
   * Fired when dispatch status changes
   */
  updateStatus: (dispatchId: string, fromStatus: string, toStatus: string) => {
    gtagEvent("update_dispatch_status", {
      dispatch_id: dispatchId,
      from_status: fromStatus,
      to_status: toStatus,
      updated_at: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when dispatch completes successfully
   */
  complete: (
    dispatchId: string,
    ordersDelivered: number,
    totalValue: number,
    deliveryTimeHours: number
  ) => {
    gtagEvent("delivery_completed", {
      dispatch_id: dispatchId,
      orders_delivered: ordersDelivered,
      value: totalValue,
      currency: "INR",
      delivery_time_hours: deliveryTimeHours,
      completed_at: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when delivery fails
   */
  failed: (dispatchId: string, reason: string, ordersAffected: number) => {
    gtagEvent("delivery_failed", {
      dispatch_id: dispatchId,
      failure_reason: reason,
      orders_affected: ordersAffected,
      failed_at: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when dispatch location is updated (live tracking)
   */
  updateCoordinates: (dispatchId: string, lat: number, lng: number) => {
    gtagEvent("dispatch_location_updated", {
      dispatch_id: dispatchId,
      latitude: lat,
      longitude: lng,
      updated_at: new Date().toISOString(),
      event_category: "business",
    });
  },
};

/**
 * COLLECTIONS & FINANCE EVENTS
 * Track payments, invoices, transactions, and financial reports
 */
export const collectionEvents = {
  /**
   * Fired when user records a payment
   */
  recordPayment: (
    paymentId: string,
    amount: number,
    method: string,
    orderId: string
  ) => {
    gtagEvent("record_payment", {
      payment_id: paymentId,
      value: amount,
      currency: "INR",
      payment_method: method, // 'cash', 'check', 'bank_transfer', 'upi'
      order_id: orderId,
      recorded_at: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when invoice is generated
   */
  generateInvoice: (
    invoiceId: string,
    amount: number,
    customerId: string,
    orderId: string
  ) => {
    gtagEvent("generate_invoice", {
      invoice_id: invoiceId,
      value: amount,
      currency: "INR",
      customer_id: customerId,
      order_id: orderId,
      generated_at: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when collection is completed
   */
  completeCollection: (
    collectionId: string,
    totalAmount: number,
    paymentsCount: number,
    collectorName: string
  ) => {
    gtagEvent("collection_completed", {
      collection_id: collectionId,
      value: totalAmount,
      currency: "INR",
      payments_count: paymentsCount,
      collector_name: collectorName,
      completed_at: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when credit/debit transaction is recorded
   */
  recordCreditTransaction: (
    transactionId: string,
    orderId: string,
    amount: number,
    type: "debit" | "credit"
  ) => {
    gtagEvent("credit_transaction", {
      transaction_id: transactionId,
      order_id: orderId,
      value: amount,
      currency: "INR",
      transaction_type: type,
      timestamp: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when financial report is generated
   */
  generateFinanceReport: (
    reportType: string,
    dateRange: string,
    recordCount: number
  ) => {
    gtagEvent("generate_report", {
      report_type: reportType, // 'collections', 'outstanding', 'cash_flow'
      date_range: dateRange,
      record_count: recordCount,
      generated_at: new Date().toISOString(),
      event_category: "business",
    });
  },
};

/**
 * INVENTORY & PRODUCT EVENTS
 * Track product searches, filtering, updates, and inventory alerts
 */
export const inventoryEvents = {
  /**
   * Fired when user views product catalog
   */
  viewProducts: (productsCount: number, categories: string[]) => {
    gtagEvent("view_item_list", {
      item_list_id: "product_catalog",
      item_list_name: "Product Inventory",
      item_count: productsCount,
      categories: categories.join(","),
      event_category: "business",
    });
  },

  /**
   * Fired when user searches products
   */
  searchProducts: (searchQuery: string, resultsCount: number, category: string) => {
    gtagEvent("search", {
      search_term: searchQuery,
      results_count: resultsCount,
      search_category: category || "all",
      event_category: "business",
    });
  },

  /**
   * Fired when user applies product filters
   */
  filterProducts: (filters: Record<string, unknown>, resultsCount: number) => {
    gtagEvent("filter_products", {
      filters_applied: Object.keys(filters).join(","),
      results_count: resultsCount,
      filtered_at: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when product inventory is updated
   */
  updateInventory: (
    productId: string,
    productName: string,
    oldQty: number,
    newQty: number
  ) => {
    gtagEvent("update_inventory", {
      product_id: productId,
      product_name: productName,
      old_quantity: oldQty,
      new_quantity: newQty,
      quantity_change: newQty - oldQty,
      updated_at: new Date().toISOString(),
      event_category: "business",
    });
  },

  /**
   * Fired when stock falls below minimum threshold
   */
  lowStockAlert: (
    productId: string,
    productName: string,
    currentStockLevel: number,
    minimumLevel: number
  ) => {
    gtagEvent("low_stock_alert", {
      product_id: productId,
      product_name: productName,
      current_stock: currentStockLevel,
      minimum_level: minimumLevel,
      triggered_at: new Date().toISOString(),
      event_category: "business",
    });
  },
};

/**
 * ENGAGEMENT & PLATFORM EVENTS
 * Track user engagement, settings, offline sync, support, and errors
 */
export const engagementEvents = {
  /**
   * Fired when user views dashboard
   */
  viewDashboard: (
    dashboardType: string,
    userRole: string,
    metricsLoaded: Record<string, number>
  ) => {
    gtagEvent("view_dashboard", {
      dashboard_type: dashboardType, // 'main', 'analytics', 'finance', 'operations'
      user_role: userRole,
      metrics_visible: Object.keys(metricsLoaded).join(","),
      loaded_at: new Date().toISOString(),
      event_category: "engagement",
    });
  },

  /**
   * Fired when user exports data from dashboard/reports
   */
  exportData: (
    exportType: string,
    format: string,
    recordCount: number,
    dateRange: string
  ) => {
    gtagEvent("export_data", {
      export_type: exportType, // 'orders', 'dispatch', 'collections', 'inventory'
      export_format: format, // 'pdf', 'csv', 'excel'
      record_count: recordCount,
      date_range: dateRange,
      exported_at: new Date().toISOString(),
      event_category: "engagement",
    });
  },

  /**
   * Fired when offline sync completes
   */
  offlineSyncCompleted: (
    recordsCount: number,
    syncDurationSeconds: number,
    conflictsResolved: number
  ) => {
    gtagEvent("offline_sync_completed", {
      records_synced: recordsCount,
      sync_duration_seconds: syncDurationSeconds,
      conflicts_resolved: conflictsResolved,
      synced_at: new Date().toISOString(),
      event_category: "engagement",
    });
  },

  /**
   * Fired when user views settings page
   */
  viewSettings: (settingsCategory: string) => {
    gtagEvent("view_settings", {
      settings_category: settingsCategory, // 'general', 'billing', 'users', 'integrations'
      event_category: "engagement",
    });
  },

  /**
   * Fired when user updates a setting
   */
  updateSettings: (settingName: string, oldValue: unknown, newValue: unknown) => {
    gtagEvent("update_settings", {
      setting_name: settingName,
      old_value: String(oldValue),
      new_value: String(newValue),
      updated_at: new Date().toISOString(),
      event_category: "engagement",
    });
  },

  /**
   * Fired when user contacts support
   */
  contactSupport: (supportType: string, issue: string) => {
    gtagEvent("contact_support", {
      support_type: supportType, // 'chat', 'email', 'phone'
      issue_category: issue,
      contacted_at: new Date().toISOString(),
      event_category: "engagement",
    });
  },

  /**
   * Fired when error occurs and is reported
   */
  reportError: (errorType: string, errorMessage: string, page: string) => {
    gtagEvent("report_error", {
      error_type: errorType,
      error_message: errorMessage.substring(0, 100), // Truncate for privacy
      page: page,
      reported_at: new Date().toISOString(),
      event_category: "engagement",
    });
  },
};
