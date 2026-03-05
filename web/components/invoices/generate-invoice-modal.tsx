"use client";

/**
 * GenerateInvoiceModal
 *
 * Shown on the Order Detail page when delivered quantities exist and
 * the order is not fully invoiced yet.
 *
 * Usage:
 *   <GenerateInvoiceModal
 *     open={open}
 *     onClose={() => setOpen(false)}
 *     orderId={orderId}
 *     orderLines={order.lines}    // lines with delivered_qty and invoiced_qty
 *     token={token}
 *     orgId={orgId}
 *     onSuccess={(invoice) => router.push(`/sales-invoices/${invoice.id}`)}
 *   />
 */

import { useState, useMemo } from "react";
import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { FileText } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

export interface OrderLinePreview {
  id:            number;
  product_id:    number;
  product_name:  string;
  product_sku:   string;
  unit_price:    number;
  discount_pct:  number;
  gst_rate:      number;
  hsn_code:      string | null;
  qty:           number;          // ordered
  delivered_qty: number;
  invoiced_qty:  number;
}

interface GenerateInvoiceModalProps {
  open:        boolean;
  onClose:     () => void;
  orderId:     number;
  orderLines:  OrderLinePreview[];
  token:       string | null;
  orgId:       string | null;
  onSuccess:   (invoice: { id: number; invoice_number: string }) => void;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const fmt = (n: number) =>
  `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

function computeLineTotal(line: OrderLinePreview, qty: number) {
  const base     = qty * line.unit_price;
  const taxable  = base * (1 - line.discount_pct / 100);
  const tax      = taxable * (line.gst_rate / 100);
  return { taxable, tax, total: taxable + tax };
}

// ── Component ─────────────────────────────────────────────────────────────────

export function GenerateInvoiceModal({
  open,
  onClose,
  orderId,
  orderLines,
  token,
  orgId,
  onSuccess,
}: GenerateInvoiceModalProps) {
  // Only show lines with invoiceable quantity
  const invoiceableLines = useMemo(
    () => orderLines.filter((l) => l.delivered_qty - l.invoiced_qty > 0),
    [orderLines]
  );

  // qty overrides keyed by order line id (user can adjust down from max)
  const [qtyOverrides, setQtyOverrides] = useState<Record<number, string>>({});
  const [notes, setNotes]               = useState("");
  const [saving, setSaving]             = useState(false);
  const [error, setError]               = useState<string | null>(null);

  const resolveQty = (l: OrderLinePreview) => {
    const raw = qtyOverrides[l.id];
    if (raw !== undefined) {
      const parsed = parseFloat(raw);
      return isNaN(parsed) ? 0 : Math.min(Math.max(0, parsed), l.delivered_qty - l.invoiced_qty);
    }
    return l.delivered_qty - l.invoiced_qty;
  };

  const totals = useMemo(() => {
    let subtotal = 0;
    let taxTotal = 0;
    invoiceableLines.forEach((l) => {
      const qty = resolveQty(l);
      const { taxable, tax } = computeLineTotal(l, qty);
      subtotal += taxable;
      taxTotal += tax;
    });
    return { subtotal, taxTotal, grand: subtotal + taxTotal };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [invoiceableLines, qtyOverrides]);

  const handleGenerate = async () => {
    if (!token || !orgId) return;
    setSaving(true);
    setError(null);

    const delivered_lines = invoiceableLines
      .map((l) => ({
        sales_order_line_id: l.id,
        qty:                 resolveQty(l),
      }))
      .filter((dl) => dl.qty > 0);

    if (delivered_lines.length === 0) {
      setError("No lines have invoiceable quantities.");
      setSaving(false);
      return;
    }

    try {
      const res = await fetch(
        `/api/v1/sales_invoices/generate_from_order/${orderId}`,
        {
          method:  "POST",
          headers: {
            Authorization:       `Bearer ${token}`,
            "X-Organization-Id": orgId,
            "Content-Type":      "application/json",
          },
          body: JSON.stringify({ delivered_lines, notes: notes || undefined }),
        }
      );
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Failed to generate invoice");
      onSuccess({ id: body.data.id, invoice_number: body.data.invoice_number });
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setSaving(false);
    }
  };

  if (!open) return null;

  return (
    <Modal open={open} onClose={onClose} title="Generate Invoice from Order">
      <div className="space-y-4 min-w-[560px]">
        {invoiceableLines.length === 0 ? (
          <div className="text-sm text-muted-foreground py-6 text-center">
            All delivered quantities have already been invoiced.
          </div>
        ) : (
          <>
            <p className="text-sm text-muted-foreground">
              Adjust quantities if you want to create a partial invoice. Maximum is the
              uninvoiced delivered quantity per line.
            </p>

            {/* Lines preview table */}
            <div className="border rounded-lg overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-muted/40">
                  <tr>
                    {["Product", "Rate", "Max Qty", "Invoice Qty", "Taxable", "GST"].map((h) => (
                      <th key={h} className="px-3 py-2 text-left text-xs font-semibold text-muted-foreground">
                        {h}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {invoiceableLines.map((l) => {
                    const maxQty = l.delivered_qty - l.invoiced_qty;
                    const qty    = resolveQty(l);
                    const { taxable, tax } = computeLineTotal(l, qty);
                    return (
                      <tr key={l.id}>
                        <td className="px-3 py-2">
                          <div className="font-medium">{l.product_name}</div>
                          <div className="text-xs text-muted-foreground">{l.product_sku}</div>
                        </td>
                        <td className="px-3 py-2 text-right">{fmt(l.unit_price)}</td>
                        <td className="px-3 py-2 text-center text-muted-foreground">{maxQty}</td>
                        <td className="px-3 py-2">
                          <Input
                            type="number"
                            min={0}
                            max={maxQty}
                            step={1}
                            value={qtyOverrides[l.id] ?? String(maxQty)}
                            onChange={(e) =>
                              setQtyOverrides((prev) => ({ ...prev, [l.id]: e.target.value }))
                            }
                            className="w-20 text-right h-7 text-sm"
                          />
                        </td>
                        <td className="px-3 py-2 text-right">{fmt(taxable)}</td>
                        <td className="px-3 py-2 text-right">{fmt(tax)}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            {/* Totals preview */}
            <div className="bg-muted/30 rounded-lg p-3 text-sm space-y-1">
              <div className="flex justify-between text-muted-foreground">
                <span>Subtotal (Taxable)</span>
                <span>{fmt(totals.subtotal)}</span>
              </div>
              <div className="flex justify-between text-muted-foreground">
                <span>Total Tax</span>
                <span>{fmt(totals.taxTotal)}</span>
              </div>
              <div className="flex justify-between font-bold text-base border-t pt-1">
                <span>Grand Total</span>
                <span className="text-primary">{fmt(totals.grand)}</span>
              </div>
            </div>

            {/* Notes */}
            <div className="space-y-1.5">
              <label className="text-sm font-medium">Notes (optional)</label>
              <Input
                placeholder="Add notes to the invoice…"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
              />
            </div>

            {error && (
              <p className="text-sm text-destructive">{error}</p>
            )}

            <div className="flex justify-end gap-2 pt-1">
              <Button variant="outline" size="sm" onClick={onClose}>
                Cancel
              </Button>
              <Button
                size="sm"
                disabled={saving || totals.grand === 0}
                onClick={handleGenerate}
              >
                <FileText className="h-4 w-4 mr-1" />
                {saving ? "Generating…" : "Generate Invoice"}
              </Button>
            </div>
          </>
        )}
      </div>
    </Modal>
  );
}
