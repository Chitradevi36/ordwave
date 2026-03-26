import { useQuery } from "@tanstack/react-query";
import { apiClient } from "../client";
import { useOrgBranch } from "@/lib/org-branch-context";
import type { BankAccount } from "@/types/bankReconciliation";

/** Returns all active bank accounts for the current organisation. */
export function useBankAccounts() {
  const { orgId } = useOrgBranch();

  return useQuery<BankAccount[]>({
    queryKey: ["bank_accounts", orgId],
    queryFn: async () => {
      const { data } = await apiClient.get<BankAccount[]>("/api/v1/bank_accounts");
      return data;
    },
    staleTime: 30_000,
    enabled: !!orgId,
  });
}
