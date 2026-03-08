"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import {
  ChevronLeft, RefreshCw, CheckCircle2, XCircle,
  Clock, Loader2, AlertTriangle,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useOrgBranch } from "@/lib/org-branch-context";
import {
  fetchSyncRecord,
  retrySyncRecord,
  type AccountingSyncRecord,
} from "@/lib/api/accounting";
import {
  SyncStatusBadge, PriorityBadge,
  providerLabel, fmtDatetime, prettyJson,
} from "../../_utils";

// ── Detail row helper ─────────────────────────────────────────────────────────

function DetailRow({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col sm:flex-row sm:items-start py-2.5 border-b border-border last:border-0 gap-1 sm:gap-4">
      <span className="text-xs font-medium text-text-secondary uppercase tracking-wide sm:w-40 shrink-0">
        {label}
      </span>
      <div className="text-sm text-text-primary">{children}</div>
    </div>
  );
}

// ── JSON block ────────────────────────────────────────────────────────────────

function JsonBlock({ label, value }: { label: string; value: unknown }) {
  const [collapsed, setCollapsed] = useState(true);
  const content = prettyJson(value);
  if (content === "—") return null;

  return (
    <Card>
      <CardHeader className="pb-2 flex flex-row items-center justify-between">
        <CardTitle className="text-sm">{label}</CardTitle>
        <Button
          size="sm"
          variant="ghost"
          onClick={() => setCollapsed((p) => !p)}
          className="text-xs text-text-secondary h-7"
        >
          {collapsed ? "Expand" : "Collapse"}
        </Button>
      </CardHeader>
      {!collapsed && (
        <CardContent className="pt-0">
          <pre className="bg-background-subtle rounded-md p-3 text-xs font-mono text-text-primary overflow-auto max-h-96 whitespace-pre-wrap">
            {content}
          </pre>
        </CardContent>
      )}
    </Card>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function SyncRecordDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [record, setRecord]   = useState<AccountingSyncRecord | null>(null);
  const [loading, setLoading] = useState(true);
  const [retrying, setRetrying] = useState(false);
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const load = useCallback(async () => {
    if (!token || !orgId || !id) return;
    setLoading(true);
    try {
      const data = await fetchSyncRecord(Number(id), token, orgId);
      setRecord(data);
    } catch {
      setMessage({ type: "error", text: "Failed to load sync record." });
    } finally {
      setLoading(false);
    }
  }, [token, orgId, id]);

  useEffect(() => { load(); }, [load]);

  const handleRetry = async () => {
    if (!token || !orgId || !record) return;
    setRetrying(true);
    try {
      const result = await retrySyncRecord(record.id, token, orgId);
      setMessage({ type: "success", text: result.message || "Retry enqueued." });
      setTimeout(() => load(), 1000);
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { errors?: string[] } } })?.response?.data?.errors?.[0]
        ?? "Retry failed.";
      setMessage({ type: "error", text: msg });
    } finally {
      setRetrying(false);
    }
  };

  const canRetry =
    record && (record.status === "failed" || record.status === "retrying") &&
    record.attempt_count < record.max_retries;

  if (loading) {
    return (
      <div className="space-y-4">
        {[1, 2].map((n) => (
          <Card key={n}>
            <CardContent className="p-6 space-y-3">
              {[1, 2, 3, 4].map((m) => (
                <div key={m} className="flex gap-4">
                  <div className="h-4 w-32 bg-border rounded animate-pulse" />
                  <div className="h-4 flex-1 bg-border/50 rounded animate-pulse" />
                </div>
              ))}
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  if (!record) {
    return (
      <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-lg px-4 py-3 text-sm text-red-700">
        <XCircle className="h-4 w-4 shrink-0" />
        Sync record not found.
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* ── Banner ── */}
      {message && (
        <div
          className={`flex items-center gap-2 rounded-lg px-4 py-3 text-sm border-l-4 ${
            message.type === "success"
              ? "bg-[#E8F5EE] border-accent text-[#1B4332]"
              : "bg-red-50 border-danger text-red-700"
          }`}
        >
          {message.type === "success" ? (
            <CheckCircle2 className="h-4 w-4 shrink-0" />
          ) : (
            <XCircle className="h-4 w-4 shrink-0" />
          )}
          {message.text}
        </div>
      )}

      {/* ── Header ── */}
      <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
        <div>
          <button
            onClick={() => router.push("/accounting/sync-records")}
            className="flex items-center gap-1 text-xs text-text-secondary hover:text-text-primary mb-2 transition-colors"
          >
            <ChevronLeft className="h-3.5 w-3.5" />
            Sync Dashboard
          </button>
          <div className="flex items-center gap-3 flex-wrap">
            <h2 className="text-lg font-bold text-text-primary font-mono">
              {record.entity_type} #{record.entity_id}
            </h2>
            <SyncStatusBadge status={record.status} />
            <PriorityBadge priority={record.priority} />
          </div>
          <p className="text-xs text-text-secondary mt-1">
            {record.event_type} · {providerLabel(record.provider)}
          </p>
        </div>

        {canRetry && (
          <Button onClick={handleRetry} disabled={retrying} className="shrink-0">
            {retrying ? (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            ) : (
              <RefreshCw className="mr-2 h-4 w-4" />
            )}
            Retry Now
          </Button>
        )}
      </div>

      <div className="grid lg:grid-cols-3 gap-5">

        {/* ── Left: metadata ── */}
        <div className="lg:col-span-2 space-y-5">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm">Record Details</CardTitle>
            </CardHeader>
            <CardContent className="pt-0">
              <DetailRow label="ID">{record.id}</DetailRow>
              <DetailRow label="Provider">{providerLabel(record.provider)}</DetailRow>
              <DetailRow label="Entity">{record.entity_type} #{record.entity_id}</DetailRow>
              <DetailRow label="Entity Version">
                <span className="font-mono text-xs">{record.entity_version}</span>
              </DetailRow>
              <DetailRow label="Event Type">{record.event_type}</DetailRow>
              <DetailRow label="Direction">{record.direction}</DetailRow>
              <DetailRow label="Status"><SyncStatusBadge status={record.status} /></DetailRow>
              <DetailRow label="Priority"><PriorityBadge priority={record.priority} /></DetailRow>
              <DetailRow label="Idempotency Key">
                <span className="font-mono text-xs break-all">{record.idempotency_key}</span>
              </DetailRow>
              {record.external_reference && (
                <DetailRow label="External Ref">
                  <span className="font-mono text-xs">{record.external_reference}</span>
                </DetailRow>
              )}
            </CardContent>
          </Card>

          {/* Payload */}
          <JsonBlock label="Payload Snapshot" value={record.payload_json} />

          {/* Response */}
          <JsonBlock label="Response Body" value={record.response_body} />
        </div>

        {/* ── Right: timeline ── */}
        <div className="space-y-5">

          {/* Retry info */}
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm">Attempts</CardTitle>
            </CardHeader>
            <CardContent className="pt-0">
              <DetailRow label="Attempt Count">
                {record.attempt_count} / {record.max_retries}
              </DetailRow>
              <DetailRow label="Last Tried">
                {fmtDatetime(record.last_attempted_at)}
              </DetailRow>
              {record.succeeded_at && (
                <DetailRow label="Succeeded At">
                  {fmtDatetime(record.succeeded_at)}
                </DetailRow>
              )}
            </CardContent>
          </Card>

          {/* Error */}
          {record.error_message && (
            <Card className="border-red-200">
              <CardHeader className="pb-2">
                <CardTitle className="text-sm flex items-center gap-2 text-danger">
                  <AlertTriangle className="h-4 w-4" />
                  Error
                </CardTitle>
              </CardHeader>
              <CardContent className="pt-0">
                <pre className="text-xs text-red-700 font-mono whitespace-pre-wrap bg-red-50 rounded p-2">
                  {record.error_message}
                </pre>
              </CardContent>
            </Card>
          )}

          {/* Timestamps */}
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm">Timestamps</CardTitle>
            </CardHeader>
            <CardContent className="pt-0">
              <DetailRow label="Created">{fmtDatetime(record.created_at)}</DetailRow>
              <DetailRow label="Updated">{fmtDatetime(record.updated_at)}</DetailRow>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
