import { useQuery } from "@tanstack/react-query";
import { apiClient } from "../client";
import { useOrgBranch } from "@/lib/org-branch-context";

export interface RiskyRetailer {
  id: number;
  customer_id: number;
  customer_name: string;
  customer_code: string;
  credit_limit: number;
  current_balance: number;
  available_credit: number;
  overdue_amount: number;
  overdue_days: number;
  hold_required: boolean;
  watchlist: boolean;
  overdue_bucket: string;
  utilization_pct: number;
}

export interface CreditRiskData {
  summary?: {
    total_accounts?: number;
    risky_count?: number;
    blocked_count?: number;
    watchlist_count?: number;
    total_overdue?: number;
    total_exposure?: number;
  };
  aging_buckets?: {
    current?: number;
    d1_15?: number;
    d16_30?: number;
    d31_60?: number;
    over_60?: number;
  };
  risky_retailers?: RiskyRetailer[];
}

export function useCreditRisk(params?: { branchId?: string; enabled?: boolean }) {
  const { orgId, branchId: currentBranchId } = useOrgBranch();
  const branchId = params?.branchId ?? currentBranchId;

  return useQuery<CreditRiskData>({
    queryKey: ["credit-risk", { orgId, branchId }],
    queryFn: async () => {
      const queryParams: Record<string, string> = {};
      if (branchId) queryParams.branch_id = branchId;

      const { data } = await apiClient.get<{ data: CreditRiskData }>("/api/v1/analytics/credit_risk", {
        params: queryParams,
      });
      return data.data;
    },
    staleTime: 60_000,
    enabled: (params?.enabled ?? true) && !!orgId,
  });
}
