"use client";

import { ShieldCheck, ShieldAlert, ShieldX } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

export interface OrderHeroProps {
  orderNumber: string;
  customerName: string;
  branch: string;
  status: string;
  creditDecision: string | null;
  totalAmount: number;
  actions: Array<{
    label: string;
    onClick: () => void;
    variant?: "default" | "outline" | "danger";
  }>;
}

const CREDIT_ICON: Record<string, React.ReactNode> = {
  ok: <ShieldCheck className="h-4 w-4 text-success" />,
  hold: <ShieldAlert className="h-4 w-4 text-warning" />,
  blocked: <ShieldX className="h-4 w-4 text-danger" />,
};

const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "success" | "danger" | "outline"> = {
  draft: "secondary",
  submitted: "default",
  on_hold: "warning",
  approved: "success",
  rejected: "danger",
  cancelled: "outline",
};

function fmtINR(n: number) {
  return `₹${n.toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;
}

export function OrderHero({
  orderNumber,
  customerName,
  branch,
  status,
  creditDecision,
  totalAmount,
  actions,
}: OrderHeroProps) {
  return (
    <div className="rounded-lg border border-border bg-white p-4 sm:p-6 mb-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 mb-4">
        <div>
          <h1 className="text-2xl sm:text-3xl font-bold text-text-primary mb-1">{orderNumber}</h1>
          <p className="text-xs sm:text-sm text-text-secondary">
            {customerName} • {branch}
          </p>
        </div>

        <div className="flex flex-col items-start sm:items-end gap-1">
          <div className="text-right">
            <p className="text-xl sm:text-2xl font-bold text-text-primary">{fmtINR(totalAmount)}</p>
            <p className="text-xs text-text-secondary">Order Total</p>
          </div>
        </div>
      </div>

      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 sm:gap-4">
        <div className="flex items-center gap-2 sm:gap-3 flex-wrap">
          <Badge variant={STATUS_VARIANT[status] ?? "secondary"}>
            {status.replace("_", " ")}
          </Badge>

          {creditDecision && (
            <div className="flex items-center gap-2 px-2 sm:px-3 py-1 rounded-full border border-border bg-background-subtle">
              {CREDIT_ICON[creditDecision]}
              <span className="text-xs font-medium text-text-secondary">
                Credit:{" "}
                {creditDecision === "ok"
                  ? "OK"
                  : creditDecision === "hold"
                    ? "Hold"
                    : "Blocked"}
              </span>
            </div>
          )}
        </div>

        <div className="flex gap-2 flex-wrap justify-start sm:justify-end">
          {actions.map((action, idx) => (
            <Button
              key={idx}
              size="sm"
              variant={action.variant || "default"}
              onClick={action.onClick}
              className="text-xs sm:text-sm"
            >
              {action.label}
            </Button>
          ))}
        </div>
      </div>
    </div>
  );
}
