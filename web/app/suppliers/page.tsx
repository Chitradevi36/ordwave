"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Plus, Search, X, Pencil, Ban, CheckCircle2 } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";

// ─── Types ────────────────────────────────────────────────────────────────────
interface Supplier {
  id: number;
  name: string;
  code: string;
  status: string;
  phone: string | null;
  email: string | null;
  contact_person: string | null;
  gstin: string | null;
  city: string | null;
  state: string | null;
  payment_terms_days: number;
  credit_limit: number | null;
  supplier_products_count: number;
}

const STATUS_VARIANT: Record<string, "success" | "secondary" | "danger"> = {
  active:      "success",
  inactive:    "secondary",
  blacklisted: "danger",
};

const STATUSES = ["active", "inactive", "blacklisted"];

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function SuppliersPage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [suppliers,     setSuppliers]     = useState<Supplier[]>([]);
  const [loading,       setLoading]       = useState(false);
  const [actionLoading, setActionLoading] = useState<number | null>(null);
  const [search,        setSearch]        = useState("");
  const [status,        setStatus]        = useState("");
  const [page,          setPage]          = useState(1);
  const [totalPages,    setTotalPages]    = useState(1);
  const [totalCount,    setTotalCount]    = useState(0);

  const fetchSuppliers = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qs = new URLSearchParams({ page: String(page), per_page: "25" });
      if (search) qs.set("q",      search);
      if (status) qs.set("status", status);

      const res  = await fetch(`http://localhost:3001/api/v1/suppliers?${qs}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        setSuppliers(json.data);
        setTotalPages(json.meta?.total_pages ?? 1);
        setTotalCount(json.meta?.total_count  ?? 0);
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, search, status]);

  useEffect(() => { fetchSuppliers(); }, [fetchSuppliers]);

  const handleAction = useCallback(async (id: number, action: "blacklist" | "activate") => {
    if (!token || !orgId) return;
    setActionLoading(id);
    try {
      const res = await fetch(`http://localhost:3001/api/v1/suppliers/${id}/${action}`, {
        method:  "POST",
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (res.ok) fetchSuppliers();
    } finally {
      setActionLoading(null);
    }
  }, [token, orgId, fetchSuppliers]);

  const columns: Column<Supplier>[] = [
    {
      key:    "name",
      header: "Supplier",
      render: (_: unknown, row: Supplier) => (
        <div>
          <p className="font-medium text-text-primary">{row.name}</p>
          <p className="text-xs text-text-secondary">{row.code}</p>
        </div>
      ),
    },
    {
      key:    "contact",
      header: "Contact",
      render: (_: unknown, row: Supplier) => (
        <div>
          {row.contact_person && (
            <p className="text-sm text-text-primary">{row.contact_person}</p>
          )}
          {row.phone && (
            <p className="text-xs text-text-secondary">{row.phone}</p>
          )}
        </div>
      ),
    },
    {
      key:    "location",
      header: "Location",
      render: (_: unknown, row: Supplier) => (
        <span className="text-sm text-text-secondary">
          {[row.city, row.state].filter(Boolean).join(", ") || "—"}
        </span>
      ),
    },
    {
      key:    "gstin",
      header: "GSTIN",
      render: (v) => (
        <span className="text-sm font-mono text-text-secondary">
          {(v as string) ?? "—"}
        </span>
      ),
    },
    {
      key:    "payment_terms_days",
      header: "Payment Terms",
      render: (v) => (
        <span className="text-sm text-text-secondary">
          {(v as number) === 0 ? "Immediate" : `Net ${v}`}
        </span>
      ),
    },
    {
      key:    "supplier_products_count",
      header: "Products",
      render: (v) => (
        <span className="text-sm text-text-secondary">{v as number}</span>
      ),
    },
    {
      key:    "status",
      header: "Status",
      render: (v) => (
        <Badge variant={STATUS_VARIANT[v as string] ?? "secondary"}>
          {String(v).charAt(0).toUpperCase() + String(v).slice(1)}
        </Badge>
      ),
    },
    {
      key:    "actions_col",
      header: "",
      render: (_: unknown, row: Supplier) => (
        <div className="flex items-center gap-1" onClick={(e) => e.stopPropagation()}>
          <button
            onClick={() => router.push(`/suppliers/${row.id}/edit`)}
            className="p-1 rounded hover:bg-muted text-text-secondary hover:text-text-primary transition-colors"
            title="Edit"
          >
            <Pencil className="h-3.5 w-3.5" />
          </button>
          {row.status !== "blacklisted" ? (
            <button
              onClick={() => handleAction(row.id, "blacklist")}
              disabled={actionLoading === row.id}
              className="p-1 rounded hover:bg-muted text-text-secondary hover:text-danger transition-colors disabled:opacity-40"
              title="Blacklist"
            >
              <Ban className="h-3.5 w-3.5" />
            </button>
          ) : (
            <button
              onClick={() => handleAction(row.id, "activate")}
              disabled={actionLoading === row.id}
              className="p-1 rounded hover:bg-muted text-text-secondary hover:text-success transition-colors disabled:opacity-40"
              title="Activate"
            >
              <CheckCircle2 className="h-3.5 w-3.5" />
            </button>
          )}
        </div>
      ),
    },
  ];

  const clearFilters = () => { setSearch(""); setStatus(""); setPage(1); };
  const hasFilters = search || status;

  return (
    <AppShell title="Suppliers">
      <PageHeader
        title="Suppliers"
        description={`${totalCount} total suppliers`}
        actions={[
          { label: "Add Supplier", onClick: () => router.push("/suppliers/new"), icon: Plus },
        ]}
      />

      {/* Filters */}
      <div className="mb-4 flex flex-wrap gap-2 items-center">
        <div className="relative flex-1 min-w-[220px] max-w-sm">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            className="pl-8"
            placeholder="Search by name, code, GSTIN, phone…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          />
        </div>

        <select
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
          value={status}
          onChange={(e) => { setStatus(e.target.value); setPage(1); }}
        >
          <option value="">All Statuses</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>{s.charAt(0).toUpperCase() + s.slice(1)}</option>
          ))}
        </select>

        {hasFilters && (
          <Button variant="ghost" size="sm" onClick={clearFilters}>
            <X className="h-3.5 w-3.5 mr-1" /> Clear
          </Button>
        )}
      </div>

      {/* Table */}
      {loading ? (
        <div className="flex items-center justify-center h-48">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      ) : (
        <>
          <DataTable
            columns={columns}
            data={suppliers}
            emptyMessage="No suppliers found."
            onRowClick={(row) => router.push(`/suppliers/${row.id}`)}
          />

          {totalPages > 1 && (
            <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
              <span>Page {page} of {totalPages}</span>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
                  Previous
                </Button>
                <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
                  Next
                </Button>
              </div>
            </div>
          )}
        </>
      )}
    </AppShell>
  );
}
