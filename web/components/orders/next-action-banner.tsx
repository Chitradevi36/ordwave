"use client";

import { AlertCircle, CheckCircle2, Clock } from "lucide-react";
import { Button } from "@/components/ui/button";

export interface NextActionBannerProps {
  status: string;
  creditDecision: string | null;
  invoicedAt?: string | null;
  paidAt?: string | null;
  creditReasons?: string[] | null;
  deliveredAt?: string | null;
  onAction?: (action: string) => void;
}

export function NextActionBanner({
  status,
  creditDecision,
  invoicedAt,
  paidAt,
  creditReasons,
  deliveredAt,
  onAction,
}: NextActionBannerProps) {
  // Determine next action based on order state
  let action: {
    type: "warning" | "info" | "success";
    icon: React.ReactNode;
    title: string;
    description: string;
    buttonLabel?: string;
    buttonAction?: string;
  } | null = null;

  if (status === "draft") {
    action = {
      type: "info",
      icon: <Clock className="h-5 w-5" />,
      title: "Draft Order Ready",
      description: "Review the order details and submit for approval.",
      buttonLabel: "Submit Order",
      buttonAction: "submit",
    };
  } else if (creditDecision === "blocked") {
    action = {
      type: "warning",
      icon: <AlertCircle className="h-5 w-5" />,
      title: "Credit Blocked",
      description: creditReasons?.[0] || "Order exceeds credit limit. Manual approval or credit increase required.",
      buttonLabel: "Review Credit",
      buttonAction: "credit_review",
    };
  } else if (creditDecision === "hold") {
    action = {
      type: "warning",
      icon: <AlertCircle className="h-5 w-5" />,
      title: "Awaiting Approval",
      description: "Order is on credit hold. A manager must review and approve.",
      buttonLabel: "View Approvals",
      buttonAction: "approvals",
    };
  } else if (status === "submitted") {
    action = {
      type: "info",
      icon: <Clock className="h-5 w-5" />,
      title: "Pending Review",
      description: "Waiting for order approval by your manager.",
      buttonLabel: "Notify Manager",
      buttonAction: "notify",
    };
  } else if (status === "approved" && !invoicedAt && deliveredAt) {
    action = {
      type: "success",
      icon: <CheckCircle2 className="h-5 w-5" />,
      title: "Ready to Invoice",
      description: "Order delivered but invoice not yet generated.",
      buttonLabel: "Generate Invoice",
      buttonAction: "invoice",
    };
  } else if (invoicedAt && !paidAt) {
    action = {
      type: "info",
      icon: <Clock className="h-5 w-5" />,
      title: "Payment Pending",
      description: "Invoice is due. Record payment to close the order.",
      buttonLabel: "Record Payment",
      buttonAction: "payment",
    };
  }

  if (!action) return null;

  const bgColor =
    action.type === "warning"
      ? "border-warning bg-warning/5"
      : action.type === "success"
        ? "border-success bg-success/5"
        : "border-primary bg-primary/5";

  const textColor =
    action.type === "warning"
      ? "text-warning"
      : action.type === "success"
        ? "text-success"
        : "text-primary";

  return (
    <div className={`rounded-lg border ${bgColor} p-3 sm:p-4 mb-6 flex flex-col sm:flex-row items-start gap-2 sm:gap-3 sm:items-center`}>
      <div className={`shrink-0 mt-0.5 ${textColor}`}>{action.icon}</div>

      <div className="flex-1 min-w-0 flex-col flex">
        <p className="font-semibold text-sm sm:text-base text-text-primary">{action.title}</p>
        <p className="text-xs sm:text-sm text-text-secondary mt-0.5">{action.description}</p>
      </div>

      {action.buttonLabel && action.buttonAction && (
        <Button
          size="sm"
          onClick={() => onAction?.(action.buttonAction!)}
          className="shrink-0 text-xs sm:text-sm whitespace-nowrap"
        >
          {action.buttonLabel}
        </Button>
      )}
    </div>
  );
}
