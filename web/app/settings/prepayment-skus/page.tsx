"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { DataTable, Column } from "@/components/ui/data-table";
import { Modal } from "@/components/ui/modal";
import { useOrgBranch } from "@/lib/org-branch-context";

import { Plus, PowerOff, Search, X } from "lucide-react";
import { API_URL } from "@/lib/api/client";

// ──────────────────────────────────────────────────────────────────────────────
// Types
// ──────────────────────────────────────────────────────────────────────────────
interface PrepaymentSku {
  id: number;
  product_id: number;
  product_name: string;
  product_sku: string;
  branch_id: number | null;
  branch_name: string | null;
  reason: string;
  effective_from: string;
  active: boolean;
  created_by: string;
  created_at: string;
}

interface ProductOption {
  id: number;
  name: string;
  sku: string;
}

interface AddSkuForm {
  product_id: string;
  product_label: string;   // display string once selected
  branch_id: string;
  reason: string;
  effective_from: string;
}

const EMPTY_FORM: AddSkuForm = {
  product_id:    "",
  product_label: "",
  branch_id:     "",
  reason:        "",
  effective_from: new Date().toISOString().slice(0, 10),
};

// ──────────────────────────────────────────────────────────────────────────────
// ProductCombobox
// ──────────────────────────────────────────────────────────────────────────────
function ProductCombobox({
  token, orgId, value, label,
  onChange,
}: {
  token: string | null;
  orgId: string | null;
  value: string;
  label: string;
  onChange: (id: string, label: string) => void;
}) {
  const [query,    setQuery]    = useState(label);
  const [results,  setResults]  = useState<ProductOption[]>([]);
  const [open,     setOpen]     = useState(false);
  const [searching, setSearching] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // Close dropdown on outside click
  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, []);

  // Sync display label when form is reset
  useEffect(() => {
    if (!value) setQuery("");
  }, [value]);

  const search = useCallback(async (q: string) => {
    if (!token || !orgId || q.trim().length < 1) { setResults([]); return; }
    setSearching(true);
    try {
      const res  = await fetch(
        `${API_URL}/api/v1/products?q=${encodeURIComponent(q)}&status=active&per_page=20`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } }
      );
      const json = await res.json();
      setResults((json.data ?? []).map((p: { id: number; name: string; sku: string }) => ({
        id: p.id, name: p.name, sku: p.sku,
      })));
    } finally {
      setSearching(false);
    }
  }, [token, orgId]);

  const handleInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    const q = e.target.value;
    setQuery(q);
    onChange("", "");          // clear selection while typing
    setOpen(true);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => search(q), 300);
  };

  const handleSelect = (p: ProductOption) => {
    onChange(String(p.id), `${p.name} · ${p.sku}`);
    setQuery(`${p.name} · ${p.sku}`);
    setOpen(false);
    setResults([]);
  };

  const handleClear = () => {
    onChange("", "");
    setQuery("");
    setResults([]);
  };

  return (
    <div ref={containerRef} className="relative">
      <div className="relative">
        <Search className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-text-secondary" />
        <input
          type="text"
          value={query}
          onChange={handleInput}
          onFocus={() => query && !value && setOpen(true)}
          placeholder="Search by name or SKU…"
          className="w-full rounded-md border border-border bg-background pl-9 pr-8 py-2 text-sm text-text-primary placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-accent"
        />
        {(query || value) && (
          <button
            type="button"
            onClick={handleClear}
            className="absolute right-2.5 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary"
          >
            <X className="h-3.5 w-3.5" />
          </button>
        )}
      </div>

      {/* Selected badge */}
      {value && (
        <p className="mt-1 text-xs text-success font-medium">✓ Selected — ID #{value}</p>
      )}

      {/* Dropdown */}
      {open && (
        <div className="absolute z-50 mt-1 w-full rounded-md border border-border bg-background shadow-lg max-h-52 overflow-y-auto">
          {searching ? (
            <div className="flex items-center justify-center py-4">
              <div className="h-4 w-4 animate-spin rounded-full border-2 border-accent border-t-transparent" />
            </div>
          ) : results.length === 0 ? (
            <p className="px-4 py-3 text-sm text-text-secondary">
              {query.trim().length < 1 ? "Type to search products…" : "No products found."}
            </p>
          ) : (
            results.map((p) => (
              <button
                key={p.id}
                type="button"
                onMouseDown={(e) => { e.preventDefault(); handleSelect(p); }}
                className="flex w-full items-center justify-between px-4 py-2.5 text-left text-sm hover:bg-background-subtle transition-colors"
              >
                <span className="font-medium text-text-primary">{p.name}</span>
                <span className="ml-2 shrink-0 text-xs text-text-secondary">{p.sku}</span>
              </button>
            ))
          )}
        </div>
      )}
    </div>
  );
}
export default function PrepaymentSkusPage() {
  const { token, orgId } = useOrgBranch();
  const [skus,    setSkus]    = useState<PrepaymentSku[]>([]);
  const [loading, setLoading] = useState(false);
  const [showAdd, setShowAdd] = useState(false);
  const [form,    setForm]    = useState<AddSkuForm>(EMPTY_FORM);
  const [saving,  setSaving]  = useState(false);
  const [deactivatingId, setDeactivatingId] = useState<number | null>(null);
  const [toast,   setToast]   = useState<{ type: "success" | "error"; msg: string } | null>(null);
  const [filterActive, setFilterActive] = useState<"all" | "active" | "inactive">("active");

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  const fetchSkus = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const activeParam = filterActive !== "all" ? `?active=${filterActive === "active"}` : "";
      const res  = await fetch(`${API_URL}/api/v1/prepayment_skus${activeParam}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) setSkus(json.data ?? []);
    } finally {
      setLoading(false);
    }
  }, [token, orgId, filterActive]);

  useEffect(() => { fetchSkus(); }, [fetchSkus]);

  const handleAdd = async () => {
    if (!token || !orgId || !form.product_id) return;
    setSaving(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/prepayment_skus`, {
        method:  "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          prepayment_sku: {
            product_id:    Number(form.product_id),
            branch_id:     form.branch_id ? Number(form.branch_id) : null,
            reason:        form.reason,
            effective_from: form.effective_from,
          },
        }),
      });
      const json = await res.json();
      if (res.ok) {
        showToast("success", "Prepayment SKU added.");
        setShowAdd(false);
        setForm(EMPTY_FORM);
        fetchSkus();
      } else {
        showToast("error", json.errors?.join(", ") ?? "Failed to add");
      }
    } finally {
      setSaving(false);
    }
  };

  const handleDeactivate = async (sku: PrepaymentSku) => {
    if (!confirm(`Deactivate prepayment requirement for "${sku.product_name}"?`)) return;
    setDeactivatingId(sku.id);
    try {
      const res = await fetch(`${API_URL}/api/v1/prepayment_skus/${sku.id}/deactivate`, {
        method:  "POST",
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (res.ok) {
        showToast("success", "Prepayment SKU deactivated.");
        fetchSkus();
      } else {
        showToast("error", "Deactivation failed.");
      }
    } finally {
      setDeactivatingId(null);
    }
  };

  const columns: Column<PrepaymentSku>[] = [
    {
      key: "product_name",
      header: "Product",
      render: (_, row) => (
        <div>
          <p className="font-medium text-text-primary">{row.product_name}</p>
          <p className="text-xs text-text-secondary">{row.product_sku}</p>
        </div>
      ),
    },
    {
      key: "branch_name",
      header: "Branch",
      render: (_, row) => row.branch_name ?? <span className="text-text-secondary text-xs">All branches</span>,
    },
    {
      key: "effective_from",
      header: "Effective From",
      render: (_, row) => new Date(row.effective_from).toLocaleDateString("en-IN"),
    },
    {
      key: "reason",
      header: "Reason",
      render: (_, row) => <span className="text-text-secondary text-xs">{row.reason || "—"}</span>,
    },
    {
      key: "active",
      header: "Status",
      render: (_, row) => (
        <Badge variant={row.active ? "default" : "secondary"}>
          {row.active ? "Active" : "Inactive"}
        </Badge>
      ),
    },
    {
      key: "id",
      header: "",
      render: (_, row) => row.active ? (
        <Button
          variant="outline"
          size="sm"
          onClick={() => handleDeactivate(row)}
          disabled={deactivatingId === row.id}
        >
          <PowerOff className="h-3.5 w-3.5 mr-1" />
          {deactivatingId === row.id ? "…" : "Deactivate"}
        </Button>
      ) : null,
    },
  ];

  return (
    <AppShell title="Prepayment SKUs">
      <PageHeader
        title="Prepayment SKUs"
        description="Products that require advance payment before order fulfilment."
        actions={[
          {
            label: "Add SKU",
            onClick: () => setShowAdd(true),
            icon: Plus,
          },
        ]}
      />

      {/* Toast */}
      {toast && (
        <div className={`mb-4 rounded-md border px-4 py-2.5 text-sm ${
          toast.type === "success"
            ? "bg-success/10 border-success/20 text-success"
            : "bg-danger/10 border-danger/20 text-danger"
        }`}>
          {toast.msg}
        </div>
      )}

      {/* Filter */}
      <div className="mb-4 flex gap-2">
        {(["active", "inactive", "all"] as const).map((f) => (
          <button
            key={f}
            onClick={() => setFilterActive(f)}
            className={`rounded-full px-3 py-1 text-xs font-medium capitalize transition-colors ${
              filterActive === f
                ? "bg-accent text-white"
                : "bg-background-subtle text-text-secondary hover:text-text-primary"
            }`}
          >
            {f}
          </button>
        ))}
      </div>

      <Card>
        <CardContent className="p-0">
          <DataTable columns={columns} data={skus} isLoading={loading} emptyMessage="No prepayment SKUs found." />
        </CardContent>
      </Card>

      {/* Add Modal */}
      <Modal
        open={showAdd}
        onClose={() => { setShowAdd(false); setForm(EMPTY_FORM); }}
        title="Add Prepayment SKU"
        description="Require advance payment for this product."
        size="md"
      >
        <div className="space-y-4">
          <div>
            <label className="text-sm font-medium text-text-primary">Product *</label>
            <div className="mt-1">
              <ProductCombobox
                token={token}
                orgId={orgId}
                value={form.product_id}
                label={form.product_label}
                onChange={(id, label) => setForm((p) => ({ ...p, product_id: id, product_label: label }))}
              />
            </div>
          </div>
          <div>
            <label className="text-sm font-medium text-text-primary">Branch ID (optional)</label>
            <Input
              type="number"
              placeholder="Leave blank for all branches"
              value={form.branch_id}
              onChange={(e) => setForm((p) => ({ ...p, branch_id: e.target.value }))}
              className="mt-1"
            />
          </div>
          <div>
            <label className="text-sm font-medium text-text-primary">Effective From *</label>
            <Input
              type="date"
              value={form.effective_from}
              onChange={(e) => setForm((p) => ({ ...p, effective_from: e.target.value }))}
              className="mt-1"
            />
          </div>
          <div>
            <label className="text-sm font-medium text-text-primary">Reason</label>
            <textarea
              value={form.reason}
              onChange={(e) => setForm((p) => ({ ...p, reason: e.target.value }))}
              placeholder="Reason for prepayment requirement..."
              rows={2}
              className="mt-1 w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent resize-none"
            />
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <Button variant="outline" onClick={() => { setShowAdd(false); setForm(EMPTY_FORM); }}>
              Cancel
            </Button>
            <Button onClick={handleAdd} disabled={saving || !form.product_id}>
              {saving ? "Adding…" : "Add SKU"}
            </Button>
          </div>
        </div>
      </Modal>
    </AppShell>
  );
}
