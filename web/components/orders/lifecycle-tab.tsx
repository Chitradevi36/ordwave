"use client";

import { useState, useEffect, useRef } from "react";
import { Package, Truck, FileText, DollarSign, ExternalLink, CheckCircle2, Circle, Clock } from "lucide-react";
import Link from "next/link";
import { API_URL } from "@/lib/api/client";

// â”€â”€ Types â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

type Stage = "order" | "delivery" | "invoice" | "payment";

interface LifecycleStep {
  stage:  Stage;
  event:  string;
  label:  string;
  at:     string | null;
  actor:  string | null;
  reason: string | null;
  meta:   Record<string, unknown>;
}

interface LifecycleData {
  steps:        LifecycleStep[];
  order_number: string;
}

// â”€â”€ Stage config â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const STAGES: Stage[] = ["order", "delivery", "invoice", "payment"];

const STAGE_CFG: Record<Stage, {
  dot:    string;
  ring:   string;
  card:   string;
  badge:  string;
  text:   string;
  icon:   React.ComponentType<{ className?: string }>;
  label:  string;
  terminalEvents: string[]; // events that mean the stage is "done"
}> = {
  order: {
    dot:    "bg-blue-500",
    ring:   "ring-blue-200",
    card:   "border-blue-100 bg-blue-50/60",
    badge:  "text-blue-700 bg-blue-100",
    text:   "text-blue-700",
    icon:   Package,
    label:  "Order",
    terminalEvents: ["order_approved", "order_delivered", "order_partial_delivery"],
  },
  delivery: {
    dot:    "bg-amber-500",
    ring:   "ring-amber-200",
    card:   "border-amber-100 bg-amber-50/60",
    badge:  "text-amber-700 bg-amber-100",
    text:   "text-amber-700",
    icon:   Truck,
    label:  "Delivery",
    terminalEvents: ["stop_delivered", "stop_partial_delivery"],
  },
  invoice: {
    dot:    "bg-purple-500",
    ring:   "ring-purple-200",
    card:   "border-purple-100 bg-purple-50/60",
    badge:  "text-purple-700 bg-purple-100",
    text:   "text-purple-700",
    icon:   FileText,
    label:  "Invoice",
    terminalEvents: ["invoice_issued"],
  },
  payment: {
    dot:    "bg-emerald-500",
    ring:   "ring-emerald-200",
    card:   "border-emerald-100 bg-emerald-50/60",
    badge:  "text-emerald-700 bg-emerald-100",
    text:   "text-emerald-700",
    icon:   DollarSign,
    label:  "Payment",
    terminalEvents: ["payment_collected"],
  },
};

