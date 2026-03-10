"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ShieldCheck, ShieldAlert, ShieldX } from "lucide-react";

function fmtINR(n: number | string) {
  return `₹${Number(n).toLocaleString("en-IN", { maximumFractionDigits: 0 })}`;
}

function Row({
  label,
  value,
  highlight,
}: {
  label: string;
  value: React.ReactNode;
  highlight?: boolean;
}) {
  return (
    <div className="flex items-start justify-between gap-2 sm:gap-3 py-2">
      <span
        className={`text-xs sm:text-sm ${highlight ? "font-medium text-text-primary" : "text-text-secondary"}`}
      >
        {label}
      </span>
      <span className={`text-xs sm:text-sm text-right ${highlight ? "font-semibold" : ""}`}>
        {value}
      </span>
    </div>
  );
}

const CREDIT_ICON: Record<string, React.ReactNode> = {
  ok: <ShieldCheck className="h-6 w-6 text-success" />,
  hold: <ShieldAlert className="h-6 w-6 text-warning" />,
  blocked: <ShieldX className="h-6 w-6 text-danger" />,
};

const CREDIT_LABEL: Record<string, string> = {
  ok: "Credit OK",
  hold: "On Hold",
  blocked: "Blocked",
};

const CREDIT_VARIANT: Record<string, "success" | "warning" | "danger"> =  {
  ok: "success",
  hold: "warning",
  blocked: "danger",
};

export interface CreditFinancePanelProps {
  creditDecision?: string | null;
  creditReasons?: string[] | null;
  creditLimit?: number;
  outstandingAtOrder?: number;
  creditSnapshot?: Record<string, number | string>;
  invoiceAmount?: number;
  paidAmount?: number;
  outstandingAmount?: number;
  onRecordPayment?: () => void;
  onGenerateInvoice?: () => void;
  onCreateCreditNote?: () => void;
  onViewInvoice?: () => void;
}

export function CreditFinancePanel({
  creditDecision,
  creditReasons,
  creditLimit,
  outstandingAtOrder,
  creditSnapshot,
  invoiceAmount,
  paidAmount,
  outstandingAmount,
  onRecordPayment,
  onGenerateInvoice,
  onCreateCreditNote,
  onViewInvoice,
}: CreditFinancePanelProps) {
  return (
    <div className="space-y-4">
      {/* Credit Decision */}
      {creditDecision && (
        <Card
          className={
            creditDecision === "ok"
              ? "border-success bg-success/5"
              : creditDecision === "hold"
                ? "border-warning bg-warning/5"
                : "border-danger bg-danger/5"
          }
        >
          <CardContent className="flex items-start gap-4 py-4">
            {CREDIT_ICON[creditDecision]}
            <div className="flex-1">
              <p className="font-semibold text-text-primary">
                {CREDIT_LABEL[creditDecision]}
              </p>
              {creditReasons && creditReasons.length > 0 && (
                <ul className="mt-2 list-disc list-inside text-sm text-text-secondary space-y-1">
                  {creditReasons.map((reason, idx) => (
                    <li key={idx}>{reason}</li>
                  ))}
                </ul>
              )}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Credit Metrics */}
      {creditLimit !== undefined || outstandingAtOrder !== undefined ? (
        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Credit Status</CardTitle>
          </CardHeader>
          <CardContent className="space-y-0">
            {creditLimit !== undefined && (
              <Row label="Credit Limit" value={fmtINR(creditLimit)} />
            )}
            {outstandingAtOrder !== undefined && (
              <Row label="Outstanding at Order Time" value={fmtINR(outstandingAtOrder)} />
            )}
            {creditSnapshot &&
              Object.entries(creditSnapshot).map(([key, val]) => (
                <Row
                  key={key}
                  label={key.replace(/_/g, " ")}
                  value={
                    typeof val === "number"
                      ? fmtINR(val)
                      : String(val)
                  }
                />
              ))}
          </CardContent>
        </Card>
      ) : null}

      {/* Invoice & Payment */}
      {invoiceAmount !== undefined || paidAmount !== undefined ? (
        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Payment Status</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            {invoiceAmount !== undefined && (
              <Row label="Invoice Amount" value={fmtINR(invoiceAmount)} />
            )}
            {paidAmount !== undefined && (
              <Row label="Paid Amount" value={fmtINR(paidAmount)} highlight />
            )}
            {outstandingAmount !== undefined && outstandingAmount > 0 && (
              <Row label="Outstanding" value={fmtINR(outstandingAmount)} highlight />
            )}

            <div className="pt-3 border-t border-border flex flex-wrap gap-2">
              {onGenerateInvoice && (
                <Button size="sm" variant="outline" onClick={onGenerateInvoice}>
                  Generate Invoice
                </Button>
              )}
              {onViewInvoice && invoiceAmount !== undefined && (
                <Button size="sm" variant="outline" onClick={onViewInvoice}>
                  View Invoice
                </Button>
              )}
              {onRecordPayment && paidAmount !== undefined && outstandingAmount! > 0 && (
                <Button size="sm" onClick={onRecordPayment}>
                  Record Payment
                </Button>
              )}
              {onCreateCreditNote && (
                <Button size="sm" variant="outline" onClick={onCreateCreditNote}>
                  Create Credit Note
                </Button>
              )}
            </div>
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}
