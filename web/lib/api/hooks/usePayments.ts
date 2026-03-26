import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "../client";
import { useOrgBranch } from "@/lib/org-branch-context";

// ── Types ────────────────────────────────────────────────────────────────────

export interface Payment {
  id: number;
  receipt_number: string;
  payment_mode: string;
  status: string;
  amount: number | string;
  received_date: string;
  customer?: { id: number; name: string; code: string };
  created_by?: { id: number; full_name: string };
  created_at: string;
}

export interface PaymentsParams {
  page?: number;
  per_page?: number;
  status?: string;
  payment_mode?: string;
  customer_id?: number;
  q?: string;
  sort?: string;
}

export interface PaginationMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
}

export interface PaymentsResponse {
  data: Payment[];
  meta: PaginationMeta;
}

// ── List hook ────────────────────────────────────────────────────────────────

export function usePayments(params: PaymentsParams = {}) {
  const { orgId, branchId } = useOrgBranch();
  const { page = 1, per_page = 20, status, payment_mode, customer_id, q, sort } = params;

  return useQuery<PaymentsResponse>({
    queryKey: ["payments", { page, per_page, status, payment_mode, customer_id, q, sort, orgId, branchId }],
    queryFn: async () => {
      const qp: Record<string, string | number> = { page, per_page };
      if (status) qp.status = status;
      if (payment_mode) qp.payment_mode = payment_mode;
      if (customer_id) qp.customer_id = customer_id;
      if (q) qp.q = q;
      if (sort) qp.sort = sort;
      if (branchId) qp.branch_id = branchId;

      const { data } = await apiClient.get<PaymentsResponse>("/api/v1/payments", { params: qp });
      return data;
    },
    staleTime: 30_000,
    placeholderData: (prev) => prev,
    enabled: !!orgId,
  });
}

// ── Detail hook ──────────────────────────────────────────────────────────────

export function usePayment(id: number | string | null) {
  const { orgId } = useOrgBranch();

  return useQuery<Payment>({
    queryKey: ["payment", id, orgId],
    queryFn: async () => {
      const { data } = await apiClient.get<{ data: Payment }>(`/api/v1/payments/${id}`);
      return data.data;
    },
    enabled: !!orgId && !!id,
  });
}

// ── Mutations ────────────────────────────────────────────────────────────────

export function useCreatePayment() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (payment: Record<string, unknown>) =>
      apiClient.post("/api/v1/payments", { payment }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["payments"] });
      qc.invalidateQueries({ queryKey: ["sales_invoices"] });
    },
  });
}

export function useConfirmPayment() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) =>
      apiClient.post(`/api/v1/payments/${id}/confirm`),
    onSuccess: (_data, id) => {
      qc.invalidateQueries({ queryKey: ["payments"] });
      qc.invalidateQueries({ queryKey: ["payment", id] });
      qc.invalidateQueries({ queryKey: ["sales_invoices"] });
    },
  });
}
