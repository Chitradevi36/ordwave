"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Plus, Search, X, Pencil, Ban, CheckCircle2, Upload } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";

// ─── Types ───────────────────────────────────────────────────────────────────
interface Route {
  id: number;
  name: string;
  code: string;
}

interface CreditAccount {
  credit_limit: number;
  current_balance: number;
  available_credit: number;
  overdue_amount: number;
  overdue_days: number;
}

interface Customer {
  id: number;
  name: string;
  code: string;
  channel: string;
  tier: string;
  status: string;
  phone: string | null;
  email: string | null;
  credit_limit: number;
  route: Route | null;
  credit_account: CreditAccount | null;
}

const CHANNEL_LABEL: Record<string, string> = {
  general_trade: "General Trade",
  modern_trade: "Modern Trade",
  horeca: "HoReCa",
  pharmacy: "Pharmacy",
  electronics: "Electronics",
  wholesale: "Wholesale",
  distributor: "Distributor",
};

const TIER_VARIANT: Record<string, "default" | "secondary" | "success" | "warning" | "outline"> = {
  platinum: "default",
  gold: "warning",
  silver: "secondary",
  bronze: "outline",
};

const STATUS_VARIANT: Record<string, "success" | "danger" | "warning"> = {
  active: "success", inactive: "danger", blocked: "warning",
};

const CHANNELS = ["general_trade", "modern_trade", "horeca", "pharmacy", "electronics", "wholesale", "distributor"];
const TIERS    = ["platinum", "gold", "silver", "bronze"];

// ─── Saved views ─────────────────────────────────────────────────────────────
type SavedView = "all" | "overdue" | "blocked" | "no_route" | "near_limit";
const SAVED_VIEWS: { key: SavedView; label: string }[] = [
  { key: "all",        label: "All Customers" },
  { key: "overdue",    label: "Overdue" },
  { key: "blocked",    label: "Blocked" },
  { key: "no_route",   label: "No Route" },
  { key: "near_limit", label: "Near Limit" },
];

const VIEW_PARAMS: Record<SavedView, Record<string, string>> = {
  all:        {},
  overdue:    { credit_status: "overdue" },
  blocked:    { status: "blocked" },
  no_route:   { no_route: "true" },
  near_limit: { credit_status: "near_limit" },
};

