"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { DataTable, Column } from "@/components/ui/data-table";
import { Tabs } from "@/components/ui/tabs";
import { Modal } from "@/components/ui/modal";
import { ArrowLeftRight, Pencil, Truck, PackageCheck, XCircle, TrendingUp, TrendingDown, Clock, CheckCircle } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { cn } from "@/lib/utils";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────
interface TransferLine {
  id: number;
  product_id: number;
  product_name: string | null;
  product_sku: string | null;
  qty_requested: number;
  qty_dispatched: number;
  qty_received: number;
  qty_damaged: number;
  qty_in_transit: number;
  reason_code: string | null;
  fully_accounted: boolean;
}

interface StockMovement {
  id: number;
  movement_type: string;
  direction: string;
  product_id: number;
  product_name: string | null;
  qty: number;
  branch_id: number;
  occurred_at: string;
}

interface TimelineEvent {
  id: number;
  action: string;
  changes: Record<string, unknown>;
  actor_name: string | null;
  created_at: string;
}

interface TransferDetail {
  id: number;
  transfer_number: string;
  transfer_date: string;
  status: string;
  notes: string | null;
  dispatched_at: string | null;
  received_at: string | null;
  cancellation_reason: string | null;
  created_at: string;
  source_branch: { id: number; name: string } | null;
  destination_branch: { id: number; name: string } | null;
  created_by: { id: number; name: string } | null;
  dispatched_by: { id: number; name: string } | null;
  received_by: { id: number; name: string } | null;
  lines: TransferLine[];
  stock_movements: StockMovement[];
  timeline: TimelineEvent[];
}

// ─── Dispatch line state ──────────────────────────────────────────────────────
interface DispatchRow {
  line_id: number;
  product_sku: string;
  product_name: string;
  qty_requested: number;
  qty_dispatched: string;
}

// ─── Receive line state ───────────────────────────────────────────────────────
interface ReceiveRow {
  line_id: number;
  product_sku: string;
  product_name: string;
  qty_dispatched: number;
  qty_received: string;
  qty_damaged: string;
  reason_code: string;
}

// ─── Constants ────────────────────────────────────────────────────────────────
const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "success" | "danger" | "outline"> = {
  draft:              "secondary",
  dispatched:         "warning",
  partially_received: "default",
  received:           "success",
  cancelled:          "outline",
};

const STATUS_LABEL: Record<string, string> = {
  draft:              "Draft",
  dispatched:         "Dispatched",
  partially_received: "Partially Received",
  received:           "Received",
  cancelled:          "Cancelled",
};

const ACTION_LABEL: Record<string, string> = {
  transfer_created:           "Transfer Created",
  transfer_updated:           "Edited",
  transfer_dispatched:        "Dispatched",
  transfer_received:          "Fully Received",
  transfer_partially_received:"Partially Received",
  transfer_cancelled:         "Cancelled",
};

const REASON_CODES = [
  { value: "shortage",  label: "Shortage" },
  { value: "damage",    label: "Damaged in Transit" },
  { value: "quality",   label: "Quality Issue" },
  { value: "expired",   label: "Expired" },
  { value: "other",     label: "Other" },
];

const MOVE_TYPE_LABEL: Record<string, string> = {
  transfer_out: "Transfer Out (Source)",
  transfer_in:  "Transfer In (Destination)",
};

