"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ArrowLeftRight, TrendingUp, TrendingDown, Minus } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import Link from "next/link";

// ─── Types ────────────────────────────────────────────────────────────────────
interface PriceList {
  id: number; name: string; list_type: string;
  valid_from: string | null; valid_to: string | null;
  items_count: number;
}

interface PriceItem {
  product_id: number;
  product_sku: string;
  product_name: string;
  unit_price: number;
  min_qty: number;
  discount_pct: number;
}

const TYPE_LABEL: Record<string, string> = {
  standard: "Standard", promo: "Promo",
  retailer_specific: "Retailer Specific", tier_specific: "Tier Specific",
};
const TYPE_VARIANT: Record<string, "default" | "secondary" | "warning" | "outline"> = {
  standard: "default", promo: "warning",
  retailer_specific: "secondary", tier_specific: "outline",
};

const fmt = (n: number) => `₹${n.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

// ─── Sub-nav ──────────────────────────────────────────────────────────────────
function ProductsSubNav() {
  const items = [
    { key: "products",    label: "Products",         href: "/products" },
    { key: "categories",  label: "Categories",       href: "/products/categories" },
    { key: "uom",         label: "Units of Measure", href: "/products/uom" },
    { key: "price-lists", label: "Price Lists",      href: "/products/price-lists" },
  ];
  return (
    <div className="flex gap-1 border-b border-border mb-6">
      {items.map((item) => (
        <Link
          key={item.key}
          href={item.href}
          className="px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors border-transparent text-text-secondary hover:text-text-primary"
        >
          {item.label}
        </Link>
      ))}
    </div>
  );
}

// ─── Price List Selector ──────────────────────────────────────────────────────
function PriceListSelector({
  label, selected, lists, onChange,
}: {
  label:    string;
  selected: PriceList | null;
  lists:    PriceList[];
  onChange: (pl: PriceList | null) => void;
}) {
  return (
    <div className="flex-1 min-w-0">
      <p className="text-xs font-medium text-text-secondary mb-1.5">{label}</p>
      <select
        className="w-full h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
        value={selected?.id ?? ""}
        onChange={(e) => {
          const id = Number(e.target.value);
          onChange(lists.find((l) => l.id === id) ?? null);
        }}
      >
        <option value="">— Select price list —</option>
        {lists.map((l) => (
          <option key={l.id} value={l.id}>{l.name} ({TYPE_LABEL[l.list_type] ?? l.list_type})</option>
        ))}
      </select>
      {selected && (
        <div className="mt-1 flex items-center gap-2 text-xs text-text-secondary">
          <Badge variant={TYPE_VARIANT[selected.list_type] ?? "outline"}>{TYPE_LABEL[selected.list_type]}</Badge>
          <span>{selected.items_count} products</span>
          {selected.valid_from && <span>Valid: {new Date(selected.valid_from).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" })}</span>}
        </div>
      )}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function PriceListComparePage() {
  const { token, orgId } = useOrgBranch();

  const [priceLists, setPriceLists]   = useState<PriceList[]>([]);
  const [listA,      setListA]        = useState<PriceList | null>(null);
  const [listB,      setListB]        = useState<PriceList | null>(null);
  const [itemsA,     setItemsA]       = useState<PriceItem[]>([]);
  const [itemsB,     setItemsB]       = useState<PriceItem[]>([]);
  const [loadingA,   setLoadingA]     = useState(false);
  const [loadingB,   setLoadingB]     = useState(false);
  const [search,     setSearch]       = useState("");

  // Fetch all price lists once
  useEffect(() => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/price_lists?per_page=100`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => setPriceLists(j.data ?? []));
  }, [token, orgId]);

  const fetchItems = useCallback(async (plId: number, setter: (items: PriceItem[]) => void, setLoading: (v: boolean) => void) => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/price_lists/${plId}?per_page=500`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      const items: PriceItem[] = (json.data?.items ?? []).map((i: {
        product_id: number; product?: { sku: string; name: string };
        unit_price: string | number; min_qty?: number; discount_pct?: string | number;
      }) => ({
        product_id:   i.product_id,
        product_sku:  i.product?.sku  ?? "—",
        product_name: i.product?.name ?? "—",
        unit_price:   Number(i.unit_price),
        min_qty:      i.min_qty ?? 1,
        discount_pct: Number(i.discount_pct ?? 0),
      }));
      setter(items);
    } finally {
      setLoading(false);
    }
  }, [token, orgId]);

  useEffect(() => {
    if (listA) fetchItems(listA.id, setItemsA, setLoadingA);
    else       setItemsA([]);
  }, [listA, fetchItems]);

  useEffect(() => {
    if (listB) fetchItems(listB.id, setItemsB, setLoadingB);
    else       setItemsB([]);
  }, [listB, fetchItems]);

  // Build comparison table
  const mapB = Object.fromEntries(itemsB.map((i) => [i.product_id, i]));
  const allProductIds = [...new Set([...itemsA.map((i) => i.product_id), ...itemsB.map((i) => i.product_id)])];

  const rows = allProductIds.map((pid) => {
    const a = itemsA.find((i) => i.product_id === pid) ?? null;
    const b = mapB[pid] ?? null;
    const diff = a && b ? b.unit_price - a.unit_price : null;
    const diffPct = a && b && a.unit_price > 0 ? ((b.unit_price - a.unit_price) / a.unit_price) * 100 : null;
    return { pid, a, b, diff, diffPct, name: a?.product_name ?? b?.product_name ?? "—", sku: a?.product_sku ?? b?.product_sku ?? "—" };
  });

  const filtered = search
    ? rows.filter((r) => r.name.toLowerCase().includes(search.toLowerCase()) || r.sku.toLowerCase().includes(search.toLowerCase()))
    : rows;

  const onlyInA = rows.filter((r) => r.a && !r.b).length;
  const onlyInB = rows.filter((r) => !r.a && r.b).length;
  const inBoth  = rows.filter((r) => r.a && r.b).length;
  const higherInB = rows.filter((r) => r.diff != null && r.diff > 0).length;
  const lowerInB  = rows.filter((r) => r.diff != null && r.diff < 0).length;

  return (
    <AppShell title="Compare Price Lists">
      <PageHeader title="Compare Price Lists" description="Diff two price lists side by side" />

      <ProductsSubNav />

      {/* Selector row */}
      <div className="mb-6 flex flex-wrap gap-4 items-end">
        <PriceListSelector label="Price List A" selected={listA} lists={priceLists} onChange={(pl) => { setListA(pl); if (pl?.id === listB?.id) setListB(null); }} />
        <div className="flex items-end pb-1">
          <ArrowLeftRight className="h-5 w-5 text-text-secondary" />
        </div>
        <PriceListSelector label="Price List B" selected={listB} lists={priceLists} onChange={(pl) => { setListB(pl); if (pl?.id === listA?.id) setListA(null); }} />
      </div>

      {(!listA || !listB) && (
        <div className="rounded-lg border border-dashed border-border p-12 text-center">
          <ArrowLeftRight className="h-10 w-10 mx-auto text-text-secondary mb-3" />
          <p className="text-sm font-medium text-text-primary">Select two price lists to compare</p>
          <p className="text-xs text-text-secondary mt-1">You can compare standard, promo, or any two active price lists.</p>
        </div>
      )}

      {listA && listB && (loadingA || loadingB) && (
        <div className="flex justify-center py-12">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      )}

      {listA && listB && !loadingA && !loadingB && (
        <>
          {/* Stats row */}
          <div className="mb-4 flex flex-wrap gap-3">
            {[
              { label: "Products in A only", value: String(onlyInA), color: "text-text-secondary" },
              { label: "Products in B only", value: String(onlyInB), color: "text-text-secondary" },
              { label: "In both lists",      value: String(inBoth),  color: "text-text-primary font-semibold" },
              { label: "Higher price in B",  value: String(higherInB), color: "text-danger" },
              { label: "Lower price in B",   value: String(lowerInB),  color: "text-success" },
            ].map((s) => (
              <div key={s.label} className="rounded-lg border border-border bg-background-subtle px-3 py-2">
                <p className={`text-sm ${s.color}`}>{s.value}</p>
                <p className="text-[10px] text-text-secondary">{s.label}</p>
              </div>
            ))}
          </div>

          {/* Search */}
          <div className="mb-3">
            <input
              type="text"
              placeholder="Search product…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="h-9 w-full max-w-sm rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
            />
          </div>

          {/* Table */}
          <div className="rounded-lg border border-border overflow-auto">
            <table className="w-full text-sm">
              <thead className="bg-background-subtle">
                <tr>
                  <th className="px-4 py-2.5 text-left font-semibold text-text-secondary">Product</th>
                  <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">{listA.name}</th>
                  <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">{listB.name}</th>
                  <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">Diff</th>
                  <th className="px-4 py-2.5 text-right font-semibold text-text-secondary">% Change</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border bg-white">
                {filtered.map((row) => {
                  const diffClass = row.diff == null ? "" : row.diff > 0 ? "text-danger" : row.diff < 0 ? "text-success" : "text-text-secondary";
                  const DiffIcon  = row.diff == null ? null : row.diff > 0 ? TrendingUp : row.diff < 0 ? TrendingDown : Minus;
                  return (
                    <tr key={row.pid} className="hover:bg-background-subtle">
                      <td className="px-4 py-2.5">
                        <p className="font-medium text-text-primary">{row.name}</p>
                        <p className="text-xs text-text-secondary">{row.sku}</p>
                      </td>
                      <td className={`px-4 py-2.5 text-right tabular-nums ${row.a ? "text-text-primary" : "text-text-secondary"}`}>
                        {row.a ? fmt(row.a.unit_price) : <span className="text-xs">Not in list</span>}
                      </td>
                      <td className={`px-4 py-2.5 text-right tabular-nums ${row.b ? "text-text-primary" : "text-text-secondary"}`}>
                        {row.b ? fmt(row.b.unit_price) : <span className="text-xs">Not in list</span>}
                      </td>
                      <td className={`px-4 py-2.5 text-right tabular-nums ${diffClass}`}>
                        {DiffIcon && row.diff != null && (
                          <span className="flex items-center justify-end gap-1">
                            <DiffIcon className="h-3 w-3" />
                            {row.diff > 0 ? "+" : ""}{fmt(row.diff)}
                          </span>
                        )}
                        {row.diff == null && <span className="text-text-secondary">—</span>}
                      </td>
                      <td className={`px-4 py-2.5 text-right tabular-nums ${diffClass}`}>
                        {row.diffPct != null ? `${row.diffPct > 0 ? "+" : ""}${row.diffPct.toFixed(1)}%` : "—"}
                      </td>
                    </tr>
                  );
                })}
                {filtered.length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-text-secondary text-sm">No products found.</td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </>
      )}
    </AppShell>
  );
}
