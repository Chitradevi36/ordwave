"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

function fmtDate(d: string | null | undefined) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

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
    <div className="flex items-start justify-between gap-3 py-2">
      <span className={`text-sm ${highlight ? "font-medium text-text-primary" : "text-text-secondary"}`}>
        {label}
      </span>
      <span className={`text-sm text-right ${highlight ? "font-semibold text-text-primary" : ""}`}>
        {value}
      </span>
    </div>
  );
}

export interface OperationalSnapshotProps {
  orderedAt: string;
  expectedDelivery: string | null;
  dispatchTrip?: string | null;
  sourceChannel?: string;
  salesRep?: string;
}

export function OperationalSnapshot({
  orderedAt,
  expectedDelivery,
  dispatchTrip,
  sourceChannel,
  salesRep,
}: OperationalSnapshotProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm">Operational Snapshot</CardTitle>
      </CardHeader>
      <CardContent className="space-y-0">
        <Row label="Ordered At" value={fmtDate(orderedAt)} />
        <Row label="Expected Delivery" value={expectedDelivery ? fmtDate(expectedDelivery) : "Not scheduled"} highlight />
        {dispatchTrip && <Row label="Dispatch Trip" value={dispatchTrip} />}
        {sourceChannel && <Row label="Source" value={sourceChannel} />}
        {salesRep && <Row label="Sales Rep" value={salesRep} />}
      </CardContent>
    </Card>
  );
}

export interface CommercialContextProps {
  retailer: string;
  billingParty?: string;
  shippingAddress?: string;
  route?: string;
  pricingPolicy?: string;
  creditResult?: string;
}

export function CommercialContext({
  retailer,
  billingParty,
  shippingAddress,
  route,
  pricingPolicy,
  creditResult,
}: CommercialContextProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm">Commercial Context</CardTitle>
      </CardHeader>
      <CardContent className="space-y-0">
        <Row label="Retailer" value={retailer} highlight />
        {billingParty && <Row label="Billing Party" value={billingParty} />}
        {shippingAddress && <Row label="Shipping Address" value={shippingAddress} />}
        {route && <Row label="Route / Beat" value={route} />}
        {pricingPolicy && <Row label="Pricing Policy" value={pricingPolicy} />}
        {creditResult && <Row label="Credit Decision" value={creditResult} highlight />}
      </CardContent>
    </Card>
  );
}

export interface AmountBreakdownProps {
  subtotal: number;
  discount: number;
  taxableValue?: number;
  gstAmount?: number;
  roundOff?: number;
  grandTotal: number;
  invoiceAmount?: number;
  paidAmount?: number;
  outstandingAmount?: number;
}

export function AmountBreakdown({
  subtotal,
  discount,
  taxableValue,
  gstAmount,
  roundOff,
  grandTotal,
  invoiceAmount,
  paidAmount,
  outstandingAmount,
}: AmountBreakdownProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm">Amount Breakdown</CardTitle>
      </CardHeader>
      <CardContent className="space-y-0">
        {/* Order amounts */}
        <div className="pb-3 mb-3 border-b border-border">
          <Row label="Subtotal" value={fmtINR(subtotal)} />
          {discount > 0 && <Row label="Discount" value={`−${fmtINR(discount)}`} />}
          {taxableValue !== undefined && <Row label="Taxable Value" value={fmtINR(taxableValue)} />}
          {gstAmount !== undefined && <Row label="GST" value={fmtINR(gstAmount)} />}
          {roundOff !== undefined && roundOff !== 0 && <Row label="Round Off" value={fmtINR(roundOff)} />}
          <Row label="Grand Total" value={fmtINR(grandTotal)} highlight />
        </div>

        {/* Finance tracking */}
        {invoiceAmount !== undefined && (
          <div>
            <Row label="Invoice Amount" value={fmtINR(invoiceAmount)} />
            {paidAmount !== undefined && (
              <Row label="Paid Amount" value={fmtINR(paidAmount)} highlight />
            )}
            {outstandingAmount !== undefined && outstandingAmount > 0 && (
              <Row label="Outstanding" value={fmtINR(outstandingAmount)} highlight />
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
