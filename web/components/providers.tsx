"use client";

import { useState, useEffect } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { GoogleOAuthProvider } from "@react-oauth/google";
import { Toaster } from "sonner";
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

  const googleClientId = process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID || "";

  useEffect(() => {
    if (typeof window !== 'undefined') {
      console.log('[OrdWave OAuth Debug]', {
        hasClientId: !!googleClientId,
        clientIdLength: googleClientId?.length || 0,
        environment: process.env.NODE_ENV,
        timestamp: new Date().toISOString(),
      });
      
      if (!googleClientId) {
        console.error('❌ NEXT_PUBLIC_GOOGLE_CLIENT_ID environment variable is NOT SET');
        console.error('Set it in your deployment platform (Vercel/AWS/etc) and redeploy');
      }
    }
  }, [googleClientId]);

  return (
    <QueryClientProvider client={queryClient}>
      <GoogleOAuthProvider clientId={googleClientId}>
        <OrgBranchProvider>
          <Toaster
            position="top-right"
            richColors
            closeButton
            toastOptions={{ className: "text-sm" }}
          />
          <UpgradeBannerListener />
          {children}
        </OrgBranchProvider>
      </GoogleOAuthProvider>
    </QueryClientProvider>
  );
}
