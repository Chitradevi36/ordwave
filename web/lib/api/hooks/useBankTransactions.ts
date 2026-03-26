import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "../client";
import { useOrgBranch } from "@/lib/org-branch-context";
import type {
  BankTransaction,
  BankDashboard,
  PaginatedResponse,
  ConfirmMatchPayload,
  MarkAsAdvancePayload,
} from "@/types/bankReconciliation";

// ── Hooks ──────────────────────────────────────────────────────────────────

export function useBankTransactions(params: {
  status?: string;
  bank_account_id?: number;
  direction?: string;
  page?: number;
  per_page?: number;
}) {
  const { orgId } = useOrgBranch();
  return useQuery<PaginatedResponse<BankTransaction>>({
    queryKey: ["bank_transactions", params, orgId],
    queryFn: async () => {
      const qp: Record<string, string | number> = {};
      Object.entries(params).forEach(([k, v]) => {
        if (v !== undefined && v !== "") qp[k] = v;
      });
      const { data } = await apiClient.get<PaginatedResponse<BankTransaction>>(
        "/api/v1/bank_transactions",
        { params: qp }
      );
      return data;
    },
    staleTime: 30_000,
    placeholderData: (prev) => prev,
    enabled: !!orgId,
  });
}

export function useBankTransaction(id: number | null) {
  const { orgId } = useOrgBranch();
  return useQuery<{ data: BankTransaction }>({
    queryKey: ["bank_transaction", id, orgId],
    queryFn: async () => {
      const { data } = await apiClient.get<{ data: BankTransaction }>(
        `/api/v1/bank_transactions/${id}`
      );
      return data;
    },
    enabled: !!orgId && !!id,
  });
}

export function useConfirmMatch(txnId: number) {
  const qc = useQueryClient();
  return useMutation<{ data: BankTransaction }, Error, ConfirmMatchPayload>({
    mutationFn: async (payload) => {
      const { data } = await apiClient.post<{ data: BankTransaction }>(
        `/api/v1/bank_transactions/${txnId}/confirm_match`,
        payload
      );
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["bank_transactions"] });
      qc.invalidateQueries({ queryKey: ["bank_transaction", txnId] });
      qc.invalidateQueries({ queryKey: ["bank_dashboard"] });
    },
  });
}

export function useMarkAsAdvance(txnId: number) {
  const qc = useQueryClient();
  return useMutation<{ data: BankTransaction }, Error, MarkAsAdvancePayload>({
    mutationFn: async (payload) => {
      const { data } = await apiClient.post<{ data: BankTransaction }>(
        `/api/v1/bank_transactions/${txnId}/mark_as_advance`,
        payload
      );
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["bank_transactions"] });
      qc.invalidateQueries({ queryKey: ["bank_transaction", txnId] });
    },
  });
}

export function useIgnoreTransaction(txnId: number) {
  const qc = useQueryClient();
  return useMutation<{ data: BankTransaction }, Error, void>({
    mutationFn: async () => {
      const { data } = await apiClient.post<{ data: BankTransaction }>(
        `/api/v1/bank_transactions/${txnId}/ignore`
      );
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["bank_transactions"] });
      qc.invalidateQueries({ queryKey: ["bank_dashboard"] });
    },
  });
}

export function useRetryMatch(txnId: number) {
  const qc = useQueryClient();
  return useMutation<{ data: BankTransaction }, Error, void>({
    mutationFn: async () => {
      const { data } = await apiClient.post<{ data: BankTransaction }>(
        `/api/v1/bank_transactions/${txnId}/retry_match`
      );
      return data;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["bank_transactions"] });
      qc.invalidateQueries({ queryKey: ["bank_transaction", txnId] });
    },
  });
}

export function useBankDashboard(params: { bank_account_id?: number } = {}) {
  const { orgId } = useOrgBranch();
  return useQuery<BankDashboard>({
    queryKey: ["bank_dashboard", params, orgId],
    queryFn: async () => {
      const qp: Record<string, string | number> = {};
      if (params.bank_account_id) qp.bank_account_id = params.bank_account_id;
      const { data } = await apiClient.get<BankDashboard>(
        "/api/v1/bank_transactions/dashboard",
        { params: qp }
      );
      return data;
    },
    staleTime: 30_000,
    enabled: !!orgId,
  });
}
