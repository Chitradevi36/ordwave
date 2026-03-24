"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import {
  ChevronLeft, Download, CheckCircle2, XCircle,
  Clock, AlertTriangle, RefreshCw, Loader2,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useOrgBranch } from "@/lib/org-branch-context";
import { AccessDeniedError } from "@/components/errors/access-denied-error";
import {
  fetchExportFile,
  downloadExportFileUrl,
  type AccountingExportFile,
} from "@/lib/api/accounting";
import { ExportStatusBadge, providerLabel, fmtDate, fmtDatetime } from "../../_utils";

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

// ── Status indicator ──────────────────────────────────────────────────────────

function StatusIndicator({ status }: { status: string }) {
  if (status === "generating") {
    return (
      <div className="flex items-center gap-3 bg-blue-50 border border-blue-200 rounded-lg p-4">
        <Loader2 className="h-5 w-5 text-blue-600 animate-spin shrink-0" />
        <div>
          <p className="text-sm font-medium text-blue-800">Export in progress</p>
          <p className="text-xs text-blue-600 mt-0.5">
            The background job is running. Refresh in a moment to check progress.
          </p>
        </div>
      </div>
    );
  }
  if (status === "ready") {
    return (
      <div className="flex items-center gap-3 bg-[#E8F5EE] border border-accent/30 rounded-lg p-4">
        <CheckCircle2 className="h-5 w-5 text-accent shrink-0" />
        <div>
          <p className="text-sm font-medium text-[#1B4332]">Export ready</p>
          <p className="text-xs text-[#2D6A4F] mt-0.5">XML file generated successfully. Download below.</p>
        </div>
      </div>
    );
  }
  if (status === "failed") {
    return (
      <div className="flex items-center gap-3 bg-red-50 border border-red-200 rounded-lg p-4">
        <XCircle className="h-5 w-5 text-danger shrink-0" />
        <div>
          <p className="text-sm font-medium text-red-800">Export failed</p>
          <p className="text-xs text-red-600 mt-0.5">See error message below for details.</p>
        </div>
      </div>
    );
  }
  return null;
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function ExportFileDetailPage() {
  const { id } = useParams<{ id: string }>();
  const searchParams = useSearchParams();
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [file, setFile]         = useState<AccountingExportFile | null>(null);
  const [loading, setLoading]   = useState(true);
  const [downloading, setDownloading] = useState(false);
  const [message, setMessage]   = useState<{ type: "success" | "error"; text: string } | null>(null);
  const [error, setError]       = useState<{ status: number; message: string } | null>(null);

  const load = useCallback(async () => {
    if (!token || !orgId || !id) return;
    setLoading(true);
    setError(null);
    try {
      const data = await fetchExportFile(Number(id), token, orgId);
      setFile(data);
    } catch (err: any) {
      const status = err?.response?.status || 500;
      const message = err?.response?.data?.errors?.[0] ?? "Failed to load export file.";
      setError({ status, message });
    } finally {
      setLoading(false);
    }
  }, [token, orgId, id]);

  useEffect(() => { load(); }, [load]);

  // Auto-trigger download if redirected with ?download=1
  useEffect(() => {
    if (searchParams.get("download") === "1" && file?.downloadable && !downloading) {
      handleDownload();
    }
  }, [file]); // eslint-disable-line react-hooks/exhaustive-deps

  // Poll while generating
  useEffect(() => {
    if (file?.status !== "generating") return;
    const interval = setInterval(() => load(), 5000);
    return () => clearInterval(interval);
  }, [file?.status, load]);

  const handleDownload = async () => {
    if (!token || !orgId || !file) return;
    setDownloading(true);
    try {
      const url = await downloadExportFileUrl(file.id, token, orgId);
      if (url) {
        window.open(url, "_blank");
      } else {
        setMessage({ type: "error", text: "Download URL not available." });
      }
    } catch {
      setMessage({ type: "error", text: "Download failed. File may have been deleted." });
    } finally {
      setDownloading(false);
    }
  };

  if (error) {
    return <AccessDeniedError status={error.status} message={error.message} backLink="/accounting/export-files" resourceType="Export File" />;
  }

  if (loading) {
    return (
      <div className="space-y-4 max-w-3xl">
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

  if (!file) {
    return (
      <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-lg px-4 py-3 text-sm text-red-700">
        <XCircle className="h-4 w-4 shrink-0" />
        Export file not found.
      </div>
    );
  }

  return (
    <div className="max-w-3xl space-y-5">
      {/* Banner */}
      {message && (
        <div
          className={`flex items-center gap-2 rounded-lg border-l-4 px-4 py-3 text-sm ${
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

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
        <div>
          <button
            onClick={() => router.push("/accounting/export-files")}
            className="flex items-center gap-1 text-xs text-text-secondary hover:text-text-primary mb-2 transition-colors"
          >
            <ChevronLeft className="h-3.5 w-3.5" />
            Export Center
          </button>
          <div className="flex items-center gap-3 flex-wrap">
            <h2 className="text-lg font-bold text-text-primary">
              {providerLabel(file.provider)} · {file.export_type.replace(/_/g, " ")}
            </h2>
            <ExportStatusBadge status={file.status} />
          </div>
          <p className="text-xs text-text-secondary mt-1">
            Created {fmtDatetime(file.created_at)}
          </p>
        </div>

        <div className="flex gap-2 shrink-0">
          <Button size="sm" variant="outline" onClick={() => load()}>
            <RefreshCw className="h-3.5 w-3.5 mr-1.5" />
            Refresh
          </Button>
          {file.downloadable && (
            <Button onClick={handleDownload} disabled={downloading}>
              {downloading ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <Download className="mr-2 h-4 w-4" />
              )}
              Download XML
            </Button>
          )}
        </div>
      </div>

      {/* Status banner */}
      <StatusIndicator status={file.status} />

      {/* Details */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm">Export Details</CardTitle>
        </CardHeader>
        <CardContent className="pt-0">
          <DetailRow label="Integration">
            {file.accounting_integration
              ? providerLabel(file.accounting_integration.provider)
              : "—"}
          </DetailRow>
          <DetailRow label="Export Type">
            <span className="capitalize">{file.export_type.replace(/_/g, " ")}</span>
          </DetailRow>
          <DetailRow label="Date Range">
            {file.date_from
              ? `${fmtDate(file.date_from)} – ${fmtDate(file.date_to)}`
              : "All dates"}
          </DetailRow>
          <DetailRow label="Branch">
            {file.branch?.name ?? "All branches"}
          </DetailRow>
          <DetailRow label="Status">
            <ExportStatusBadge status={file.status} />
          </DetailRow>
          <DetailRow label="Generated By">
            {file.generated_by
              ? `${file.generated_by.first_name} ${file.generated_by.last_name}`.trim() ||
                file.generated_by.email
              : "—"}
          </DetailRow>
          {file.file_path && (
            <DetailRow label="File Path">
              <span className="font-mono text-xs text-text-secondary break-all">
                {file.file_path}
              </span>
            </DetailRow>
          )}
          <DetailRow label="Created">{fmtDatetime(file.created_at)}</DetailRow>
          <DetailRow label="Updated">{fmtDatetime(file.updated_at)}</DetailRow>
        </CardContent>
      </Card>

      {/* Error */}
      {file.error_message && (
        <Card className="border-red-200">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm flex items-center gap-2 text-danger">
              <AlertTriangle className="h-4 w-4" />
              Error Message
            </CardTitle>
          </CardHeader>
          <CardContent className="pt-0">
            <pre className="text-xs text-red-700 font-mono whitespace-pre-wrap bg-red-50 rounded p-3">
              {file.error_message}
            </pre>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
