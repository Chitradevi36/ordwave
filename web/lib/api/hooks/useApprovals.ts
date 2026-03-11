import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "../client";

export interface HeldOrder {
  id: number;
  order_number: string;
  customer_id?: number;
  customer_name: string;
  total_amount: number;
  status: string;
  created_by: string;
  created_at: string;
  lines_count: number;
}

export interface CreditRequest {
  id: number;
  customer_name: string;
  current_limit: number;
  new_limit: number;
  counter_offer_limit: number | null;
  reason: string;
  requested_by: string;
  created_at: string;
}

export interface ApprovalsData {
  held_orders: HeldOrder[];
  credit_requests: CreditRequest[];
  total_count: number;
}

export function useApprovals(opts?: { enabled?: boolean }) {
  return useQuery<ApprovalsData>({
    queryKey: ["approvals"],
    queryFn: async () => {
      const { data } = await apiClient.get<{ data: ApprovalsData }>("/api/v1/approvals");
      return data.data;
    },
    refetchInterval: 30_000,
    staleTime: 15_000,
    enabled: opts?.enabled ?? true,
  });
}

export function useApproveOrder() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, decision, reason }: { id: number; decision: "approved" | "rejected"; reason?: string }) =>
      apiClient.post(`/api/v1/sales_orders/${id}/approve`, { decision, reason }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["approvals"] });
      qc.invalidateQueries({ queryKey: ["orders"] });
    },
  });
}

export function useDecideCreditLimit() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({
      id, decision, counter_offer_limit, decision_note,
    }: { id: number; decision: string; counter_offer_limit?: string; decision_note?: string }) =>
      apiClient.post(`/api/v1/credit_limit_change_requests/${id}/decision`, {
        decision, counter_offer_limit, decision_note,
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["approvals"] }),
  });
}
