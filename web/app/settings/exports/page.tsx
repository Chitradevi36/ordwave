"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import {
  Download, FileText, Clock, CheckCircle, XCircle,
  AlertCircle, RefreshCw, Plus
} from "lucide-react";

interface ExportRecord {
  id: number;
  export_type: string;
  status: "pending" | "processing" | "completed" | "failed";
  file_url?: string;
  row_count?: number;
  filters?: Record<string, unknown>;
  error_message?: string;
  created_at: string;
  completed_at?: string;
}

const EXPORT_TYPES = [
  { value: "orders",        label: "Orders" },
  { value: "invoices",      label: "Invoices" },
  { value: "payments",      label: "Payments" },
  { value: "customers",     label: "Customers" },
  { value: "products",      label: "Products" },
  { value: "inventory",     label: "Inventory" },
  { value: "credit_notes",  label: "Credit Notes" },
  { value: "returns",       label: "Returns" },
];

const STATUS_CONFIG: Record<string, { label: string; icon: React.ComponentType<{ className?: string }>; cls: string }> = {
  pending:    { label: "Pending",    icon: Clock,         cls: "text-text-secondary" },
  processing: { label: "Processing", icon: RefreshCw,     cls: "text-amber-600 animate-spin" },
  completed:  { label: "Completed",  icon: CheckCircle,   cls: "text-success" },
  failed:     { label: "Failed",     icon: XCircle,       cls: "text-danger" },
};

function fmt(dt: string) {
  return new Intl.DateTimeFormat("en-IN", {
    day: "2-digit", month: "short", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  }).format(new Date(dt));
}

