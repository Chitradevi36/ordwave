// web/lib/api/hooks/useBilling.ts
//
// Custom hook for billing data and actions.
// Follows the same pull pattern as other hooks in this project.

import { useState, useEffect, useCallback } from "react";
import { useOrgBranch } from "@/lib/org-branch-context";
import {
  fetchBillingSubscription,
  fetchBillingInvoices,
  createBillingCheckout,
  cancelBillingSubscription,
  type BillingSubscriptionResponse,
  type BillingEvent,
} from "@/lib/api/billing";

// ── useBillingSubscription ───────────────────────────────────────────────────

export function useBillingSubscription() {
  const { token, orgId } = useOrgBranch();
  const [data, setData] = useState<BillingSubscriptionResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refetch = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const result = await fetchBillingSubscription();
      setData(result);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to load billing data");
    } finally {
      setLoading(false);
    }
  }, [token, orgId]);

  useEffect(() => {
    refetch();
  }, [refetch]);

  return { data, loading, error, refetch };
}

// ── useBillingInvoices ───────────────────────────────────────────────────────

export function useBillingInvoices() {
  const { token, orgId } = useOrgBranch();
  const [invoices, setInvoices] = useState<BillingEvent[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refetch = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const result = await fetchBillingInvoices();
      setInvoices(result);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Failed to load invoices");
    } finally {
      setLoading(false);
    }
  }, [token, orgId]);

  useEffect(() => {
    refetch();
  }, [refetch]);

  return { invoices, loading, error, refetch };
}

// ── useBillingActions ────────────────────────────────────────────────────────

export function useBillingActions() {
  const [checkoutLoading, setCheckoutLoading] = useState(false);
  const [cancelLoading, setCancelLoading] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  const startCheckout = useCallback(async (plan: string): Promise<string | null> => {
    setCheckoutLoading(true);
    setActionError(null);
    try {
      const result = await createBillingCheckout(plan);
      
      // Use checkout_data if available (primary method)
      if (result.checkout_data) {
        return await openRazorpayCheckout(result.checkout_data);
      }
      
      // Fallback to short_url if checkout_data not available
      if (result.short_url) {
        window.open(result.short_url, "_blank");
        return result.short_url;
      }
      
      throw new Error("No checkout URL available");
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : "Checkout failed";
      setActionError(msg);
      return null;
    } finally {
      setCheckoutLoading(false);
    }
  }, []);

  const cancelSubscription = useCallback(async (): Promise<boolean> => {
    setCancelLoading(true);
    setActionError(null);
    try {
      await cancelBillingSubscription();
      return true;
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : "Cancellation failed";
      setActionError(msg);
      return false;
    } finally {
      setCancelLoading(false);
    }
  }, []);

  return { startCheckout, cancelSubscription, checkoutLoading, cancelLoading, actionError };
}

// ── Razorpay Checkout helper ─────────────────────────────────────────────

async function openRazorpayCheckout(checkoutData: any): Promise<string> {
  return new Promise((resolve, reject) => {
    // Ensure Razorpay script is loaded
    if (!(window as any).Razorpay) {
      const script = document.createElement("script");
      script.src = "https://checkout.razorpay.com/v1/checkout.js";
      script.async = true;
      script.onload = () => triggerCheckout(checkoutData, resolve, reject);
      script.onerror = () => reject(new Error("Failed to load Razorpay Checkout"));
      document.body.appendChild(script);
    } else {
      triggerCheckout(checkoutData, resolve, reject);
    }
  }).then(() => checkoutData.subscription_id).catch(err => {
    throw err;
  });
}

function triggerCheckout(checkoutData: any, resolve: any, reject: any) {
  const options = {
    key: checkoutData.key_id,
    subscription_id: checkoutData.subscription_id,
    name: "OrdWave",
    description: checkoutData.description,
    customer_notify: 1,
    amount: checkoutData.amount,
    currency: checkoutData.currency,
    email: checkoutData.customer_email,
    prefill: {
      name: checkoutData.customer_name,
      email: checkoutData.customer_email,
    },
    handler: (response: any) => {
      console.log("Payment successful:", response);
      resolve(response.razorpay_payment_id);
    },
    modal: {
      ondismiss: () => {
        reject(new Error("Payment cancelled by user"));
      },
    },
  };

  const rzp = new (window as any).Razorpay(options);
  rzp.open();
}
