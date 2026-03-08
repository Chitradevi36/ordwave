import { Badge } from "@/components/ui/badge";
import type { BadgeProps } from "@/components/ui/badge";

// ── Status → badge variant mapping ───────────────────────────────────────────

const INTEGRATION_STATUS: Record<string, BadgeProps["variant"]> = {
  connected:    "success",
  disconnected: "secondary",
  error:        "danger",
  disabled:     "outline",
};

const SYNC_STATUS: Record<string, BadgeProps["variant"]> = {
  pending:    "warning",
  processing: "default",       // blue (primary)
  success:    "success",
  failed:     "danger",
  retrying:   "warning",
  skipped:    "outline",
};

const EXPORT_STATUS: Record<string, BadgeProps["variant"]> = {
  generating: "default",
  ready:      "success",
  failed:     "danger",
};

const PRIORITY: Record<string, BadgeProps["variant"]> = {
  high:   "danger",
  medium: "warning",
  low:    "outline",
};

export function IntegrationStatusBadge({ status }: { status: string }) {
  return (
    <Badge variant={INTEGRATION_STATUS[status] ?? "secondary"}>
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </Badge>
  );
}

export function SyncStatusBadge({ status }: { status: string }) {
  return (
    <Badge variant={SYNC_STATUS[status] ?? "secondary"}>
      {status.toUpperCase()}
    </Badge>
  );
}

export function ExportStatusBadge({ status }: { status: string }) {
  return (
    <Badge variant={EXPORT_STATUS[status] ?? "secondary"}>
      {status.charAt(0).toUpperCase() + status.slice(1)}
    </Badge>
  );
}

export function PriorityBadge({ priority }: { priority: string }) {
  return (
    <Badge variant={PRIORITY[priority] ?? "outline"}>
      {priority.charAt(0).toUpperCase() + priority.slice(1)}
    </Badge>
  );
}

// ── Provider display names ────────────────────────────────────────────────────

const PROVIDER_LABELS: Record<string, string> = {
  tally:      "Tally",
  zoho_books: "Zoho Books",
  busy:       "Busy",
  marg:       "Marg",
  vyapar:     "Vyapar",
  cleartax:   "ClearTax",
};

export function providerLabel(provider: string): string {
  return PROVIDER_LABELS[provider] ?? provider;
}

// ── Date formatting ───────────────────────────────────────────────────────────

export function fmtTimestamp(value: string | null): string {
  if (!value) return "—";
  const d = new Date(value);
  const now = new Date();
  const diffMs = now.getTime() - d.getTime();
  const diffH = diffMs / 1000 / 60 / 60;

  if (diffH < 1) return "Just now";
  if (diffH < 24)
    return d.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" });
  if (diffH < 48) return "Yesterday " + d.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" });
  return d.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

export function fmtDate(value: string | null): string {
  if (!value) return "—";
  return new Date(value).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

export function fmtDatetime(value: string | null): string {
  if (!value) return "—";
  return new Date(value).toLocaleString("en-IN", {
    day: "2-digit", month: "short", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

// ── Pretty JSON for <pre> blocks ──────────────────────────────────────────────

export function prettyJson(value: unknown): string {
  if (!value) return "—";
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return String(value);
  }
}
