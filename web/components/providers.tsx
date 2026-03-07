"use client";

import { useState } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { OrgBranchProvider } from "@/lib/org-branch-context";
import { UpgradeBannerListener } from "@/components/ui/upgrade-banner";

export function ClientProviders({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 30_000,           // 30 seconds
            refetchOnWindowFocus: false,
            retry: 1,
          },
        },
      })
  );

  return (
    <QueryClientProvider client={queryClient}>
      <OrgBranchProvider>
        <UpgradeBannerListener />
        {children}
      </OrgBranchProvider>
    </QueryClientProvider>
  );
}
