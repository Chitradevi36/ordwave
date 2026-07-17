"use client";

import { usePageTracking } from "@/lib/analytics";

export function MarketingProviders({ children }: { children: React.ReactNode }) {
  usePageTracking();
  return <>{children}</>;
}