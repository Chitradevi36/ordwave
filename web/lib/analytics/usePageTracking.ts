"use client";

// ───────────────────────────────────────────────────────────────────────────
// OrdWave – Automatic Route-Change Page View Hook
//
// Drop this into any client-side provider component (e.g. providers.tsx).
// It fires trackRoutePageView() whenever the Next.js pathname changes.
// ───────────────────────────────────────────────────────────────────────────

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import { trackRoutePageView } from "./track";

export function usePageTracking(): void {
  const pathname = usePathname();
  const lastPathname = useRef<string>("");

  useEffect(() => {
    // Skip if pathname hasn't changed (e.g. query-string-only changes that
    // don't change the pathname still trigger a re-render)
    if (pathname === lastPathname.current) return;
    lastPathname.current = pathname;

    trackRoutePageView(pathname);
  }, [pathname]);
}
