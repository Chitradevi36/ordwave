// ───────────────────────────────────────────────────────────────────────────
// OrdWave – Analytics Public API
//
// Import everything you need from "@/lib/analytics"
// ───────────────────────────────────────────────────────────────────────────

export { GA_MEASUREMENT_ID, isAnalyticsEnabled } from "./ga";

export {
  trackPageView,
  trackRoutePageView,
  trackClick,
  trackBusinessEvent,
  trackAuthEvent,
  trackOnboardingEvent,
  setUserContext,
} from "./track";

export { usePageTracking } from "./usePageTracking";

export {
  orderEvents,
  billingEvents,
  dispatchEvents,
  collectionEvents,
  inventoryEvents,
  engagementEvents,
} from "./events";

export { ANALYTICS_EVENTS, ROUTE_EVENT_MAP } from "./constants";
export type { AnalyticsEventName } from "./constants";

export type {
  AnalyticsRole,
  AmountBucket,
  BaseEventParams,
  PageViewParams,
  ClickEventParams,
  BusinessEventParams,
  AnalyticsUserProperties,
} from "./types";
