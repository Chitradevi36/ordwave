"use client";

import { useState, useEffect, useCallback } from "react";
import { API_URL } from "@/lib/api/client";
import { useOrgBranch } from "@/lib/org-branch-context";
import type { RiskTier } from "@/components/customers/risk-badge";

// ─── Types ─────────────────────────────────────────────────────────────────

export interface RiskFactor {
  key:    string;
  label:  string;
  points: number;
  detail: string;
}

export interface RetailerRiskProfile {
  id:            number;
  customer_id:   number;
  risk_score:    number;
  risk_tier:     RiskTier;
  recommendation: string;
  factors:       RiskFactor[];
  score_version: string;
  computed_at:   string;
  stale:         boolean;
}

export interface RiskyCustomer {
  id:          number;
  name:        string;
  code:        string;
  risk_score:  number;
  risk_tier:   RiskTier;
  recommendation: string;
  computed_at: string;
}

// ─── useRetailerRisk ────────────────────────────────────────────────────────
// Fetches (and optionally recomputes) the risk profile for one customer.

export function useRetailerRisk(customerId: string | number | null) {
  const { token, orgId } = useOrgBranch();

  const [data,        setData]        = useState<RetailerRiskProfile | null>(null);
  const [loading,     setLoading]     = useState(false);
  const [error,       setError]       = useState<string | null>(null);
  const [recomputing, setRecomputing] = useState(false);

  const fetch_ = useCallback(async () => {
    if (!customerId || !token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(
        `${API_URL}/api/v1/customers/${customerId}/risk_profile`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } },
      );
      if (!res.ok) throw new Error("Failed to load risk profile");
      const json = await res.json();
      setData(json.data ?? null);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }, [customerId, token, orgId]);

  useEffect(() => { fetch_(); }, [fetch_]);

  const recompute = useCallback(async () => {
    if (!customerId || !token || !orgId) return;
    setRecomputing(true);
    try {
      const res = await fetch(
        `${API_URL}/api/v1/customers/${customerId}/risk_profile/recompute`,
        {
          method: "POST",
          headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        },
      );
      if (!res.ok) throw new Error("Recompute failed");
      const json = await res.json();
      setData(json.data ?? null);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setRecomputing(false);
    }
  }, [customerId, token, orgId]);

  return { data, loading, error, recompute, recomputing, refresh: fetch_ };
}

// ─── useRiskiestRetailers ──────────────────────────────────────────────────
// Fetches the top-N riskiest customers for the dashboard panel.

export function useRiskiestRetailers(limit = 5) {
  const { token, orgId } = useOrgBranch();

  const [data,    setData]    = useState<RiskyCustomer[]>([]);
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState<string | null>(null);

  useEffect(() => {
    if (!token || !orgId) return;
    setLoading(true);
    fetch(`${API_URL}/api/v1/credit/risk/riskiest?limit=${limit}`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => setData(j.data ?? []))
      .catch(() => setError("Failed to load riskiest retailers"))
      .finally(() => setLoading(false));
  }, [token, orgId, limit]);

  return { data, loading, error };
}
