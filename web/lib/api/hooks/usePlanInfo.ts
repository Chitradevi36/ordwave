import { useState, useEffect, useCallback } from "react";
import { apiClient } from "@/lib/api/client";
import { useOrgBranch } from "@/lib/org-branch-context";

export interface PlanInfo {
  plan:             string;
  max_branches:     number | null;
  max_active_users: number | null;
  features:         string[];
  usage: {
    branches:     number;
    active_users: number;
  };
  at_limit: {
    branches: boolean;
    users:    boolean;
  };
}

export function usePlanInfo() {
  const { token, orgId } = useOrgBranch();
  const [data,    setData]    = useState<PlanInfo | null>(null);
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState<string | null>(null);

  const refetch = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await apiClient.get<{ data: PlanInfo }>(
        `/api/v1/organizations/${orgId}/plan_info`
      );
      setData(res.data.data);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : "Failed to load plan info";
      setError(msg);
    } finally {
      setLoading(false);
    }
  }, [token, orgId]);

  useEffect(() => { refetch(); }, [refetch]);

  const featureEnabled = (feature: string) =>
    data?.features.includes(feature) ?? true; // optimistic while loading

  return { data, loading, error, refetch, featureEnabled };
}
