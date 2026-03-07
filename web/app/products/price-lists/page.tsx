"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { Plus, X, Search, Pencil, List } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";

import Link from "next/link";
import { API_URL } from "@/lib/api/client";

// ─── Sub-nav ──────────────────────────────────────────────────────────────────
function ProductsSubNav({ active }: { active: "products" | "categories" | "uom" | "price-lists" }) {
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
          className={`px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors ${
            active === item.key
              ? "border-primary text-primary"
              : "border-transparent text-text-secondary hover:text-text-primary"
          }`}
        >
          {item.label}
        </Link>
      ))}
    </div>
  );
}

// ─── Types ────────────────────────────────────────────────────────────────────
interface Branch    { id: number; name: string; }
interface PriceList {
  id:          number;
  name:        string;
  list_type:   string;
  valid_from:  string | null;
  valid_to:    string | null;
  items_count: number;
  branch:      { id: number; name: string } | null;
}

const LIST_TYPES = ["standard", "promo", "retailer_specific", "tier_specific"];

const TYPE_LABEL: Record<string, string> = {
  standard:          "Standard",
  promo:             "Promo",
  retailer_specific: "Retailer Specific",
  tier_specific:     "Tier Specific",
};

const TYPE_VARIANT: Record<string, "default" | "secondary" | "success" | "warning" | "outline"> = {
  standard:          "default",
  promo:             "warning",
  retailer_specific: "secondary",
  tier_specific:     "outline",
};