// â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function fmtDateTime(d: string | null | undefined) {
  if (!d) return "â€”";
  return new Date(d).toLocaleString("en-IN", {
    day: "2-digit", month: "short", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

function relativeTime(d: string | null | undefined): string {
  if (!d) return "";
  const diff = Date.now() - new Date(d).getTime();
  const mins = Math.floor(diff / 60_000);
  if (mins < 1)   return "just now";
  if (mins < 60)  return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24)   return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  if (days < 30)  return `${days}d ago`;
  return "";
}

function fmtINR(n: number | string | undefined | null) {
  if (n == null) return "â€”";
  return `â‚¹${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function dateBucket(d: string | null | undefined): string {
  if (!d) return "Unknown date";
  const date = new Date(d);
  const today = new Date();
  const diff  = Math.floor((today.setHours(0,0,0,0) - new Date(date).setHours(0,0,0,0)) / 86_400_000);
  if (diff === 0) return "Today";
  if (diff === 1) return "Yesterday";
  return date.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

// â”€â”€ Metadata as compact chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function Chip({ label, value, linked, href }: {
  label:   string;
  value:   string;
  linked?: boolean;
  href?:   string;
}) {
  const inner = (
    <span className="inline-flex items-center gap-1">
      <span className="text-[10px] text-text-secondary font-normal">{label}</span>
      <span className="font-medium text-text-primary">{value}</span>
      {linked && <ExternalLink className="h-2.5 w-2.5 text-text-secondary" />}
    </span>
  );
  const cls = "inline-flex items-center rounded border border-border bg-white px-1.5 py-0.5 text-xs transition-colors hover:border-primary/40";
  if (linked && href) {
    return <Link href={href} className={cls}>{inner}</Link>;
  }
  return <span className={cls}>{inner}</span>;
}

function StepChips({ step }: { step: LifecycleStep }) {
  const m = step.meta;

  if (step.event === "trip_dispatched") {
    return (
      <div className="flex flex-wrap gap-1.5 mt-2">
        {m.trip_number != null && <Chip label="Trip"    value={m.trip_number as string} />}
        {m.vehicle     != null && <Chip label="Vehicle" value={m.vehicle as string} />}
        {m.driver      != null && <Chip label="Driver"  value={m.driver as string} />}
      </div>
    );
  }

  if (step.stage === "delivery" && step.event.startsWith("stop_")) {
    return (
      <div className="flex flex-wrap gap-1.5 mt-2">
        {m.exception_code != null && <Chip label="Exception"    value={m.exception_code as string} />}
        {m.delivery_notes != null && <Chip label="Notes"        value={m.delivery_notes as string} />}
      </div>
    );
  }

  if (step.stage === "invoice") {
    return (
      <div className="flex flex-wrap gap-1.5 mt-2">
        {m.invoice_number != null && (
          <Chip
            label="Invoice" value={m.invoice_number as string}
            linked href={`/sales-invoices/${m.invoice_id as number}`}
          />
        )}
        {m.grand_total      != null && <Chip label="Total"  value={fmtINR(m.grand_total as number)} />}
        {m.generation_source != null && <Chip label="Source" value={(m.generation_source as string).replace(/_/g, " ")} />}
      </div>
    );
  }

  if (step.stage === "payment") {
    return (
      <div className="flex flex-wrap gap-1.5 mt-2">
        {m.payment_number != null && (
          <Chip
            label="Payment" value={m.payment_number as string}
            linked href={`/collections/${m.payment_id as number}`}
          />
        )}
        {m.amount          != null && <Chip label="Amount"  value={fmtINR(m.amount as number)} />}
        {m.mode            != null && <Chip label="Mode"    value={(m.mode as string).replace(/_/g, " ")} />}
        {m.invoice_number  != null && <Chip label="Against" value={m.invoice_number as string} />}
      </div>
    );
  }

  return null;
}

// â”€â”€ Pipeline progress header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function PipelineHeader({ steps, activeFilter, onFilter }: {
  steps:        LifecycleStep[];
  activeFilter: Stage | "all";
  onFilter:     (s: Stage | "all") => void;
}) {
  // Work out which stages are complete
  const doneStages = new Set<Stage>();
  const activeStages = new Set<Stage>(steps.map(s => s.stage));

  for (const stage of STAGES) {
    const cfg      = STAGE_CFG[stage];
    const stageSteps = steps.filter(s => s.stage === stage);
    const done     = stageSteps.some(s => cfg.terminalEvents.includes(s.event));
    if (done) doneStages.add(stage);
  }

  return (
    <div className="mb-5">
      {/* Pipeline strip */}
      <div className="flex items-center gap-0 mb-3">
        {STAGES.map((stage, i) => {
          const cfg    = STAGE_CFG[stage];
          const done   = doneStages.has(stage);
          const active = activeStages.has(stage) && !done;
          const Icon   = cfg.icon;

          return (
            <div key={stage} className="flex items-center flex-1 min-w-0">
              {/* Node */}
              <button
                onClick={() => onFilter(activeFilter === stage ? "all" : stage)}
                className={[
                  "flex flex-col items-center gap-1 group flex-1 min-w-0 rounded-lg py-2 px-1 transition-colors",
                  activeFilter === stage ? "bg-muted/60" : "hover:bg-muted/40",
                ].join(" ")}
                title={`Filter: ${cfg.label}`}
              >
                <div className={[
                  "h-8 w-8 rounded-full flex items-center justify-center ring-2 transition-all",
                  done   ? `${cfg.dot} ${cfg.ring} text-white`
                         : active ? `bg-white ${cfg.ring} ${cfg.text} border border-current`
                         : "bg-muted/40 ring-border text-text-secondary",
                ].join(" ")}>
                  {done
                    ? <CheckCircle2 className="h-4 w-4" />
                    : active
                    ? <Icon className="h-4 w-4" />
                    : <Circle className="h-4 w-4 opacity-40" />}
                </div>
                <span className={[
                  "text-[10px] font-medium truncate w-full text-center",
                  done ? cfg.text : active ? cfg.text : "text-text-secondary",
                ].join(" ")}>
                  {cfg.label}
                  {/* {done   && " âœ“"} */}
                  {/* {active && " â€¢"} */}
                </span>
              </button>

              {/* Connector bar */}
              {i < STAGES.length - 1 && (
                <div className={[
                  "h-0.5 w-6 shrink-0 rounded transition-colors",
                  doneStages.has(STAGES[i + 1]) || activeStages.has(STAGES[i + 1])
                    ? "bg-border"
                    : "bg-border/40",
                ].join(" ")} />
              )}
            </div>
          );
        })}
      </div>

      {/* "All" pill + count badge */}
      <div className="flex items-center gap-2 flex-wrap">
        <button
          onClick={() => onFilter("all")}
          className={[
            "text-xs px-2.5 py-1 rounded-full border font-medium transition-colors",
            activeFilter === "all"
              ? "bg-primary text-white border-primary"
              : "border-border text-text-secondary hover:border-primary/50 hover:text-primary",
          ].join(" ")}
        >
          All ({steps.length})
        </button>
        {STAGES.filter(s => activeStages.has(s)).map(stage => {
          const count = steps.filter(s => s.stage === stage).length;
          const cfg   = STAGE_CFG[stage];
          return (
            <button
              key={stage}
              onClick={() => onFilter(activeFilter === stage ? "all" : stage)}
              className={[
                "text-xs px-2.5 py-1 rounded-full border font-medium transition-colors",
                activeFilter === stage
                  ? `${cfg.dot} text-white border-transparent`
                  : `border-border ${cfg.text} hover:border-current/50`,
              ].join(" ")}
            >
              {cfg.label} ({count})
            </button>
          );
        })}
      </div>
    </div>
  );
}

// â”€â”€ Skeleton â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function Skeleton() {
  return (
    <div className="space-y-3 animate-pulse">
      {Array.from({ length: 4 }).map((_, i) => (
        <div key={i} className="flex gap-3 items-start">
          <div className="mt-1 h-5 w-5 rounded-full bg-muted/60 shrink-0" />
          <div className="flex-1 rounded-lg border border-border bg-muted/20 p-3 space-y-2">
            <div className="h-3 w-1/3 bg-muted/60 rounded" />
            <div className="h-2 w-1/2 bg-muted/40 rounded" />
          </div>
        </div>
      ))}
    </div>
  );
}

// â”€â”€ Main component â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export function LifecycleTab({
  orderId,
  token,
  orgId,
}: {
  orderId: number;
  token:   string;
  orgId:   string;
}) {
  const [data,         setData]         = useState<LifecycleData | null>(null);
  const [loading,      setLoading]      = useState(true);
  const [error,        setError]        = useState<string | null>(null);
  const [activeFilter, setActiveFilter] = useState<Stage | "all">("all");
  const fetched = useRef(false);

  useEffect(() => {
    if (fetched.current) return;
    fetched.current = true;
    async function load() {
      try {
        const res  = await fetch(`${API_URL}/api/v1/sales_orders/${orderId}/lifecycle`, {
          headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        });
        const json = await res.json();
        if (res.ok) setData(json.data);
        else        setError(json.errors?.[0] ?? "Failed to load lifecycle");
      } catch {
        setError("Network error loading lifecycle");
      } finally {
        setLoading(false);
      }
    }
    void load();
  }, [orderId, token, orgId]);

  if (loading) return <Skeleton />;
  if (error)   return <p className="text-sm text-danger">{error}</p>;

  const allSteps = data?.steps ?? [];
  if (!allSteps.length) return <p className="text-sm text-text-secondary">No lifecycle events recorded yet.</p>;

  const filtered = activeFilter === "all"
    ? allSteps
    : allSteps.filter(s => s.stage === activeFilter);

  // Group by date bucket
  const groups: { bucket: string; steps: LifecycleStep[] }[] = [];
  for (const step of filtered) {
    const bucket = dateBucket(step.at);
    const last   = groups[groups.length - 1];
    if (last?.bucket === bucket) last.steps.push(step);
    else groups.push({ bucket, steps: [step] });
  }

  return (
    <div>
      <PipelineHeader
        steps={allSteps}
        activeFilter={activeFilter}
        onFilter={setActiveFilter}
      />

      {groups.map((group, gi) => (
        <div key={gi} className="mb-6">
          {/* Day label */}
          <div className="flex items-center gap-2 mb-3">
            <span className="text-[11px] font-semibold text-text-secondary uppercase tracking-wider">
              {group.bucket}
            </span>
            <div className="flex-1 h-px bg-border" />
          </div>

          <div className="relative pl-7">
            {/* Vertical connector */}
            <div className="absolute left-[9px] top-2 bottom-2 w-px bg-border" />

            <ol className="space-y-2.5">
              {group.steps.map((step, i) => {
                const cfg  = STAGE_CFG[step.stage] ?? STAGE_CFG.order;
                const Icon = cfg.icon;
                const rel  = relativeTime(step.at);

                return (
                  <li key={i} className="relative group">
                    {/* Coloured dot */}
                    <div
                      className={`absolute -left-[26px] top-2.5 h-[18px] w-[18px] rounded-full flex items-center
                        justify-center ${cfg.dot} shadow-sm ring-2 ring-white`}
                      aria-hidden="true"
                    >
                      <Icon className="h-2.5 w-2.5 text-white" />
                    </div>

                    <div className={`rounded-lg border p-3 text-sm transition-shadow group-hover:shadow-sm ${cfg.card}`}>
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0 flex-1">
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className={`inline-block text-[10px] font-semibold uppercase tracking-wider
                              px-1.5 py-0.5 rounded ${cfg.badge}`}>
                              {cfg.label}
                            </span>
                            <span className="font-medium text-text-primary">{step.label}</span>
                          </div>

                          {step.actor && (
                            <p className="text-xs text-text-secondary mt-0.5">by {step.actor}</p>
                          )}
                          {step.reason && (
                            <p className="text-xs text-text-secondary italic mt-0.5">"{step.reason}"</p>
                          )}

                          <StepChips step={step} />
                        </div>

                        <div className="shrink-0 text-right">
                          <time
                            dateTime={step.at ?? ""}
                            className="block text-[11px] text-text-secondary tabular-nums"
                            title={fmtDateTime(step.at)}
                          >
                            {fmtDateTime(step.at)}
                          </time>
                          {rel && (
                            <span className="text-[10px] text-text-secondary/60">{rel}</span>
                          )}
                        </div>
                      </div>
                    </div>
                  </li>
                );
              })}
            </ol>
          </div>
        </div>
      ))}
    </div>
  );
}

