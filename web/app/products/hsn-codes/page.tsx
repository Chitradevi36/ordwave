"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Search, RefreshCw, Hash } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import Link from "next/link";

// ─── Types ────────────────────────────────────────────────────────────────────
interface HsnCode {
  id:          number;
  code:        string;
  description: string | null;
  gst_rate:    number;
  cess_rate:   number | null;
  category:    string | null;
}

const GST_VARIANT: Record<number, "success" | "default" | "warning" | "secondary"> = {
  0:  "outline" as "default",
  5:  "success",
  12: "default",
  18: "warning",
  28: "secondary",
};

// ─── Sub-nav (shared pattern) ─────────────────────────────────────────────────
function ProductsSubNav() {
  const items = [
    { label: "Products",         href: "/products" },
    { label: "Categories",       href: "/products/categories" },
    { label: "Units of Measure", href: "/products/uom" },
    { label: "Price Lists",      href: "/products/price-lists" },
    { label: "HSN / SAC",        href: "/products/hsn-codes" },
  ];
  return (
    <div className="flex gap-1 border-b border-border mb-6 overflow-x-auto">
      {items.map((item) => (
        <Link
          key={item.href}
          href={item.href}
          className="px-4 py-2 text-sm font-medium border-b-2 -mb-px whitespace-nowrap transition-colors border-transparent text-text-secondary hover:text-text-primary"
        >
          {item.label}
        </Link>
      ))}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function HsnCodesPage() {
  const { token, orgId } = useOrgBranch();

  const [codes,    setCodes]    = useState<HsnCode[]>([]);
  const [loading,  setLoading]  = useState(false);
  const [total,    setTotal]    = useState(0);
  const [page,     setPage]     = useState(1);
  const [search,   setSearch]   = useState("");
  const [gstFilter, setGstFilter] = useState("");
  const perPage = 25;

  const fetchCodes = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qs = new URLSearchParams({ page: String(page), per_page: String(perPage) });
      if (search)    qs.set("q",        search);
      if (gstFilter) qs.set("gst_rate", gstFilter);
      const res  = await fetch(`${API_URL}/api/v1/hsn_sac_codes?${qs}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      setCodes(json.data ?? []);
      setTotal(json.meta?.total ?? json.data?.length ?? 0);
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, search, gstFilter]);

  useEffect(() => { fetchCodes(); }, [fetchCodes]);

  const gstOptions = [0, 5, 12, 18, 28];

  return (
    <AppShell title="HSN / SAC Codes" hideBreadcrumb>
      <PageHeader
        title="HSN / SAC Codes"
        description="Harmonised System of Nomenclature and Service Accounting Codes used in GST invoicing"
        actions={[
          { label: "Refresh", onClick: fetchCodes, icon: RefreshCw, variant: "outline" },
        ]}
      />

      {/* <ProductsSubNav /> */}

      {/* Filters */}
      <div className="mb-4 flex flex-wrap gap-3 items-center">
        <div className="relative flex-1 min-w-0 max-w-xs">
          <Search className="absolute left-2.5 top-2 h-4 w-4 text-text-secondary" />
          <input
            type="text"
            placeholder="Search code or description…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
            className="w-full h-9 rounded-md border border-border bg-background pl-8 pr-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
          />
        </div>

        <div className="flex gap-1 flex-wrap">
          <button
            onClick={() => { setGstFilter(""); setPage(1); }}
            className={`px-3 h-8 text-xs rounded-full border transition-colors ${!gstFilter ? "bg-accent text-white border-accent" : "border-border text-text-secondary hover:text-text-primary"}`}
          >
            All rates
          </button>
          {gstOptions.map((r) => (
            <button
              key={r}
              onClick={() => { setGstFilter(String(r)); setPage(1); }}
              className={`px-3 h-8 text-xs rounded-full border transition-colors ${gstFilter === String(r) ? "bg-accent text-white border-accent" : "border-border text-text-secondary hover:text-text-primary"}`}
            >
              {r}% GST
            </button>
          ))}
        </div>
      </div>

      {/* Stats chips */}
      <div className="mb-4 flex items-center gap-3">
        <Hash className="h-4 w-4 text-text-secondary" />
        <span className="text-sm text-text-secondary">{total.toLocaleString("en-IN")} code{total !== 1 ? "s" : ""} found</span>
      </div>

      {/* Table */}
      {loading ? (
        <div className="flex justify-center py-12">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      ) : (
        <>
          <div className="rounded-lg border border-border overflow-auto">
            <table className="w-full text-sm">
              <thead className="bg-background-subtle">
                <tr>
                  <th className="px-4 py-2.5 text-left font-semibold text-text-secondary w-36">HSN / SAC Code</th>
                  <th className="px-4 py-2.5 text-left font-semibold text-text-secondary">Description</th>
                  <th className="px-4 py-2.5 text-left font-semibold text-text-secondary w-28">Category</th>
                  <th className="px-4 py-2.5 text-right font-semibold text-text-secondary w-24">GST Rate</th>
                  <th className="px-4 py-2.5 text-right font-semibold text-text-secondary w-24">CESS</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border bg-white">
                {codes.map((c) => (
                  <tr key={c.id} className="hover:bg-background-subtle">
                    <td className="px-4 py-2.5 font-mono text-sm font-medium text-accent">{c.code}</td>
                    <td className="px-4 py-2.5 text-text-primary">{c.description ?? "—"}</td>
                    <td className="px-4 py-2.5">
                      {c.category ? (
                        <Badge variant="outline">{c.category}</Badge>
                      ) : (
                        <span className="text-text-secondary text-xs">—</span>
                      )}
                    </td>
                    <td className="px-4 py-2.5 text-right">
                      <Badge variant={GST_VARIANT[c.gst_rate] ?? "outline"}>{c.gst_rate}%</Badge>
                    </td>
                    <td className="px-4 py-2.5 text-right text-text-secondary tabular-nums text-xs">
                      {c.cess_rate != null && Number(c.cess_rate) > 0 ? `${Number(c.cess_rate).toFixed(1)}%` : "—"}
                    </td>
                  </tr>
                ))}
                {codes.length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-4 py-10 text-center text-text-secondary text-sm">
                      No HSN / SAC codes found.
                      {(search || gstFilter) && (
                        <button
                          onClick={() => { setSearch(""); setGstFilter(""); setPage(1); }}
                          className="ml-2 text-accent hover:underline"
                        >
                          Clear filters
                        </button>
                      )}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {total > perPage && (
            <div className="mt-4 flex items-center justify-between text-sm">
              <span className="text-text-secondary">
                Showing {((page - 1) * perPage) + 1}–{Math.min(page * perPage, total)} of {total}
              </span>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" disabled={page === 1} onClick={() => setPage((p) => p - 1)}>Previous</Button>
                <Button variant="outline" size="sm" disabled={page * perPage >= total} onClick={() => setPage((p) => p + 1)}>Next</Button>
              </div>
            </div>
          )}
        </>
      )}
    </AppShell>
  );
}
