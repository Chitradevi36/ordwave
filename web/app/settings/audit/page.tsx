"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ChevronsLeft, ChevronLeft, ChevronRight, ChevronsRight, Shield } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";

const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "";

interface AuditActor {
  id: number;
  name: string;
}

interface AuditLog {
  id: number;
  action: string;
  auditable_type: string;
  auditable_id: number;
  reason: string | null;
  changes: Record<string, unknown> | null;
  created_at: string;
  actor: AuditActor | null;
}

interface AuditMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
}

interface AuditResponse {
  data: AuditLog[];
  meta: AuditMeta;
}

const ENTITY_TYPES = [
  { value: "all", label: "All entity types" },
  { value: "SalesOrder", label: "Sales Order" },
  { value: "Payment", label: "Payment" },
  { value: "CreditNote", label: "Credit Note" },
  { value: "Customer", label: "Customer" },
  { value: "User", label: "User" },
  { value: "Product", label: "Product" },
  { value: "Scheme", label: "Scheme" },
  { value: "DeliveryTrip", label: "Delivery Trip" },
];

const ACTION_BADGE_COLORS: Record<string, string> = {
  created: "bg-green-100 text-green-800",
  updated: "bg-blue-100 text-blue-800",
  deleted: "bg-red-100 text-red-800",
  approved: "bg-emerald-100 text-emerald-800",
  rejected: "bg-red-100 text-red-800",
  submitted: "bg-yellow-100 text-yellow-800",
  cancelled: "bg-orange-100 text-orange-800",
  dispatched: "bg-purple-100 text-purple-800",
  delivered: "bg-teal-100 text-teal-800",
};

function actionBadgeClass(action: string): string {
  const key = Object.keys(ACTION_BADGE_COLORS).find((k) =>
    action.toLowerCase().includes(k)
  );
  return key
    ? ACTION_BADGE_COLORS[key]
    : "bg-gray-100 text-gray-700";
}

function formatDateTime(iso: string): string {
  try {
    return new Intl.DateTimeFormat("en-IN", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
    }).format(new Date(iso));
  } catch {
    return iso;
  }
}

function authHeaders(): HeadersInit {
  if (typeof window === "undefined") return {};
  const token = localStorage.getItem("token") ?? "";
  const orgId = localStorage.getItem("organization_id") ?? "";
  return {
    Authorization: `Bearer ${token}`,
    "X-Organization-Id": orgId,
    "Content-Type": "application/json",
  };
}

