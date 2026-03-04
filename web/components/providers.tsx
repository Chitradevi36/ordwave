"use client";

import { OrgBranchProvider } from "@/lib/org-branch-context";

export function ClientProviders({ children }: { children: React.ReactNode }) {
  return <OrgBranchProvider>{children}</OrgBranchProvider>;
}
