"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { EmptyState } from "@/components/ui/empty-state";
import { ClipboardList, Search } from "lucide-react";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────
interface PickListSummary {
  id: number;
  pick_number: string;
  status: string;
  started_at: string | null;
  completed_at: string | null;
  created_at: string;
  total_items: number;
  picked_items: number;
  branch: { id: number; name: string };
  sales_order: { id: number; order_number: string };
  picker: { id: number; name: string } | null;
}

// ─── Constants ────────────────────────────────────────────────────────────────
const STATUS_TABS = [
  { key: "",           label: "All" },
  { key: "pending",    label: "Pending" },
  { key: "in_progress",label: "In Progress" },
  { key: "completed",  label: "Completed" },
  { key: "cancelled",  label: "Cancelled" },
];

const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "success" | "danger" | "outline"> = {
  pending:     "secondary",
  in_progress: "warning",
  completed:   "success",
  cancelled:   "outline",
};

// ─── Helpers ──────────────────────────────────────────────────────────────────
function fmtDateTime(d: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleString("en-IN", {
    day: "2-digit", month: "short", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1)  return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24)  return `${hrs}h ago`;
  return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short" });
}

// ─── Progress Bar ─────────────────────────────────────────────────────────────
function ProgressBar({ picked, total }: { picked: number; total: number }) {
  const pct = total > 0 ? Math.round((picked / total) * 100) : 0;
  return (
    <div className="flex items-center gap-2">
      <div className="flex-1 h-1.5 rounded-full bg-border overflow-hidden">
        <div
          className={`h-full rounded-full transition-all ${pct === 100 ? "bg-success" : "bg-primary"}`}
          style={{ width: `${pct}%` }}
        />
      </div>
      <span className="text-xs text-text-secondary whitespace-nowrap">{picked}/{total}</span>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function PickListsPage() {
  const router = useRouter();
  const { token, orgId, branches } = useOrgBranch();

  const [pickLists, setPickLists] = useState<PickListSummary[]>([]);
  const [loading, setLoading]     = useState(false);
  const [tab, setTab]             = useState("");
  const [search, setSearch]       = useState("");
  const [branchFilter, setBranchFilter] = useState("");
  const [toast, setToast] = useState<{ type: "success" | "error"; msg: string } | null>(null);

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  const fetchPickLists = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qp = new URLSearchParams();
      if (tab)          qp.set("status",    tab);
      if (branchFilter) qp.set("branch_id", branchFilter);
      if (search)       qp.set("q",         search);
      qp.set("per_page", "50");

      const res  = await fetch(`${API_URL}/api/v1/pick_lists?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) setPickLists(json.data ?? []);
      else        showToast("error", json.errors?.[0] ?? "Failed to load pick lists");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, tab, branchFilter, search]);

  useEffect(() => { void fetchPickLists(); }, [fetchPickLists]);

  return (
    <AppShell breadcrumbs={[
      { label: "Operations", href: "/operations" },
      { label: "Pick Lists" },
    ]}>
      {toast && (
        <div className={`fixed top-4 right-4 z-50 rounded-lg px-4 py-3 text-sm text-white shadow-lg ${
          toast.type === "success" ? "bg-success" : "bg-danger"
        }`}>
          {toast.msg}
        </div>
      )}

      <PageHeader title="Pick Lists" description="Warehouse picking tasks for approved orders" />

      {/* Status tabs */}
      <div className="flex items-center gap-1 border-b border-border mb-4 overflow-x-auto">
        {STATUS_TABS.map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={`px-4 py-2 text-sm font-medium whitespace-nowrap transition-colors ${
              tab === t.key
                ? "border-b-2 border-accent text-accent"
                : "text-text-secondary hover:text-text-primary"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Search + branch filter */}
      <div className="flex items-center gap-2 mb-4 flex-wrap">
        <div className="relative flex-1 min-w-[180px] max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            placeholder="Search pick # or order #…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>
        <select
          value={branchFilter}
          onChange={(e) => setBranchFilter(e.target.value)}
          className="rounded-md border border-border px-2 py-1.5 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary"
        >
          <option value="">All branches</option>
          {branches.map((b) => (
            <option key={b.id} value={String(b.id)}>{b.name}</option>
          ))}
        </select>
      </div>

      {/* Table */}
      {!loading && pickLists.length === 0 ? (
        <EmptyState
          icon={ClipboardList}
          title="No pick lists found"
          description={
            tab
              ? `No ${tab.replace("_", " ")} pick lists.`
              : "Pick lists are created automatically when orders are approved."
          }
        />
      ) : (
        <div className="overflow-x-auto rounded-xl border border-border">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border bg-background-subtle text-left text-xs text-text-secondary">
                <th className="px-4 py-3 font-semibold">Pick #</th>
                <th className="px-4 py-3 font-semibold">Order</th>
                <th className="px-4 py-3 font-semibold">Branch</th>
                <th className="px-4 py-3 font-semibold">Progress</th>
                <th className="px-4 py-3 font-semibold">Status</th>
                <th className="px-4 py-3 font-semibold">Picker</th>
                <th className="px-4 py-3 font-semibold">Created</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border/60">
              {loading
                ? Array.from({ length: 6 }).map((_, i) => (
                    <tr key={i}>
                      {Array.from({ length: 7 }).map((_, j) => (
                        <td key={j} className="px-4 py-3">
                          <div className="h-4 rounded bg-background-subtle animate-pulse" />
                        </td>
                      ))}
                    </tr>
                  ))
                : pickLists.map((pl) => (
                    <tr
                      key={pl.id}
                      className="hover:bg-background-subtle/60 cursor-pointer transition-colors"
                      onClick={() => router.push(`/operations/pick-lists/${pl.id}`)}
                    >
                      <td className="px-4 py-3 font-mono font-semibold text-primary">{pl.pick_number}</td>
                      <td className="px-4 py-3">
                        <span
                          className="text-primary hover:underline cursor-pointer"
                          onClick={(e) => {
                            e.stopPropagation();
                            router.push(`/orders/${pl.sales_order.id}`);
                          }}
                        >
                          {pl.sales_order.order_number}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-text-secondary">{pl.branch.name}</td>
                      <td className="px-4 py-3 min-w-[140px]">
                        <ProgressBar picked={pl.picked_items} total={pl.total_items} />
                      </td>
                      <td className="px-4 py-3">
                        <Badge variant={STATUS_VARIANT[pl.status] ?? "secondary"}>
                          {pl.status.replace("_", " ")}
                        </Badge>
                      </td>
                      <td className="px-4 py-3 text-text-secondary">
                        {pl.picker?.name ?? <span className="italic text-xs">Unassigned</span>}
                      </td>
                      <td className="px-4 py-3 text-text-secondary" title={fmtDateTime(pl.created_at)}>
                        {relativeTime(pl.created_at)}
                      </td>
                    </tr>
                  ))}
            </tbody>
          </table>
        </div>
      )}
    </AppShell>
  );
}
