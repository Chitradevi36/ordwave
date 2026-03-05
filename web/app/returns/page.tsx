"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Breadcrumb, BreadcrumbItem } from "@/components/ui/breadcrumb";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";
import { Plus, Search } from "lucide-react";

const STATUS_TABS = [
  { key: "",                    label: "All" },
  { key: "draft",               label: "Draft" },
  { key: "submitted",           label: "Submitted" },
  { key: "qc_in_progress",      label: "QC In Progress" },
  { key: "qc_completed",        label: "QC Completed" },
  { key: "credit_note_issued",  label: "Credit Noted" },
  { key: "cancelled",           label: "Cancelled" },
];

const STATUS_VARIANT: Record<string, "secondary" | "warning" | "default" | "success" | "danger" | "outline"> = {
  draft:               "secondary",
  submitted:           "warning",
  qc_in_progress:      "warning",
  qc_completed:        "default",
  credit_note_issued:  "success",
  cancelled:           "danger",
};

interface ReturnSummary {
  id: number;
  return_number: string;
  status: string;
  source_type: string;
  return_date: string;
  item_count: number;
  created_at: string;
  customer: { id: number; name: string };
  branch: { id: number; name: string };
  credit_note: { credit_note_number: string; total: number } | null;
}

export default function ReturnsPage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [returns, setReturns]       = useState<ReturnSummary[]>([]);
  const [loading, setLoading]       = useState(true);
  const [activeTab, setActiveTab]   = useState("");
  const [search, setSearch]         = useState("");
  const [page, setPage]             = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [counts, setCounts]         = useState<Record<string, number>>({});

  const fetchReturns = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page), per_page: "25" });
      if (activeTab) params.set("status", activeTab);
      if (search)    params.set("q", search);

      const res = await fetch(`/api/v1/return_requests?${params}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (!res.ok) throw new Error("Failed to fetch returns");
      const body = await res.json();
      setReturns(body.data);
      setTotalPages(body.meta?.total_pages ?? 1);
      setCounts(body.meta?.counts ?? {});
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, activeTab, search]);

  useEffect(() => { fetchReturns(); }, [fetchReturns]);
  useEffect(() => { setPage(1); }, [activeTab, search]);

  const totalCount = Object.values(counts).reduce((s, v) => s + v, 0);

  const columns: Column<ReturnSummary>[] = [
    {
      key:    "return_number",
      header: "Return #",
      render: (_, row) => <span className="font-mono text-sm font-medium">{row.return_number}</span>,
    },
    {
      key:    "customer",
      header: "Customer",
      render: (_, row) => <span className="font-medium">{row.customer.name}</span>,
    },
    {
      key:    "source_type",
      header: "Source",
      render: (_, row) => <span className="capitalize text-sm">{row.source_type}</span>,
    },
    {
      key:    "status",
      header: "Status",
      render: (_, row) => (
        <Badge variant={STATUS_VARIANT[row.status] ?? "secondary"}>
          {row.status.replace(/_/g, " ")}
        </Badge>
      ),
    },
    {
      key:    "item_count",
      header: "Items",
      render: (_, row) => <span className="text-sm text-text-secondary">{row.item_count}</span>,
    },
    {
      key:    "return_date",
      header: "Date",
      render: (_, row) => (
        <span className="text-sm text-text-secondary">
          {new Date(row.return_date).toLocaleDateString("en-IN")}
        </span>
      ),
    },
    {
      key:    "credit_note",
      header: "Credit Note",
      render: (_, row) =>
        row.credit_note ? (
          <span className="font-mono text-xs text-success">{row.credit_note.credit_note_number}</span>
        ) : (
          <span className="text-text-secondary text-xs">—</span>
        ),
    },
  ];

  const breadcrumbs: BreadcrumbItem[] = [{ label: "Returns", href: "/returns" }];

  return (
    <AppShell>
      <Breadcrumb items={breadcrumbs} />

      <PageHeader
        title="Returns"
        description="Manage customer returns, QC, and credit notes"
        actions={[
          { label: "New Return", onClick: () => router.push("/returns/new"), icon: Plus },
        ]}
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
                  ? "border-b-2 border-primary text-primary"
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
          placeholder="Search return # or customer"
          value={search}
          onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          className="pl-9"
        />
      </div>

      <DataTable
        columns={columns}
        data={returns}
        isLoading={loading}
        onRowClick={(row) => router.push(`/returns/${row.id}`)}
        emptyMessage="No returns found"
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
