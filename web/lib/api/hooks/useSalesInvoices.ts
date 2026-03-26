import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "../client";
import { useOrgBranch } from "@/lib/org-branch-context";

// ── Types ────────────────────────────────────────────────────────────────────

export interface SalesInvoice {
  id: number;
  invoice_number: string;
  status: string;
  total_amount: number | string;
  paid_amount: number | string;
  balance_due: number | string;
  due_date: string | null;
  issued_at: string | null;
  customer?: { id: number; name: string; code: string };
  sales_order?: { id: number; order_number: string };
  created_at: string;
}

export interface InvoicesParams {
  page?: number;
  per_page?: number;
  status?: string;
  customer_id?: number;
  q?: string;
  sort?: string;
  overdue?: boolean;
}

export interface PaginationMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
}

export interface InvoicesResponse {
  data: SalesInvoice[];
  meta: PaginationMeta;
}

// ── List hook ────────────────────────────────────────────────────────────────

export function useSalesInvoices(params: InvoicesParams = {}) {
  const { orgId, branchId } = useOrgBranch();
  const { page = 1, per_page = 20, status, customer_id, q, sort, overdue } = params;

  return useQuery<InvoicesResponse>({
    queryKey: ["sales_invoices", { page, per_page, status, customer_id, q, sort, overdue, orgId, branchId }],
    queryFn: async () => {
      const qp: Record<string, string | number> = { page, per_page };
      if (status) qp.status = status;
      if (customer_id) qp.customer_id = customer_id;
      if (q) qp.q = q;
      if (sort) qp.sort = sort;
      if (overdue) qp.overdue = "true";
      if (branchId) qp.branch_id = branchId;

      const { data } = await apiClient.get<InvoicesResponse>("/api/v1/sales_invoices", { params: qp });
      return data;
    },
    staleTime: 30_000,
    placeholderData: (prev) => prev,
    enabled: !!orgId,
  });
}

// ── Detail hook ──────────────────────────────────────────────────────────────

export function useSalesInvoice(id: number | string | null) {
  const { orgId } = useOrgBranch();

  return useQuery<SalesInvoice>({
    queryKey: ["sales_invoice", id, orgId],
    queryFn: async () => {
      const { data } = await apiClient.get<{ data: SalesInvoice }>(`/api/v1/sales_invoices/${id}`);
      return data.data;
    },
    enabled: !!orgId && !!id,
  });
}

// ── Mutations ────────────────────────────────────────────────────────────────

export function useVoidInvoice() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => apiClient.post(`/api/v1/sales_invoices/${id}/void`),
    onSuccess: (_data, id) => {
      qc.invalidateQueries({ queryKey: ["sales_invoices"] });
      qc.invalidateQueries({ queryKey: ["sales_invoice", id] });
    },
  });
}
