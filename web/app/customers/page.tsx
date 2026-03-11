"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Modal } from "@/components/ui/modal";
import { Plus, Search, X, Pencil, Ban, CheckCircle2, Upload, Download, CheckCircle, FileWarning } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { CreditUsageBar } from "@/components/ui/credit-usage-bar";
import { API_URL } from "@/lib/api/client";

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

interface CreditUsageSummary {
  order_exposure:    number;
  hold_exposure:     number;
  credit_used_total: number;
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
  credit_usage_summary: CreditUsageSummary | null;
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
  { key: "all",        label: "All" },
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

// ─── Bulk Import Modal ────────────────────────────────────────────────────────
function CustomersBulkImportModal({
  token, orgId, onClose, onImported,
}: {
  token:      string | null;
  orgId:      string | null;
  onClose:    () => void;
  onImported: () => void;
}) {
  const [file,    setFile]    = useState<File | null>(null);
  const [loading, setLoading] = useState(false);
  const [result,  setResult]  = useState<{
    success_count: number;
    skipped_rows:  { row: number; code: string; reason: string }[];
    failed_rows:   { row: number; code: string; errors: string[] }[];
  } | null>(null);
  const [error,   setError]   = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  const downloadSample = () => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/customers/sample_csv`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.blob())
      .then((blob) => {
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url; a.download = "sample_customers.csv"; a.click();
        URL.revokeObjectURL(url);
      });
  };

  const handleUpload = async () => {
    if (!file || !token || !orgId) return;
    setLoading(true); setError(""); setResult(null);
    try {
      const fd = new FormData();
      fd.append("file", file);
      const res = await fetch(`${API_URL}/api/v1/customers/bulk_import`, {
        method:  "POST",
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        body:    fd,
      });
      const json = await res.json();
      if (res.ok) setResult(json.data);
      else        setError(json.errors?.join(", ") ?? "Import failed");
    } catch {
      setError("Network error — please try again");
    } finally {
      setLoading(false);
    }
  };

  const handleDone = () => {
    if (result && result.success_count > 0) onImported();
    onClose();
  };

  return (
    <Modal open onClose={onClose} title="Bulk Import Customers" size="lg">
      <div className="space-y-5">
        <div className="rounded-md border border-border bg-background-subtle px-4 py-3 text-sm text-text-secondary">
          <p className="font-medium text-text-primary mb-1">CSV format</p>
          <p>Required: <code className="font-mono text-xs bg-white border border-border rounded px-1">name</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">code</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">branch_code</code></p>
          <p className="mt-0.5">Optional: <code className="font-mono text-xs bg-white border border-border rounded px-1">channel</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">tier</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">phone</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">email</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">credit_limit</code>, <code className="font-mono text-xs bg-white border border-border rounded px-1">route_code</code></p>
          <p className="mt-0.5 text-xs">Rows with an existing customer code will be <span className="font-medium">skipped</span>. Max 2,000 rows per file.</p>
        </div>

        <button type="button" onClick={downloadSample} className="inline-flex items-center gap-2 text-sm text-primary hover:underline">
          <Download className="h-4 w-4" /> Download sample CSV
        </button>

        {!result && (
          <div>
            <div
              onClick={() => inputRef.current?.click()}
              className="flex flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed border-border bg-background-subtle hover:border-primary/50 hover:bg-primary/5 transition-colors cursor-pointer py-8"
            >
              <Upload className="h-7 w-7 text-text-secondary/60" />
              {file ? (
                <div className="text-center">
                  <p className="text-sm font-medium text-text-primary">{file.name}</p>
                  <p className="text-xs text-text-secondary">{(file.size / 1024).toFixed(1)} KB</p>
                </div>
              ) : (
                <div className="text-center">
                  <p className="text-sm text-text-primary">Click to select a CSV file</p>
                  <p className="text-xs text-text-secondary">.csv files only</p>
                </div>
              )}
            </div>
            <input
              ref={inputRef}
              type="file"
              accept=".csv,text/csv"
              className="hidden"
              onChange={(e) => { setFile(e.target.files?.[0] ?? null); setError(""); }}
            />
          </div>
        )}

        {error && (
          <div className="flex items-start gap-2 rounded-md bg-danger/8 border border-danger/20 px-3 py-2.5 text-sm text-danger">
            <FileWarning className="h-4 w-4 shrink-0 mt-0.5" />{error}
          </div>
        )}

        {result && (
          <div className="space-y-3">
            <div className="flex items-center gap-4 flex-wrap">
              <div className="flex items-center gap-2 rounded-md bg-success/10 border border-success/20 px-3 py-2 text-sm">
                <CheckCircle className="h-4 w-4 text-success" />
                <span className="font-medium text-success">{result.success_count} imported</span>
              </div>
              {result.skipped_rows.length > 0 && (
                <div className="flex items-center gap-2 rounded-md bg-warning/10 border border-warning/20 px-3 py-2 text-sm">
                  <span className="font-medium text-warning">{result.skipped_rows.length} skipped (duplicate codes)</span>
                </div>
              )}
              {result.failed_rows.length > 0 && (
                <div className="flex items-center gap-2 rounded-md bg-danger/8 border border-danger/20 px-3 py-2 text-sm">
                  <FileWarning className="h-4 w-4 text-danger" />
                  <span className="font-medium text-danger">{result.failed_rows.length} failed</span>
                </div>
              )}
            </div>
            {result.failed_rows.length > 0 && (
              <div className="rounded-md border border-border overflow-auto max-h-44">
                <table className="w-full text-xs">
                  <thead className="bg-background-subtle">
                    <tr>
                      <th className="px-3 py-2 text-left font-semibold text-text-secondary">Row</th>
                      <th className="px-3 py-2 text-left font-semibold text-text-secondary">Code</th>
                      <th className="px-3 py-2 text-left font-semibold text-text-secondary">Error</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border bg-white">
                    {result.failed_rows.map((f) => (
                      <tr key={f.row}>
                        <td className="px-3 py-1.5 tabular-nums text-text-secondary">{f.row}</td>
                        <td className="px-3 py-1.5 font-mono">{f.code || "—"}</td>
                        <td className="px-3 py-1.5 text-danger">{f.errors.join(", ")}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        <div className="flex justify-end gap-2 border-t border-border pt-3">
          {result ? (
            <Button onClick={handleDone}>Done</Button>
          ) : (
            <>
              <Button variant="outline" onClick={onClose} disabled={loading}>Cancel</Button>
              <Button onClick={handleUpload} disabled={!file || loading}>
                {loading ? (
                  <><span className="h-3.5 w-3.5 mr-2 animate-spin rounded-full border-2 border-white border-t-transparent inline-block" />Importing…</>
                ) : (
                  <><Upload className="h-4 w-4 mr-2" />Import CSV</>
                )}
              </Button>
            </>
          )}
        </div>
      </div>
    </Modal>
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
  const [creditStatus,  setCreditStatus]  = useState("");
  const [savedView,     setSavedView]     = useState<SavedView>("all");
  const [page,          setPage]          = useState(1);
  const [totalPages,    setTotalPages]    = useState(1);
  const [totalCount,    setTotalCount]    = useState(0);
  const [exporting,     setExporting]     = useState(false);
  const [showImport,    setShowImport]    = useState(false);

  const handleViewChange = (view: SavedView) => {
    setSavedView(view);
    setSearch(""); setChannel(""); setTier(""); setStatus(""); setCreditStatus("");
    setPage(1);
  };

  const handleBlockCustomer = useCallback(async (id: number, action: "block" | "unblock") => {
    if (!token || !orgId) return;
    setActionLoading(id);
    try {
      const res = await fetch(`${API_URL}/api/v1/customers/${id}/${action}`, {
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
      header: "Retailer",
      render: (_: unknown, row: Customer) => (
        <div>
          <p className="font-medium text-text-primary">{row.name}</p>
          {/* <p className="text-xs text-text-secondary">{row.code}</p> */}
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
      header: "Credit Used / Limit",
      render: (_: unknown, row: Customer) => (
        <CreditUsageBar
          ca={row.credit_account}
          usage={row.credit_usage_summary}
          compact
          widthClass="min-w-[140px]"
        />
      ),
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
            className="inline-flex items-center justify-center h-7 w-7 rounded-md border border-border bg-background text-text-secondary hover:text-text-primary hover:bg-background-subtle transition-colors"
            title="Edit"
          >
            <Pencil className="h-3.5 w-3.5" />
          </button>
          {row.status !== "blocked" ? (
            <button
              onClick={() => handleBlockCustomer(row.id, "block")}
              disabled={actionLoading === row.id}
              className="inline-flex items-center justify-center h-7 w-7 rounded-md border border-border bg-background text-text-secondary hover:text-danger hover:border-danger/40 hover:bg-danger/5 transition-colors disabled:opacity-40"
              title="Block"
            >
              <Ban className="h-3.5 w-3.5" />
            </button>
          ) : (
            <button
              onClick={() => handleBlockCustomer(row.id, "unblock")}
              disabled={actionLoading === row.id}
              className="inline-flex items-center justify-center h-7 w-7 rounded-md border border-border bg-background text-text-secondary hover:text-success hover:border-success/40 hover:bg-success/5 transition-colors disabled:opacity-40"
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
      const qs = new URLSearchParams({ page: String(page), per_page: "20", include_credit_usage: "true" });
      if (search)       qs.set("q",             search);
      if (channel)      qs.set("channel",        channel);
      if (tier)         qs.set("tier",           tier);
      if (status)       qs.set("status",         status);
      if (creditStatus) qs.set("credit_status",  creditStatus);
      Object.entries(VIEW_PARAMS[savedView]).forEach(([k, v]) => qs.set(k, v));

      const res  = await fetch(`${API_URL}/api/v1/customers?${qs}`, {
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
  }, [token, orgId, page, search, channel, tier, status, creditStatus, savedView]);

  useEffect(() => { fetchCustomers(); }, [fetchCustomers]);

  const clearFilters = () => {
    setSearch(""); setChannel(""); setTier(""); setStatus(""); setCreditStatus(""); setPage(1);
  };

  const hasFilters = search || channel || tier || status || creditStatus;

  const handleExportCsv = useCallback(async () => {
    if (!token || !orgId || exporting) return;
    setExporting(true);
    try {
      const qs = new URLSearchParams();
      if (search)  qs.set("q",       search);
      if (channel) qs.set("channel", channel);
      if (tier)    qs.set("tier",    tier);
      if (status)  qs.set("status",  status);
      Object.entries(VIEW_PARAMS[savedView]).forEach(([k, v]) => qs.set(k, v));
      const res = await fetch(`${API_URL}/api/v1/customers/export_csv?${qs}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const blob = await res.blob();
      const url  = URL.createObjectURL(blob);
      const a    = document.createElement("a");
      const cd   = res.headers.get("Content-Disposition") ?? "";
      const name = cd.match(/filename="?([^"]+)"?/)?.[1] ?? "customers_export.csv";
      a.href = url; a.download = name; a.click();
      URL.revokeObjectURL(url);
    } finally {
      setExporting(false);
    }
  }, [token, orgId, search, channel, tier, status, savedView, exporting]);

  return (
    <AppShell title="Retailers">
      <PageHeader
        title="Retailers & Credit Accounts"
        description="Retailers, channel partners &amp; credit accounts."
        actions={[
          {
            label: "Import CSV",
            onClick: () => setShowImport(true),
            icon: Upload,
            variant: "outline",
          },
          {
            label:   exporting ? "Exporting…" : "Export CSV",
            onClick: handleExportCsv,
            icon:    Download,
            variant: "ghost",
          },
          { label: "Add Retailer", onClick: () => router.push("/customers/new"), icon: Plus },
        ]}
      />

      {showImport && (
        <CustomersBulkImportModal
          token={token}
          orgId={orgId}
          onClose={() => setShowImport(false)}
          onImported={() => { setShowImport(false); fetchCustomers(); }}
        />
      )}

      {/* Saved view tabs */}
      <div className="flex mb-4 border-b border-border overflow-x-auto">
        {SAVED_VIEWS.map((v) => (
          <button
            key={v.key}
            onClick={() => handleViewChange(v.key)}
            className={`px-4 py-2.5 text-sm font-medium border-b-2 transition-colors whitespace-nowrap ${
              savedView === v.key
                ? "border-primary text-primary"
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

        <select
          className="h-9 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
          value={creditStatus}
          onChange={(e) => { setCreditStatus(e.target.value); setSavedView("all"); setPage(1); }}
        >
          <option value="">Credit Status</option>
          <option value="overdue">Overdue</option>
          <option value="hold">On Hold</option>
          <option value="near_limit">Near Limit</option>
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
