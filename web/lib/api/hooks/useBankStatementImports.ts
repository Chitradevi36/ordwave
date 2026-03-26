import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "../client";
import { useOrgBranch } from "@/lib/org-branch-context";
import type { BankStatementImport, PaginatedResponse } from "@/types/bankReconciliation";

export function useBankStatementImports(params: { bank_account_id?: number; page?: number } = {}) {
  const { orgId } = useOrgBranch();
  return useQuery<PaginatedResponse<BankStatementImport>>({
    queryKey: ["bank_statement_imports", params, orgId],
    queryFn: async () => {
      const qp: Record<string, string | number> = {};
      Object.entries(params).forEach(([k, v]) => {
        if (v !== undefined) qp[k] = v as string | number;
      });
      const { data } = await apiClient.get<PaginatedResponse<BankStatementImport>>(
        "/api/v1/bank_statement_imports",
        { params: qp }
      );
      return data;
    },
    staleTime: 30_000,
    enabled: !!orgId,
  });
}

export function useBankStatementImport(id: number | null) {
  const { orgId } = useOrgBranch();
  return useQuery<{ data: BankStatementImport }>({
    queryKey: ["bank_statement_import", id, orgId],
    queryFn: async () => {
      const { data } = await apiClient.get<{ data: BankStatementImport }>(
        `/api/v1/bank_statement_imports/${id}`
      );
      return data;
    },
    enabled: !!orgId && !!id,
  });
}

export function useUploadBankStatement() {
  const qc = useQueryClient();
  return useMutation<BankStatementImport, Error, { bankAccountId: number; file: File }>({
    mutationFn: async ({ bankAccountId, file }) => {
      const form = new FormData();
      form.append("file", file);
      form.append("bank_account_id", String(bankAccountId));
      const { data } = await apiClient.post<{ data: BankStatementImport }>(
        "/api/v1/bank_statement_imports",
        form,
        { headers: { "Content-Type": "multipart/form-data" } }
      );
      return data.data ?? (data as unknown as BankStatementImport);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["bank_statement_imports"] });
    },
  });
}
