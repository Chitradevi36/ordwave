// web/lib/api/billing.ts
//
// API client functions for billing endpoints.
// All functions use the shared apiClient which attaches JWT and org headers.

import { apiClient } from "@/lib/api/client";

// ── Types ────────────────────────────────────────────────────────────────────

export interface SubscriptionData {
  id: number;
  plan: string;
  status: string;
  razorpay_subscription_id: string | null;
  current_period_start: string | null;
  current_period_end: string | null;
  cancelled_at: string | null;
  ends_at: string | null;
  created_at: string;
}

export interface PlanDetails {
  display_name: string;
  price_monthly_inr: number;
  description: string;
}

export interface UsageSummary {
  plan: string;
  max_branches: number | null;
  max_active_users: number | null;
  max_orders_per_month: number | null;
  max_products: number | null;
  features: string[];
}

export interface PlanCatalogEntry {
  plan: string;
  display_name: string;
  price_monthly_inr: number;
  price_paise: number;
  description: string;
  highlight: boolean;
  features?: string[];
}

export interface BillingSubscriptionResponse {
  subscription: SubscriptionData | null;
  plan: string;
  billing_status: string;
  plan_details: PlanDetails;
  usage_summary: UsageSummary;
  all_plans: PlanCatalogEntry[];
}

export interface BillingEvent {
  id: number;
  event_type: string;
  created_at: string;
  amount: number | null;
  currency: string;
  status: string;
}

export interface CheckoutResponse {
  subscription_id: number;
  short_url: string;
  plan: string;
  message: string;
}

// ── API calls ────────────────────────────────────────────────────────────────

export async function fetchBillingSubscription(): Promise<BillingSubscriptionResponse> {
  const res = await apiClient.get<{ data: BillingSubscriptionResponse }>(
    "/api/v1/billing/subscription"
  );
  return res.data.data;
}

export async function fetchBillingInvoices(): Promise<BillingEvent[]> {
  const res = await apiClient.get<{ data: BillingEvent[] }>(
    "/api/v1/billing/invoices"
  );
  return res.data.data;
}

export async function createBillingCheckout(plan: string): Promise<CheckoutResponse> {
  const res = await apiClient.post<{ data: CheckoutResponse }>(
    "/api/v1/billing/checkout",
    { plan }
  );
  return res.data.data;
}

export async function cancelBillingSubscription(): Promise<{ message: string; ends_at: string | null }> {
  const res = await apiClient.post<{ data: { message: string; ends_at: string | null } }>(
    "/api/v1/billing/cancel"
  );
  return res.data.data;
}
