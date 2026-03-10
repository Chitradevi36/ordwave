"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Eye } from "lucide-react";

export interface OrderLineItem {
  id: number;
  product_id: number;
  product_name: string;
  product_sku: string;
  hsn_code: string | null;
  qty: number;
  unit_price: number;
  discount_pct: number;
  gst_rate: number;
  line_total: number;
}

function fmtINR(n: number) {
  return `₹${n.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export interface OrderLinesTableProps {
  lines: OrderLineItem[];
  onViewProduct?: (productId: number) => void;
  onEditLine?: (lineId: number) => void;
  editable?: boolean;
}

export function OrderLinesTable({
  lines,
  onViewProduct,
  onEditLine,
  editable = false,
}: OrderLinesTableProps) {
  const subtotal = lines.reduce((sum, l) => sum + l.line_total, 0);
  const totalGst = lines.reduce(
    (sum, l) => sum + (l.line_total * l.gst_rate) / 100,
    0
  );
  const totalDiscount = lines.reduce(
    (sum, l) => sum + ((l.qty * l.unit_price * l.discount_pct) / 100),
    0
  );

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-sm">Order Lines ({lines.length})</CardTitle>
      </CardHeader>
      <CardContent>
        {lines.length === 0 ? (
          <p className="text-sm text-text-secondary italic">No items in this order.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border">
                  <th className="text-left px-3 py-2 font-medium text-text-secondary">
                    Product
                  </th>
                  <th className="text-left px-3 py-2 font-medium text-text-secondary text-xs">
                    HSN
                  </th>
                  <th className="text-right px-3 py-2 font-medium text-text-secondary">
                    Qty
                  </th>
                  <th className="text-right px-3 py-2 font-medium text-text-secondary">
                    Unit Price
                  </th>
                  <th className="text-right px-3 py-2 font-medium text-text-secondary">
                    Discount
                  </th>
                  <th className="text-right px-3 py-2 font-medium text-text-secondary">
                    GST
                  </th>
                  <th className="text-right px-3 py-2 font-medium text-text-secondary">
                    Line Total
                  </th>
                  <th className="text-center px-3 py-2 font-medium text-text-secondary">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody>
                {lines.map((line) => (
                  <tr key={line.id} className="border-b border-border hover:bg-background-subtle">
                    <td className="px-3 py-2">
                      <div>
                        <p className="font-medium text-text-primary">{line.product_name}</p>
                        <p className="text-xs text-text-secondary">{line.product_sku}</p>
                      </div>
                    </td>
                    <td className="px-3 py-2 text-xs text-text-secondary">
                      {line.hsn_code ?? "—"}
                    </td>
                    <td className="px-3 py-2 text-right font-medium">{line.qty}</td>
                    <td className="px-3 py-2 text-right text-text-secondary">
                      {fmtINR(line.unit_price)}
                    </td>
                    <td className="px-3 py-2 text-right text-text-secondary">
                      {line.discount_pct > 0 ? `${line.discount_pct}%` : "—"}
                    </td>
                    <td className="px-3 py-2 text-right text-text-secondary">
                      {line.gst_rate}%
                    </td>
                    <td className="px-3 py-2 text-right font-semibold text-text-primary">
                      {fmtINR(line.line_total)}
                    </td>
                    <td className="px-3 py-2 text-center">
                      <div className="flex justify-center gap-1">
                        {onViewProduct && (
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => onViewProduct(line.product_id)}
                            title="View product"
                          >
                            <Eye className="h-3 w-3" />
                          </Button>
                        )}
                        {editable && onEditLine && (
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => onEditLine(line.id)}
                            title="Edit line"
                          >
                            Edit
                          </Button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr className="border-t border-border font-semibold">
                  <td colSpan={6} className="px-3 py-3 text-right text-text-primary">
                    Subtotal
                  </td>
                  <td className="px-3 py-3 text-right text-text-primary">
                    {fmtINR(subtotal)}
                  </td>
                  <td />
                </tr>
                {totalDiscount > 0 && (
                  <tr className="text-danger">
                    <td colSpan={6} className="px-3 py-2 text-right text-text-secondary">
                      Discount
                    </td>
                    <td className="px-3 py-2 text-right font-medium">
                      −{fmtINR(totalDiscount)}
                    </td>
                    <td />
                  </tr>
                )}
                <tr>
                  <td colSpan={6} className="px-3 py-2 text-right text-text-secondary">
                    GST
                  </td>
                  <td className="px-3 py-2 text-right font-medium">
                    {fmtINR(totalGst)}
                  </td>
                  <td />
                </tr>
              </tfoot>
            </table>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
