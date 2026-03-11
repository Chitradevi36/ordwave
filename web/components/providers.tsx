"use client";

import { useState } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { OrgBranchProvider } from "@/lib/org-branch-context";
import { UpgradeBannerListener } from "@/components/ui/upgrade-banner";
import { usePageTracking } from "@/lib/analytics";

/** Fires a GA4 page_view on every route change — must be inside a Router context */
function AnalyticsProvider({ children }: { children: React.ReactNode }) {
  usePageTracking();
  return <>{children}</>;
}

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
        <AnalyticsProvider>
          <UpgradeBannerListener />
          {children}
        </AnalyticsProvider>
      </OrgBranchProvider>
    </QueryClientProvider>
  );
}
