"use client";

// ── UpgradeBanner ──────────────────────────────────────────────────────────
//
// Listens for a custom "plan:limit_exceeded" DOM event (emitted by the Axios
// 402 interceptor in client.ts) and renders a dismissable full-width banner.
//
// Add <UpgradeBannerListener /> once near the root of your layout.
//
// The banner auto-clears on navigation (router.events) or manual dismiss.
//
import { useEffect, useState } from "react";
import { X, ArrowUpCircle } from "lucide-react";
import { useRouter } from "next/navigation";

export interface PlanLimitPayload {
  message:    string;
  limit_type: string;
  current?:   number;
  max?:       number;
  upgrade_to: string | null;
}

const PLAN_LIMIT_EVENT = "plan:limit_exceeded";

// Emit this from the Axios 402 interceptor
export function emitPlanLimitExceeded(payload: PlanLimitPayload) {
  if (typeof window === "undefined") return;
  window.dispatchEvent(new CustomEvent(PLAN_LIMIT_EVENT, { detail: payload }));
}

// Drop this component somewhere high in the component tree (e.g. AppShell or layout)
export function UpgradeBannerListener() {
  const [payload, setPayload] = useState<PlanLimitPayload | null>(null);
  const router = useRouter();

  useEffect(() => {
    const handler = (e: Event) => {
      setPayload((e as CustomEvent<PlanLimitPayload>).detail);
    };
    window.addEventListener(PLAN_LIMIT_EVENT, handler);
    return () => window.removeEventListener(PLAN_LIMIT_EVENT, handler);
  }, []);

  // Dismiss on navigation
  useEffect(() => {
    setPayload(null);
  }, [router]);

  if (!payload) return null;

  const planLabel = payload.upgrade_to
    ? payload.upgrade_to.charAt(0).toUpperCase() + payload.upgrade_to.slice(1)
    : null;

  return (
    <div
      role="alert"
      className="fixed top-0 left-0 right-0 z-50 flex items-center gap-3 bg-amber-50 border-b border-amber-300 px-4 py-3 text-sm shadow-md animate-in slide-in-from-top duration-200"
    >
      <ArrowUpCircle className="h-4 w-4 text-amber-600 shrink-0" />
      <p className="flex-1 text-amber-900">
        <span className="font-semibold">Plan limit reached — </span>
        {payload.message}
        {payload.current !== undefined && payload.max !== undefined && (
          <span className="ml-1 text-amber-700">
            ({payload.current} / {payload.max})
          </span>
        )}
      </p>
      {planLabel && (
        <a
          href="/settings/billing"
          className="shrink-0 rounded-md bg-amber-600 text-white px-3 py-1 text-xs font-semibold hover:bg-amber-700 transition-colors"
        >
          Upgrade to {planLabel}
        </a>
      )}
      <button
        onClick={() => setPayload(null)}
        aria-label="Dismiss"
        className="shrink-0 text-amber-600 hover:text-amber-900"
      >
        <X className="h-4 w-4" />
      </button>
    </div>
  );
}