function fmtDate(d: string) {
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

function fmtQty(n: number | string | null | undefined) {
  const num = Number(n ?? 0);
  return (isNaN(num) ? 0 : num).toLocaleString("en-IN", { minimumFractionDigits: 0, maximumFractionDigits: 3 });
}

// ─────────────────────────────────────────────────────────────────────────────
export default function TransferDetailPage() {
  const params = useParams();
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [transfer,           setTransfer]           = useState<TransferDetail | null>(null);
  const [isLoading,          setIsLoading]          = useState(false);
  const [apiErrors,          setApiErrors]          = useState<string[]>([]);

  // Modals
  const [dispatchOpen,       setDispatchOpen]       = useState(false);
  const [receiveOpen,        setReceiveOpen]        = useState(false);
  const [cancelOpen,         setCancelOpen]         = useState(false);

  // Dispatch state
  const [dispatchRows,       setDispatchRows]       = useState<DispatchRow[]>([]);
  const [isDispatching,      setIsDispatching]      = useState(false);
  const [dispatchErrors,     setDispatchErrors]     = useState<string[]>([]);

  // Receive state
  const [receiveRows,        setReceiveRows]        = useState<ReceiveRow[]>([]);
  const [isReceiving,        setIsReceiving]        = useState(false);
  const [receiveErrors,      setReceiveErrors]      = useState<string[]>([]);

  // Cancel state
  const [cancelReason,       setCancelReason]       = useState("");
  const [isCancelling,       setIsCancelling]       = useState(false);

  const fetchTransfer = useCallback(async () => {
    if (!token || !orgId) return;
    setIsLoading(true);
    try {
      const res = await fetch(`${API_URL}/api/v1/stock_transfers/${params.id}`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } });
      const json = await res.json();
      if (res.ok) setTransfer(json.data);
    } finally { setIsLoading(false); }
  }, [token, orgId, params.id]);

  useEffect(() => { fetchTransfer(); }, [fetchTransfer]);

  // Initialise dispatch rows when modal opens
  useEffect(() => {
    if (dispatchOpen && transfer) {
      setDispatchRows(
        transfer.lines.map((l) => ({
          line_id:       l.id,
          product_sku:   l.product_sku ?? "",
          product_name:  l.product_name ?? "",
          qty_requested: l.qty_requested,
          qty_dispatched: String(l.qty_requested),
        }))
      );
      setDispatchErrors([]);
    }
  }, [dispatchOpen, transfer]);

  // Initialise receive rows when modal opens
  useEffect(() => {
    if (receiveOpen && transfer) {
      setReceiveRows(
        transfer.lines
          .filter((l) => l.qty_in_transit > 0)
          .map((l) => ({
            line_id:       l.id,
            product_sku:   l.product_sku ?? "",
            product_name:  l.product_name ?? "",
            qty_dispatched: l.qty_dispatched,
            qty_received:  String(l.qty_in_transit),
            qty_damaged:   "0",
            reason_code:   "",
          }))
      );
      setReceiveErrors([]);
    }
  }, [receiveOpen, transfer]);

  // ── Dispatch submit ────────────────────────────────────────────────────────
  const handleDispatch = async () => {
    setDispatchErrors([]);
    setIsDispatching(true);
    try {
      const res = await fetch(`${API_URL}/api/v1/stock_transfers/${params.id}/dispatch`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId ?? "",
        },
        body: JSON.stringify({
          lines: dispatchRows.map((r) => ({
            line_id:        r.line_id,
            qty_dispatched: parseFloat(r.qty_dispatched) || 0,
          })),
        }),
      });
      const json = await res.json();
      if (res.ok) {
        setDispatchOpen(false);
        await fetchTransfer();
      } else {
        setDispatchErrors(json.errors ?? ["Dispatch failed"]);
      }
    } finally { setIsDispatching(false); }
  };

  // ── Receive submit ─────────────────────────────────────────────────────────
  const handleReceive = async () => {
    setReceiveErrors([]);
    setIsReceiving(true);
    try {
      const res = await fetch(`${API_URL}/api/v1/stock_transfers/${params.id}/receive`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId ?? "",
        },
        body: JSON.stringify({
          lines: receiveRows.map((r) => ({
            line_id:     r.line_id,
            qty_received: parseFloat(r.qty_received) || 0,
            qty_damaged:  parseFloat(r.qty_damaged) || 0,
            reason_code:  r.reason_code || undefined,
          })),
        }),
      });
      const json = await res.json();
      if (res.ok) {
        setReceiveOpen(false);
        await fetchTransfer();
      } else {
        setReceiveErrors(json.errors ?? ["Receive failed"]);
      }
    } finally { setIsReceiving(false); }
  };

  // ── Cancel submit ──────────────────────────────────────────────────────────
  const handleCancel = async () => {
    if (!cancelReason.trim()) return;
    setIsCancelling(true);
    try {
      const res = await fetch(`${API_URL}/api/v1/stock_transfers/${params.id}/cancel`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId ?? "",
        },
        body: JSON.stringify({ reason: cancelReason }),
      });
      const json = await res.json();
      if (res.ok) {
        setCancelOpen(false);
        await fetchTransfer();
      } else {
        setApiErrors(json.errors ?? ["Cancel failed"]);
      }
    } finally { setIsCancelling(false); }
  };

  if (isLoading || !transfer) {
    return (
      <AppShell>
        <div className="flex items-center gap-2 text-text-secondary mt-8">
          <Clock className="h-4 w-4 animate-spin" /> Loading transfer…
        </div>
      </AppShell>
    );
  }

  // Receive-single-line (inline) ─────────────────────────────────────────────
  const [receivingLineId, setReceivingLineId] = useState<number | null>(null);

  const handleReceiveLine = async (lineId: number, qtyReceived: number, qtyDamaged = 0) => {
    setReceivingLineId(lineId);
    try {
      const res = await fetch(`${API_URL}/api/v1/stock_transfers/${params.id}/receive`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId ?? "",
        },
        body: JSON.stringify({
          lines: [{ line_id: lineId, qty_received: qtyReceived, qty_damaged: qtyDamaged }],
        }),
      });
      if (res.ok) await fetchTransfer();
    } finally {
      setReceivingLineId(null);
    }
  };
  const canReceiveInline = transfer.status === "dispatched" || transfer.status === "partially_received";
  const lineColumns: Column<TransferLine>[] = [
    { key: "product_sku",   header: "SKU",
      render: (_: unknown, r: TransferLine) => <span className="font-mono text-sm">{r.product_sku}</span> },
    { key: "product_name",  header: "Product",
      render: (_: unknown, r: TransferLine) => <span className="text-sm">{r.product_name}</span> },
    { key: "qty_requested", header: "Requested",
      render: (_: unknown, r: TransferLine) => <span className="font-mono text-sm">{fmtQty(r.qty_requested)}</span> },
    { key: "qty_dispatched",header: "Dispatched",
      render: (_: unknown, r: TransferLine) => <span className="font-mono text-sm">{fmtQty(r.qty_dispatched)}</span> },
    { key: "qty_received",  header: "Received",
      render: (_: unknown, r: TransferLine) => <span className="font-mono text-sm text-emerald-600">{fmtQty(r.qty_received)}</span> },
    { key: "qty_damaged",   header: "Damaged",
      render: (_: unknown, r: TransferLine) => (
        <span className={cn("font-mono text-sm", r.qty_damaged > 0 && "text-red-600")}>
          {fmtQty(r.qty_damaged)}
        </span>
      ) },
    { key: "qty_in_transit",header: "In Transit",
      render: (_: unknown, r: TransferLine) => (
        <span className={cn("font-mono text-sm", r.qty_in_transit > 0 && "text-amber-600")}>
          {fmtQty(r.qty_in_transit)}
        </span>
      ) },
    { key: "fully_accounted", header: "Status",
      render: (_: unknown, r: TransferLine) =>
        r.fully_accounted
          ? <Badge variant="success">Done</Badge>
          : r.qty_dispatched > 0
            ? <Badge variant="warning">In Transit</Badge>
            : <Badge variant="secondary">Pending</Badge> },
    ...(canReceiveInline ? [{
      key: "_actions" as keyof TransferLine,
      header: "",
      render: (_: unknown, r: TransferLine) =>
        r.fully_accounted || r.qty_in_transit <= 0 ? null : (
          <Button
            size="sm"
            variant="outline"
            className="text-xs h-7 px-2"
            disabled={receivingLineId === r.id}
            onClick={(e) => {
              e.stopPropagation();
              void handleReceiveLine(r.id, r.qty_in_transit);
            }}
          >
            <PackageCheck className="h-3 w-3 mr-1" />
            {receivingLineId === r.id ? "…" : "Receive"}
          </Button>
        ),
    }] : []),
  ];


  // ── Movement columns ───────────────────────────────────────────────────────
  const moveCols: Column<StockMovement>[] = [
    { key: "movement_type", header: "Type",
      render: (_: unknown, r: StockMovement) => (
        <div className="flex items-center gap-1.5 text-sm">
          {r.direction === "in"
            ? <TrendingUp className="h-3.5 w-3.5 text-emerald-500" />
            : <TrendingDown className="h-3.5 w-3.5 text-rose-500" />}
          {MOVE_TYPE_LABEL[r.movement_type] ?? r.movement_type}
        </div>
      ) },
    { key: "product_name",  header: "Product",
      render: (_: unknown, r: StockMovement) => <span className="text-sm">{r.product_name}</span> },
    { key: "qty",           header: "Qty",
      render: (_: unknown, r: StockMovement) => (
        <span className={cn("font-mono text-sm font-medium", r.direction === "in" ? "text-emerald-600" : "text-rose-600")}>
          {r.direction === "in" ? "+" : "-"}{fmtQty(r.qty)}
        </span>
      ) },
    { key: "occurred_at",   header: "Date",
      render: (_: unknown, r: StockMovement) => (
        <span className="text-sm text-text-secondary">{fmtDate(r.occurred_at)}</span>
      ) },
  ];

  const tabItems = [
    {
      value: "summary",
      label: "Summary",
      content: (
        <div className="space-y-4">
          {/* Info cards */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { label: "Total Lines",      value: transfer.lines.length },
              { label: "Total Dispatched", value: fmtQty(transfer.lines.reduce((s, l) => s + l.qty_dispatched, 0)) },
              { label: "Total Received",   value: fmtQty(transfer.lines.reduce((s, l) => s + l.qty_received, 0)) },
              { label: "Total Damaged",    value: fmtQty(transfer.lines.reduce((s, l) => s + l.qty_damaged, 0)) },
            ].map((c) => (
              <div key={c.label} className="rounded-lg border bg-card p-4">
                <p className="text-xs text-text-secondary uppercase tracking-wide mb-1">{c.label}</p>
                <p className="text-2xl font-bold font-mono">{c.value}</p>
              </div>
            ))}
          </div>

          {/* Meta */}
          <div className="rounded-lg border p-4 text-sm space-y-2">
            <div className="flex gap-2">
              <span className="w-32 text-text-secondary">Route</span>
              <span className="flex items-center gap-1.5 font-medium">
                {transfer.source_branch?.name}
                <ArrowLeftRight className="h-3.5 w-3.5 text-text-secondary" />
                {transfer.destination_branch?.name}
              </span>
            </div>
            <div className="flex gap-2">
              <span className="w-32 text-text-secondary">Transfer Date</span>
              <span>{fmtDate(transfer.transfer_date)}</span>
            </div>
            {transfer.dispatched_at && (
              <div className="flex gap-2">
                <span className="w-32 text-text-secondary">Dispatched</span>
                <span>{fmtDate(transfer.dispatched_at)} by {transfer.dispatched_by?.name}</span>
              </div>
            )}
            {transfer.received_at && (
              <div className="flex gap-2">
                <span className="w-32 text-text-secondary">Received</span>
                <span>{fmtDate(transfer.received_at)} by {transfer.received_by?.name}</span>
              </div>
            )}
            {transfer.notes && (
              <div className="flex gap-2">
                <span className="w-32 text-text-secondary">Notes</span>
                <span className="text-foreground">{transfer.notes}</span>
              </div>
            )}
            {transfer.cancellation_reason && (
              <div className="flex gap-2 text-destructive">
                <span className="w-32 text-text-secondary">Cancel Reason</span>
                <span>{transfer.cancellation_reason}</span>
              </div>
            )}
          </div>
        </div>
      ),
    },
    {
      value: "lines",
      label: "Lines",
      content: (
        <DataTable
          columns={lineColumns}
          data={transfer.lines}
          emptyMessage="No lines on this transfer."
        />
      ),
    },
    {
      value: "ledger",
      label: "Ledger",
      content: (
        <DataTable
          columns={moveCols}
          data={transfer.stock_movements}
          emptyMessage="No ledger entries yet."
        />
      ),
    },
    {
      value: "timeline",
      label: "Timeline",
      content: (
        <div className="space-y-3">
          {transfer.timeline.length === 0 && (
            <p className="text-sm text-text-secondary">No events yet.</p>
          )}
          {transfer.timeline.map((ev) => (
            <div key={ev.id} className="flex gap-3 items-start">
              <div className="mt-1 h-2 w-2 rounded-full bg-primary shrink-0" />
              <div>
                <p className="text-sm font-medium">{ACTION_LABEL[ev.action] ?? ev.action}</p>
                <p className="text-xs text-text-secondary">
                  {ev.actor_name} · {fmtDate(ev.created_at)}
                </p>
              </div>
            </div>
          ))}
        </div>
      ),
    },
  ];

  // Status timeline stages
  const timelineStages = [
    { key: "created",    label: "Created",    date: transfer.created_at,    done: true },
    { key: "dispatched", label: "Dispatched",  date: transfer.dispatched_at, done: !!transfer.dispatched_at },
    { key: "received",   label: "Received",   date: transfer.received_at,   done: !!transfer.received_at },
  ];

  return (
    <AppShell breadcrumbs={[
        { label: "Operations", href: "/operations" },
        { label: "Transfers", href: "/inventory/transfers" },
        { label: transfer.transfer_number },
      ]}>

      <PageHeader
        title={transfer.transfer_number}
        description={
          <div className="flex items-center gap-2">
            <Badge variant={STATUS_VARIANT[transfer.status] ?? "secondary"}>
              {STATUS_LABEL[transfer.status] ?? transfer.status}
            </Badge>
            <span className="text-sm text-text-secondary">
              {transfer.source_branch?.name} → {transfer.destination_branch?.name}
            </span>
          </div>
        }
        actions={[
          ...(transfer.status === "draft" ? [
            { label: "Edit", onClick: () => router.push(`/inventory/transfers/${transfer.id}/edit`), variant: "outline" as const, icon: Pencil },
            { label: "Dispatch", onClick: () => setDispatchOpen(true), icon: Truck },
            { label: "Cancel", onClick: () => setCancelOpen(true), variant: "danger" as const, icon: XCircle },
          ] : []),
          ...(transfer.status === "dispatched" || transfer.status === "partially_received" ? [
            { label: "Receive All", onClick: () => {
                setReceiveRows(
                  transfer.lines
                    .filter((l) => l.qty_in_transit > 0)
                    .map((l) => ({ ...{
                      line_id: l.id, product_sku: l.product_sku ?? "",
                      product_name: l.product_name ?? "", qty_dispatched: l.qty_dispatched,
                      qty_received: String(l.qty_in_transit), qty_damaged: "0", reason_code: "",
                    } }))
                );
                setReceiveOpen(true);
              }, icon: PackageCheck },
          ] : []),
        ]}
      />

      {/* Visual status timeline */}
      <div className="flex items-center gap-0 mb-6">
        {timelineStages.map((stage, idx) => (
          <div key={stage.key} className="flex items-center gap-0 flex-1 last:flex-none">
            <div className="flex flex-col items-center min-w-[80px]">
              <div className={cn(
                "h-7 w-7 rounded-full flex items-center justify-center text-xs font-bold border-2 transition-colors",
                stage.done && !transfer.cancellation_reason
                  ? "bg-green-500 border-green-500 text-white"
                  : "bg-white border-border text-text-secondary"
              )}>
                {stage.done && !transfer.cancellation_reason
                  ? <CheckCircle className="h-4 w-4" />
                  : <span>{idx + 1}</span>}
              </div>
              <p className={cn("text-xs mt-1 font-medium", stage.done ? "text-text-primary" : "text-text-secondary")}>
                {stage.label}
              </p>
              {stage.date && (
                <p className="text-[10px] text-text-secondary">{fmtDate(stage.date)}</p>
              )}
            </div>
            {idx < timelineStages.length - 1 && (
              <div className={cn("flex-1 h-0.5 self-start mt-3.5",
                stage.done ? "bg-green-400" : "bg-border"
              )} />
            )}
          </div>
        ))}
      </div>

      {apiErrors.length > 0 && (
        <div className="mb-4 rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
          {apiErrors.map((e, i) => <p key={i}>{e}</p>)}
        </div>
      )}

      <Tabs items={tabItems} defaultValue="summary" />

      {/* ── Dispatch Modal ─────────────────────────────────────────────────── */}
      <Modal
        open={dispatchOpen}
        onClose={() => setDispatchOpen(false)}
        title="Dispatch Transfer"
        description="Confirm quantities to dispatch from source branch."
        size="lg"
      >
        <div className="space-y-4 mt-4">
          {dispatchErrors.length > 0 && (
            <div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive space-y-1">
              {dispatchErrors.map((e, i) => <p key={i}>{e}</p>)}
            </div>
          )}

          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-text-secondary text-xs">
                <th className="text-left pb-2 font-medium">Product</th>
                <th className="text-right pb-2 font-medium w-24">Requested</th>
                <th className="text-right pb-2 font-medium w-28">Dispatch Qty</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {dispatchRows.map((row) => (
                <tr key={row.line_id} className="py-2">
                  <td className="py-2">
                    <p className="font-medium">{row.product_name}</p>
                    <p className="text-xs text-text-secondary font-mono">{row.product_sku}</p>
                  </td>
                  <td className="text-right py-2 font-mono">{fmtQty(row.qty_requested)}</td>
                  <td className="text-right py-2">
                    <Input
                      type="number"
                      min="0.001"
                      max={row.qty_requested}
                      step="0.001"
                      className="h-8 text-sm font-mono text-right w-24 ml-auto"
                      value={row.qty_dispatched}
                      onChange={(e) =>
                        setDispatchRows((prev) =>
                          prev.map((r) => r.line_id === row.line_id
                            ? { ...r, qty_dispatched: e.target.value }
                            : r)
                        )
                      }
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          <div className="flex justify-end gap-3 pt-2">
            <Button variant="outline" onClick={() => setDispatchOpen(false)}>Cancel</Button>
            <Button onClick={handleDispatch} disabled={isDispatching}>
              {isDispatching ? "Dispatching…" : "Confirm Dispatch"}
            </Button>
          </div>
        </div>
      </Modal>

      {/* ── Receive (GRN) Modal ────────────────────────────────────────────── */}
      <Modal
        open={receiveOpen}
        onClose={() => setReceiveOpen(false)}
        title="Receive / GRN"
        description="Record received and damaged quantities at destination."
        size="xl"
      >
        <div className="space-y-4 mt-4">
          {receiveErrors.length > 0 && (
            <div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive space-y-1">
              {receiveErrors.map((e, i) => <p key={i}>{e}</p>)}
            </div>
          )}

          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-text-secondary text-xs">
                <th className="text-left pb-2 font-medium">Product</th>
                <th className="text-right pb-2 font-medium w-20">In Transit</th>
                <th className="text-right pb-2 font-medium w-24">Received</th>
                <th className="text-right pb-2 font-medium w-24">Damaged</th>
                <th className="pb-2 font-medium w-32">Reason</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {receiveRows.map((row) => (
                <tr key={row.line_id}>
                  <td className="py-2 pr-2">
                    <p className="font-medium">{row.product_name}</p>
                    <p className="text-xs text-text-secondary font-mono">{row.product_sku}</p>
                  </td>
                  <td className="text-right py-2 font-mono">{fmtQty(row.qty_dispatched)}</td>
                  <td className="text-right py-2">
                    <Input
                      type="number" min="0" step="0.001"
                      className="h-8 text-sm font-mono text-right w-20 ml-auto"
                      value={row.qty_received}
                      onChange={(e) =>
                        setReceiveRows((prev) =>
                          prev.map((r) => r.line_id === row.line_id
                            ? { ...r, qty_received: e.target.value }
                            : r)
                        )
                      }
                    />
                  </td>
                  <td className="text-right py-2 px-1">
                    <Input
                      type="number" min="0" step="0.001"
                      className="h-8 text-sm font-mono text-right w-20 ml-auto"
                      value={row.qty_damaged}
                      onChange={(e) =>
                        setReceiveRows((prev) =>
                          prev.map((r) => r.line_id === row.line_id
                            ? { ...r, qty_damaged: e.target.value }
                            : r)
                        )
                      }
                    />
                  </td>
                  <td className="py-2 pl-1">
                    <select
                      value={row.reason_code}
                      onChange={(e) =>
                        setReceiveRows((prev) =>
                          prev.map((r) => r.line_id === row.line_id
                            ? { ...r, reason_code: e.target.value }
                            : r)
                        )
                      }
                      className="h-8 w-full rounded-md border border-input bg-background px-2 text-xs"
                    >
                      <option value="">—</option>
                      {REASON_CODES.map((rc) => (
                        <option key={rc.value} value={rc.value}>{rc.label}</option>
                      ))}
                    </select>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          {receiveRows.length === 0 && (
            <p className="text-sm text-text-secondary text-center py-4">
              All quantities have already been accounted for.
            </p>
          )}

          <div className="flex justify-end gap-3 pt-2">
            <Button variant="outline" onClick={() => setReceiveOpen(false)}>Cancel</Button>
            <Button onClick={handleReceive} disabled={isReceiving || receiveRows.length === 0}>
              {isReceiving ? "Saving…" : "Confirm Receipt"}
            </Button>
          </div>
        </div>
      </Modal>

      {/* ── Cancel Modal ───────────────────────────────────────────────────── */}
      <Modal
        open={cancelOpen}
        onClose={() => setCancelOpen(false)}
        title="Cancel Transfer"
        description="This action cannot be undone. No inventory movements will be created."
        size="sm"
      >
        <div className="space-y-4 mt-4">
          <div className="space-y-1.5">
            <label className="text-sm font-medium">Reason *</label>
            <Input
              placeholder="Enter cancellation reason…"
              value={cancelReason}
              onChange={(e) => setCancelReason(e.target.value)}
            />
          </div>
          <div className="flex justify-end gap-3">
            <Button variant="outline" onClick={() => setCancelOpen(false)}>Back</Button>
            <Button
              onClick={handleCancel}
              disabled={isCancelling || !cancelReason.trim()}
              className="bg-destructive text-white hover:bg-destructive/90"
            >
              {isCancelling ? "Cancelling…" : "Cancel Transfer"}
            </Button>
          </div>
        </div>
      </Modal>
    </AppShell>
  );
}
