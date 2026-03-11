// ───────────────────────────────────────────────────────────────────────────
// OrderLane Pro – GA4 Core Wrapper
//
// Low-level, safe gtag adapter. All calls are guarded against:
// - SSR (no window)
// - missing gtag (script not loaded yet)
// - missing measurement ID
// - any other runtime errors
//
// NEVER call gtag() directly outside this file.
// ───────────────────────────────────────────────────────────────────────────

import { AnalyticsUserProperties } from "./types";

/** GA4 Measurement ID — set via NEXT_PUBLIC_GA_MEASUREMENT_ID env var */
export const GA_MEASUREMENT_ID =
  process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID ?? "";

/** True only when we're in a browser with a valid measurement ID */
export function isAnalyticsEnabled(): boolean {
  return (
    typeof window !== "undefined" &&
    GA_MEASUREMENT_ID.length > 0 &&
    // In development only track if explicitly opted in
    (process.env.NODE_ENV === "production" ||
      process.env.NEXT_PUBLIC_GA_DEV_ENABLED === "true")
  );
}

/** Safely call gtag — never throws, fails silently */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function safeGtag(command: string, ...args: any[]): void {
  try {
    if (!isAnalyticsEnabled()) return;
    if (typeof window === "undefined") return;
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const w = window as any;
    if (typeof w.gtag !== "function") return;
    w.gtag(command, ...args);
  } catch {
    // Analytics must never crash the app — silently swallow all errors
  }
}

/** Send a page_view hit to GA4 */
export function gtagPageView(
  pagePath: string,
  pageTitle?: string,
): void {
  safeGtag("event", "page_view", {
    page_path:     pagePath,
    page_title:    pageTitle ?? document.title,
    page_location: typeof window !== "undefined" ? window.location.href : pagePath,
  });
}

/** Send a custom event to GA4 */
export function gtagEvent(
  eventName: string,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  params?: Record<string, any>,
): void {
  safeGtag("event", eventName, params);
}

/** Set user properties on GA4 — called once after auth */
export function gtagSetUser(props: AnalyticsUserProperties): void {
  safeGtag("set", "user_properties", {
    role:             props.role,
    organization_id:  String(props.organization_id ?? ""),
    branch_id:        String(props.branch_id ?? ""),
    app_environment:  props.app_environment ?? process.env.NODE_ENV,
  });
}

/** Initialize gtag config (called once from GA4Provider on mount) */
export function gtagInit(): void {
  if (!GA_MEASUREMENT_ID) return;
  safeGtag("js", new Date());
  safeGtag("config", GA_MEASUREMENT_ID, {
    send_page_view: false, // We handle page views manually to avoid duplicates
  });
}
