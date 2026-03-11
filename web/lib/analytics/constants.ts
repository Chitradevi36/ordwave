// ───────────────────────────────────────────────────────────────────────────
// OrderLane Pro – GA4 Analytics Event Constants + Route Map
// ───────────────────────────────────────────────────────────────────────────

// ── Auth events ───────────────────────────────────────────────────────────────
export const ANALYTICS_EVENTS = {
  // ── Auth ────────────────────────────────────────────────────────────────
  SIGNUP_PAGE_VIEWED:        "signup_page_viewed",
  SIGNUP_EMAIL_SUBMITTED:    "signup_email_submitted",
  SIGNUP_OTP_VERIFIED:       "signup_otp_verified",
  SIGNUP_PASSWORD_SET:       "signup_password_set",
  SIGNUP_COMPLETED:          "signup_completed",
  LOGIN_PAGE_VIEWED:         "login_page_viewed",
  LOGIN_COMPLETED:           "login_completed",
  LOGIN_FAILED:              "login_failed",
  FORGOT_PASSWORD_VIEWED:    "forgot_password_viewed",
  RESET_PASSWORD_VIEWED:     "reset_password_viewed",

  // ── Onboarding ──────────────────────────────────────────────────────────
  ONBOARDING_PAGE_VIEWED:    "onboarding_page_viewed",
  ONBOARDING_STEP_COMPLETED: "onboarding_step_completed",
  ONBOARDING_COMPLETED:      "onboarding_completed",

  // ── Activation Milestones ───────────────────────────────────────────────
  FIRST_BRANCH_CREATED:           "first_branch_created",
  FIRST_PRODUCT_CREATED:          "first_product_created",
  FIRST_RETAILER_CREATED:         "first_retailer_created",
  FIRST_ORDER_CREATED:            "first_order_created",
  FIRST_INVOICE_GENERATED:        "first_invoice_generated",
  FIRST_COLLECTION_RECORDED:      "first_collection_recorded",
  FIRST_DISPATCH_COMPLETED:       "first_dispatch_completed",
  FIRST_PURCHASE_INVOICE_CREATED: "first_purchase_invoice_created",
  FIRST_SETUP_COMPLETED:          "first_setup_completed",

  // ── Dashboard ───────────────────────────────────────────────────────────
  DASHBOARD_VIEWED:                "dashboard_viewed",
  DASHBOARD_ALERT_CLICKED:         "dashboard_alert_clicked",
  DASHBOARD_RECENT_ORDER_CLICKED:  "dashboard_recent_order_clicked",
  DASHBOARD_TOP_CUSTOMER_CLICKED:  "dashboard_top_customer_clicked",
  DASHBOARD_TOP_PRODUCT_CLICKED:   "dashboard_top_product_clicked",
  DASHBOARD_SUMMARY_CARD_CLICKED:  "dashboard_summary_card_clicked",

  // ── Sales / Orders ──────────────────────────────────────────────────────
  ORDERS_LIST_VIEWED:    "orders_list_viewed",
  ORDER_DETAIL_VIEWED:   "order_detail_viewed",
  CREATE_ORDER_CLICKED:  "create_order_clicked",
  ORDER_CREATED:         "order_created",
  ORDER_SUBMITTED:       "order_submitted",
  ORDER_APPROVED:        "order_approved",
  ORDER_REJECTED:        "order_rejected",
  ORDER_ON_HOLD:         "order_on_hold",
  ORDER_CANCELLED:       "order_cancelled",
  APPROVALS_PAGE_VIEWED: "approvals_page_viewed",
  SALES_PAGE_VIEWED:     "sales_page_viewed",

  // ── Retailers / Customers ───────────────────────────────────────────────
  RETAILERS_PAGE_VIEWED:  "retailers_page_viewed",
  RETAILER_DETAIL_VIEWED: "retailer_detail_viewed",
  RETAILER_CREATED:       "retailer_created",
  RETAILER_CREDIT_LIMIT_SET: "retailer_credit_limit_set",
  CREDIT_LIMIT_REQUESTED:    "credit_limit_requested",
  CREDIT_LIMIT_APPROVED:     "credit_limit_approved",
  ROUTES_PAGE_VIEWED:    "routes_page_viewed",
  BEATS_PAGE_VIEWED:     "beats_page_viewed",
  BEAT_PLAN_CREATED:     "beat_plan_created",
  ROUTE_CREATED:         "route_created",

  // ── Inventory ───────────────────────────────────────────────────────────
  INVENTORY_PAGE_VIEWED:         "inventory_page_viewed",
  INVENTORY_STOCK_VIEWED:        "inventory_stock_viewed",
  INVENTORY_TRANSFERS_VIEWED:    "inventory_transfers_viewed",
  INVENTORY_ADJUSTMENTS_VIEWED:  "inventory_adjustments_viewed",
  INVENTORY_ADJUSTMENT_CREATED:  "inventory_adjustment_created",
  STOCK_TRANSFER_CREATED:        "stock_transfer_created",

  // ── Products ────────────────────────────────────────────────────────────
  PRODUCTS_PAGE_VIEWED:    "products_page_viewed",
  PRODUCT_CREATED:         "product_created",
  CATALOG_PAGE_VIEWED:     "catalog_page_viewed",
  HSN_CODES_PAGE_VIEWED:   "hsn_codes_page_viewed",
  PRICE_LIST_VIEWED:       "price_list_viewed",
  PRICE_LIST_CREATED:      "price_list_created",
  SCHEMES_PAGE_VIEWED:     "schemes_page_viewed",
  SCHEME_CREATED:          "scheme_created",

  // ── Purchases / Suppliers ───────────────────────────────────────────────
  PURCHASES_PAGE_VIEWED:         "purchases_page_viewed",
  PURCHASE_INVOICE_VIEWED:       "purchase_invoice_viewed",
  PURCHASE_INVOICE_CREATED:      "purchase_invoice_created",
  SUPPLIERS_PAGE_VIEWED:         "suppliers_page_viewed",
  SUPPLIER_CREATED:              "supplier_created",
  SUPPLIER_DEBIT_NOTES_VIEWED:   "supplier_debit_notes_viewed",

  // ── Dispatch / Delivery ─────────────────────────────────────────────────
  DISPATCH_PAGE_VIEWED:        "dispatch_page_viewed",
  DISPATCH_EXCEPTIONS_VIEWED:  "dispatch_exceptions_viewed",
  TRIP_CREATED:                "trip_created",
  DELIVERY_COMPLETED:          "delivery_completed",
  OPERATIONS_PAGE_VIEWED:      "operations_page_viewed",
  RETURNS_PAGE_VIEWED:         "returns_page_viewed",
  RETURN_CREATED:              "return_created",

  // ── Finance / Collections ───────────────────────────────────────────────
  COLLECTIONS_PAGE_VIEWED:   "collections_page_viewed",
  COLLECTION_RECORDED:       "collection_recorded",
  FINANCE_PAGE_VIEWED:       "finance_page_viewed",
  INVOICES_PAGE_VIEWED:      "invoices_page_viewed",
  INVOICE_GENERATED:         "invoice_generated",
  CREDIT_NOTES_PAGE_VIEWED:  "credit_notes_page_viewed",
  CREDIT_NOTE_CREATED:       "credit_note_created",
  ACCOUNTING_PAGE_VIEWED:    "accounting_page_viewed",
  COMPLIANCE_PAGE_VIEWED:    "compliance_page_viewed",

  // ── Insights ────────────────────────────────────────────────────────────
  INSIGHTS_PAGE_VIEWED:               "insights_page_viewed",
  INSIGHTS_SALES_VIEWED:              "insights_sales_viewed",
  INSIGHTS_COLLECTIONS_VIEWED:        "insights_collections_viewed",
  INSIGHTS_BEAT_PERFORMANCE_VIEWED:   "insights_beat_performance_viewed",  INSIGHTS_RETURNS_VIEWED:            "insights_returns_viewed",
  INSIGHTS_INVENTORY_VIEWED:          "insights_inventory_viewed",
  INSIGHTS_CREDIT_RISK_VIEWED:        "insights_credit_risk_viewed",
  INSIGHTS_SCHEMES_VIEWED:            "insights_schemes_viewed",

  // ── Credit Risk Intelligence ─────────────────────────────────────────────
  RETAILER_RISK_VIEWED:               "retailer_risk_viewed",
  RISK_RECOMPUTED:                    "risk_recomputed",
  RISK_RECOMMENDATION_APPLIED:        "risk_recommendation_applied",
  RISKIEST_RETAILERS_PANEL_VIEWED:    "riskiest_retailers_panel_viewed",

  // ── Approvals sub-pages ──────────────────────────────────────────────────
  APPROVALS_CREDIT_LIMITS_VIEWED:     "approvals_credit_limits_viewed",

  // ── Delivery sub-pages ───────────────────────────────────────────────────
  DELIVERY_REJECTIONS_VIEWED:         "delivery_rejections_viewed",
  // ── Setup / Settings ────────────────────────────────────────────────────
  SETUP_PAGE_VIEWED:   "setup_page_viewed",
  USERS_PAGE_VIEWED:   "users_page_viewed",
  USER_INVITED:        "user_invited",
  BRANCH_CREATED:      "branch_created",

  // ── Navigation ──────────────────────────────────────────────────────────
  SIDEBAR_NAV_CLICKED:   "sidebar_nav_clicked",
  HEADER_CREATE_CLICKED: "header_create_clicked",
  GLOBAL_SEARCH_USED:    "global_search_used",
  NOTIFICATION_OPENED:   "notification_opened",
} as const;

