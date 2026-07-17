/*
 * OrdWave marketing analytics wrapper.
 * Safe GA4 helpers for page views and CTA clicks.
 */

/** GA4 Measurement ID used by the marketing site. */
export const GA_MEASUREMENT_ID = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID ?? "";

export function isAnalyticsEnabled(): boolean {
  return typeof window !== "undefined" && GA_MEASUREMENT_ID.length > 0;
}

type GtagArg = string | number | boolean | Date | null | undefined | Record<string, unknown>;

type GtagFunction = (command: string, ...args: GtagArg[]) => void;

type WindowWithGtag = Window & {
  gtag?: GtagFunction;
};

export function safeGtag(command: string, ...args: GtagArg[]): void {
  try {
    if (!isAnalyticsEnabled()) return;
    if (typeof window === "undefined") return;

    const w = window as WindowWithGtag;
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