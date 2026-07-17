"use client";

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import { trackPageView } from "./track";

export function usePageTracking(): void {
  const pathname = usePathname();
  const lastPathname = useRef("");

  useEffect(() => {
    if (!pathname || pathname === lastPathname.current) return;
    lastPathname.current = pathname;
    trackPageView(pathname);
  }, [pathname]);
}