"use client";

import { useState } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import {
  CreditCard,
  CheckCircle,
  AlertTriangle,
  XCircle,
  Clock,
  Zap,
  TrendingUp,
  Crown,
  RefreshCw,
  ExternalLink,
  Receipt,
  ChevronRight,
} from "lucide-react";
import { useBillingSubscription, useBillingActions, useBillingInvoices } from "@/lib/api/hooks/useBilling";
import type { PlanCatalogEntry } from "@/lib/api/billing";

// ── Helpers ──────────────────────────────────────────────────────────────────

function formatDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleDateString("en-IN", {
    day: "numeric",
    month: "short",
    year: "numeric",
  });
}

function formatAmount(paise: number | null | undefined): string {
  if (paise == null) return "—";
  return `₹${(paise / 100).toLocaleString("en-IN")}`;
}

// ── Status badge ─────────────────────────────────────────────────────────────

const STATUS_CONFIG: Record<string, { label: string; color: string; icon: React.ReactNode }> = {
  active:    { label: "Active",    color: "bg-green-100 text-green-700",  icon: <CheckCircle className="h-3.5 w-3.5" /> },
  inactive:  { label: "Inactive",  color: "bg-muted text-text-secondary",  icon: <Clock className="h-3.5 w-3.5" /> },
  past_due:  { label: "Past Due",  color: "bg-red-100 text-red-700",      icon: <AlertTriangle className="h-3.5 w-3.5" /> },
  cancelled: { label: "Cancelled", color: "bg-amber-100 text-amber-700",  icon: <XCircle className="h-3.5 w-3.5" /> },
  trialing:  { label: "Trial",     color: "bg-blue-100 text-blue-700",    icon: <Clock className="h-3.5 w-3.5" /> },
};

function BillingStatusBadge({ status }: { status: string }) {
  const cfg = STATUS_CONFIG[status] ?? { label: status, color: "bg-muted text-text-secondary", icon: null };
  return (
    <span className={`inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs font-medium ${cfg.color}`}>
      {cfg.icon}
      {cfg.label}
    </span>
  );
}

// ── Plan icon ────────────────────────────────────────────────────────────────

function PlanIcon({ plan }: { plan: string }) {
  if (plan === "pro")     return <Crown    className="h-5 w-5 text-amber-500" />;
  if (plan === "starter") return <TrendingUp className="h-5 w-5 text-blue-500" />;
  return <Zap className="h-5 w-5 text-muted-foreground" />;
}

// ── Plan card ────────────────────────────────────────────────────────────────

interface PlanCardProps {
  catalog: PlanCatalogEntry;
  currentPlan: string;
  onUpgrade: (plan: string) => void;
  loading: boolean;
}

const PLAN_FEATURES: Record<string, string[]> = {
  free:    ["1 branch", "3 users", "100 orders/month", "500 products", "GST / e-Invoice"],
  starter: ["3 branches", "15 users", "Unlimited orders", "Unlimited products", "Data exports", "API access", "GST / e-Invoice"],
  pro:     ["Unlimited branches", "Unlimited users", "Unlimited orders", "Advanced analytics", "Webhooks", "Custom roles", "Priority support", "GST / e-Invoice"],
};

function PlanCard({ catalog, currentPlan, onUpgrade, loading }: PlanCardProps) {
  const isCurrent  = catalog.plan === currentPlan;
  const isDowngrade = ["free", "starter", "pro"].indexOf(catalog.plan) < ["free", "starter", "pro"].indexOf(currentPlan);
  const features   = PLAN_FEATURES[catalog.plan] ?? [];

  return (
    <div
      className={`relative rounded-xl border-2 p-5 flex flex-col gap-4 transition-all ${
        catalog.highlight
          ? "border-primary shadow-md"
          : isCurrent
          ? "border-green-400"
          : "border-border"
      }`}
    >
      {catalog.highlight && (
        <div className="absolute -top-3 left-1/2 -translate-x-1/2">
          <span className="bg-primary text-primary-foreground text-xs font-semibold px-3 py-1 rounded-full">
            Most Popular
          </span>
        </div>
      )}

      <div className="flex items-start justify-between">
        <div className="flex items-center gap-2">
          <PlanIcon plan={catalog.plan} />
          <div>
            <h3 className="font-semibold text-base">{catalog.display_name}</h3>
            <p className="text-xs text-text-secondary">{catalog.description}</p>
          </div>
        </div>
        {isCurrent && (
          <span className="text-xs text-green-600 font-medium bg-green-50 px-2 py-0.5 rounded-full border border-green-200">
            Current
          </span>
        )}
      </div>

      <div>
        <span className="text-2xl font-bold">
          {catalog.price_monthly_inr === 0 ? "Free" : `₹${catalog.price_monthly_inr.toLocaleString("en-IN")}`}
        </span>
        {catalog.price_monthly_inr > 0 && (
          <span className="text-sm text-text-secondary ml-1">/month</span>
        )}
      </div>

      <ul className="space-y-1.5 flex-1">
        {features.map((f) => (
          <li key={f} className="flex items-center gap-2 text-sm text-text-secondary">
            <CheckCircle className="h-3.5 w-3.5 text-green-500 shrink-0" />
            {f}
          </li>
        ))}
      </ul>

      {!isCurrent && !isDowngrade && (
        <Button
          className="w-full"
          variant={catalog.highlight ? "default" : "outline"}
          disabled={loading}
          onClick={() => onUpgrade(catalog.plan)}
        >
          {loading ? (
            <RefreshCw className="h-4 w-4 animate-spin mr-2" />
          ) : (
            <ExternalLink className="h-4 w-4 mr-2" />
          )}
          Upgrade to {catalog.display_name}
        </Button>
      )}
    </div>
  );
}

