"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";

import { useOrgBranch } from "@/lib/org-branch-context";
import { Plus, Search, Pencil, Trash2, X, AlertTriangle, Ruler } from "lucide-react";
import Link from "next/link";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────
interface Uom {
  id:            number;
  name:          string;
  symbol:        string;
  active:        boolean;
  product_count: number;
}

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

// ─── UOM Form Modal ───────────────────────────────────────────────────────────
function UomModal({
  open, existing, token, orgId,
  onClose, onSaved,
}: {
  open:      boolean;
  existing?: Uom | null;
  token:     string | null;
  orgId:     string | null;
  onClose:   () => void;
  onSaved:   (uom: Uom) => void;
}) {
  const isEdit = !!existing;
  const [name,   setName]   = useState(existing?.name   ?? "");
  const [symbol, setSymbol] = useState(existing?.symbol ?? "");
  const [active, setActive] = useState(existing?.active ?? true);
  const [loading, setLoading] = useState(false);
  const [errors,  setErrors]  = useState<string[]>([]);

  useEffect(() => {
    setName(existing?.name   ?? "");
    setSymbol(existing?.symbol ?? "");
    setActive(existing?.active ?? true);
    setErrors([]);
  }, [existing, open]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !orgId) return;
    setLoading(true); setErrors([]);

    const url    = isEdit
      ? `${API_URL}/api/v1/units_of_measure/${existing!.id}`
      : `${API_URL}/api/v1/units_of_measure`;
    const method = isEdit ? "PATCH" : "POST";

    try {
      const res  = await fetch(url, {
        method,
        headers: {
          "Content-Type":      "application/json",
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({
          units_of_measure: {
            name:   name.trim(),
            symbol: symbol.trim().toUpperCase(),
            active,
          },
        }),
      });
      const json = await res.json();
      if (res.ok) {
        onSaved(json.data);
      } else {
        setErrors(json.errors ?? ["Something went wrong"]);
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={isEdit ? "Edit Unit of Measure" : "New Unit of Measure"}
      description={
        isEdit
          ? "Update unit details. Symbol must stay unique across the system."
          : "Add a unit of measure to the global catalogue."
      }
      size="sm"
    >
      <form onSubmit={handleSubmit} className="mt-4 space-y-4">
        {errors.length > 0 && (
          <div className="rounded-md bg-danger/10 border border-danger/20 p-3">
            <ul className="text-sm text-danger list-disc list-inside space-y-1">
              {errors.map((e, i) => <li key={i}>{e}</li>)}
            </ul>
          </div>
        )}

        <div>
          <label className="text-sm font-medium text-text-primary mb-1 block">
            Name <span className="text-danger">*</span>
          </label>
          <Input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. Kilogram"
            required
            autoFocus
          />
        </div>

        <div>
          <label className="text-sm font-medium text-text-primary mb-1 block">
            Symbol <span className="text-danger">*</span>
          </label>
          <Input
            value={symbol}
            onChange={(e) => setSymbol(e.target.value.toUpperCase())}
            placeholder="e.g. KG"
            maxLength={20}
            required
          />
          <p className="mt-1 text-xs text-text-secondary">
            Short code used in documents and forms — auto-uppercased, must be unique.
          </p>
        </div>

        <div className="flex items-center justify-between py-2 border-t border-border">
          <span className="text-sm font-medium text-text-primary">Active</span>
          <button
            type="button"
            onClick={() => setActive((p) => !p)}
            className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
              active ? "bg-primary" : "bg-border"
            }`}
          >
            <span
              className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform ${
                active ? "translate-x-4" : "translate-x-1"
              }`}
            />
          </button>
        </div>

        <div className="flex justify-end gap-3 pt-2">
          <Button type="button" variant="outline" onClick={onClose} disabled={loading}>Cancel</Button>
          <Button type="submit" disabled={loading || !name.trim() || !symbol.trim()}>
            {loading ? "Saving…" : isEdit ? "Save Changes" : "Create"}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

// ─── Delete Confirmation ──────────────────────────────────────────────────────
function DeleteModal({
  uom, token, orgId,
  onClose, onDeleted,
}: {
  uom:      Uom;
  token:    string | null;
  orgId:    string | null;
  onClose:  () => void;
  onDeleted: (id: number) => void;
}) {
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState("");
  const hasProducts = uom.product_count > 0;

  const handleDelete = async () => {
    if (!token || !orgId || hasProducts) return;
    setLoading(true); setError("");
    try {
      const res = await fetch(
        `${API_URL}/api/v1/units_of_measure/${uom.id}`,
        {
          method:  "DELETE",
          headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        },
      );
      if (res.ok) {
        onDeleted(uom.id);
      } else {
        const json = await res.json();
        setError((json.errors ?? ["Delete failed"]).join(", "));
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal open onClose={onClose} title="Delete Unit of Measure" size="sm">
      <div className="mt-4 space-y-4">
        {hasProducts ? (
          <div className="flex items-start gap-3 rounded-md bg-warning/10 border border-warning/20 p-3">
            <AlertTriangle className="h-4 w-4 text-warning shrink-0 mt-0.5" />
            <p className="text-sm text-text-primary">
              <strong>{uom.name} ({uom.symbol})</strong> is used by{" "}
              <strong>{uom.product_count} product{uom.product_count !== 1 ? "s" : ""}</strong>.
              Reassign those products to a different unit before deleting.
            </p>
          </div>
        ) : (
          <p className="text-sm text-text-secondary">
            Delete <strong className="text-text-primary">{uom.name} ({uom.symbol})</strong>? This cannot be undone.
          </p>
        )}

        {error && <p className="text-sm text-danger">{error}</p>}

        <div className="flex justify-end gap-3">
          <Button variant="outline" onClick={onClose}>Cancel</Button>
          {!hasProducts && (
            <Button
              variant="danger"
              onClick={handleDelete}
              disabled={loading}
            >
              {loading ? "Deleting…" : "Delete"}
            </Button>
          )}
        </div>
      </div>
    </Modal>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function UomPage() {
  const { token, orgId } = useOrgBranch();

  const [uoms,       setUoms]       = useState<Uom[]>([]);
  const [loading,    setLoading]    = useState(false);
  const [search,     setSearch]     = useState("");
  const [page,       setPage]       = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  const [modalOpen, setModalOpen] = useState(false);
  const [editing,   setEditing]   = useState<Uom | null>(null);
  const [deleting,  setDeleting]  = useState<Uom | null>(null);

  const load = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page), per_page: "25" });
      if (search) params.set("q", search);
      const res  = await fetch(
        `${API_URL}/api/v1/units_of_measure?${params}`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } },
      );
      const json = await res.json();
      if (res.ok) {
        setUoms(json.data ?? []);
        setTotalPages(json.meta?.total_pages ?? 1);
        setTotalCount(json.meta?.total_count  ?? 0);
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, search]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { setPage(1); }, [search]);

  const handleSaved = (uom: Uom) => {
    setUoms((prev) => {
      const idx = prev.findIndex((u) => u.id === uom.id);
      return idx >= 0 ? prev.map((u) => (u.id === uom.id ? uom : u)) : [uom, ...prev];
    });
    setModalOpen(false);
    setEditing(null);
    if (!editing) setTotalCount((n) => n + 1);
  };

  const handleDeleted = (id: number) => {
    setUoms((prev) => prev.filter((u) => u.id !== id));
    setDeleting(null);
    setTotalCount((n) => Math.max(0, n - 1));
  };

  const openCreate = () => { setEditing(null); setModalOpen(true); };
  const openEdit   = (uom: Uom) => { setEditing(uom); setModalOpen(true); };

  const columns: Column<Uom>[] = [
    {
      key:    "name",
      header: "Name",
      render: (_, row) => (
        <div className="flex items-center gap-2">
          <Ruler className="h-3.5 w-3.5 text-text-secondary shrink-0" />
          <span className="font-medium text-text-primary">{row.name}</span>
        </div>
      ),
    },
    {
      key:    "symbol",
      header: "Symbol",
      render: (_, row) => (
        <span className="font-mono text-sm bg-background-subtle px-2 py-0.5 rounded text-text-primary">
          {row.symbol}
        </span>
      ),
    },
    {
      key:    "product_count",
      header: "Products",
      render: (_, row) => (
        <Badge variant={row.product_count > 0 ? "default" : "outline"}>
          {row.product_count}
        </Badge>
      ),
    },
    {
      key:    "active",
      header: "Status",
      render: (_, row) => (
        <Badge variant={row.active ? "success" : "outline"}>
          {row.active ? "Active" : "Inactive"}
        </Badge>
      ),
    },
    {
      key:    "actions" as keyof Uom,
      header: "",
      render: (_, row) => (
        <div className="flex items-center justify-end gap-1">
          <button
            onClick={() => openEdit(row)}
            className="p-1.5 rounded hover:bg-background-subtle text-text-secondary hover:text-text-primary transition-colors"
            title="Edit"
          >
            <Pencil className="h-3.5 w-3.5" />
          </button>
          <button
            onClick={() => setDeleting(row)}
            className="p-1.5 rounded hover:bg-danger/10 text-text-secondary hover:text-danger transition-colors"
            title="Delete"
          >
            <Trash2 className="h-3.5 w-3.5" />
          </button>
        </div>
      ),
    },
  ];

  return (
    <AppShell title="Units of Measure">
      <PageHeader
        title="Units of Measure"
        description={`${totalCount} unit${totalCount !== 1 ? "s" : ""} · global catalogue`}
        actions={[
          { label: "New Unit", icon: Plus, onClick: openCreate },
        ]}
      />

      <ProductsSubNav active="uom" />

      {/* Toolbar */}
      <div className="flex items-center gap-3 mb-4">
        <div className="relative flex-1 max-w-xs">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by name or symbol…"
            className="pl-9"
          />
        </div>
        {search && (
          <button onClick={() => setSearch("")} className="text-text-secondary hover:text-text-primary">
            <X className="h-4 w-4" />
          </button>
        )}
      </div>

      <DataTable
        columns={columns}
        data={uoms}
        isLoading={loading}
        emptyContent={
          <div className="flex flex-col items-center gap-3 py-4">
            <p className="text-sm text-text-secondary">No units of measure yet</p>
            <button
              type="button"
              onClick={openCreate}
              className="inline-flex items-center gap-1.5 rounded-md bg-primary px-3 py-1.5 text-xs font-medium text-white hover:bg-primary/90 transition-colors"
            >
              <Plus className="h-3.5 w-3.5" />
              New Unit
            </button>
          </div>
        }
      />

      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
          <span>{totalCount} units</span>
          <div className="flex items-center gap-2">
            <button disabled={page <= 1} onClick={() => setPage((p) => p - 1)}
              className="px-3 py-1 rounded border border-border hover:bg-background-subtle disabled:opacity-40">Previous</button>
            <span>Page {page} of {totalPages}</span>
            <button disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}
              className="px-3 py-1 rounded border border-border hover:bg-background-subtle disabled:opacity-40">Next</button>
          </div>
        </div>
      )}

      {/* Create / Edit Modal */}
      <UomModal
        open={modalOpen}
        existing={editing}
        token={token}
        orgId={orgId}
        onClose={() => { setModalOpen(false); setEditing(null); }}
        onSaved={handleSaved}
      />

      {/* Delete Confirmation */}
      {deleting && (
        <DeleteModal
          uom={deleting}
          token={token}
          orgId={orgId}
          onClose={() => setDeleting(null)}
          onDeleted={handleDeleted}
        />
      )}
    </AppShell>
  );
}
