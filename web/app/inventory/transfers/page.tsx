"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { API_URL } from "@/lib/api/client";

import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Search, Plus, ArrowLeftRight } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { cn } from "@/lib/utils";

// ─── Types ────────────────────────────────────────────────────────────────────
interface TransferSummary {
  id: number;
  transfer_number: string;
  transfer_date: string;
  status: string;
  lines_count: number;
  total_qty_dispatched: number;
  total_qty_received: number;
  notes: string | null;
  created_at: string;
  source_branch: { id: number; name: string } | null;
  destination_branch: { id: number; name: string } | null;
  created_by: { id: number; name: string } | null;
}

interface Branch { id: number; name: string; }

// ─── Status config ────────────────────────────────────────────────────────────
const STATUS_TABS = [
  { value: "",                  label: "All" },
  { value: "draft",             label: "Draft" },
  { value: "dispatched",        label: "Dispatched" },
  { value: "partially_received",label: "Partial" },
  { value: "received",          label: "Received" },
  { value: "cancelled",         label: "Cancelled" },
];

const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "success" | "danger" | "outline"> = {
  draft:              "secondary",
  dispatched:         "warning",
  partially_received: "default",
  received:           "success",
  cancelled:          "outline",
};

const STATUS_LABEL: Record<string, string> = {
  draft:              "Draft",
  dispatched:         "Dispatched",
  partially_received: "Partial",
  received:           "Received",
  cancelled:          "Cancelled",
};

function fmtDate(d: string) {
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function TransfersPage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [transfers,  setTransfers]  = useState<TransferSummary[]>([]);
  const [branches,   setBranches]   = useState<Branch[]>([]);
  const [isLoading,  setIsLoading]  = useState(false);
  const [activeTab,  setActiveTab]  = useState("");
  const [search,     setSearch]     = useState("");
  const [branchId,   setBranchId]   = useState("");
  const [page,       setPage]       = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  useEffect(() => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/branches?per_page=200`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    }).then((r) => r.json()).then((j) => setBranches(j.data ?? []));
  }, [token, orgId]);

  const fetchTransfers = useCallback(async () => {
    if (!token || !orgId) return;
    setIsLoading(true);
    try {
      const p = new URLSearchParams({
        page: String(page), per_page: "25",
        ...(activeTab  && { status: activeTab }),
        ...(branchId   && { branch_id: branchId }),
        ...(search     && { q: search }),
      });
      const res = await fetch(`${API_URL}/api/v1/stock_transfers?${p}`,
        { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } });
      const json = await res.json();
      setTransfers(json.data ?? []);
      setTotalPages(json.meta?.total_pages ?? 1);
      setTotalCount(json.meta?.total_count ?? 0);
    } finally { setIsLoading(false); }
  }, [token, orgId, page, activeTab, branchId, search]);

  useEffect(() => { setPage(1); }, [activeTab, branchId, search]);
  useEffect(() => { fetchTransfers(); }, [fetchTransfers]);

  const columns: Column<TransferSummary>[] = [
    {
      key: "transfer_number", header: "Transfer #",
      render: (_: unknown, row: TransferSummary) => (
        <span className="font-mono font-medium text-sm">{row.transfer_number}</span>
      ),
    },
    {
      key: "route", header: "Source → Destination",
      render: (_: unknown, row: TransferSummary) => (
        <div className="flex items-center gap-1.5 text-sm">
          <span>{row.source_branch?.name ?? "—"}</span>
          <ArrowLeftRight className="h-3.5 w-3.5 text-text-secondary shrink-0" />
          <span>{row.destination_branch?.name ?? "—"}</span>
        </div>
      ),
    },
    {
      key: "status", header: "Status",
      render: (_: unknown, row: TransferSummary) => (
        <Badge variant={STATUS_VARIANT[row.status] ?? "secondary"}>
          {STATUS_LABEL[row.status] ?? row.status}
        </Badge>
      ),
    },
    {
      key: "lines_count", header: "Lines",
      render: (_: unknown, row: TransferSummary) => (
        <span className="text-sm">{row.lines_count}</span>
      ),
    },
    {
      key: "total_qty_dispatched", header: "Dispatched",
      render: (_: unknown, row: TransferSummary) => (
        <span className="font-mono text-sm">{Number(row.total_qty_dispatched).toLocaleString("en-IN")}</span>
      ),
    },
    {
      key: "total_qty_received", header: "Received",
      render: (_: unknown, row: TransferSummary) => (
        <span className="font-mono text-sm">{Number(row.total_qty_received).toLocaleString("en-IN")}</span>
      ),
    },
    {
      key: "transfer_date", header: "Date",
      render: (_: unknown, row: TransferSummary) => (
        <span className="text-sm text-text-secondary">{fmtDate(row.transfer_date)}</span>
      ),
    },
  ];

  return (
    <AppShell hideBreadcrumb>

      <PageHeader
        title="Stock Transfers"
        description={`${totalCount} transfer${totalCount !== 1 ? "s" : ""}`}
        actions={[{ label: "New Transfer", onClick: () => router.push("/inventory/transfers/new"), icon: Plus }]}
      />

      {/* ── Status Tabs ── */}
      <div className="flex gap-1 border-b mb-4 overflow-x-auto">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.value}
            onClick={() => setActiveTab(tab.value)}
            className={cn(
              "px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors",
              activeTab === tab.value
                ? "border-primary text-primary"
                : "border-transparent text-text-secondary hover:text-text-primary"
            )}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* ── Filters ── */}
      <div className="flex flex-wrap items-center gap-3 mb-4">
        <select
          value={branchId}
          onChange={(e) => setBranchId(e.target.value)}
          className="h-9 rounded-md border border-input bg-background px-3 text-sm"
        >
          <option value="">All branches</option>
          {branches.map((b) => (
            <option key={b.id} value={String(b.id)}>{b.name}</option>
          ))}
        </select>
        <div className="relative">
          <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-text-secondary" />
          <Input
            className="pl-8 w-56"
            placeholder="Search transfer #…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </div>

      <DataTable
        columns={columns}
        data={transfers}
        isLoading={isLoading}
        emptyMessage="No transfers found."
        onRowClick={(row) => router.push(`/inventory/transfers/${row.id}`)}
      />

      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-between text-sm text-text-secondary">
          <span>Page {page} of {totalPages}</span>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Previous</Button>
            <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>Next</Button>
          </div>
        </div>
      )}
    </AppShell>
  );
}