// ── Usage meter ──────────────────────────────────────────────────────────────

function UsageMeter({ label, current, max }: { label: string; current?: number; max: number | null }) {
  if (max === null) {
    return (
      <div className="flex items-center justify-between text-sm">
        <span className="text-text-secondary">{label}</span>
        <span className="font-medium text-green-600">Unlimited</span>
      </div>
    );
  }

  const pct   = current != null && max > 0 ? Math.min((current / max) * 100, 100) : 0;
  const color = pct >= 90 ? "bg-red-500" : pct >= 70 ? "bg-amber-400" : "bg-green-500";

  return (
    <div className="space-y-1">
      <div className="flex items-center justify-between text-sm">
        <span className="text-text-secondary">{label}</span>
        <span className="font-medium">{current != null ? `${current} / ${max}` : `— / ${max}`}</span>
      </div>
      <div className="h-1.5 w-full rounded-full bg-border overflow-hidden">
        <div className={`h-full rounded-full transition-all ${color}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

// ── Invoice row ──────────────────────────────────────────────────────────────

function InvoiceRow({ event }: { event: { id: number; event_type: string; created_at: string; amount: number | null; currency: string; status: string } }) {
  const isCharge  = event.event_type === "subscription.charged";
  const isFailed  = event.event_type === "payment.failed";

  return (
    <div className="flex items-center justify-between py-2.5 border-b border-border last:border-0">
      <div className="flex items-center gap-3">
        <div className={`p-1.5 rounded-full ${isCharge ? "bg-green-100" : isFailed ? "bg-red-100" : "bg-muted"}`}>
          <Receipt className={`h-4 w-4 ${isCharge ? "text-green-600" : isFailed ? "text-red-600" : "text-text-secondary"}`} />
        </div>
        <div>
          <p className="text-sm font-medium">
            {isCharge ? "Payment collected" : isFailed ? "Payment failed" : event.event_type.replace(/\./g, " ")}
          </p>
          <p className="text-xs text-text-secondary">{formatDate(event.created_at)}</p>
        </div>
      </div>
      <div className="text-right">
        <p className={`text-sm font-semibold ${isFailed ? "text-red-600" : "text-foreground"}`}>
          {formatAmount(event.amount)}
        </p>
        <p className="text-xs text-text-secondary">{event.currency}</p>
      </div>
    </div>
  );
}

// ── Main page ────────────────────────────────────────────────────────────────

export default function BillingPage() {
  const { data, loading, error, refetch }    = useBillingSubscription();
  const { invoices }                          = useBillingInvoices();
  const { startCheckout, cancelSubscription, checkoutLoading, cancelLoading, actionError } = useBillingActions();
  const [cancelConfirm, setCancelConfirm]    = useState(false);
  const [cancelMsg, setCancelMsg]            = useState<string | null>(null);

  async function handleUpgrade(plan: string) {
    try {
      const result = await startCheckout(plan);
      if (result) {
        // Checkout succeeded - refetch billing data
        setTimeout(() => refetch(), 2000);
      }
    } catch (e) {
      // Error handled by startCheckout hook
      console.error("Checkout error:", e);
    }
  }

  async function handleCancel() {
    if (!cancelConfirm) {
      setCancelConfirm(true);
      return;
    }
    const ok = await cancelSubscription();
    if (ok) {
      setCancelMsg("Subscription cancelled. You'll retain access until the end of your current period.");
      setCancelConfirm(false);
      refetch();
    }
  }

  if (loading) {
    return (
      <AppShell>
        <PageHeader title="Billing" subtitle="Manage your subscription and payment details" />
        <div className="p-6 space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-28 rounded-xl bg-border animate-pulse" />
          ))}
        </div>
      </AppShell>
    );
  }

  if (error) {
    return (
      <AppShell>
        <PageHeader title="Billing" subtitle="Manage your subscription and payment details" />
        <div className="p-6">
          <Card>
            <CardContent className="flex items-center gap-3 py-6 text-destructive">
              <AlertTriangle className="h-5 w-5" />
              <p className="text-sm">{error}</p>
            </CardContent>
          </Card>
        </div>
      </AppShell>
    );
  }

  const plan         = data?.plan ?? "free";
  const status       = data?.billing_status ?? "inactive";
  const sub          = data?.subscription;
  const usage        = data?.usage_summary;
  const allPlans     = data?.all_plans ?? [];
  const planDetails  = data?.plan_details;

  return (
    <AppShell>
      <PageHeader
        title="Billing"
        subtitle="Manage your subscription and payment details"
        actions={[
          { label: "Refresh", onClick: refetch, disabled: loading, icon: RefreshCw, variant: "ghost" }
        ]}
      />

      <div className="p-6 space-y-6">

        {/* Action feedback */}
        {(actionError || cancelMsg) && (
          <div className={`flex items-center gap-3 p-4 rounded-lg text-sm ${
            actionError ? "bg-red-50 text-red-700 border border-red-200" : "bg-green-50 text-green-700 border border-green-200"
          }`}>
            {actionError ? <AlertTriangle className="h-4 w-4 shrink-0" /> : <CheckCircle className="h-4 w-4 shrink-0" />}
            {actionError ?? cancelMsg}
          </div>
        )}

        {/* Past due warning */}
        {status === "past_due" && (
          <div className="flex items-start gap-3 p-4 rounded-lg bg-red-50 border border-red-200 text-red-700 text-sm">
            <AlertTriangle className="h-4 w-4 shrink-0 mt-0.5" />
            <div>
              <p className="font-medium">Payment required</p>
              <p className="text-xs mt-0.5">
                We couldn&apos;t process your last payment. Please update your payment method
                {sub?.ends_at ? ` before ${formatDate(sub.ends_at)}` : ""} to avoid service interruption.
              </p>
            </div>
          </div>
        )}

        {/* Current plan summary */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              <CreditCard className="h-4 w-4" />
              Current Plan
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <PlanIcon plan={plan} />
                <div>
                  <p className="font-semibold">{planDetails?.display_name ?? plan}</p>
                  <p className="text-sm text-text-secondary">{planDetails?.description}</p>
                </div>
              </div>
              <BillingStatusBadge status={status} />
            </div>

            {sub && (
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <p className="text-text-secondary text-xs mb-0.5">Period start</p>
                  <p className="font-medium">{formatDate(sub.current_period_start)}</p>
                </div>
                <div>
                  <p className="text-text-secondary text-xs mb-0.5">Period end</p>
                  <p className="font-medium">{formatDate(sub.current_period_end)}</p>
                </div>
                {sub.ends_at && (
                  <div className="col-span-2">
                    <p className="text-text-secondary text-xs mb-0.5">Access until</p>
                    <p className="font-medium text-amber-600">{formatDate(sub.ends_at)}</p>
                  </div>
                )}
              </div>
            )}

            {sub && sub.status === "active" && plan !== "free" && (
              <div className="pt-2 border-t border-border">
                {cancelConfirm ? (
                  <div className="flex items-center gap-3">
                    <p className="text-sm text-destructive flex-1">
                      This will cancel your subscription at the end of the current billing period.
                    </p>
                    <Button size="sm" variant="danger" onClick={handleCancel} disabled={cancelLoading}>
                      {cancelLoading ? <RefreshCw className="h-3.5 w-3.5 animate-spin mr-1" /> : null}
                      Confirm cancel
                    </Button>
                    <Button size="sm" variant="ghost" onClick={() => setCancelConfirm(false)}>
                      Keep plan
                    </Button>
                  </div>
                ) : (
                  <Button size="sm" variant="ghost" className="text-destructive hover:text-destructive" onClick={handleCancel}>
                    Cancel subscription
                    <ChevronRight className="h-3.5 w-3.5 ml-1" />
                  </Button>
                )}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Usage summary */}
        {usage && (
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-base">Usage</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3">
              <UsageMeter label="Branches"    max={usage.max_branches} />
              <UsageMeter label="Active users" max={usage.max_active_users} />
              <UsageMeter label="Orders / month" max={usage.max_orders_per_month} />
              <UsageMeter label="Products"    max={usage.max_products} />
            </CardContent>
          </Card>
        )}

        {/* Plan comparison */}
        {allPlans.length > 0 && (
          <div>
            <h2 className="text-sm font-semibold mb-3 text-text-secondary uppercase tracking-wide">Available Plans</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {allPlans.map((p) => (
                <PlanCard
                  key={p.plan}
                  catalog={p}
                  currentPlan={plan}
                  onUpgrade={handleUpgrade}
                  loading={checkoutLoading}
                />
              ))}
            </div>
          </div>
        )}

        {/* Payment history */}
        {invoices.length > 0 && (
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-base flex items-center gap-2">
                <Receipt className="h-4 w-4" />
                Payment History
              </CardTitle>
            </CardHeader>
            <CardContent>
              {invoices.map((inv) => (
                <InvoiceRow key={inv.id} event={inv} />
              ))}
            </CardContent>
          </Card>
        )}

      </div>
    </AppShell>
  );
}
