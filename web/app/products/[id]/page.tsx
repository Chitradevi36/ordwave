"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs } from "@/components/ui/tabs";
import {
  Package, Edit, Archive, Tag, List, BarChart2,
  ShoppingCart, Building2, CheckCircle, AlertTriangle, XCircle,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────
interface StockByBranch {
  branch_id: number; branch_name: string;
  on_hand: number; reserved: number; available: number;
  threshold: number | null;
}
interface RecentOrderLine {
  order_id: number; order_number: string; customer_name: string | null;
  qty: number; unit_price: number; status: string; ordered_at: string;
}
interface PriceListEntry {
  price_list_id: number;   price_list_name: string; list_type: string;
  unit_price: number;      min_qty: number;          discount_pct: number;
  valid_from: string | null; valid_to: string | null;
}
interface ProductDetail {
  id: number; sku: string; name: string; description: string | null;
  gst_rate: number; status: string; min_order_qty: number;
  barcode: string | null; weight_kg: number | null;
  image_url: string | null; purchase_price?: number;
  hsn:      { id: number | null; code: string | null; description: string | null; gst_rate: number | null } | null;
  category: { id: number | null; name: string | null } | null;
  uom:      { id: number | null; name: string | null; symbol: string | null } | null;
  stock_by_branch:    StockByBranch[];
  recent_orders:      RecentOrderLine[];
  price_list_entries: PriceListEntry[];
}

const STATUS_VARIANT: Record<string, "success" | "danger" | "warning" | "outline"> = {
  active: "success", discontinued: "danger", inactive: "warning",
};
const LIST_TYPE_LABEL: Record<string, string> = {
  standard: "Standard", promo: "Promo", retailer_specific: "Retailer", tier_specific: "Tier",
};
const LIST_TYPE_VARIANT: Record<string, "default" | "warning" | "secondary" | "outline"> = {
  standard: "default", promo: "warning", retailer_specific: "secondary", tier_specific: "outline",
};
const ORDER_STATUS_VARIANT: Record<string, "default" | "warning" | "outline" | "danger"> = {
  approved: "default", on_hold: "warning", submitted: "outline", cancelled: "danger",
};

// ─── Stock Tab ────────────────────────────────────────────────────────────────
function StockTab({ rows }: { rows: StockByBranch[] }) {
  if (!rows.length) return (
    <div className="rounded-lg border border-dashed border-border p-8 text-center">
      <Building2 className="h-8 w-8 mx-auto text-text-secondary mb-2" />
      <p className="text-sm text-text-secondary">No stock records found across branches.</p>
    </div>
  );
  return (
    <div className="rounded-lg border border-border overflow-auto">
      <table className="w-full text-sm">
        <thead className="bg-background-subtle">
          <tr>
            <th className="px-4 py-2.5 text-left font-semibold text-text-secondary">Branch</th>
            <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">On Hand</th>
            <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">Reserved</th>
            <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">Available</th>
            <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">Threshold</th>
            <th className="px-4 py-2.5 text-left font-semibold text-text-secondary">Status</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border bg-white">
          {rows.map((r) => {
            const isLow      = r.threshold != null && r.available <= r.threshold;
            const isZero     = r.available === 0;
            const StatusIcon = isZero ? XCircle : isLow ? AlertTriangle : CheckCircle;
            const statusClass = isZero ? "text-danger" : isLow ? "text-warning" : "text-success";
            return (
              <tr key={r.branch_id} className="hover:bg-background-subtle">
                <td className="px-4 py-2.5 font-medium text-text-primary">{r.branch_name}</td>
                <td className="px-4 py-2.5 text-right tabular-nums">{r.on_hand}</td>
                <td className="px-4 py-2.5 text-right tabular-nums text-text-secondary">{r.reserved}</td>
                <td className={`px-4 py-2.5 text-right tabular-nums font-semibold ${isZero ? "text-danger" : isLow ? "text-warning" : "text-text-primary"}`}>{r.available}</td>
                <td className="px-4 py-2.5 text-right tabular-nums text-text-secondary">{r.threshold ?? "—"}</td>
                <td className={`px-4 py-2.5 ${statusClass}`}>
                  <span className="flex items-center gap-1.5 text-xs">
                    <StatusIcon className="h-3.5 w-3.5" />
                    {isZero ? "Out of Stock" : isLow ? "Low Stock" : "In Stock"}
                  </span>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

// ─── Recent Orders Tab ─────────────────────────────────────────────────────────
function RecentOrdersTab({ rows }: { rows: RecentOrderLine[] }) {
  if (!rows.length) return (
    <div className="rounded-lg border border-dashed border-border p-8 text-center">
      <ShoppingCart className="h-8 w-8 mx-auto text-text-secondary mb-2" />
      <p className="text-sm text-text-secondary">No recent orders for this product.</p>
    </div>
  );
  const fmt = (n: number) => `₹${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;
  const fmtDate = (d: string) => new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
  return (
    <div className="rounded-lg border border-border overflow-auto">
      <table className="w-full text-sm">
        <thead className="bg-background-subtle">
          <tr>
            <th className="px-4 py-2.5 text-left font-semibold text-text-secondary">Order</th>
            <th className="px-4 py-2.5 text-left font-semibold text-text-secondary">Customer</th>
            <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">Qty</th>
            <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">Unit Price</th>
            <th className="px-4 py-2.5 text-left font-semibold text-text-secondary">Status</th>
            <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">Date</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border bg-white">
          {rows.map((r) => (
            <tr key={`${r.order_id}-${r.order_number}`} className="hover:bg-background-subtle">
              <td className="px-4 py-2.5 font-mono text-xs font-medium text-accent">
                <a href={`/orders/${r.order_id}`} className="hover:underline">{r.order_number}</a>
              </td>
              <td className="px-4 py-2.5 text-text-primary">{r.customer_name ?? "—"}</td>
              <td className="px-4 py-2.5 text-right tabular-nums">{r.qty}</td>
              <td className="px-4 py-2.5 text-right tabular-nums">{fmt(r.unit_price)}</td>
              <td className="px-4 py-2.5">
                <Badge variant={ORDER_STATUS_VARIANT[r.status] ?? "outline"}>
                  {r.status.replace("_", " ")}
                </Badge>
              </td>
              <td className="px-4 py-2.5 text-right text-text-secondary text-xs">{fmtDate(r.ordered_at)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// ─── Price Lists Tab ──────────────────────────────────────────────────────────
function PriceListsTab({ entries }: { entries: PriceListEntry[] }) {
  if (!entries.length) return (
    <div className="rounded-lg border border-dashed border-border p-8 text-center">
      <List className="h-8 w-8 mx-auto text-text-secondary mb-2" />
      <p className="text-sm text-text-secondary">Not assigned to any active price list.</p>
    </div>
  );
  const fmt = (n: number) => `₹${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;
  const fmtDate = (d: string | null) => d ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—";
  return (
    <div className="rounded-lg border border-border overflow-auto">
      <table className="w-full text-sm">
        <thead className="bg-background-subtle">
          <tr>
            <th className="px-4 py-2.5 text-left font-semibold text-text-secondary">Price List</th>
            <th className="px-4 py-2.5 text-left font-semibold text-text-secondary">Type</th>
            <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">Unit Price</th>
            <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">Min Qty</th>
            <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">Disc.%</th>
            <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">Valid To</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border bg-white">
          {entries.map((e) => (
            <tr key={e.price_list_id} className="hover:bg-background-subtle">
              <td className="px-4 py-2.5 font-medium text-accent">
                <a href={`/products/price-lists/${e.price_list_id}`} className="hover:underline">{e.price_list_name}</a>
              </td>
              <td className="px-4 py-2.5">
                <Badge variant={LIST_TYPE_VARIANT[e.list_type] ?? "outline"}>{LIST_TYPE_LABEL[e.list_type] ?? e.list_type}</Badge>
              </td>
              <td className="px-4 py-2.5 text-right tabular-nums font-semibold">{fmt(e.unit_price)}</td>
              <td className="px-4 py-2.5 text-right tabular-nums text-text-secondary">{e.min_qty}</td>
              <td className="px-4 py-2.5 text-right tabular-nums text-text-secondary">{Number(e.discount_pct) > 0 ? `${Number(e.discount_pct).toFixed(1)}%` : "—"}</td>
              <td className="px-4 py-2.5 text-right text-text-secondary text-xs">{fmtDate(e.valid_to)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────
function OverviewTab({ product }: { product: ProductDetail }) {
  const rows: { label: string; value: React.ReactNode }[] = [
    { label: "SKU",         value: <span className="font-mono">{product.sku}</span> },
    { label: "Category",    value: product.category?.name ?? "—" },
    { label: "UOM",         value: product.uom ? `${product.uom.name} (${product.uom.symbol})` : "—" },
    { label: "GST Rate",    value: `${product.gst_rate}%` },
    { label: "Min Order Qty", value: product.min_order_qty },
    { label: "HSN Code",    value: product.hsn?.code ?? "—" },
    { label: "HSN Desc",    value: product.hsn?.description ?? "—" },
    { label: "Barcode",     value: product.barcode ?? "—" },
    { label: "Weight",      value: product.weight_kg ? `${product.weight_kg} kg` : "—" },
    ...(product.purchase_price != null ? [{ label: "Purchase Price", value: `₹${Number(product.purchase_price).toLocaleString("en-IN")}` }] : []),
  ];
  return (
    <Card>
      <CardHeader><CardTitle className="text-sm">Product Details</CardTitle></CardHeader>
      <CardContent className="space-y-2 text-sm divide-y divide-border">
        {rows.map((r) => (
          <div key={r.label} className="flex justify-between gap-4 py-1.5 first:pt-0">
            <span className="text-text-secondary shrink-0">{r.label}</span>
            <span className="text-text-primary text-right">{r.value}</span>
          </div>
        ))}
        {product.description && (
          <div className="pt-2">
            <p className="text-text-secondary text-xs mb-1">Description</p>
            <p className="text-sm text-text-primary whitespace-pre-wrap">{product.description}</p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function ProductDetailPage() {
  const params    = useParams();
  const router    = useRouter();
  const productId = params.id as string;
  const { token, orgId } = useOrgBranch();

  const [product, setProduct] = useState<ProductDetail | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!token || !orgId) return;
    setLoading(true);
    fetch(`${API_URL}/api/v1/products/${productId}`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => { if (j.data) setProduct(j.data); })
      .finally(() => setLoading(false));
  }, [productId, token, orgId]);

  if (loading) return (
    <AppShell title="Products">
      <div className="flex items-center justify-center h-48">
        <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
      </div>
    </AppShell>
  );

  if (!product) return (
    <AppShell title="Products">
      <p className="text-text-secondary">Product not found.</p>
    </AppShell>
  );

  // Aggregate totals
  const totalAvailable = product.stock_by_branch.reduce((s, r) => s + r.available, 0);
  const totalOnHand    = product.stock_by_branch.reduce((s, r) => s + r.on_hand, 0);

  const tabItems = [
    { value: "overview",   label: "Overview",   content: <OverviewTab product={product} /> },
    { value: "stock",      label: `Stock (${totalAvailable})`, content: <StockTab rows={product.stock_by_branch} /> },
    { value: "orders",     label: `Recent Orders (${product.recent_orders.length})`, content: <RecentOrdersTab rows={product.recent_orders} /> },
    { value: "pricelists", label: `Price Lists (${product.price_list_entries.length})`, content: <PriceListsTab entries={product.price_list_entries} /> },
  ];

  return (
    <AppShell title="Products" breadcrumbs={[
      { label: "Products", href: "/products" },
      { label: product.name },
    ]}>
      <PageHeader
        title={product.name}
        description={`${product.sku}${product.category?.name ? ` · ${product.category.name}` : ""}`}
        actions={[
          { label: "Edit",         onClick: () => router.push(`/products/${productId}/edit`),   icon: Edit, variant: "outline" },
          { label: "Price Lists",  onClick: () => router.push("/products/price-lists"),          icon: List, variant: "ghost" },
        ]}
      >
        {/* Status + badges */}
        <div className="mt-1.5 flex flex-wrap items-center gap-2">
          <Badge variant={STATUS_VARIANT[product.status] ?? "outline"}>
            {product.status.charAt(0).toUpperCase() + product.status.slice(1)}
          </Badge>
          {product.uom?.symbol && <Badge variant="outline">{product.uom.symbol}</Badge>}
          <span className="text-xs text-text-secondary">
            {totalOnHand} on hand · {totalAvailable} available across {product.stock_by_branch.length} branch{product.stock_by_branch.length !== 1 ? "es" : ""}
          </span>
        </div>
      </PageHeader>

      <Tabs items={tabItems} />
    </AppShell>
  );
}
