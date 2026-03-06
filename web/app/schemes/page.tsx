"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import {
  Tag, Search, X, Plus, ChevronRight, Zap, Package,
  CalendarDays, ShieldCheck, TrendingUp, Clock, AlertTriangle,
  BarChart2, SlidersHorizontal,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
// ─── Types ────────────────────────────────────────────────────────────────────

interface ProductPreview { id: number; name: string | null; sku: string | null }

interface SchemeSummary {
  id: number;
  code: string;
  name: string;
  scheme_type: string;
  status: string;
  applies_to: string;
  start_date: string | null;
  end_date: string | null;
  priority: number;
  exclusive: boolean;
  applicable_days: number[];
  branch_id: number | null;
  notes: string | null;
  conditions_count: number;
  rewards_count: number;
  reward_summary: string | null;
  products_preview: ProductPreview[];
  created_at: string;
}

interface SchemeStats {
  total: number;
  active: number;
  inactive: number;
  expired: number;
  expiring_soon: number;
  exclusive: number;
  evergreen: number;
  by_type: Record<string, number>;
}

interface ProductSuggestion { id: number; name: string; sku: string }

interface PageMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
}

// ─── Constants ────────────────────────────────────────────────────────────────

const STATUS_TABS = [
  { key: "",         label: "All" },
  { key: "active",   label: "Active" },
  { key: "inactive", label: "Inactive" },
  { key: "expired",  label: "Expired" },
];

const TYPE_LABELS: Record<string, string> = {
  buy_x_get_y:           "Buy X Get Y",
  slab_discount:         "Slab Discount",
  item_discount:         "Item Discount",
  order_value_discount:  "Order Value",
};

const TYPE_COLORS: Record<string, string> = {
  buy_x_get_y:           "bg-violet-100 text-violet-700 border-violet-200",
  slab_discount:         "bg-blue-100 text-blue-700 border-blue-200",
  item_discount:         "bg-teal-100 text-teal-700 border-teal-200",
  order_value_discount:  "bg-orange-100 text-orange-700 border-orange-200",
};

const STATUS_VARIANT: Record<string, "default" | "secondary" | "success" | "outline" | "danger"> = {
  active:   "success",
  inactive: "secondary",
  expired:  "danger",
};

const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

// ─── Helpers ─────────────────────────────────────────────────────────────────