export default function ExportsPage() {
  const { token, orgId } = useOrgBranch();

  const [exports,     setExports]     = useState<ExportRecord[]>([]);
  const [loading,     setLoading]     = useState(false);
  const [creating,    setCreating]    = useState(false);
  const [newType,     setNewType]     = useState("orders");
  const [newFormat,   setNewFormat]   = useState("csv");
  const [dateFrom,    setDateFrom]    = useState("");
  const [dateTo,      setDateTo]      = useState("");
  const [showCreate,  setShowCreate]  = useState(false);
  const [toast,       setToast]       = useState<{ type: "success" | "error"; msg: string } | null>(null);

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 4000);
  };

  const headers = useCallback(
    () => ({ Authorization: `Bearer ${token}`, "X-Organization-Id": orgId ?? "" }),
    [token, orgId]
  );

  const fetchExports = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/exports?per_page=50`, { headers: headers() });
      const json = await res.json();
      if (res.ok) setExports(json.data ?? []);
    } finally {
      setLoading(false);
    }
  }, [token, orgId, headers]);

  useEffect(() => {
    fetchExports();
    // Auto-refresh every 15s to pick up completed exports
    const id = setInterval(fetchExports, 15_000);
    return () => clearInterval(id);
  }, [fetchExports]);

  const handleCreate = async () => {
    if (!token || !orgId) return;
    setCreating(true);
    try {
      const body: Record<string, unknown> = { export_type: newType, format: newFormat };
      if (dateFrom) body.date_from = dateFrom;
      if (dateTo)   body.date_to   = dateTo;

      const res  = await fetch(`${API_URL}/api/v1/exports`, {
        method: "POST",
        headers: { ...headers(), "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const json = await res.json();
      if (res.ok) {
        showToast("success", "Export started — it will appear below when ready");
        setShowCreate(false);
        setDateFrom("");
        setDateTo("");
        setNewFormat("csv");
        fetchExports();
      } else {
        showToast("error", json.errors?.join(", ") ?? "Failed to start export");
      }
    } finally {
      setCreating(false);
    }
  };

  return (
    <AppShell title="Exports">
      <PageHeader
        title="Exports"
        description="Download CSV or Excel exports of your data"
        backHref="/settings"
        actions={[
          {
            label: "New Export",
            onClick: () => setShowCreate(true),
            icon: Plus,
          },
        ]}
      />

      {/* Toast */}
      {toast && (
        <div className={`fixed bottom-4 right-4 z-50 flex items-center gap-2 rounded-lg px-4 py-3 shadow-lg text-sm font-medium text-white ${
          toast.type === "success" ? "bg-success" : "bg-danger"
        }`}>
          {toast.type === "success" ? <CheckCircle className="h-4 w-4" /> : <XCircle className="h-4 w-4" />}
          {toast.msg}
        </div>
      )}

      {/* New export form */}
      {showCreate && (
        <Card className="mb-4">
          <CardHeader>
            <CardTitle className="text-sm font-semibold">Create New Export</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-wrap items-end gap-3">
            <div className="min-w-[180px]">
              <label className="mb-1 block text-xs text-text-secondary">Data Type</label>
              <select
                value={newType}
                onChange={(e) => setNewType(e.target.value)}
                className="h-9 w-full rounded-md border border-input bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
              >
                {EXPORT_TYPES.map((t) => (
                  <option key={t.value} value={t.value}>{t.label}</option>
                ))}
              </select>
            </div>
            <div className="min-w-[140px]">
              <label className="mb-1 block text-xs text-text-secondary">Format</label>
              <select
                value={newFormat}
                onChange={(e) => setNewFormat(e.target.value)}
                className="h-9 w-full rounded-md border border-input bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
              >
                <option value="csv">CSV</option>
                <option value="xlsx">Excel (XLSX)</option>
                <option value="pdf">PDF</option>
              </select>
            </div>
            <div>
              <label className="mb-1 block text-xs text-text-secondary">Date From</label>
              <input
                type="date"
                value={dateFrom}
                onChange={(e) => setDateFrom(e.target.value)}
                className="h-9 rounded-md border border-input bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
              />
            </div>
            <div>
              <label className="mb-1 block text-xs text-text-secondary">Date To</label>
              <input
                type="date"
                value={dateTo}
                onChange={(e) => setDateTo(e.target.value)}
                className="h-9 rounded-md border border-input bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
              />
            </div>
            <div className="flex gap-2">
              <Button onClick={handleCreate} disabled={creating}>
                {creating ? "Starting…" : "Start Export"}
              </Button>
              <Button variant="outline" onClick={() => setShowCreate(false)}>Cancel</Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Export history */}
      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle className="flex items-center gap-2 text-sm font-semibold">
            <FileText className="h-4 w-4 text-accent" />
            Export History
          </CardTitle>
          <button
            onClick={fetchExports}
            className="text-text-secondary hover:text-text-primary transition-colors"
            aria-label="Refresh"
          >
            <RefreshCw className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
          </button>
        </CardHeader>
        <CardContent className="p-0">
          {loading && exports.length === 0 ? (
            <div className="divide-y divide-border">
              {[1,2,3].map((i) => (
                <div key={i} className="flex items-center justify-between px-4 py-3">
                  <div className="space-y-1.5">
                    <div className="h-3.5 w-32 rounded bg-border animate-pulse" />
                    <div className="h-2.5 w-48 rounded bg-border/60 animate-pulse" />
                  </div>
                  <div className="h-8 w-20 rounded bg-border animate-pulse" />
                </div>
              ))}
            </div>
          ) : exports.length === 0 ? (
            <div className="py-12 text-center">
              <FileText className="mx-auto mb-2 h-8 w-8 text-text-secondary/40" />
              <p className="text-sm font-medium text-text-primary">No exports yet</p>
              <p className="mt-0.5 text-xs text-text-secondary">
                Create your first export to download your data as CSV.
              </p>
            </div>
          ) : (
            <div className="divide-y divide-border">
              {exports.map((exp) => {
                const sc = STATUS_CONFIG[exp.status] ?? STATUS_CONFIG.pending;
                const IconComponent = sc.icon;
                return (
                  <div key={exp.id} className="flex items-center justify-between px-4 py-3">
                    <div className="flex items-center gap-3 min-w-0">
                      <IconComponent className={`h-4 w-4 shrink-0 ${sc.cls}`} />
                      <div className="min-w-0">
                        <p className="text-sm font-medium text-text-primary">
                          {EXPORT_TYPES.find((t) => t.value === exp.export_type)?.label ?? exp.export_type}
                          {exp.row_count != null && (
                            <span className="ml-1.5 text-xs font-normal text-text-secondary">
                              ({exp.row_count.toLocaleString("en-IN")} rows)
                            </span>
                          )}
                        </p>
                        <p className="text-xs text-text-secondary">
                          {fmt(exp.created_at)}
                          {exp.completed_at && ` · Completed ${fmt(exp.completed_at)}`}
                        </p>
                        {exp.error_message && (
                          <p className="mt-0.5 flex items-center gap-1 text-xs text-danger">
                            <AlertCircle className="h-3 w-3" /> {exp.error_message}
                          </p>
                        )}
                      </div>
                    </div>

                    {exp.status === "completed" && exp.file_url ? (
                      <a
                        href={exp.file_url}
                        download
                        rel="noopener noreferrer"
                        className="inline-flex items-center gap-1.5 rounded-md border border-input bg-background px-3 py-1.5 text-xs font-medium text-text-primary hover:bg-background-subtle transition-colors"
                      >
                        <Download className="h-3.5 w-3.5" /> Download
                      </a>
                    ) : (
                      <span className={`text-xs font-medium ${sc.cls}`}>{sc.label}</span>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </CardContent>
      </Card>
    </AppShell>
  );
}