// ─── Credit bar ───────────────────────────────────────────────────────────────
function CreditBar({ ca }: { ca: CreditAccount | null }) {
  if (!ca || ca.credit_limit === 0) return <span className="text-sm text-text-secondary">—</span>;
  const utilPct = Math.min(100, Math.round((ca.current_balance / ca.credit_limit) * 100));
  const barColor = utilPct >= 90 ? "bg-danger" : utilPct >= 70 ? "bg-warning" : "bg-success";
  return (
    <div className="min-w-[110px]">
      <p className="text-xs text-text-secondary leading-tight">
        ₹{ca.current_balance.toLocaleString("en-IN")}{" "}
        <span className="text-text-secondary/50">/</span>{" "}
        ₹{ca.credit_limit.toLocaleString("en-IN")}
      </p>
      <div className="mt-1 h-1.5 w-full rounded-full bg-border overflow-hidden">
        <div className={`h-full rounded-full ${barColor}`} style={{ width: `${utilPct}%` }} />
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function CustomersPage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [customers,     setCustomers]     = useState<Customer[]>([]);
  const [loading,       setLoading]       = useState(false);
  const [actionLoading, setActionLoading] = useState<number | null>(null);
  const [search,        setSearch]        = useState("");
  const [channel,       setChannel]       = useState("");
  const [tier,          setTier]          = useState("");
  const [status,        setStatus]        = useState("");
  const [savedView,     setSavedView]     = useState<SavedView>("all");
  const [page,          setPage]          = useState(1);
  const [totalPages,    setTotalPages]    = useState(1);
  const [totalCount,    setTotalCount]    = useState(0);
  const [importing,     setImporting]     = useState(false);
  const [importMsg,     setImportMsg]     = useState<{ type: "success" | "error"; text: string } | null>(null);

  const handleViewChange = (view: SavedView) => {
    setSavedView(view);
    setSearch(""); setChannel(""); setTier(""); setStatus("");
    setPage(1);
  };

  const handleBlockCustomer = useCallback(async (id: number, action: "block" | "unblock") => {
    if (!token || !orgId) return;
    setActionLoading(id);
    try {
      const res = await fetch(`http://localhost:3001/api/v1/customers/${id}/${action}`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (res.ok) {
        setCustomers((prev) =>
          prev.map((c) => c.id === id ? { ...c, status: action === "block" ? "blocked" : "active" } : c)
        );
      }
    } finally {
      setActionLoading(null);
    }
  }, [token, orgId]);

  // Columns defined inside component to close over router + handleBlockCustomer
  const columns: Column<Customer>[] = [
    {
      key: "name",
      header: "Customer",
      render: (_: unknown, row: Customer) => (
        <div>
          <p className="font-medium text-text-primary">{row.name}</p>
          <p className="text-xs text-text-secondary">{row.code}</p>
        </div>
      ),
    },
    {
      key: "channel",
      header: "Channel",
      render: (v) => <span className="text-sm text-text-secondary">{CHANNEL_LABEL[v as string] ?? v}</span>,
    },
    {
      key: "route",
      header: "Route",
      render: (_: unknown, row: Customer) => (
        <span className="text-sm">{row.route?.name ?? <span className="text-text-secondary">—</span>}</span>
      ),
    },
    {
      key: "tier",
      header: "Tier",
      render: (v) => (
        <Badge variant={TIER_VARIANT[v as string] ?? "outline"}>
          {String(v).charAt(0).toUpperCase() + String(v).slice(1)}
        </Badge>
      ),
    },
    {
      key: "credit_bar",
      header: "Credit (Used / Limit)",
      render: (_: unknown, row: Customer) => <CreditBar ca={row.credit_account} />,
    },
    {
      key: "overdue_col",
      header: "Overdue",
      render: (_: unknown, row: Customer) => {
        const ca = row.credit_account;
        if (!ca || ca.overdue_amount <= 0) return <span className="text-sm text-text-secondary">—</span>;
        return (
          <div>
            <p className="text-sm font-medium text-danger">₹{ca.overdue_amount.toLocaleString("en-IN")}</p>
            {ca.overdue_days > 0 && (
              <span className="inline-flex items-center rounded-full bg-danger/10 px-1.5 py-0.5 text-xs font-medium text-danger mt-0.5">
                {ca.overdue_days}d
              </span>
            )}
          </div>
        );
      },
    },
    {
      key: "status",
      header: "Status",
      render: (v) => (
        <Badge variant={STATUS_VARIANT[v as string] ?? "outline"}>
          {String(v).charAt(0).toUpperCase() + String(v).slice(1)}
        </Badge>
      ),
    },
    {
      key: "actions_col",
      header: "",
      render: (_: unknown, row: Customer) => (
        <div className="flex items-center gap-1" onClick={(e) => e.stopPropagation()}>
          <button
            onClick={() => router.push(`/customers/${row.id}/edit`)}
            className="p-1 rounded hover:bg-muted text-text-secondary hover:text-text-primary transition-colors"
            title="Edit"
          >
            <Pencil className="h-3.5 w-3.5" />
          </button>
          {row.status !== "blocked" ? (
            <button
              onClick={() => handleBlockCustomer(row.id, "block")}
              disabled={actionLoading === row.id}
              className="p-1 rounded hover:bg-muted text-text-secondary hover:text-danger transition-colors disabled:opacity-40"
              title="Block"
            >
              <Ban className="h-3.5 w-3.5" />
            </button>
          ) : (
            <button
              onClick={() => handleBlockCustomer(row.id, "unblock")}
              disabled={actionLoading === row.id}
              className="p-1 rounded hover:bg-muted text-text-secondary hover:text-success transition-colors disabled:opacity-40"
              title="Unblock"
            >
              <CheckCircle2 className="h-3.5 w-3.5" />
            </button>
          )}
        </div>
      ),
    },
  ];

  const fetchCustomers = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const qs = new URLSearchParams({ page: String(page), per_page: "20" });
      if (search)  qs.set("q", search);
      if (channel) qs.set("channel", channel);
      if (tier)    qs.set("tier", tier);
      if (status)  qs.set("status", status);
      Object.entries(VIEW_PARAMS[savedView]).forEach(([k, v]) => qs.set(k, v));

      const res  = await fetch(`http://localhost:3001/api/v1/customers?${qs}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        setCustomers(json.data);
        setTotalPages(json.meta?.total_pages ?? 1);
        setTotalCount(json.meta?.total_count  ?? 0);
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, search, channel, tier, status, savedView]);

  useEffect(() => { fetchCustomers(); }, [fetchCustomers]);

  const clearFilters = () => {
    setSearch(""); setChannel(""); setTier(""); setStatus(""); setPage(1);
  };

  const handleBulkImport = useCallback(async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !token || !orgId) return;
    setImporting(true);
    setImportMsg(null);
    try {
      const form = new FormData();
      form.append("file", file);
      const res = await fetch(`http://localhost:3001/api/v1/customers/bulk_import`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        body: form,
      });
      const json = await res.json();
      if (res.status === 401) {
        setImportMsg({ type: "error", text: "Session expired. Please log in again." });
        return;
      }
      if (res.ok) {
        const d = json.data;
        const skippedNote = d.skipped_rows?.length ? ` ${d.skipped_rows.length} skipped (duplicates).` : "";
        const failedNote  = d.failed_rows?.length  ? ` ${d.failed_rows.length} failed.` : "";
        setImportMsg({ type: "success", text: `${d.success_count} customers imported.${skippedNote}${failedNote}` });
        fetchCustomers();
      } else {
        setImportMsg({ type: "error", text: json.errors?.join(", ") ?? "Import failed" });
      }
    } catch {
      setImportMsg({ type: "error", text: "Network error during import" });
    } finally {
      setImporting(false);
      e.target.value = "";
    }
  }, [token, orgId, fetchCustomers]);

  const hasFilters = search || channel || tier || status;

  return (
    <AppShell title="Customers">
      <PageHeader
        title="Customers"
        description={`${totalCount} total customers`}
        actions={[
          {
            label: importing ? "Importing…" : "Import CSV",
            onClick: () => document.getElementById("customer-import-input")?.click(),
            icon: Upload,
            variant: "outline",
          },
          { label: "Add Customer", onClick: () => router.push("/customers/new"), icon: Plus },
        ]}
      />

      {/* Hidden file input for bulk import */}
      <input
        id="customer-import-input"
        type="file"
        accept=".csv"
        className="sr-only"
        onChange={handleBulkImport}
      />

      {/* Import result / sample download */}
      <div className="-mt-3 mb-4 flex items-center gap-3">
        <a
          href="/samples/sample_customers.csv"
          download
          className="text-xs text-accent hover:underline"
        >
          Download sample CSV
        </a>
        {importMsg && (
          <span className={`text-xs font-medium ${
            importMsg.type === "success" ? "text-success" : "text-danger"
          }`}>
            {importMsg.text}
          </span>
        )}
      </div>

      {/* Saved view tabs */}
      <div className="flex mb-4 border-b border-border">
        {SAVED_VIEWS.map((v) => (
          <button
            key={v.key}
            onClick={() => handleViewChange(v.key)}
            className={`px-4 py-2.5 text-sm font-medium border-b-2 transition-colors whitespace-nowrap ${
              savedView === v.key
                ? "border-accent text-accent"
                : "border-transparent text-text-secondary hover:text-text-primary"
            }`}
          >
            {v.label}
          </button>
        ))}
      </div>

      {/* Filters */}
      <div className="mb-4 flex flex-wrap gap-2 items-center">
        <div className="relative flex-1 min-w-[220px] max-w-sm">
          <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            className="pl-8"
            placeholder="Search by name, code, phone…"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          />
        </div>

        <select
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
          value={channel}
          onChange={(e) => { setChannel(e.target.value); setPage(1); }}
        >
          <option value="">All Channels</option>
          {CHANNELS.map((c) => (
            <option key={c} value={c}>{CHANNEL_LABEL[c]}</option>
          ))}
        </select>

        <select
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
          value={tier}
          onChange={(e) => { setTier(e.target.value); setPage(1); }}
        >
          <option value="">All Tiers</option>
          {TIERS.map((t) => (
            <option key={t} value={t}>{t.charAt(0).toUpperCase() + t.slice(1)}</option>
          ))}
        </select>

        <select
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
          value={status}
          onChange={(e) => { setStatus(e.target.value); setSavedView("all"); setPage(1); }}
        >
          <option value="">All Statuses</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
          <option value="blocked">Blocked</option>
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
            data={customers}
            emptyMessage="No customers found."
            onRowClick={(row) => router.push(`/customers/${row.id}`)}
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
