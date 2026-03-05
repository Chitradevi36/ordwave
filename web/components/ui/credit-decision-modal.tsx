"use client";

import { useRouter } from "next/navigation";
import { ShieldCheck, ShieldAlert, ShieldX, TrendingDown, CreditCard, Clock, DollarSign, AlertTriangle, ChevronDown, ChevronUp, BarChart3 } from "lucide-react";
import { useState } from "react";
import { Modal } from "./modal";
import { Badge } from "./badge";
import { Button } from "./button";
import { cn } from "@/lib/utils";

// ─── Types ────────────────────────────────────────────────────────────────────

export interface CreditMetrics {
  credit_limit?:       number;
  outstanding?:        number;
  available?:          number;
  overdue_days?:       number;
  overdue_bucket?:     string;
  outstanding_pct?:    number;
  order_total?:        number;
  // Enriched exposure breakdown (added by RetailerCreditUsageService)
  invoice_outstanding?: number;
  order_exposure?:      number;
  hold_exposure?:       number;
  credit_used_total?:   number;
  available_credit?:    number;
}

export interface CreditActionsRequired {
  collection_required?: boolean;
  prepayment_required?: number[];
  approval_required?:   boolean;
}

export interface CreditResult {
  decision:         "ok" | "hold" | "blocked";
  reasons:          string[];
  metrics:          CreditMetrics;
  actions_required: CreditActionsRequired;
}

export interface CreditDecisionModalProps {
  open:         boolean;
  onClose:      () => void;
  credit:       CreditResult | null;
  orderId?:     number | string;
  orderNumber?: string;
  customerId?:  number;
  /** Whether the current user can approve on-hold orders (manager+) */
  canApprove?:  boolean;
}

// ─── Formatters ───────────────────────────────────────────────────────────────

function fmtINR(n: number | undefined) {
  if (n === undefined || n === null) return "—";
  return `₹${n.toLocaleString("en-IN", { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`;
}

// ─── Internal sub-components ─────────────────────────────────────────────────

function MetricCard({ icon, label, value, className }: {
  icon:       React.ReactNode;
  label:      string;
  value:      string;
  className?: string;
}) {
  return (
    <div className={cn("flex items-center gap-2 rounded-lg border border-border bg-background-subtle px-3 py-2", className)}>
      <div className="text-text-secondary shrink-0">{icon}</div>
      <div className="min-w-0">
        <p className="text-[10px] text-text-secondary leading-none mb-0.5 uppercase tracking-wide">{label}</p>
        <p className="text-sm font-semibold truncate">{value}</p>
      </div>
    </div>
  );
}

