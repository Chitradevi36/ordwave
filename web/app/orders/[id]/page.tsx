"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Breadcrumb } from "@/components/ui/breadcrumb";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs } from "@/components/ui/tabs";
import { Modal } from "@/components/ui/modal";
import {
  CheckCircle2, XCircle, Ban, RefreshCw, Send, AlertTriangle,
  ShieldCheck, ShieldX, ShieldAlert, Pencil, CalendarDays, PauseCircle,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { CreditDecisionModal, CreditResult } from "@/components/ui/credit-decision-modal";
import { Alert } from "@/components/ui/alert";

// ─── Types ────────────────────────────────────────────────────────────────────
interface OrderLine {
  id: number;
  product_id: number;
  product_name: string;
  product_sku: string;
  qty: number;
  unit_price: number;
  discount_pct: number;
  gst_rate: number;
  line_total: number;
  price_source: string;
  hsn_code: string | null;
}

interface AuditEntry {
  id: number;
  action: string;
  changes: Record<string, unknown>;
  reason: string | null;
  actor_name: string | null;
  created_at: string;
}

interface OrderDetail {
  id: number;
  order_number: string;
  status: string;
  credit_decision: string | null;
  credit_reasons: string[];
  credit_snapshot: Record<string, unknown>;
  delivery_date: string | null;
  notes: string | null;
  total_amount: number;
  discount_amount: number;
  submitted_at: string | null;
  approved_at: string | null;
  cancelled_at: string | null;
  cancellation_reason: string | null;
  created_at: string;
  updated_at: string;
  customer: { id: number; name: string; code: string };
  branch: { id: number; name: string };
  created_by: { id: number; name: string };
  lines: OrderLine[];
  timeline: AuditEntry[];
}

// ─── Constants ────────────────────────────────────────────────────────────────
const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "success" | "danger" | "outline"> = {
  draft:     "secondary",
  submitted: "default",
  on_hold:   "warning",
  approved:  "success",
  rejected:  "danger",
  cancelled: "outline",
};

const CREDIT_ICON: Record<string, React.ReactNode> = {
  ok:      <ShieldCheck className="h-4 w-4 text-success" />,
  hold:    <ShieldAlert className="h-4 w-4 text-warning" />,
  blocked: <ShieldX className="h-4 w-4 text-danger" />,
};

const ACTION_LABEL: Record<string, string> = {
  order_created:       "Order Created",
  order_updated:       "Order Updated",
  order_submitted:     "Submitted",
  order_credit_checked: "Credit Checked",
  order_on_hold:       "Placed On Hold",
  order_approved:      "Approved",
  order_rejected:      "Rejected",
  order_cancelled:     "Cancelled",
  order_price_refreshed: "Prices Refreshed",
};

function fmtINR(n: number | string) {
  return `₹${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function fmtDate(d: string | null | undefined) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

function fmtDateTime(d: string | null | undefined) {
  if (!d) return "—";
  return new Date(d).toLocaleString("en-IN", {
    day: "2-digit", month: "short", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function OverviewTab({ order }: { order: OrderDetail }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      <Card>
        <CardHeader><CardTitle className="text-sm">Order Info</CardTitle></CardHeader>
        <CardContent className="space-y-2 text-sm">
          <Row label="Order #"       value={<span className="font-mono">{order.order_number}</span>} />
          <Row label="Status"        value={<Badge variant={STATUS_VARIANT[order.status]}>{order.status.replace("_", " ")}</Badge>} />
          <Row label="Delivery Date" value={fmtDate(order.delivery_date)} />
          <Row label="Notes"         value={order.notes ?? "—"} />
          <Row label="Created"       value={fmtDateTime(order.created_at)} />
          <Row label="Submitted"     value={fmtDateTime(order.submitted_at)} />
          {order.approved_at && <Row label="Approved"  value={fmtDateTime(order.approved_at)} />}
          {order.cancelled_at && <>
            <Row label="Cancelled" value={fmtDateTime(order.cancelled_at)} />
            <Row label="Reason"    value={order.cancellation_reason ?? "—"} />
          </>}
        </CardContent>
      </Card>

      <Card>
        <CardHeader><CardTitle className="text-sm">Parties</CardTitle></CardHeader>
        <CardContent className="space-y-2 text-sm">
          <Row label="Customer"   value={`${order.customer.name} (${order.customer.code})`} />
          <Row label="Branch"     value={order.branch.name} />
          <Row label="Created By" value={order.created_by?.name ?? "—"} />
        </CardContent>
      </Card>

      <Card className="md:col-span-2">
        <CardHeader><CardTitle className="text-sm">Financials</CardTitle></CardHeader>
        <CardContent className="grid grid-cols-3 gap-4 text-sm">
          <div>
            <p className="text-text-secondary mb-1">Gross Total</p>
            <p className="text-lg font-semibold">{fmtINR(Number(order.total_amount) + Number(order.discount_amount))}</p>
          </div>
          <div>
            <p className="text-text-secondary mb-1">Discount</p>
            <p className="text-lg font-semibold text-danger">−{fmtINR(Number(order.discount_amount))}</p>
          </div>
          <div>
            <p className="text-text-secondary mb-1">Net Total</p>
            <p className="text-lg font-bold">{fmtINR(Number(order.total_amount))}</p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-start gap-2">
      <span className="w-32 text-text-secondary shrink-0">{label}</span>
      <span className="flex-1">{value}</span>
    </div>
  );
}

function LinesTab({ lines }: { lines: OrderLine[] }) {
  const PRICE_SOURCE_COLOR: Record<string, string> = {
    retailer_specific: "text-success",
    tier_specific:     "text-success",
    promo:             "text-accent",
    standard:          "text-text-secondary",
    manual:            "text-primary",
    missing:           "text-danger",
  };

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-border text-left text-text-secondary">
            <th className="pb-2 pr-3">SKU</th>
            <th className="pb-2 pr-3">Product</th>
            <th className="pb-2 pr-3 text-right">Qty</th>
            <th className="pb-2 pr-3 text-right">Unit Price</th>
            <th className="pb-2 pr-3 text-right">Disc %</th>
            <th className="pb-2 pr-3 text-right">GST %</th>
            <th className="pb-2 pr-3 text-right">Line Total</th>
            <th className="pb-2 text-left">Source</th>
          </tr>
        </thead>
        <tbody>
          {lines.map(l => (
            <tr key={l.id} className="border-b border-border/40 hover:bg-muted/30">
              <td className="py-2 pr-3 font-mono text-xs">{l.product_sku}</td>
              <td className="py-2 pr-3">{l.product_name}</td>
              <td className="py-2 pr-3 text-right">{l.qty}</td>
              <td className="py-2 pr-3 text-right">{fmtINR(l.unit_price)}</td>
              <td className="py-2 pr-3 text-right">{l.discount_pct}%</td>
              <td className="py-2 pr-3 text-right">{l.gst_rate}%</td>
              <td className="py-2 pr-3 text-right font-medium">{fmtINR(l.line_total)}</td>
              <td className={`py-2 text-xs font-medium ${PRICE_SOURCE_COLOR[l.price_source] ?? ""}`}>
                {l.price_source?.replace("_", " ") ?? "—"}
              </td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <td colSpan={6} className="pt-3 text-right pr-3 text-text-secondary font-medium">Total</td>
            <td className="pt-3 text-right pr-3 font-bold text-base">
              {fmtINR(lines.reduce((s, l) => s + Number(l.line_total), 0))}
            </td>
            <td />
          </tr>
        </tfoot>
      </table>
    </div>
  );
}

function CreditTab({ order }: { order: OrderDetail }) {
  if (!order.credit_decision) {
    return <p className="text-sm text-text-secondary">Credit check not yet run (order not submitted).</p>;
  }

  const iconMap: Record<string, React.ReactNode> = {
    ok:      <ShieldCheck className="h-8 w-8 text-success" />,
    hold:    <ShieldAlert className="h-8 w-8 text-warning" />,
    blocked: <ShieldX className="h-8 w-8 text-danger" />,
  };
  const labelMap: Record<string, string> = {
    ok:      "Credit OK — order can proceed",
    hold:    "On Hold — manual approval required",
    blocked: "Blocked — hard credit limit breached",
  };

  const snap = order.credit_snapshot as Record<string, number | string | undefined>;

  return (
    <div className="space-y-4">
      {/* Decision banner */}
      <Card className={
        order.credit_decision === "ok"      ? "border-success bg-success/5"
        : order.credit_decision === "hold"  ? "border-warning bg-warning/5"
        : "border-danger bg-danger/5"
      }>
        <CardContent className="flex items-center gap-4 py-4">
          {iconMap[order.credit_decision]}
          <div>
            <p className="font-semibold">{labelMap[order.credit_decision]}</p>
            {order.credit_reasons?.length > 0 && (
              <ul className="mt-1 list-disc list-inside text-sm text-text-secondary">
                {order.credit_reasons.map((r, i) => <li key={i}>{r}</li>)}
              </ul>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Metrics */}
      {Object.keys(snap).length > 0 && (
        <Card>
          <CardHeader><CardTitle className="text-sm">Credit Metrics (at Submit)</CardTitle></CardHeader>
          <CardContent className="grid grid-cols-2 md:grid-cols-3 gap-3 text-sm">
            {Object.entries(snap).map(([k, v]) => (
              <div key={k} className="bg-muted/30 rounded-md p-3">
                <p className="text-text-secondary text-xs mb-1">{k.replace(/_/g, " ")}</p>
                <p className="font-semibold">
                  {typeof v === "number" && k.includes("amount") ? fmtINR(v) : String(v ?? "—")}
                </p>
              </div>
            ))}
          </CardContent>
        </Card>
      )}
    </div>
  );
}

function TimelineTab({ timeline }: { timeline: AuditEntry[] }) {
  if (!timeline.length) return <p className="text-sm text-text-secondary">No activity yet.</p>;

  return (
    <div className="relative pl-6 space-y-4">
      {/* Vertical line */}
      <div className="absolute left-2.5 top-0 bottom-0 w-px bg-border" />

      {timeline.map(entry => (
        <div key={entry.id} className="relative">
          {/* Dot */}
          <div className="absolute -left-[15px] top-1 h-2.5 w-2.5 rounded-full bg-primary border-2 border-white" />

          <div className="bg-muted/30 rounded-md p-3 text-sm">
            <div className="flex items-center justify-between mb-1">
              <span className="font-medium">{ACTION_LABEL[entry.action] ?? entry.action}</span>
              <span className="text-xs text-text-secondary">{fmtDateTime(entry.created_at)}</span>
            </div>
            {entry.actor_name && (
              <p className="text-xs text-text-secondary">by {entry.actor_name}</p>
            )}
            {entry.reason && (
              <p className="mt-1 text-xs italic text-text-secondary">"{entry.reason}"</p>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function OrderDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [order, setOrder]     = useState<OrderDetail | null>(null);
  const [loading, setLoading] = useState(true);

  // Modals
  const [approveModal, setApproveModal] = useState(false);
  const [cancelModal,  setCancelModal]  = useState(false);
  const [holdModal,    setHoldModal]    = useState(false);
  const [decision,     setDecision]     = useState<"approved" | "rejected">("approved");
  const [decisionReason, setDecisionReason] = useState("");
  const [cancelReason, setCancelReason] = useState("");
  const [holdReason,   setHoldReason]   = useState("");
  const [acting, setActing] = useState(false);

  // Credit decision modal
  const [creditModal,  setCreditModal]  = useState(false);
  const [creditResult, setCreditResult] = useState<CreditResult | null>(null);

  // Limited edit (delivery_date + notes for submitted/on_hold by manager)
  const [editModal,  setEditModal]  = useState(false);
  const [editDate,   setEditDate]   = useState("");
  const [editNotes,  setEditNotes]  = useState("");

  const [toast, setToast] = useState<{ type: "success" | "error"; msg: string } | null>(null);

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  const fetch_ = useCallback(async () => {
    if (!token || !orgId || !params.id) return;
    setLoading(true);
    try {
      const res  = await fetch(`http://localhost:3001/api/v1/sales_orders/${params.id}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) setOrder(json.data);
      else        showToast("error", json.errors?.[0] ?? "Failed to load order");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, params.id]);

  useEffect(() => { void fetch_(); }, [fetch_]);

  const postAction = async (path: string, body: Record<string, unknown>): Promise<boolean> => {
    setActing(true);
    try {
      const res  = await fetch(`http://localhost:3001/api/v1/sales_orders/${params.id}/${path}`, {
        method:  "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });
      const json = await res.json();
      if (res.ok) {
        setOrder(json.data);
        showToast("success", "Done");
        return true;
      } else {
        showToast("error", json.errors?.[0] ?? "Action failed");
        return false;
      }
    } finally {
      setActing(false);
    }
  };

  const handleSubmit = async () => {
    setActing(true);
    try {
      const res  = await fetch(`http://localhost:3001/api/v1/sales_orders/${params.id}/submit`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({}),
      });
      const json = await res.json();

      if (res.ok && json.data) {
        // OK or HOLD — update order, show credit modal
        setOrder(json.data);
        setCreditResult(json.credit ?? null);
        setCreditModal(true);
      } else if (!res.ok && json.code === "credit_blocked") {
        // BLOCKED — order stays draft, refresh to capture credit_snapshot
        await fetch_();
        setCreditResult(json.credit ?? null);
        setCreditModal(true);
      } else {
        showToast("error", json.errors?.[0] ?? "Submit failed");
      }
    } finally {
      setActing(false);
    }
  };
  const handleRefreshPrice = () => postAction("refresh_price", {});

  const openLimitedEdit = () => {
    if (!order) return;
    setEditDate(order.delivery_date ?? "");
    setEditNotes(order.notes ?? "");
    setEditModal(true);
  };

  const handleLimitedEditSubmit = async () => {
    setActing(true);
    try {
      const res  = await fetch(`http://localhost:3001/api/v1/sales_orders/${params.id}`, {
        method:  "PATCH",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({ order: { delivery_date: editDate || null, notes: editNotes || null } }),
      });
      const json = await res.json();
      if (res.ok) {
        setOrder(json.data);
        setEditModal(false);
        showToast("success", "Order updated");
      } else {
        showToast("error", json.errors?.[0] ?? "Update failed");
      }
    } finally {
      setActing(false);
    }
  };

  const handleApproveSubmit = async () => {
    const ok = await postAction("approve", { decision, reason: decisionReason });
    if (ok) { setApproveModal(false); setDecisionReason(""); setDecision("approved"); }
  };
  const handleCancelSubmit = async () => {
    const ok = await postAction("cancel", { reason: cancelReason });
    if (ok) { setCancelModal(false); setCancelReason(""); }
  };
  const handleHoldSubmit = async () => {
    const ok = await postAction("hold", { reason: holdReason });
    if (ok) { setHoldModal(false); setHoldReason(""); }
  };

  if (loading) {
    return (
      <AppShell>
        <div className="flex items-center justify-center py-24 text-text-secondary text-sm">
          Loading…
        </div>
      </AppShell>
    );
  }

  if (!order) return null;

  const tabItems = [
    { value: "overview", label: "Overview",     content: <OverviewTab order={order} /> },
    { value: "lines",    label: `Lines (${order.lines.length})`, content: <LinesTab lines={order.lines} /> },
    { value: "credit",   label: "Credit Check",  content: <CreditTab order={order} /> },
    { value: "timeline", label: "Timeline",      content: <TimelineTab timeline={order.timeline} /> },
  ];

  return (
    <AppShell>
      {toast && (
        <div className={`fixed top-4 right-4 z-50 rounded-lg px-4 py-3 text-sm text-white shadow-lg ${
          toast.type === "success" ? "bg-success" : "bg-danger"
        }`}>
          {toast.msg}
        </div>
      )}

      <Breadcrumb items={[
        { label: "Orders", href: "/orders" },
        { label: order.order_number },
      ]} />

      <PageHeader
        title={order.order_number}
        description={`${order.customer.name} · ${order.branch.name}`}
        actions={[
          // Edit (draft only — full edit)
          ...(order.status === "draft" ? [{
            label: "Edit Order",
            icon: Pencil,
            onClick: () => router.push(`/orders/${order.id}/edit`),
            variant: "outline" as const,
          }] : []),
          // Edit logistics (submitted/on_hold — delivery_date + notes only)
          ...(["submitted", "on_hold"].includes(order.status) ? [{
            label: "Edit Logistics",
            icon: CalendarDays,
            onClick: openLimitedEdit,
            variant: "outline" as const,
          }] : []),
          // Submit (draft only)
          ...(order.status === "draft" ? [{
            label: "Submit",
            icon: Send,
            onClick: handleSubmit,
          }] : []),
          // Refresh prices (draft only)
          ...(order.status === "draft" ? [{
            label: "Refresh Prices",
            icon: RefreshCw,
            onClick: handleRefreshPrice,
            variant: "outline" as const,
          }] : []),
          // Approve/Reject (submitted or on_hold — managers+)
          ...(["submitted", "on_hold"].includes(order.status) ? [{
            label: "Review",
            icon: CheckCircle2,
            onClick: () => { setDecision("approved"); setDecisionReason(""); setApproveModal(true); },
          }] : []),
          // Put on Hold (submitted only — managers+)
          ...(order.status === "submitted" ? [{
            label: "Put on Hold",
            icon: PauseCircle,
            onClick: () => { setHoldReason(""); setHoldModal(true); },
            variant: "outline" as const,
          }] : []),
          // Cancel
          ...(!["rejected", "cancelled"].includes(order.status) ? [{
            label: "Cancel Order",
            icon: Ban,
            onClick: () => { setCancelReason(""); setCancelModal(true); },
            variant: "outline" as const,
          }] : []),
        ]}
      />

      {/* Status + credit badges + total */}
      <div className="flex items-center gap-2 mb-4 -mt-2">
        <Badge variant={STATUS_VARIANT[order.status]}>
          {order.status.replace("_", " ")}
        </Badge>
        {order.credit_decision && (
          <div className="flex items-center gap-1">
            {CREDIT_ICON[order.credit_decision]}
            <span className="text-xs text-text-secondary capitalize">
              Credit {order.credit_decision}
            </span>
          </div>
        )}
        <span className="text-lg font-bold ml-auto">{fmtINR(order.total_amount)}</span>
      </div>

      {/* On-hold banner */}
      {order.status === "on_hold" && (
        <Alert variant="warning" title="Order on hold — pending credit approval" className="mb-4">
          {order.credit_reasons?.length > 0 && (
            <ul className="mt-1 list-disc list-inside">
              {order.credit_reasons.map((r, i) => <li key={i}>{r}</li>)}
            </ul>
          )}
          <p className="mt-2 text-xs">A branch manager or owner must approve this order before it proceeds.</p>
        </Alert>
      )}

      {/* Submitted banner — credit ok, awaiting manager sign-off */}
      {order.status === "submitted" && (
        <Alert variant="default" title="Order submitted — awaiting approval" className="mb-4">
          <p className="text-xs">A manager can approve, reject, or put this order on hold using the buttons above.</p>
        </Alert>
      )}

      {/* Blocked banner — order stays in draft after a failed credit check */}
      {order.credit_decision === "blocked" && order.status === "draft" && (
        <Alert variant="danger" title="Order blocked by credit policy" className="mb-4">
          {order.credit_reasons?.length > 0 && (
            <ul className="mt-1 list-disc list-inside">
              {order.credit_reasons.map((r, i) => <li key={i}>{r}</li>)}
            </ul>
          )}
          <button
            type="button"
            className="mt-2 text-sm underline text-danger hover:text-danger/80"
            onClick={() => {
              setCreditResult({
                decision:         "blocked",
                reasons:          order.credit_reasons ?? [],
                metrics:          order.credit_snapshot as CreditResult["metrics"],
                actions_required: {},
              });
              setCreditModal(true);
            }}
          >
            View details &amp; required actions
          </button>
        </Alert>
      )}

      <Tabs items={tabItems} defaultValue="overview" />

      {/* Approve/Reject Modal */}
      <Modal
        open={approveModal}
        onClose={() => setApproveModal(false)}
        title="Review Order"
      >
        <div className="space-y-4">
          <p className="text-sm text-text-secondary">
            {order.status === "on_hold"
              ? `Order ${order.order_number} is on hold pending credit review. Approve or reject to proceed.`
              : `Order ${order.order_number} is submitted and awaiting approval. Approve or reject to proceed.`}
          </p>

          <div className="flex gap-3">
            <button
              onClick={() => setDecision("approved")}
              className={`flex-1 rounded-md border py-2 text-sm font-medium transition-colors ${
                decision === "approved"
                  ? "border-success bg-success/10 text-success"
                  : "border-border text-text-secondary hover:bg-muted"
              }`}
            >
              <CheckCircle2 className="h-4 w-4 inline mr-1" /> Approve
            </button>
            <button
              onClick={() => setDecision("rejected")}
              className={`flex-1 rounded-md border py-2 text-sm font-medium transition-colors ${
                decision === "rejected"
                  ? "border-danger bg-danger/10 text-danger"
                  : "border-border text-text-secondary hover:bg-muted"
              }`}
            >
              <XCircle className="h-4 w-4 inline mr-1" /> Reject
            </button>
          </div>

          <div>
            <label className="text-sm font-medium mb-1 block">
              Reason {decision === "rejected" ? "*" : "(optional)"}
            </label>
            <textarea
              value={decisionReason}
              onChange={e => setDecisionReason(e.target.value)}
              rows={3}
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder={decision === "approved" ? "Optional note…" : "Reason for rejection…"}
            />
          </div>

          <div className="flex justify-end gap-3">
            <Button variant="outline" onClick={() => setApproveModal(false)}>Cancel</Button>
            <Button
              onClick={handleApproveSubmit}
              disabled={acting || (decision === "rejected" && !decisionReason.trim())}
              className={decision === "rejected" ? "bg-danger hover:bg-danger/90" : ""}
            >
              Confirm {decision === "approved" ? "Approval" : "Rejection"}
            </Button>
          </div>
        </div>
      </Modal>

      {/* Cancel Modal */}
      <Modal
        open={cancelModal}
        onClose={() => setCancelModal(false)}
        title="Cancel Order"
      >
        <div className="space-y-4">
          <p className="text-sm text-text-secondary">
            Are you sure you want to cancel order <strong>{order.order_number}</strong>?
            This cannot be undone.
          </p>
          <div>
            <label className="text-sm font-medium mb-1 block">Reason *</label>
            <textarea
              value={cancelReason}
              onChange={e => setCancelReason(e.target.value)}
              rows={3}
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="Reason for cancellation…"
            />
          </div>
          <div className="flex justify-end gap-3">
            <Button variant="outline" onClick={() => setCancelModal(false)}>Back</Button>
            <Button
              className="bg-danger hover:bg-danger/90"
              disabled={acting || !cancelReason.trim()}
              onClick={handleCancelSubmit}
            >
              Confirm Cancel
            </Button>
          </div>
        </div>
      </Modal>

      {/* Hold Modal */}
      <Modal
        open={holdModal}
        onClose={() => setHoldModal(false)}
        title="Put Order on Hold"
        description="The order will move to on-hold status. A manager will need to approve or reject it before it proceeds."
      >
        <div className="space-y-4">
          <div>
            <label className="text-sm font-medium mb-1 block">Reason *</label>
            <textarea
              value={holdReason}
              onChange={e => setHoldReason(e.target.value)}
              rows={3}
              autoFocus
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="e.g. Awaiting stock confirmation, customer query…"
            />
          </div>
          <div className="flex justify-end gap-3">
            <Button variant="outline" onClick={() => setHoldModal(false)}>Cancel</Button>
            <Button
              disabled={acting || !holdReason.trim()}
              onClick={handleHoldSubmit}
            >
              Confirm Hold
            </Button>
          </div>
        </div>
      </Modal>

      {/* Credit Decision Modal */}
      <CreditDecisionModal
        open={creditModal}
        onClose={() => setCreditModal(false)}
        credit={creditResult}
        orderId={order.id}
        orderNumber={order.order_number}
        customerId={order.customer.id}
      />

      {/* Edit Logistics Modal (submitted/on_hold — delivery date + notes) */}
      <Modal
        open={editModal}
        onClose={() => setEditModal(false)}
        title="Edit Logistics"
        description="Update delivery date and notes. Lines and pricing cannot be changed after submission."
      >
        <div className="space-y-4">
          <div>
            <label className="text-sm font-medium mb-1 block">Delivery Date</label>
            <input
              type="date"
              value={editDate}
              onChange={e => setEditDate(e.target.value)}
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
          <div>
            <label className="text-sm font-medium mb-1 block">Notes</label>
            <textarea
              rows={3}
              value={editNotes}
              onChange={e => setEditNotes(e.target.value)}
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary resize-none"
              placeholder="Optional notes…"
            />
          </div>
          <div className="flex justify-end gap-3">
            <Button variant="outline" onClick={() => setEditModal(false)}>Cancel</Button>
            <Button onClick={handleLimitedEditSubmit} disabled={acting}>
              Save Changes
            </Button>
          </div>
        </div>
      </Modal>
    </AppShell>
  );
}
