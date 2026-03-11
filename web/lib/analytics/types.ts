// ───────────────────────────────────────────────────────────────────────────
// OrderLane Pro – GA4 Analytics Types
// ───────────────────────────────────────────────────────────────────────────

// GA4 user roles — mirrors backend roles
export type AnalyticsRole =
  | "owner"
  | "admin"
  | "manager"
  | "sales_rep"
  | "warehouse_staff"
  | "accountant"
  | "driver"
  | "visitor"  // pre-auth
  | string;

// Allowed amount buckets — never send raw financials as GA params
export type AmountBucket =
  | "0"
  | "under_1k"
  | "1k_10k"
  | "10k_50k"
  | "50k_1l"
  | "over_1l";

// Base event params — always safe, never PII
export interface BaseEventParams {
  /** Current pathname, e.g. "/orders/123" */
  page?: string;
  /** Logical module, e.g. "sales", "inventory" */
  module?: string;
  /** User role from auth context */
  role?: AnalyticsRole;
  /** Org ID (non-sensitive opaque ID) */
  organization_id?: string | number;
  /** Branch ID (non-sensitive opaque ID) */
  branch_id?: string | number;
}

// Page view params
export interface PageViewParams extends BaseEventParams {
  page_title?: string;
  page_location?: string;
}

// Click event params
export interface ClickEventParams extends BaseEventParams {
  /** Label of the button/link clicked */
  element_label?: string;
  /** Section of the page */
  section?: string;
  /** Navigation item key */
  nav_item?: string;
  /** Alert type for alert clicks */
  alert_type?: string;
  /** Alert severity */
  severity?: "high" | "medium" | "low";
  count?: number;
}

// Business event params
export interface BusinessEventParams extends BaseEventParams {
  order_id?: number | string;
  order_status?: string;
  customer_id?: number | string;
  product_id?: number | string;
  /** Bucketed amount — never raw number */
  amount_bucket?: AmountBucket;
  /** Payment method */
  payment_method?: string;
  /** Generic reason/status string */
  reason?: string;
  /** Assigned role for invite actions */
  invited_role?: AnalyticsRole;
  /** Onboarding step name */
  step?: string;
  /** Step index (0-based) */
  step_index?: number;
  /** Total steps in the flow */
  total_steps?: number;
  /** Signup/billing plan */
  plan?: string;
  /** Count of items (stops, lines, etc.) */
  items_count?: number;
  /** Error message (non-sensitive) */
  error_reason?: string;
}

// Union of all allowed param shapes
export type AnalyticsEventParams =
  | PageViewParams
  | ClickEventParams
  | BusinessEventParams;

// GA4 user properties (set once after auth)
export interface AnalyticsUserProperties {
  role?: AnalyticsRole;
  organization_id?: string | number;
  branch_id?: string | number;
  app_environment?: "production" | "staging" | "development";
}