// Derive the type of any valid event name
export type AnalyticsEventName = typeof ANALYTICS_EVENTS[keyof typeof ANALYTICS_EVENTS];

// ── Route → Event map ────────────────────────────────────────────────────────
// Maps pathname patterns to page-view event names.
// Dynamic segments are matched by prefix (see trackRoutePageView in track.ts).
export const ROUTE_EVENT_MAP: Array<{ pattern: string | RegExp; event: AnalyticsEventName; module: string }> = [
  // Auth
  { pattern: "/signup",          event: ANALYTICS_EVENTS.SIGNUP_PAGE_VIEWED,       module: "auth" },
  { pattern: "/login",           event: ANALYTICS_EVENTS.LOGIN_PAGE_VIEWED,        module: "auth" },
  { pattern: "/forgot-password", event: ANALYTICS_EVENTS.FORGOT_PASSWORD_VIEWED,   module: "auth" },
  { pattern: "/reset-password",  event: ANALYTICS_EVENTS.RESET_PASSWORD_VIEWED,    module: "auth" },

  // Onboarding
  { pattern: "/onboarding",      event: ANALYTICS_EVENTS.ONBOARDING_PAGE_VIEWED,   module: "onboarding" },
  { pattern: "/activation",      event: ANALYTICS_EVENTS.ONBOARDING_PAGE_VIEWED,   module: "onboarding" },
  { pattern: "/invite",          event: ANALYTICS_EVENTS.ONBOARDING_PAGE_VIEWED,   module: "onboarding" },

  // Dashboard
  { pattern: "/dashboard",       event: ANALYTICS_EVENTS.DASHBOARD_VIEWED,         module: "dashboard" },

  // Sales / Orders
  { pattern: "/sales",           event: ANALYTICS_EVENTS.SALES_PAGE_VIEWED,        module: "sales" },
  { pattern: /^\/orders\/\d+/,   event: ANALYTICS_EVENTS.ORDER_DETAIL_VIEWED,      module: "sales" },
  { pattern: "/orders",          event: ANALYTICS_EVENTS.ORDERS_LIST_VIEWED,       module: "sales" },
  { pattern: "/approvals",       event: ANALYTICS_EVENTS.APPROVALS_PAGE_VIEWED,    module: "sales" },
  { pattern: "/schemes",         event: ANALYTICS_EVENTS.SCHEMES_PAGE_VIEWED,      module: "sales" },
  { pattern: "/pricing/schemes", event: ANALYTICS_EVENTS.SCHEMES_PAGE_VIEWED,      module: "sales" },

  // Retailers / Customers
  { pattern: /^\/customers\/\d+/, event: ANALYTICS_EVENTS.RETAILER_DETAIL_VIEWED,  module: "retailers" },
  { pattern: "/customers",        event: ANALYTICS_EVENTS.RETAILERS_PAGE_VIEWED,   module: "retailers" },
  { pattern: "/routes",           event: ANALYTICS_EVENTS.ROUTES_PAGE_VIEWED,      module: "retailers" },
  { pattern: "/beats",            event: ANALYTICS_EVENTS.BEATS_PAGE_VIEWED,       module: "retailers" },

  // Inventory
  { pattern: "/inventory/stock",      event: ANALYTICS_EVENTS.INVENTORY_STOCK_VIEWED,       module: "inventory" },
  { pattern: "/inventory/transfers",  event: ANALYTICS_EVENTS.INVENTORY_TRANSFERS_VIEWED,    module: "inventory" },
  { pattern: "/inventory/adjustments",event: ANALYTICS_EVENTS.INVENTORY_ADJUSTMENTS_VIEWED,  module: "inventory" },
  { pattern: "/inventory",            event: ANALYTICS_EVENTS.INVENTORY_PAGE_VIEWED,         module: "inventory" },

  // Products
  { pattern: "/products/price-lists", event: ANALYTICS_EVENTS.PRICE_LIST_VIEWED,     module: "products" },
  { pattern: "/products/hsn-codes",   event: ANALYTICS_EVENTS.HSN_CODES_PAGE_VIEWED, module: "products" },
  { pattern: "/products",             event: ANALYTICS_EVENTS.PRODUCTS_PAGE_VIEWED,   module: "products" },
  { pattern: "/catalog",              event: ANALYTICS_EVENTS.CATALOG_PAGE_VIEWED,    module: "products" },

  // Purchases / Suppliers
  { pattern: "/purchases",               event: ANALYTICS_EVENTS.PURCHASES_PAGE_VIEWED,         module: "purchases" },
  { pattern: "/suppliers",               event: ANALYTICS_EVENTS.SUPPLIERS_PAGE_VIEWED,         module: "purchases" },
  { pattern: "/supplier-debit-notes",    event: ANALYTICS_EVENTS.SUPPLIER_DEBIT_NOTES_VIEWED,   module: "purchases" },

  // Dispatch / Delivery
  { pattern: /^\/delivery\/\d+/,     event: ANALYTICS_EVENTS.DISPATCH_PAGE_VIEWED,       module: "dispatch" },
  { pattern: "/delivery/exceptions",  event: ANALYTICS_EVENTS.DISPATCH_EXCEPTIONS_VIEWED, module: "dispatch" },
  { pattern: "/delivery",             event: ANALYTICS_EVENTS.DISPATCH_PAGE_VIEWED,       module: "dispatch" },
  { pattern: "/operations",           event: ANALYTICS_EVENTS.OPERATIONS_PAGE_VIEWED,     module: "dispatch" },
  { pattern: "/returns",              event: ANALYTICS_EVENTS.RETURNS_PAGE_VIEWED,        module: "dispatch" },

  // Finance
  { pattern: "/collections",         event: ANALYTICS_EVENTS.COLLECTIONS_PAGE_VIEWED,  module: "finance" },
  { pattern: "/finance",             event: ANALYTICS_EVENTS.FINANCE_PAGE_VIEWED,       module: "finance" },
  { pattern: /^\/sales-invoices\/\d+/, event: ANALYTICS_EVENTS.INVOICES_PAGE_VIEWED,   module: "finance" },
  { pattern: "/sales-invoices",      event: ANALYTICS_EVENTS.INVOICES_PAGE_VIEWED,     module: "finance" },
  { pattern: /^\/credit-notes\/\d+/,   event: ANALYTICS_EVENTS.CREDIT_NOTES_PAGE_VIEWED, module: "finance" },
  { pattern: "/credit-notes",        event: ANALYTICS_EVENTS.CREDIT_NOTES_PAGE_VIEWED, module: "finance" },
  { pattern: "/accounting",          event: ANALYTICS_EVENTS.ACCOUNTING_PAGE_VIEWED,   module: "finance" },
  { pattern: "/compliance",          event: ANALYTICS_EVENTS.COMPLIANCE_PAGE_VIEWED,   module: "finance" },

  // Insights
  { pattern: "/insights/sales",            event: ANALYTICS_EVENTS.INSIGHTS_SALES_VIEWED,            module: "insights" },
  { pattern: "/insights/collections",      event: ANALYTICS_EVENTS.INSIGHTS_COLLECTIONS_VIEWED,      module: "insights" },
  { pattern: "/insights/beat-performance", event: ANALYTICS_EVENTS.INSIGHTS_BEAT_PERFORMANCE_VIEWED, module: "insights" },
  { pattern: "/insights/returns",          event: ANALYTICS_EVENTS.INSIGHTS_RETURNS_VIEWED,          module: "insights" },
  { pattern: "/insights/inventory",        event: ANALYTICS_EVENTS.INSIGHTS_INVENTORY_VIEWED,        module: "insights" },
  { pattern: "/insights/credit-risk",      event: ANALYTICS_EVENTS.INSIGHTS_CREDIT_RISK_VIEWED,      module: "insights" },
  { pattern: "/insights/schemes",          event: ANALYTICS_EVENTS.INSIGHTS_SCHEMES_VIEWED,          module: "insights" },
  { pattern: "/insights",                  event: ANALYTICS_EVENTS.INSIGHTS_PAGE_VIEWED,             module: "insights" },

  // Approvals sub-pages
  { pattern: "/approvals/credit-limits",   event: ANALYTICS_EVENTS.APPROVALS_CREDIT_LIMITS_VIEWED,  module: "sales" },

  // Delivery sub-pages
  { pattern: "/delivery/rejections",       event: ANALYTICS_EVENTS.DELIVERY_REJECTIONS_VIEWED,      module: "dispatch" },

  // Setup / Settings
  { pattern: "/settings",   event: ANALYTICS_EVENTS.SETUP_PAGE_VIEWED,  module: "setup" },
  { pattern: "/users",      event: ANALYTICS_EVENTS.USERS_PAGE_VIEWED,  module: "setup" },
];
