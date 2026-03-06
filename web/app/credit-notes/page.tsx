"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";

import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";
import { Search } from "lucide-react";

const STATUS_TABS = [
  { key: "",       label: "All" },
  { key: "draft",  label: "Draft" },
  { key: "issued", label: "Issued" },
  { key: "void",   label: "Void" },
];

const STATUS_VARIANT: Record<string, "secondary" | "warning" | "default" | "success" | "danger"> = {
  draft:  "secondary",
  issued: "success",
  void:   "danger",
};

interface CreditNoteSummary {
  id:                 number;
  credit_note_number: string;
  status:             string;
  subtotal:           number;
  tax_total:          number;
  total:              number;
  issued_at:          string | null;
  created_at:         string;
  customer:           { id: number; name: string };
  branch:             { id: number; name: string };
  return_request:     { id: number; return_number: string };
}

export default function CreditNotesPage() {
  const router  = useRouter();
  const { token, orgId } = useOrgBranch();

  const [notes, setNotes]           = useState<CreditNoteSummary[]>([]);
  const [loading, setLoading]       = useState(true);
  const [activeTab, setActiveTab]   = useState("");
  const [search, setSearch]         = useState("");
  const [page, setPage]             = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [counts, setCounts]         = useState<Record<string, number>>({});

  const fetchNotes = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page), per_page: "25" });
      if (activeTab) params.set("status", activeTab);
      if (search)    params.set("q", search);

      const res = await fetch(`/api/v1/credit_notes?${params}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (!res.ok) throw new Error("Failed to fetch");
      const body = await res.json();
      setNotes(body.data);
      setTotalPages(body.meta?.total_pages ?? 1);
      setCounts(body.meta?.counts ?? {});
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, activeTab, search]);

  useEffect(() => { fetchNotes(); }, [fetchNotes]);
  useEffect(() => { setPage(1); }, [activeTab, search]);

  const totalCount = Object.values(counts).reduce((s, v) => s + v, 0);

  const columns: Column<CreditNoteSummary>[] = [
    {
      key:    "credit_note_number",
      header: "Credit Note #",
      render: (_, row) => (
        <span className="font-mono text-sm font-medium">{row.credit_note_number}</span>
      ),
    },
    {
      key:    "customer",
      header: "Customer",
      render: (_, row) => <span className="font-medium">{row.customer.name}</span>,
    },
    {
      key:    "return_request",
      header: "Return #",
      render: (_, row) => (
        <span
          className="font-mono text-xs text-primary cursor-pointer hover:underline"
          onClick={(e) => { e.stopPropagation(); router.push(`/returns/${row.return_request.id}`); }}
        >
          {row.return_request.return_number}
        </span>
      ),
    },
    {
      key:    "status",
      header: "Status",
      render: (_, row) => (
        <Badge variant={STATUS_VARIANT[row.status] ?? "secondary"}>
          {row.status}
        </Badge>
      ),
    },
    {
      key:    "total",
      header: "Total",
      render: (_, row) => (
        <span className="font-semibold text-success">
          Rs {Number(row.total).toLocaleString("en-IN", { minimumFractionDigits: 2 })}
        </span>
      ),
    },
    {
      key:    "issued_at",
      header: "Issued At",
      render: (_, row) => (
        <span className="text-sm text-text-secondary">
          {row.issued_at ? new Date(row.issued_at).toLocaleDateString("en-IN") : "—"}
        </span>
      ),
    },
  ];

  return (
    <AppShell>
      <PageHeader
        title="Credit Notes"
        description="Credit notes issued against customer returns"
      />

      {/* Status tabs — underline style */}
      <div className="flex items-center gap-1 border-b border-border mb-4 overflow-x-auto">
        {STATUS_TABS.map((t) => {
          const n = t.key ? (counts[t.key] ?? 0) : totalCount;
          return (
            <button
              key={t.key}
              onClick={() => { setActiveTab(t.key); setPage(1); }}
              className={`flex items-center gap-1.5 px-4 py-2 text-sm font-medium whitespace-nowrap transition-colors ${
                activeTab === t.key
                  ? "border-b-2 border-accent text-accent"
                  : "text-text-secondary hover:text-text-primary"
              }`}
            >
              {t.label}
              {n > 0 && (
                <span className={`inline-flex items-center justify-center rounded-full min-w-[18px] px-1 py-0.5 text-[10px] font-medium ${
                  activeTab === t.key
                    ? "bg-primary/10 text-primary"
                    : "bg-background-subtle text-text-secondary"
                }`}>
                  {n}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* Search */}
      <div className="relative mb-4 max-w-sm">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
        <Input
          placeholder="Search credit note # or customer..."
          value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          className="pl-9"
        />
      </div>

      <DataTable
        columns={columns}
        data={notes}
        isLoading={loading}
        onRowClick={(row) => router.push(`/credit-notes/${row.id}`)}
        emptyMessage="No credit notes found"
      />

      {totalPages > 1 && (
        <div className="flex justify-end gap-2 pt-3">
          <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
            Previous
          </Button>
          <span className="text-sm text-text-secondary self-center">Page {page} of {totalPages}</span>
          <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
            Next
          </Button>
        </div>
      )}
    </AppShell>
  );
}