function MetricsGrid({ metrics }: { metrics: CreditMetrics }) {
  if (!metrics || Object.keys(metrics).length === 0) return null;

  // Prefer enriched available_credit over the legacy available field
  const avail = metrics.available_credit ?? metrics.available;

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
        {metrics.credit_limit !== undefined && (
          <MetricCard
            icon={<CreditCard className="h-4 w-4" />}
            label="Credit Limit"
            value={fmtINR(metrics.credit_limit)}
          />
        )}
        {metrics.outstanding !== undefined && (
          <MetricCard
            icon={<TrendingDown className="h-4 w-4" />}
            label="Outstanding"
            value={fmtINR(metrics.outstanding)}
          />
        )}
        {avail !== undefined && (
          <MetricCard
            icon={<DollarSign className="h-4 w-4" />}
            label="Available"
            value={fmtINR(avail)}
            className={(avail ?? 0) <= 0 ? "border-danger/40 bg-danger/5" : ""}
          />
        )}
        {metrics.overdue_days !== undefined && (
          <MetricCard
            icon={<Clock className="h-4 w-4" />}
            label="Overdue Days"
            value={metrics.overdue_days > 0 ? `${metrics.overdue_days} days` : "None"}
            className={metrics.overdue_days > 0 ? "border-warning/40 bg-warning/5" : ""}
          />
        )}
      </div>

      {/* Exposure breakdown (shown when order_exposure is present) */}
      {metrics.order_exposure !== undefined && (
        <div className="rounded-lg border border-border bg-background-subtle text-xs overflow-hidden">
          <div className="flex items-center gap-1.5 px-3 py-2 border-b border-border">
            <BarChart3 className="h-3.5 w-3.5 text-text-secondary" />
            <span className="font-semibold text-text-primary">Credit Exposure Breakdown</span>
          </div>
          <div className="divide-y divide-border">
            {metrics.invoice_outstanding !== undefined && (
              <ExposureRow label="Invoice Outstanding" value={metrics.invoice_outstanding} />
            )}
            <ExposureRow
              label="Order Exposure (pipeline)"
              value={metrics.order_exposure}
              valueClass={(metrics.order_exposure ?? 0) > 0 ? "text-warning" : undefined}
            />
            {(metrics.hold_exposure ?? 0) > 0 && (
              <ExposureRow label="On-Hold Orders" value={metrics.hold_exposure!} valueClass="text-text-secondary" />
            )}
            {metrics.credit_used_total !== undefined && (
              <div className="flex justify-between px-3 py-1.5 bg-white">
                <span className="font-semibold text-text-primary">Credit Used Total</span>
                <span className="tabular-nums font-bold">{fmtINR(metrics.credit_used_total)}</span>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function ExposureRow({ label, value, valueClass }: { label: string; value: number; valueClass?: string }) {
  return (
    <div className="flex justify-between items-center px-3 py-1.5">
      <span className="text-text-secondary">{label}</span>
      <span className={`tabular-nums font-medium ${valueClass ?? "text-text-primary"}`}>{fmtINR(value)}</span>
    </div>
  );
}

// ─── Decision layouts ─────────────────────────────────────────────────────────

function OkLayout({ orderId, orderNumber, onClose }: {
  orderId?:     number | string;
  orderNumber?: string;
  onClose:      () => void;
}) {
  const router = useRouter();
  return (
    <>
      <div className="flex items-center gap-3 rounded-lg bg-success/10 border border-success/20 px-4 py-3">
        <ShieldCheck className="h-6 w-6 text-success shrink-0" />
        <div>
          <p className="font-semibold text-success">Credit check passed</p>
          <p className="text-sm text-text-secondary">
            {orderNumber ? `Order ${orderNumber} has` : "Order has"} been submitted successfully.
          </p>
        </div>
      </div>

      <div className="flex gap-3 pt-2">
        {orderId ? (
          <Button className="flex-1" onClick={() => { onClose(); router.push(`/orders/${orderId}`); }}>
            View Order
          </Button>
        ) : null}
        <Button variant="outline" className="flex-1" onClick={() => { onClose(); router.push("/orders/new"); }}>
          Create Another
        </Button>
      </div>
    </>
  );
}

function HoldLayout({ orderId, orderNumber, reasons, metrics, actionsRequired, canApprove, onClose }: {
  orderId?:         number | string;
  orderNumber?:     string;
  reasons:          string[];
  metrics:          CreditMetrics;
  actionsRequired:  CreditActionsRequired;
  canApprove?:      boolean;
  onClose:          () => void;
}) {
  const router = useRouter();
  return (
    <>
      <div className="flex items-center gap-3 rounded-lg bg-warning/10 border border-warning/20 px-4 py-3">
        <ShieldAlert className="h-6 w-6 text-warning shrink-0" />
        <div>
          <p className="font-semibold text-warning">Sent for approval</p>
          <p className="text-sm text-text-secondary">
            {orderNumber ? `Order ${orderNumber} is` : "Order is"} on hold and awaiting review by a branch manager or owner.
          </p>
        </div>
      </div>

      {reasons.length > 0 && (
        <div>
          <p className="text-sm font-medium mb-1.5">Why is it on hold?</p>
          <ul className="space-y-1">
            {reasons.map((r, i) => (
              <li key={i} className="flex items-start gap-2 text-sm text-text-secondary">
                <AlertTriangle className="h-3.5 w-3.5 text-warning mt-0.5 shrink-0" />
                {r}
              </li>
            ))}
          </ul>
        </div>
      )}

      <MetricsGrid metrics={metrics} />

      <div className="rounded-lg bg-muted/50 border border-border px-3 py-2 text-sm text-text-secondary">
        <strong className="text-text-primary">What happens next:</strong> A branch manager or owner will review this order.
        Once approved, it will proceed for fulfilment. You will be notified once a decision is made.
      </div>

      <div className="flex gap-3 pt-1 flex-wrap">
        {orderId && (
          <Button className="flex-1" onClick={() => { onClose(); router.push(`/orders/${orderId}`); }}>
            View Order (On Hold)
          </Button>
        )}
        {canApprove && orderId && (
          <Button variant="outline" className="flex-1" onClick={() => { onClose(); router.push(`/orders/${orderId}`); }}>
            Review &amp; Approve
          </Button>
        )}
        {actionsRequired.collection_required && (
          <Button variant="outline" className="flex-1" onClick={onClose}>
            Record Collection
          </Button>
        )}
      </div>
    </>
  );
}

function BlockedLayout({ orderId, orderNumber, reasons, metrics, actionsRequired, customerId, onClose }: {
  orderId?:        number | string;
  orderNumber?:    string;
  reasons:         string[];
  metrics:         CreditMetrics;
  actionsRequired: CreditActionsRequired;
  customerId?:     number;
  onClose:         () => void;
}) {
  const router = useRouter();
  const [expanded, setExpanded] = useState(false);

  // Determine primary CTA
  let primaryLabel  = "Edit Order";
  let primaryAction = onClose;

  if (actionsRequired.prepayment_required?.length) {
    primaryLabel  = "Use Advance Payment";
    primaryAction = onClose; // stub — navigate to payment screen when module exists
  } else if (actionsRequired.collection_required || (metrics.outstanding ?? 0) > (metrics.credit_limit ?? 0)) {
    primaryLabel  = "Record Collection";
    primaryAction = onClose; // stub — navigate to quick-collect when module exists
  } else if ((metrics.available ?? 0) < (metrics.order_total ?? 0)) {
    primaryLabel  = "Request Credit Limit Increase";
    primaryAction = () => {
      onClose();
      if (customerId) router.push(`/customers/${customerId}?tab=credit`);
    };
  }

  return (
    <>
      <div className="flex items-center gap-3 rounded-lg bg-danger/10 border border-danger/20 px-4 py-3">
        <ShieldX className="h-6 w-6 text-danger shrink-0" />
        <div>
          <p className="font-semibold text-danger">Order blocked by credit policy</p>
          <p className="text-sm text-text-secondary">
            {orderNumber ? `Order ${orderNumber} cannot` : "This order cannot"} be submitted until the issues below are resolved.
          </p>
        </div>
      </div>

      {reasons.length > 0 && (
        <div>
          <p className="text-sm font-medium mb-1.5">Blocking reasons</p>
          <ul className="space-y-1">
            {reasons.map((r, i) => (
              <li key={i} className="flex items-start gap-2 text-sm text-text-secondary">
                <ShieldX className="h-3.5 w-3.5 text-danger mt-0.5 shrink-0" />
                {r}
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Expandable metrics */}
      <button
        type="button"
        className="flex items-center gap-1 text-sm text-primary hover:underline"
        onClick={() => setExpanded(v => !v)}
      >
        {expanded ? <ChevronUp className="h-3.5 w-3.5" /> : <ChevronDown className="h-3.5 w-3.5" />}
        {expanded ? "Hide credit details" : "View credit details"}
      </button>

      {expanded && <MetricsGrid metrics={metrics} />}

      <div className="flex gap-3 pt-1 flex-wrap">
        <Button className="flex-1" onClick={primaryAction}>
          {primaryLabel}
        </Button>
        <Button variant="outline" className="flex-1" onClick={onClose}>
          Edit &amp; Save as Draft
        </Button>
      </div>

      {orderId && (
        <p className="text-center text-xs text-text-secondary">
          <button
            type="button"
            className="text-primary hover:underline"
            onClick={() => { onClose(); router.push(`/orders/${orderId}?tab=credit`); }}
          >
            View full credit details on order page
          </button>
        </p>
      )}
    </>
  );
}

// ─── Main export ──────────────────────────────────────────────────────────────

const DECISION_TITLE: Record<string, string> = {
  ok:      "Credit Check Result",
  hold:    "Credit Check Result",
  blocked: "Credit Check Result",
};

const DECISION_BADGE: Record<string, React.ReactNode> = {
  ok:      <Badge variant="success">OK</Badge>,
  hold:    <Badge variant="warning">ON HOLD</Badge>,
  blocked: <Badge variant="danger">BLOCKED</Badge>,
};

export function CreditDecisionModal({
  open,
  onClose,
  credit,
  orderId,
  orderNumber,
  customerId,
  canApprove = false,
}: CreditDecisionModalProps) {
  if (!credit) return null;

  return (
    <Modal
      open={open}
      onClose={onClose}
      size="lg"
    >
      <div className="space-y-4">
        {/* Header row */}
        <div className="flex items-center justify-between -mt-2 mb-0">
          <h2 className="text-lg font-semibold text-text-primary">
            {DECISION_TITLE[credit.decision] ?? "Credit Check Result"}
          </h2>
          {DECISION_BADGE[credit.decision]}
        </div>

        {/* Decision body */}
        {credit.decision === "ok" && (
          <OkLayout orderId={orderId} orderNumber={orderNumber} onClose={onClose} />
        )}
        {credit.decision === "hold" && (
          <HoldLayout
            orderId={orderId}
            orderNumber={orderNumber}
            reasons={credit.reasons}
            metrics={credit.metrics}
            actionsRequired={credit.actions_required}
            canApprove={canApprove}
            onClose={onClose}
          />
        )}
        {credit.decision === "blocked" && (
          <BlockedLayout
            orderId={orderId}
            orderNumber={orderNumber}
            reasons={credit.reasons}
            metrics={credit.metrics}
            actionsRequired={credit.actions_required}
            customerId={customerId}
            onClose={onClose}
          />
        )}
      </div>
    </Modal>
  );
}