export default function AuditLogPage() {
  const router = useRouter();

  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [meta, setMeta] = useState<AuditMeta | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Filters
  const [entityType, setEntityType] = useState("all");
  const [action, setAction] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [page, setPage] = useState(1);

  const fetchLogs = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams();
      params.set("page", String(page));
      if (entityType && entityType !== "all") params.set("auditable_type", entityType);
      if (action.trim()) params.set("action", action.trim());
      if (dateFrom) params.set("date_from", dateFrom);
      if (dateTo) params.set("date_to", dateTo);

      const res = await fetch(
        `${API_URL}/api/v1/audit_logs?${params.toString()}`,
        { headers: authHeaders() }
      );
      if (!res.ok) throw new Error(`Error ${res.status}`);
      const json: AuditResponse = await res.json();
      setLogs(json.data ?? []);
      setMeta(json.meta ?? null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load audit logs");
    } finally {
      setLoading(false);
    }
  }, [page, entityType, action, dateFrom, dateTo]);

  useEffect(() => {
    fetchLogs();
  }, [fetchLogs]);

  // Reset to page 1 when filters change
  function applyFilters() {
    setPage(1);
  }

  const totalPages = meta?.total_pages ?? 1;

  return (
    <div className="flex min-h-screen flex-col bg-background">
      {/* Header */}
      <div className="sticky top-0 z-10 border-b border-border bg-background-surface px-4 py-3 sm:px-6">
        <div className="flex items-center gap-3">
          <button
            onClick={() => router.push("/settings")}
            className="rounded-md p-1 hover:bg-background-subtle"
          >
            <ChevronLeft className="h-5 w-5 text-text-secondary" />
          </button>
          <div className="flex items-center gap-2">
            <Shield className="h-5 w-5 text-accent" />
            <h1 className="text-base font-semibold text-text-primary">Audit Log</h1>
          </div>
          {meta && (
            <span className="ml-auto text-xs text-text-secondary">
              {meta.total_count.toLocaleString()} entries
            </span>
          )}
        </div>
      </div>

      <div className="flex-1 space-y-4 p-4 sm:p-6">
        {/* Filters */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-sm font-medium text-text-secondary">
              Filter
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
              <select
                value={entityType}
                onChange={(e) => { setEntityType(e.target.value); setPage(1); }}
                className="h-9 rounded-md border border-border px-2 text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary"
              >
                {ENTITY_TYPES.map((t) => (
                  <option key={t.value} value={t.value}>{t.label}</option>
                ))}
              </select>

              <Input
                placeholder="Action (e.g. submitted)"
                className="h-9 text-sm"
                value={action}
                onChange={(e) => setAction(e.target.value)}
                onKeyDown={(e) => { if (e.key === "Enter") applyFilters(); }}
              />

              <Input
                type="date"
                className="h-9 text-sm"
                value={dateFrom}
                onChange={(e) => { setDateFrom(e.target.value); setPage(1); }}
              />

              <Input
                type="date"
                className="h-9 text-sm"
                value={dateTo}
                onChange={(e) => { setDateTo(e.target.value); setPage(1); }}
              />
            </div>
          </CardContent>
        </Card>

        {/* Table */}
        <Card>
          <CardContent className="p-0">
            {loading ? (
              <div className="flex items-center justify-center py-16 text-sm text-text-secondary">
                Loading…
              </div>
            ) : error ? (
              <div className="flex flex-col items-center justify-center gap-2 py-16">
                <p className="text-sm text-destructive">{error}</p>
                <Button size="sm" variant="outline" onClick={fetchLogs}>
                  Retry
                </Button>
              </div>
            ) : logs.length === 0 ? (
              <div className="flex items-center justify-center py-16 text-sm text-text-secondary">
                No audit log entries found.
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-border bg-background-subtle text-xs font-medium uppercase tracking-wide text-text-secondary">
                      <th className="px-4 py-3 text-left">Timestamp</th>
                      <th className="px-4 py-3 text-left">Actor</th>
                      <th className="px-4 py-3 text-left">Action</th>
                      <th className="px-4 py-3 text-left">Entity</th>
                      <th className="px-4 py-3 text-left">Reason / Changes</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {logs.map((log) => (
                      <tr
                        key={log.id}
                        className="hover:bg-background-subtle transition-colors"
                      >
                        <td className="whitespace-nowrap px-4 py-3 text-text-secondary">
                          {formatDateTime(log.created_at)}
                        </td>
                        <td className="px-4 py-3 font-medium text-text-primary">
                          {log.actor?.name ?? "—"}
                        </td>
                        <td className="px-4 py-3">
                          <Badge
                            className={`text-xs font-medium border-0 ${actionBadgeClass(log.action)}`}
                          >
                            {log.action}
                          </Badge>
                        </td>
                        <td className="px-4 py-3">
                          <span className="font-medium text-text-primary">
                            {log.auditable_type}
                          </span>
                          <span className="ml-1 text-text-secondary">
                            #{log.auditable_id}
                          </span>
                        </td>
                        <td className="max-w-xs px-4 py-3">
                          {log.reason ? (
                            <p
                              className="truncate text-text-secondary"
                              title={log.reason}
                            >
                              {log.reason}
                            </p>
                          ) : log.changes ? (
                            <p
                              className="truncate font-mono text-xs text-text-secondary"
                              title={JSON.stringify(log.changes, null, 2)}
                            >
                              {JSON.stringify(log.changes)}
                            </p>
                          ) : (
                            <span className="text-text-disabled">—</span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Pagination */}
        {meta && meta.total_pages > 1 && (
          <div className="flex items-center justify-between">
            <p className="text-xs text-text-secondary">
              Page {meta.current_page} of {meta.total_pages} &nbsp;·&nbsp;{" "}
              {meta.total_count.toLocaleString()} total entries
            </p>
            <div className="flex items-center gap-1">
              <Button
                size="icon"
                variant="ghost"
                className="h-8 w-8"
                disabled={page <= 1}
                onClick={() => setPage(1)}
              >
                <ChevronsLeft className="h-4 w-4" />
              </Button>
              <Button
                size="icon"
                variant="ghost"
                className="h-8 w-8"
                disabled={page <= 1}
                onClick={() => setPage((p) => p - 1)}
              >
                <ChevronLeft className="h-4 w-4" />
              </Button>
              <Button
                size="icon"
                variant="ghost"
                className="h-8 w-8"
                disabled={page >= totalPages}
                onClick={() => setPage((p) => p + 1)}
              >
                <ChevronRight className="h-4 w-4" />
              </Button>
              <Button
                size="icon"
                variant="ghost"
                className="h-8 w-8"
                disabled={page >= totalPages}
                onClick={() => setPage(totalPages)}
              >
                <ChevronsRight className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
