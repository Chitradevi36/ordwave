"use client";

import { useState } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { CheckCircle2, XCircle, ArrowLeftRight, AlertCircle, ShoppingCart, Loader2 } from "lucide-react";
import { useApprovals, useApproveOrder, useDecideCreditLimit } from "@/lib/api/hooks/useApprovals";
import { useRetailerRisk } from "@/lib/api/hooks/useRetailerRisk";
import { RiskBadge } from "@/components/customers/risk-badge";
import { ANALYTICS_EVENTS, trackBusinessEvent } from "@/lib/analytics";

function fmtINR(n: number | null | undefined) {
  if (n == null) return "—";
  return `₹${n.toLocaleString("en-IN")}`;
}

function fmtDate(iso: string) {
  try { return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }); }
  catch { return iso; }
}

/** Small badge that fetches its own risk profile for a given customer */
function OrderRiskBadge({ customerId }: { customerId: number }) {
  const { data, loading } = useRetailerRisk(customerId);
  if (loading || !data) return null;
  return <RiskBadge score={data.risk_score} tier={data.risk_tier} compact className="ml-1" />;
}

type Tab = "all" | "orders" | "credit";

export default function ApprovalsPage() {
  const [tab,    setTab]    = useState<Tab>("all");
  const [reason, setReason] = useState<Record<number, string>>({});
  const [acting, setActing] = useState<number | null>(null);

  const { data, isLoading, isError } = useApprovals();
  const approveOrder    = useApproveOrder();
  const decideCreditLim = useDecideCreditLimit();

  const orders  = data?.held_orders     ?? [];
  const credits = data?.credit_requests ?? [];
  const total   = data?.total_count     ?? 0;

  async function handleOrderDecision(id: number, decision: "approved" | "rejected") {
    setActing(id);
    try {
      await approveOrder.mutateAsync({ id, decision, reason: reason[id] });
      trackBusinessEvent(
        decision === "approved" ? ANALYTICS_EVENTS.ORDER_APPROVED : ANALYTICS_EVENTS.ORDER_REJECTED,
        { module: "approvals", page: "/approvals", order_id: id },
      );
    } finally {
      setActing(null);
    }
  }

  async function handleCreditDecision(id: number, decision: string) {
    setActing(id);
    try {
      await decideCreditLim.mutateAsync({ id, decision, decision_note: reason[id] });
      if (decision === "approved") {
        trackBusinessEvent(ANALYTICS_EVENTS.CREDIT_LIMIT_APPROVED, {
          module: "approvals", page: "/approvals", customer_id: id,
        });
      }
    } finally {
      setActing(null);
    }
  }

  const tabs: { key: Tab; label: string; count: number }[] = [
    { key: "all",    label: "All",                count: total },
    { key: "orders", label: "Orders on Hold",     count: orders.length },
    { key: "credit", label: "Credit Limit Requests", count: credits.length },
  ];

  const showOrders  = tab === "all" || tab === "orders";
  const showCredits = tab === "all" || tab === "credit";

  return (
    <AppShell>
      <PageHeader
        title="Approvals"
        description={total > 0 ? `${total} item${total !== 1 ? "s" : ""} need your attention` : "No pending approvals"}
      />

      {/* Tab bar */}
      <div className="flex gap-1 mb-5 border-b border-border">
        {tabs.map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={[
              "px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-px",
              tab === t.key
                ? "border-primary text-primary"
                : "border-transparent text-text-secondary hover:text-text-primary",
            ].join(" ")}
          >
            {t.label}
            {t.count > 0 && (
              <span className="ml-2 bg-red-100 text-red-700 text-xs font-semibold rounded-full px-1.5 py-0.5">
                {t.count}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Loading */}
      {isLoading && (
        <div className="space-y-3">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="h-28 w-full rounded-xl bg-background-subtle animate-pulse" />
          ))}
        </div>
      )}

      {/* Error */}
      {isError && !isLoading && (
        <Card>
          <CardContent className="py-10 text-center text-text-secondary">
            <AlertCircle className="mx-auto mb-2 h-8 w-8 text-danger" />
            <p className="font-medium text-text-primary">Failed to load approvals</p>
            <p className="text-sm mt-1">Check your connection and refresh the page.</p>
          </CardContent>
        </Card>
      )}

      {/* Empty */}
      {!isLoading && !isError && total === 0 && (
        <Card>
          <CardContent className="py-16 text-center">
            <CheckCircle2 className="mx-auto mb-3 h-10 w-10 text-success" />
            <p className="font-semibold text-text-primary">No pending actions</p>
            <p className="text-sm text-text-secondary mt-1">Your branch is running smoothly.</p>
          </CardContent>
        </Card>
      )}

      <div className="space-y-4">
        {/* ── Held Orders ──────────────────────────────────────────────── */}
        {showOrders && orders.map((order) => (
          <Card key={order.id} className="overflow-hidden">
            <CardContent className="p-4">
              <div className="flex items-start justify-between gap-4 flex-wrap">
                <div className="flex items-start gap-3">
                  <div className="w-9 h-9 rounded-lg bg-amber-50 text-amber-600 flex items-center justify-center shrink-0">
                    <ShoppingCart size={16} />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-text-primary">
                      {order.order_number}
                      <Badge variant="warning" className="ml-2 text-xs">On Hold</Badge>
                      {order.customer_id && <OrderRiskBadge customerId={order.customer_id} />}
                    </p>
                    <p className="text-sm text-text-secondary mt-0.5">{order.customer_name}</p>
                    <p className="text-xs text-text-secondary mt-0.5">
                      {order.lines_count} item{order.lines_count !== 1 ? "s" : ""} &bull; by {order.created_by} &bull; {fmtDate(order.created_at)}
                    </p>
                  </div>
                </div>
                <p className="text-lg font-bold text-text-primary tabular-nums">{fmtINR(order.total_amount)}</p>
              </div>

              {/* Reason input */}
              <Textarea
                className="mt-3 text-xs"
                placeholder="Add a note (required for rejection, optional for approval)…"
                rows={2}
                value={reason[order.id] ?? ""}
                onChange={(e) => setReason((p) => ({ ...p, [order.id]: e.target.value }))}
              />

              {/* Action buttons */}
              <div className="flex gap-2 mt-3">
                <Button
                  size="sm"
                  className="gap-1.5"
                  onClick={() => handleOrderDecision(order.id, "approved")}
                  disabled={acting === order.id}
                >
                  {acting === order.id ? <Loader2 size={13} className="animate-spin" /> : <CheckCircle2 size={13} />}
                  Approve
                </Button>
                <Button
                  size="sm"
                  variant="danger"
                  className="gap-1.5"
                  onClick={() => handleOrderDecision(order.id, "rejected")}
                  disabled={acting === order.id || !reason[order.id]?.trim()}
                >
                  <XCircle size={13} />
                  Reject
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}

        {/* ── Credit Limit Requests ─────────────────────────────────── */}
        {showCredits && credits.map((req) => (
          <Card key={req.id} className="overflow-hidden">
            <CardContent className="p-4">
              <div className="flex items-start justify-between gap-4 flex-wrap">
                <div className="flex items-start gap-3">
                  <div className="w-9 h-9 rounded-lg bg-blue-50 text-blue-600 flex items-center justify-center shrink-0">
                    <ArrowLeftRight size={16} />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-text-primary">
                      Credit Limit Request
                      <Badge variant="warning" className="ml-2 text-xs">Pending</Badge>
                    </p>
                    <p className="text-sm text-text-secondary mt-0.5">{req.customer_name}</p>
                    <p className="text-xs text-text-secondary mt-0.5">
                      {fmtINR(req.current_limit)} → <span className="font-semibold text-text-primary">{fmtINR(req.new_limit)}</span>
                      &nbsp;&bull; Requested by {req.requested_by} &bull; {fmtDate(req.created_at)}
                    </p>
                    {req.reason && (
                      <p className="text-xs text-text-secondary mt-1 italic">&ldquo;{req.reason}&rdquo;</p>
                    )}
                  </div>
                </div>
              </div>

              <Textarea
                className="mt-3 text-xs"
                placeholder="Decision note (optional)…"
                rows={2}
                value={reason[req.id] ?? ""}
                onChange={(e) => setReason((p) => ({ ...p, [req.id]: e.target.value }))}
              />

              <div className="flex gap-2 mt-3">
                <Button
                  size="sm"
                  className="gap-1.5"
                  onClick={() => handleCreditDecision(req.id, "approved")}
                  disabled={acting === req.id}
                >
                  {acting === req.id ? <Loader2 size={13} className="animate-spin" /> : <CheckCircle2 size={13} />}
                  Approve
                </Button>
                <Button
                  size="sm"
                  variant="danger"
                  className="gap-1.5"
                  onClick={() => handleCreditDecision(req.id, "rejected")}
                  disabled={acting === req.id}
                >
                  <XCircle size={13} />
                  Reject
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </AppShell>
  );
}