function fmtDate(d: string | null) {
  if (!d) return null;
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

function dateRange(start: string | null, end: string | null) {
  if (!start && !end) return "Evergreen";
  const s = fmtDate(start) ?? "∞";
  const e = fmtDate(end) ?? "∞";
  return `${s} – ${e}`;
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function StatCard({
  label, value, sub, icon: Icon, color,
}: {
  label: string; value: number | string; sub?: string;
  icon: React.ElementType; color: string;
}) {
  return (
    <Card>
      <CardContent className="flex items-center gap-4 p-4">
        <div className={`h-10 w-10 rounded-lg flex items-center justify-center shrink-0 ${color}`}>
          <Icon className="h-5 w-5" />
        </div>
        <div className="min-w-0">
          <p className="text-xs text-text-secondary truncate">{label}</p>
          <p className="text-xl font-bold text-text-primary leading-tight">{value}</p>
          {sub && <p className="text-[10px] text-text-secondary">{sub}</p>}
        </div>
      </CardContent>
    </Card>
  );
}

function SchemeBadgeType({ type }: { type: string }) {
  return (
    <span className={`inline-flex items-center rounded-md border px-1.5 py-0.5 text-[10px] font-medium ${TYPE_COLORS[type] ?? "bg-muted text-text-secondary border-border"}`}>
      {TYPE_LABELS[type] ?? type}
    </span>
  );
}

function DayChips({ days }: { days: number[] }) {
  if (!days || days.length === 0) return <span className="text-[10px] text-text-secondary">All days</span>;
  return (
    <div className="flex flex-wrap gap-0.5">
      {DAYS.map((d, i) => (
        <span
          key={i}
          className={`text-[9px] px-1 rounded ${days.includes(i) ? "bg-primary/10 text-primary font-medium" : "bg-muted text-text-secondary/50"}`}
        >
          {d}
        </span>
      ))}
    </div>
  );
}

// ─── Product Picker ───────────────────────────────────────────────────────────

function ProductPicker({
  value,
  onSelect,
  onClear,
}: {
  value: ProductSuggestion | null;
  onSelect: (p: ProductSuggestion) => void;
  onClear: () => void;
}) {
  const [q, setQ] = useState("");
  const [open, setOpen] = useState(false);
  const [results, setResults] = useState<ProductSuggestion[]>([]);
  const [loading, setLoading] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const { orgId, token } = useOrgBranch();

  useEffect(() => {
    if (!q.trim() || q.length < 2) { setResults([]); return; }
    const t = setTimeout(async () => {
      setLoading(true);
      try {
        const res = await fetch(
          `${API_URL}/api/v1/products?q=${encodeURIComponent(q)}&per_page=8`,
          { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId ?? "" } }
        );
        const json = await res.json();
        setResults((json.data ?? []).map((p: { id: number; name: string; sku: string }) => ({ id: p.id, name: p.name, sku: p.sku })));
      } catch {
        setResults([]);
      } finally {
        setLoading(false);
      }
    }, 300);
    return () => clearTimeout(t);
  }, [q]);

  // Close on outside click
  useEffect(() => {
    const handler = (e: MouseEvent) => { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  if (value) {
    return (
      <div className="flex items-center gap-1.5 h-9 px-3 rounded-md border border-primary/40 bg-primary/5 text-sm">
        <Package className="h-3.5 w-3.5 text-primary shrink-0" />
        <span className="text-primary font-medium text-xs truncate max-w-[180px]">{value.sku} — {value.name}</span>
        <button onClick={onClear} className="ml-1 text-primary/60 hover:text-primary">
          <X className="h-3.5 w-3.5" />
        </button>
      </div>
    );
  }

  return (
    <div ref={ref} className="relative">
      <div className="relative">
        <Package className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-text-secondary" />
        <input
          value={q}
          onChange={e => { setQ(e.target.value); setOpen(true); }}
          onFocus={() => setOpen(true)}
          placeholder="Filter by product…"
          className="h-9 pl-8 pr-3 w-52 rounded-md border border-border bg-background text-sm placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary"
        />
      </div>
      {open && (q.length >= 2) && (
        <div className="absolute top-full mt-1 left-0 z-30 w-72 rounded-md border border-border bg-background shadow-md overflow-hidden">
          {loading && <p className="px-3 py-2 text-xs text-text-secondary">Searching…</p>}
          {!loading && results.length === 0 && <p className="px-3 py-2 text-xs text-text-secondary">No products found</p>}
          {results.map(p => (
            <button
              key={p.id}
              className="w-full flex items-center gap-2 px-3 py-2 text-left hover:bg-muted"
              onMouseDown={() => { onSelect(p); setQ(""); setOpen(false); }}
            >
              <Package className="h-3.5 w-3.5 text-text-secondary shrink-0" />
              <span className="text-xs font-medium text-text-primary">{p.sku}</span>
              <span className="text-xs text-text-secondary truncate">{p.name}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// ─── Main Page ────────────────────────────────────────────────────────────────

export default function SchemesPage() {
  const router = useRouter();
  const { orgId, branchId, token } = useOrgBranch();

  const [schemes, setSchemes] = useState<SchemeSummary[]>([]);
  const [meta, setMeta] = useState<PageMeta | null>(null);
  const [stats, setStats] = useState<SchemeStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [statsLoading, setStatsLoading] = useState(true);

  // Filters
  const [tab, setTab] = useState("");
  const [typeFilter, setTypeFilter] = useState("");
  const [search, setSearch] = useState("");
  const [productFilter, setProductFilter] = useState<ProductSuggestion | null>(null);
  const [page, setPage] = useState(1);

  const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };

  // ── Fetch stats ───────────────────────────────────────────────────────────
  useEffect(() => {
    if (!orgId) return;
    setStatsLoading(true);
    fetch(`${API_URL}/api/v1/schemes/stats`, { headers })
      .then(r => r.json())
      .then(j => setStats(j.data ?? null))
      .catch(() => {})
      .finally(() => setStatsLoading(false));
  }, [orgId]);

  // ── Fetch list ────────────────────────────────────────────────────────────
  const fetchSchemes = useCallback(() => {
    if (!orgId) return;
    setLoading(true);
    const params = new URLSearchParams({ page: String(page), per_page: "20" });
    if (tab)           params.set("status", tab);
    if (typeFilter)    params.set("scheme_type", typeFilter);
    if (search.trim()) params.set("q", search.trim());
    if (productFilter) params.set("product_id", String(productFilter.id));
    if (branchId)      params.set("branch_id", branchId);

    fetch(`${API_URL}/api/v1/schemes?${params}`, { headers })
      .then(r => r.json())
      .then(j => { setSchemes(j.data ?? []); setMeta(j.meta ?? null); })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [orgId, branchId, tab, typeFilter, search, productFilter, page]);

  useEffect(() => { setPage(1); }, [tab, typeFilter, search, productFilter]);
  useEffect(() => { fetchSchemes(); }, [fetchSchemes]);

  const statusCounts: Record<string, number> = {
    "":        stats?.total ?? 0,
    active:    stats?.active ?? 0,
    inactive:  stats?.inactive ?? 0,
    expired:   stats?.expired ?? 0,
  };

  return (
    <AppShell>
      <PageHeader
        title="Schemes"
        description="Trade promotions and discount schemes applied at order time"
        actions={[{
          label: "New Scheme",
          onClick: () => router.push("/schemes/new"),
          icon: Plus,
        }]}
      />

      {/* ── Stats row ──────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3 mb-6">
        <StatCard label="Total Schemes"  value={stats?.total ?? "—"}         icon={Tag}          color="bg-blue-50 text-blue-600" />
        <StatCard label="Active"         value={stats?.active ?? "—"}         icon={ShieldCheck}  color="bg-green-50 text-green-600" />
        <StatCard label="Expiring Soon"  value={stats?.expiring_soon ?? "—"}  icon={Clock}        color="bg-amber-50 text-amber-600"
                  sub="next 7 days" />
        <StatCard label="Exclusive"      value={stats?.exclusive ?? "—"}      icon={Zap}          color="bg-violet-50 text-violet-600" />
        <StatCard label="Evergreen"      value={stats?.evergreen ?? "—"}      icon={TrendingUp}   color="bg-teal-50 text-teal-600"
                  sub="no end date" />
        <StatCard label="Expired"        value={stats?.expired ?? "—"}        icon={AlertTriangle} color="bg-red-50 text-red-600" />
      </div>

      {/* ── Toolbar ────────────────────────────────────────────────────────── */}
      <div className="mb-4 flex flex-col gap-3">
        {/* Status tabs */}
        <div className="flex items-center gap-1 border-b border-border overflow-x-auto pb-px">
          {STATUS_TABS.map(t => (
            <button
              key={t.key}
              onClick={() => setTab(t.key)}
              className={`px-3 py-1.5 text-sm font-medium whitespace-nowrap transition-colors border-b-2 -mb-px ${
                tab === t.key
                  ? "border-primary text-primary"
                  : "border-transparent text-text-secondary hover:text-text-primary"
              }`}
            >
              {t.label}
              {statusCounts[t.key] > 0 && (
                <span className={`ml-1.5 text-[10px] rounded-full px-1.5 py-0.5 ${tab === t.key ? "bg-primary/10 text-primary" : "bg-muted text-text-secondary"}`}>
                  {statusCounts[t.key]}
                </span>
              )}
            </button>
          ))}
        </div>

        {/* Filters row */}
        <div className="flex flex-wrap items-center gap-2">
          {/* Text search */}
          <div className="relative">
            <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-text-secondary" />
            <Input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Search name or code…"
              className="pl-8 h-9 w-56"
            />
            {search && (
              <button onClick={() => setSearch("")} className="absolute right-2 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary">
                <X className="h-3.5 w-3.5" />
              </button>
            )}
          </div>

          {/* Type filter */}
          <select
            value={typeFilter}
            onChange={e => setTypeFilter(e.target.value)}
            className="h-9 rounded-md border border-border bg-background px-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary/20"
          >
            <option value="">All Types</option>
            {Object.entries(TYPE_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>

          {/* Product picker */}
          <ProductPicker
            value={productFilter}
            onSelect={p => setProductFilter(p)}
            onClear={() => setProductFilter(null)}
          />

          {/* Active filters summary */}
          {(search || typeFilter || productFilter) && (
            <Button
              variant="ghost"
              size="sm"
              className="h-9 text-text-secondary gap-1"
              onClick={() => { setSearch(""); setTypeFilter(""); setProductFilter(null); }}
            >
              <SlidersHorizontal className="h-3.5 w-3.5" />
              Clear filters
            </Button>
          )}

          <span className="ml-auto text-xs text-text-secondary tabular-nums">
            {meta ? `${meta.total_count} scheme${meta.total_count !== 1 ? "s" : ""}` : ""}
          </span>
        </div>
      </div>

      {/* ── Product filter banner ─────────────────────────────────────────── */}
      {productFilter && (
        <div className="mb-4 flex items-center gap-2 rounded-md border border-primary/20 bg-primary/5 px-4 py-2.5 text-sm text-primary">
          <Package className="h-4 w-4 shrink-0" />
          <span>
            Showing schemes involving <strong>{productFilter.sku} — {productFilter.name}</strong>
          </span>
          <button onClick={() => setProductFilter(null)} className="ml-auto text-primary/60 hover:text-primary">
            <X className="h-4 w-4" />
          </button>
        </div>
      )}

      {/* ── Scheme cards grid ─────────────────────────────────────────────── */}
      {loading ? (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="h-40 rounded-lg bg-muted/50 animate-pulse" />
          ))}
        </div>
      ) : schemes.length === 0 ? (
        <EmptyState
          icon={<Tag className="h-10 w-10 text-text-secondary/40" />}
          title="No schemes found"
          description={
            productFilter
              ? `No schemes reference product "${productFilter.sku}"`
              : "Adjust your filters or create a new scheme"
          }
          action={
            <Button onClick={() => router.push("/schemes/new")} className="gap-1.5">
              <Plus className="h-4 w-4" />
              New Scheme
            </Button>
          }
        />
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {schemes.map(s => (
            <button
              key={s.id}
              onClick={() => router.push(`/schemes/${s.id}`)}
              className="group text-left rounded-xl border border-border bg-background p-4 hover:border-primary/40 hover:shadow-sm transition-all"
            >
              <div className="flex items-start justify-between gap-2 mb-3">
                <div className="min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <SchemeBadgeType type={s.scheme_type} />
                    {s.exclusive && (
                      <span className="inline-flex items-center gap-0.5 text-[10px] font-medium text-violet-600 bg-violet-50 border border-violet-200 rounded px-1.5 py-0.5">
                        <Zap className="h-2.5 w-2.5" />
                        Exclusive
                      </span>
                    )}
                  </div>
                  <h3 className="mt-1.5 text-sm font-semibold text-text-primary leading-tight group-hover:text-primary transition-colors line-clamp-1">
                    {s.name}
                  </h3>
                  <p className="text-[10px] font-mono text-text-secondary">{s.code}</p>
                </div>
                <div className="flex flex-col items-end gap-1 shrink-0">
                  <Badge variant={STATUS_VARIANT[s.status] ?? "secondary"} className="text-[10px]">
                    {s.status}
                  </Badge>
                  <ChevronRight className="h-3.5 w-3.5 text-text-secondary/40 group-hover:text-primary transition-colors" />
                </div>
              </div>

              {/* Reward */}
              {s.reward_summary && (
                <div className="flex items-center gap-1.5 mb-2">
                  <BarChart2 className="h-3 w-3 text-text-secondary shrink-0" />
                  <span className="text-xs font-medium text-text-primary">{s.reward_summary}</span>
                </div>
              )}

              {/* Products chips */}
              {s.products_preview.length > 0 && (
                <div className="flex flex-wrap gap-1 mb-2">
                  {s.products_preview.map(p => (
                    <span
                      key={p.id}
                      className={`inline-flex items-center gap-0.5 text-[10px] rounded px-1.5 py-0.5 font-medium
                        ${productFilter?.id === p.id
                          ? "bg-primary/10 text-primary border border-primary/30"
                          : "bg-muted text-text-secondary border border-border"
                        }`}
                    >
                      <Package className="h-2.5 w-2.5" />
                      {p.sku ?? `#${p.id}`}
                    </span>
                  ))}
                </div>
              )}

              {/* Date range + days */}
              <div className="flex items-center justify-between gap-2 mt-auto pt-2 border-t border-border">
                <div className="flex items-center gap-1 text-[10px] text-text-secondary">
                  <CalendarDays className="h-3 w-3" />
                  {dateRange(s.start_date, s.end_date)}
                </div>
                <DayChips days={s.applicable_days} />
              </div>
            </button>
          ))}
        </div>
      )}

      {/* ── Pagination ─────────────────────────────────────────────────────── */}
      {meta && meta.total_pages > 1 && (
        <div className="mt-6 flex items-center justify-center gap-2">
          <Button
            variant="outline"
            size="sm"
            disabled={page <= 1}
            onClick={() => setPage(p => p - 1)}
          >
            Previous
          </Button>
          <span className="text-xs text-text-secondary tabular-nums">
            Page {meta.current_page} of {meta.total_pages}
          </span>
          <Button
            variant="outline"
            size="sm"
            disabled={page >= meta.total_pages}
            onClick={() => setPage(p => p + 1)}
          >
            Next
          </Button>
        </div>
      )}
    </AppShell>
  );
}