// ─── New Price List Modal ─────────────────────────────────────────────────────
function NewPriceListModal({
  open, branches, token, orgId,
  onClose, onCreated,
}: {
  open:      boolean;
  branches:  Branch[];
  token:     string | null;
  orgId:     string | null;
  onClose:   () => void;
  onCreated: (pl: PriceList) => void;
}) {
  const [form,    setForm]    = useState({ name: "", list_type: "standard", branch_id: "", valid_from: "", valid_to: "" });
  const [loading, setLoading] = useState(false);
  const [errors,  setErrors]  = useState<string[]>([]);

  const set = (field: string) =>
    (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
      setForm((p) => ({ ...p, [field]: e.target.value }));

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !orgId) return;
    setLoading(true); setErrors([]);
    try {
      const body: Record<string, string> = { name: form.name, list_type: form.list_type };
      if (form.branch_id)  body.branch_id  = form.branch_id;
      if (form.valid_from) body.valid_from = form.valid_from;
      if (form.valid_to)   body.valid_to   = form.valid_to;

      const res  = await fetch(`${API_URL}/api/v1/price_lists`, {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({ price_list: body }),
      });
      const json = await res.json();
      if (res.ok) { onCreated(json.data); onClose(); }
      else        { setErrors(json.errors ?? ["Something went wrong"]); }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal open={open} onClose={onClose} title="New Price List">
      <form onSubmit={handleSubmit} className="space-y-4">
        {errors.length > 0 && (
          <div className="rounded bg-danger/10 border border-danger/20 p-2 text-sm text-danger">
            {errors.join(", ")}
          </div>
        )}
        <div>
          <label className="text-sm font-medium text-text-primary mb-1 block">Name *</label>
          <Input value={form.name} onChange={set("name")} placeholder="e.g. Standard Apr 2026" required />
        </div>
        <div>
          <label className="text-sm font-medium text-text-primary mb-1 block">Type *</label>
          <select value={form.list_type} onChange={set("list_type")}
            className="w-full px-3 py-2 text-sm border border-border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20">
            {LIST_TYPES.map((t) => <option key={t} value={t}>{TYPE_LABEL[t]}</option>)}
          </select>
        </div>
        <div>
          <label className="text-sm font-medium text-text-primary mb-1 block">Branch</label>
          <select value={form.branch_id} onChange={set("branch_id")}
            className="w-full px-3 py-2 text-sm border border-border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20">
            <option value="">All branches</option>
            {branches.map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
          </select>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-sm font-medium text-text-primary mb-1 block">Valid From</label>
            <Input type="date" value={form.valid_from} onChange={set("valid_from")} />
          </div>
          <div>
            <label className="text-sm font-medium text-text-primary mb-1 block">Valid To</label>
            <Input type="date" value={form.valid_to} onChange={set("valid_to")} />
          </div>
        </div>
        <div className="flex justify-end gap-2 pt-2 border-t border-border">
          <Button type="button" variant="outline" onClick={onClose} disabled={loading}>Cancel</Button>
          <Button type="submit" disabled={loading}>{loading ? "Creating…" : "Create"}</Button>
        </div>
      </form>
    </Modal>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function PriceListsPage() {
  const router = useRouter();
  const { token, orgId, branches } = useOrgBranch();

  const [priceLists,  setPriceLists]  = useState<PriceList[]>([]);
  const [loading,     setLoading]     = useState(false);
  const [search,      setSearch]      = useState("");
  const [listType,    setListType]    = useState("");
  const [branchId,    setBranchId]    = useState("");
  const [page,        setPage]        = useState(1);
  const [totalPages,  setTotalPages]  = useState(1);
  const [totalCount,  setTotalCount]  = useState(0);
  const [showNew,     setShowNew]     = useState(false);

  const columns: Column<PriceList>[] = [
    {
      key:    "name",
      header: "Name",
      render: (_, row) => (
        <div>
          <p className="font-medium text-text-primary">{row.name}</p>
          {row.branch && <p className="text-xs text-text-secondary">{row.branch.name}</p>}
        </div>
      ),
    },
    {
      key:    "list_type",
      header: "Type",
      render: (v) => (
        <Badge variant={TYPE_VARIANT[v as string] ?? "outline"}>
          {TYPE_LABEL[v as string] ?? String(v)}
        </Badge>
      ),
    },
    {
      key:    "valid_from",
      header: "Valid",
      render: (_, row) => {
        if (!row.valid_from && !row.valid_to) return <span className="text-sm text-text-secondary">Always</span>;
        const from = row.valid_from ? new Date(row.valid_from).toLocaleDateString("en-IN") : "—";
        const to   = row.valid_to   ? new Date(row.valid_to).toLocaleDateString("en-IN")   : "∞";
        return <span className="text-sm text-text-secondary">{from} → {to}</span>;
      },
    },
    {
      key:    "items_count",
      header: "Items",
      render: (v) => <span className="text-sm">{String(v)}</span>,
    },
    {
      key:    "actions_col",
      header: "",
      render: (_, row) => (
        <div className="flex items-center gap-1" onClick={(e) => e.stopPropagation()}>
          <button
            onClick={() => router.push(`/products/price-lists/${row.id}`)}
            className="p-1 rounded hover:bg-muted text-text-secondary hover:text-text-primary transition-colors"
            title="View / Edit items"
          >
            <Pencil className="h-3.5 w-3.5" />
          </button>
        </div>
      ),
    },
  ];

  const fetchPriceLists = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qs = new URLSearchParams({ page: String(page), per_page: "20" });
      if (listType) qs.set("list_type", listType);
      if (branchId) qs.set("branch_id", branchId);

      const res  = await fetch(`${API_URL}/api/v1/price_lists?${qs}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        // client-side filter by search (name)
        const data = (json.data as PriceList[]).filter((pl) =>
          !search || pl.name.toLowerCase().includes(search.toLowerCase())
        );
        setPriceLists(data);
        setTotalPages(json.meta?.total_pages ?? 1);
        setTotalCount(json.meta?.total_count  ?? 0);
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, listType, branchId, search]);

  useEffect(() => { fetchPriceLists(); }, [fetchPriceLists]);

  return (
    <AppShell>
      <PageHeader
        title="Price Lists"
        description={totalCount > 0 ? `${totalCount} lists` : undefined}
        actions={[{ label: "New Price List", onClick: () => setShowNew(true) }]}
      />

      <ProductsSubNav active="price-lists" />

      {/* Filters */}
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[200px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            className="pl-9"
            placeholder="Search by name…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          />
        </div>
        <select
          value={listType}
          onChange={(e) => { setListType(e.target.value); setPage(1); }}
          className="px-3 py-2 text-sm border border-border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20"
        >
          <option value="">All types</option>
          {LIST_TYPES.map((t) => <option key={t} value={t}>{TYPE_LABEL[t]}</option>)}
        </select>
        <select
          value={branchId}
          onChange={(e) => { setBranchId(e.target.value); setPage(1); }}
          className="px-3 py-2 text-sm border border-border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20"
        >
          <option value="">All branches</option>
          {(branches as Branch[]).map((b) => <option key={b.id} value={b.id}>{b.name}</option>)}
        </select>
        {(search || listType || branchId) && (
          <button onClick={() => { setSearch(""); setListType(""); setBranchId(""); setPage(1); }}
            className="flex items-center gap-1 text-sm text-text-secondary hover:text-text-primary">
            <X className="h-3.5 w-3.5" /> Clear
          </button>
        )}
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-24">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
        </div>
      ) : priceLists.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-lg border border-border py-20 text-center">
          <div className="mb-4 rounded-full bg-background-subtle p-4">
            <List className="h-8 w-8 text-text-secondary/50" />
          </div>
          <p className="text-sm font-medium text-text-primary">No price lists yet</p>
          <p className="mt-1 text-xs text-text-secondary">
            {(search || listType || branchId)
              ? "No price lists match the current filters."
              : "Create your first price list to start managing product pricing."}
          </p>
          {!(search || listType || branchId) && (
            <Button size="sm" className="mt-4" onClick={() => setShowNew(true)}>
              <Plus className="mr-1.5 h-3.5 w-3.5" /> New Price List
            </Button>
          )}
        </div>
      ) : (
        <DataTable
          columns={columns}
          data={priceLists}
          onRowClick={(row) => router.push(`/products/price-lists/${row.id}`)}
        />
      )}

      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
          <span>{totalCount} price lists</span>
          <div className="flex items-center gap-2">
            <button disabled={page <= 1} onClick={() => setPage((p) => p - 1)}
              className="px-3 py-1 rounded border border-border hover:bg-background-subtle disabled:opacity-40">Previous</button>
            <span>Page {page} of {totalPages}</span>
            <button disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}
              className="px-3 py-1 rounded border border-border hover:bg-background-subtle disabled:opacity-40">Next</button>
          </div>
        </div>
      )}

      <NewPriceListModal
        open={showNew}
        branches={branches as Branch[]}
        token={token}
        orgId={orgId}
        onClose={() => setShowNew(false)}
        onCreated={(pl) => { setPriceLists((prev) => [pl, ...prev]); setTotalCount((n) => n + 1); }}
      />
    </AppShell>
  );
}
