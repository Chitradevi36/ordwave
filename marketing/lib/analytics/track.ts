import { gtagEvent, gtagPageView } from "./ga";

export function trackPageView(pathname: string): void {
  gtagEvent("marketing_page_view", {
    event_category: "page_view",
    page_path: pathname,
    page_module: "marketing",
  });
  gtagPageView(pathname);
}

export function trackCtaClick(params: {
  label: string;
  section?: string;
  href?: string;
}): void {
  gtagEvent("marketing_cta_click", {
    event_category: "ui_interaction",
    element_label: params.label,
    section: params.section ?? "",
    page_module: "marketing",
    page_path: typeof window !== "undefined" ? window.location.pathname : "",
    href: params.href ?? "",
  });
}

export function trackFormSubmit(params: {
  form_name: string;
  source?: string;
}): void {
  gtagEvent("marketing_form_submit", {
    event_category: "conversion",
    form_name: params.form_name,
    source: params.source ?? "",
    page_module: "marketing",
    page_path: typeof window !== "undefined" ? window.location.pathname : "",
  });
}