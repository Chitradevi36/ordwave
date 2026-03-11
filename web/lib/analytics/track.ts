// ---------------------------------------------------------------------------
// OrdWave � High-Level Analytics Helpers
// ---------------------------------------------------------------------------

import { gtagEvent, gtagPageView, gtagSetUser } from "./ga";
import { ROUTE_EVENT_MAP, type AnalyticsEventName } from "./constants";
import type {
  AnalyticsUserProperties,
  BusinessEventParams,
  ClickEventParams,
  PageViewParams,
} from "./types";

// --- User Context ------------------------------------------------------------

export function setUserContext(props: AnalyticsUserProperties): void {
  gtagSetUser(props);
}

// --- Page Views --------------------------------------------------------------

export function trackPageView(
  eventName: AnalyticsEventName,
  params: PageViewParams,
): void {
  gtagEvent(eventName, {
    event_category:  "page_view",
    page_module:     params.module,
    page_path:       params.page,
    user_role:       params.role,
    organization_id: String(params.organization_id ?? ""),
    branch_id:       String(params.branch_id ?? ""),
    page_title:      params.page_title,
  });
  gtagPageView(params.page ?? "", params.page_title);
}

export function trackRoutePageView(
  pathname: string,
  extra?: Record<string, unknown>,
): void {
  const match = ROUTE_EVENT_MAP.find((entry) => {
    if (typeof entry.pattern === "string") {
      return pathname === entry.pattern || pathname.startsWith(entry.pattern + "/");
    }
    return entry.pattern.test(pathname);
  });
  if (!match) return;
  gtagEvent(match.event, {
    event_category: "page_view",
    page_module:    match.module,
    page_path:      pathname,
    ...extra,
  });
  gtagPageView(pathname);
}

// --- Click / UI Interactions -------------------------------------------------

export function trackClick(
  eventName: AnalyticsEventName,
  params: ClickEventParams,
): void {
  gtagEvent(eventName, {
    event_category:  "ui_interaction",
    element_label:   params.element_label,
    section:         params.section,
    nav_item:        params.nav_item,
    page_module:     params.module,
    page_path:       params.page,
    user_role:       params.role,
    organization_id: String(params.organization_id ?? ""),
    branch_id:       String(params.branch_id ?? ""),
    count:           params.count,
    alert_type:      params.alert_type,
    severity:        params.severity,
  });
}

// --- Business / Domain Events -------------------------------------------------

export function trackBusinessEvent(
  eventName: AnalyticsEventName,
  params: BusinessEventParams,
): void {
  gtagEvent(eventName, {
    event_category:  "business",
    page_module:     params.module,
    page_path:       params.page,
    user_role:       params.role,
    organization_id: String(params.organization_id ?? ""),
    branch_id:       String(params.branch_id ?? ""),
    order_id:        params.order_id,
    order_status:    params.order_status,
    customer_id:     params.customer_id,
    product_id:      params.product_id,
    amount_bucket:   params.amount_bucket,
    payment_method:  params.payment_method,
    items_count:     params.items_count,
    reason:          params.reason,
    invited_role:    params.invited_role,
    plan:            params.plan,
    error_reason:    params.error_reason,
  });
}

// --- Auth Funnel Helpers ------------------------------------------------------

export function trackAuthEvent(
  eventName: AnalyticsEventName,
  extra?: Record<string, unknown>,
): void {
  gtagEvent(eventName, { event_category: "auth", ...extra });
}

// --- Onboarding Helpers -------------------------------------------------------

export function trackOnboardingEvent(
  eventName: AnalyticsEventName,
  step: string | number,
  stepName?: string,
  extra?: Record<string, unknown>,
): void {
  gtagEvent(eventName, {
    event_category:  "onboarding",
    onboarding_step: step,
    onboarding_name: stepName ?? "",
    ...extra,
  });
}
