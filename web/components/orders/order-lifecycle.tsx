"use client";

import { CheckCircle2, XCircle, Clock } from "lucide-react";

export interface OrderLifecycleProps {
  status: string;
  createdAt: string;
  submittedAt: string | null;
  approvedAt: string | null;
  dispatchedAt?: string | null;
  deliveredAt?: string | null;
  invoicedAt?: string | null;
  paidAt?: string | null;
  cancelledAt?: string | null | undefined;
  rejectedAt?: string | null | undefined;
  cancellationReason?: string | null | undefined;
}

function fmtDate(d: string | null | undefined) {
  if (!d) return undefined;
  return new Date(d).toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

export function OrderLifecycle({
  status,
  createdAt,
  submittedAt,
  approvedAt,
  dispatchedAt,
  deliveredAt,
  invoicedAt,
  paidAt,
  cancelledAt,
  rejectedAt,
  cancellationReason,
}: OrderLifecycleProps) {
  const stages = [
    { key: "draft", label: "Draft", ts: createdAt },
    { key: "submitted", label: "Submitted", ts: submittedAt },
    { key: "approved", label: "Approved", ts: approvedAt },
    { key: "allocated", label: "Allocated", ts: null }, // placeholder, API may not have this yet
    { key: "dispatched", label: "Dispatched", ts: dispatchedAt ?? null },
    { key: "delivered", label: "Delivered", ts: deliveredAt ?? null },
    { key: "invoiced", label: "Invoiced", ts: invoicedAt ?? null },
    { key: "paid", label: "Paid", ts: paidAt ?? null },
  ];

  const stageIndex: Record<string, number> = {
    draft: 0,
    submitted: 1,
    on_hold: 1,
    approved: 2,
    allocated: 3,
    dispatched: 4,
    delivered: 5,
    invoiced: 6,
    paid: 7,
    rejected: 2, // stuck at approved
    cancelled: 1, // stuck at submitted
  };

  const currentIdx = stageIndex[status] ?? 0;
  const isFailed = ["rejected", "cancelled"].includes(status);

  return (
    <div className="rounded-lg border border-border bg-white p-4 sm:p-6 mb-6">
      <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3 sm:mb-4">
        Order Lifecycle
      </p>

      <div className="flex items-start gap-0.5 sm:gap-1 overflow-x-auto pb-2">
        {stages.map((stage, idx) => {
          const done = idx < currentIdx;
          const active = idx === currentIdx;
          const failed = active && isFailed;

          return (
            <div key={stage.key} className="flex flex-col items-center shrink-0 min-w-max">
              {/* Stage circle */}
              <div
                className={`h-6 sm:h-8 w-6 sm:w-8 rounded-full border-2 flex items-center justify-center transition-colors ${
                  failed
                    ? "border-danger bg-danger/10 text-danger"
                    : done
                      ? "border-success bg-success text-white"
                      : active
                        ? "border-primary bg-primary/10 text-primary"
                        : "border-border bg-background-subtle text-text-secondary"
                }`}
                title={stage.ts ? fmtDate(stage.ts) : ""}
              >
                {done ? (
                  <CheckCircle2 className="h-3 sm:h-4 w-3 sm:w-4" />
                ) : failed ? (
                  <XCircle className="h-3 sm:h-4 w-3 sm:w-4" />
                ) : active ? (
                  <Clock className="h-3 sm:h-4 w-3 sm:w-4" />
                ) : (
                  <span className="text-[8px] sm:text-[10px] font-bold">{idx + 1}</span>
                )}
              </div>

              {/* Label */}
              <p className="text-[8px] sm:text-[10px] font-medium text-text-primary mt-1 text-center w-10 sm:w-12 leading-tight">
                {stage.label}
              </p>

              {/* Timestamp */}
              {stage.ts && (
                <p className="text-[7px] sm:text-[8px] text-text-secondary text-center mt-0.5">
                  {fmtDate(stage.ts)}
                </p>
              )}
            </div>
          );
        })}
      </div>

      {isFailed && (
        <div className="mt-3 p-2 sm:p-3 rounded-md border border-danger/30 bg-danger/5">
          <p className="text-xs text-danger font-medium">
            Order {status.replace("_", " ")}
            {cancellationReason ? ` — ${cancellationReason}` : ""}
          </p>
        </div>
      )}
    </div>
  );
}
