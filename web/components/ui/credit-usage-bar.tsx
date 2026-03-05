"use client";

import { useState } from "react";

export interface CreditUsageSummary {
  order_exposure:    number;
  hold_exposure:     number;
  credit_used_total: number;
}

export interface CreditAccountBasic {
  credit_limit:     number;
  current_balance:  number;
  available_credit: number;
  overdue_amount:   number;
  overdue_days:     number;
}

function fmtINR(n: number | undefined | null) {
  if (n === undefined || n === null) return "—";
  return `₹${n.toLocaleString("en-IN", {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  })}`;
}

interface Props {
  ca:           CreditAccountBasic | null;
  usage?:       CreditUsageSummary | null;
  /** Show compact single-line variant (for table cells). Default: false */
  compact?:     boolean;
  /** Width class applied to the bar container. Default: "min-w-[130px]" */
  widthClass?:  string;
}

/**
 * CreditUsageBar
 *
 * Displays credit utilisation as a coloured progress bar.
 * When `usage` (order-exposure summary) is provided the bar reflects the
 * real "credit used" metric (invoice outstanding + order exposure).
 * Hovering shows a tooltip with the full breakdown.
 */
export function CreditUsageBar({ ca, usage, compact = false, widthClass = "min-w-[130px]" }: Props) {
  const [tipVisible, setTipVisible] = useState(false);

  if (!ca || Number(ca.credit_limit) === 0) {
    return <span className="text-sm text-text-secondary">—</span>;
  }

  // Use enriched total when available, otherwise fall back to current_balance.
  // Parse with Number() because Rails serialises BigDecimal as strings in JSON.
  const creditUsed  = usage ? usage.credit_used_total : Number(ca.current_balance);
  const creditLimit = Number(ca.credit_limit);
  const utilPct     = Math.min(100, Math.round((creditUsed / creditLimit) * 100));
  const barColor    = utilPct >= 90 ? "bg-danger" : utilPct >= 70 ? "bg-warning" : "bg-success";

  const invoiceOutstanding = Number(ca.current_balance);
  const orderExposure      = usage?.order_exposure   ?? 0;
  const holdExposure       = usage?.hold_exposure    ?? 0;
  const availableCredit    = Math.max(creditLimit - creditUsed, 0);

  return (
    <div
      className={`relative ${widthClass}`}
      onMouseEnter={() => setTipVisible(true)}
      onMouseLeave={() => setTipVisible(false)}
    >
      {/* Bar + label */}
      <div className="flex items-center justify-between gap-1 text-xs text-text-secondary leading-tight mb-1">
        <span>{fmtINR(creditUsed)}</span>
        <span className="text-text-secondary/50">/</span>
        <span>{fmtINR(creditLimit)}</span>
      </div>
      <div className="h-1.5 w-full rounded-full bg-border overflow-hidden">
        <div className={`h-full rounded-full ${barColor}`} style={{ width: `${utilPct}%` }} />
      </div>
      {!compact && (
        <div className="flex justify-between text-[10px] text-text-secondary mt-0.5">
          <span>{utilPct}% used</span>
          {availableCredit > 0 && (
            <span className="text-success">{fmtINR(availableCredit)} free</span>
          )}
        </div>
      )}

      {/* Tooltip */}
      {tipVisible && (
        <div className="absolute z-30 bottom-full left-0 mb-2 w-56 rounded-lg border border-border bg-white shadow-lg p-3 text-xs space-y-1.5 pointer-events-none">
          <p className="font-semibold text-text-primary mb-1">Credit Breakdown</p>
          <Row label="Credit Limit"     value={fmtINR(creditLimit)} />
          <Row label="Invoice Outstdg." value={fmtINR(invoiceOutstanding)} />
          {orderExposure > 0 && (
            <Row label="Order Exposure"  value={fmtINR(orderExposure)} className="text-warning" />
          )}
          {holdExposure > 0 && (
            <Row label="On-Hold Orders" value={fmtINR(holdExposure)} className="text-text-secondary" />
          )}
          <div className="border-t border-border pt-1.5">
            <Row label="Credit Used"   value={fmtINR(creditUsed)}     className="font-medium" />
            <Row label="Available"     value={fmtINR(availableCredit)} className="text-success font-medium" />
          </div>
          {ca.overdue_days > 0 && (
            <p className="text-danger mt-1">{ca.overdue_days}d overdue · {fmtINR(ca.overdue_amount)}</p>
          )}
        </div>
      )}
    </div>
  );
}

function Row({ label, value, className }: { label: string; value: string; className?: string }) {
  return (
    <div className="flex justify-between gap-2">
      <span className="text-text-secondary">{label}</span>
      <span className={`font-medium tabular-nums ${className ?? "text-text-primary"}`}>{value}</span>
    </div>
  );
}
