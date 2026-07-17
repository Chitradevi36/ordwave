/*
 * OrdWave marketing analytics wrapper.
 * Safe GA4 helpers for page views and CTA clicks.
 */

/** GA4 Measurement ID used by the marketing site. */
export const GA_MEASUREMENT_ID = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID ?? "";

export function isAnalyticsEnabled(): boolean {
  return typeof window !== "undefined" && GA_MEASUREMENT_ID.length > 0;
}

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
    // Analytics must never break the site.
  }
}

export function gtagPageView(pagePath: string, pageTitle?: string): void {
  safeGtag("event", "page_view", {
    page_path: pagePath,
    page_title: pageTitle ?? document.title,
    page_location: typeof window !== "undefined" ? window.location.href : pagePath,
  });
}

export function gtagEvent(eventName: string, params?: Record<string, unknown>): void {
  safeGtag("event", eventName, params);
}

export function gtagInit(): void {
  if (!GA_MEASUREMENT_ID) return;
  safeGtag("js", new Date());
  safeGtag("config", GA_MEASUREMENT_ID, { send_page_view: false });
}