import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "../client";
import { useOrgBranch } from "@/lib/org-branch-context";

// ── Types ────────────────────────────────────────────────────────────────────

export interface CreditAccount {
  credit_limit: number;
  current_balance: number;
  available_credit: number;
  overdue_amount: number;
  overdue_days: number;
}

export interface CreditUsageSummary {
  order_exposure: number;
  hold_exposure: number;
  credit_used_total: number;
}

export interface Customer {
  id: number;
  name: string;
  code: string;
  channel: string;
  tier: string;
  status: string;
  phone: string | null;
  email: string | null;
  credit_limit: number;
  route: { id: number; name: string; code: string } | null;
  credit_account: CreditAccount | null;
  credit_usage_summary: CreditUsageSummary | null;
}

export interface CustomersParams {
  page?: number;
  per_page?: number;
  q?: string;
  channel?: string;
  tier?: string;
  status?: string;
  credit_status?: string;
  no_route?: string;
  include_credit_usage?: boolean;
}

export interface PaginationMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
}

export interface CustomersResponse {
  data: Customer[];
  meta: PaginationMeta;
}

// ── List hook ────────────────────────────────────────────────────────────────

export function useCustomers(params: CustomersParams = {}) {
  const { orgId } = useOrgBranch();
  const {
    page = 1,
    per_page = 20,
    q,
    channel,
    tier,
    status,
    credit_status,
    no_route,
    include_credit_usage = true,
  } = params;

  return useQuery<CustomersResponse>({
    queryKey: ["customers", { page, per_page, q, channel, tier, status, credit_status, no_route, orgId }],
    queryFn: async () => {
      const qp: Record<string, string | number> = { page, per_page };
      if (q) qp.q = q;
      if (channel) qp.channel = channel;
      if (tier) qp.tier = tier;
      if (status) qp.status = status;
      if (credit_status) qp.credit_status = credit_status;
      if (no_route) qp.no_route = no_route;
      if (include_credit_usage) qp.include_credit_usage = "true";

      const { data } = await apiClient.get<CustomersResponse>("/api/v1/customers", { params: qp });
      return data;
    },
    staleTime: 30_000,
    placeholderData: (prev) => prev,
    enabled: !!orgId,
  });
}

// ── Detail hook ──────────────────────────────────────────────────────────────

export function useCustomer(id: number | string | null) {
  const { orgId } = useOrgBranch();

  return useQuery<Customer>({
    queryKey: ["customer", id, orgId],
    queryFn: async () => {
      const { data } = await apiClient.get<{ data: Customer }>(`/api/v1/customers/${id}`);
      return data.data;
    },
    enabled: !!orgId && !!id,
  });
}

// ── Mutations ────────────────────────────────────────────────────────────────

export function useBlockCustomer() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, action }: { id: number; action: "block" | "unblock" }) =>
      apiClient.post(`/api/v1/customers/${id}/${action}`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["customers"] });
    },
  });
}

export function useCreateCustomer() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (customer: Record<string, unknown>) =>
      apiClient.post("/api/v1/customers", { customer }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["customers"] });
    },
  });
}

export function useUpdateCustomer() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, customer }: { id: number; customer: Record<string, unknown> }) =>
      apiClient.patch(`/api/v1/customers/${id}`, { customer }),
    onSuccess: (_data, { id }) => {
      qc.invalidateQueries({ queryKey: ["customers"] });
      qc.invalidateQueries({ queryKey: ["customer", id] });
    },
  });
}
