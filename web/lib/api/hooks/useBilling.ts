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
      return result.short_url;
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
