"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import {
  Settings, Activity, AlertTriangle, CheckCircle2,
  Clock, XCircle, Plus, ChevronRight,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { useOrgBranch } from "@/lib/org-branch-context";
import {
  fetchIntegrations,
  createIntegration,
  type AccountingIntegration,
} from "@/lib/api/accounting";
import { IntegrationStatusBadge, providerLabel, fmtTimestamp } from "../_utils";

// ── Provider metadata ─────────────────────────────────────────────────────────

const PROVIDER_META: Record<string, { description: string; phase: "live" | "coming_soon" }> = {
  tally:      { description: "Tally ERP 9 / TallyPrime via XML import", phase: "live" },
  zoho_books: { description: "Zoho Books cloud accounting",              phase: "coming_soon" },
  busy:       { description: "BUSY Accounting software",                 phase: "coming_soon" },
  marg:       { description: "Marg ERP for pharma and FMCG",            phase: "coming_soon" },
};

// ── Stat card ─────────────────────────────────────────────────────────────────

function StatCard({
  icon: Icon,
  label,
  value,
  color,
}: {
  icon: React.ElementType;
  label: string;
  value: string | number;
  color: string;
}) {
  return (
    <Card>
      <CardContent className="flex items-center gap-4 p-4">
        <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-lg ${color}`}>
          <Icon className="h-5 w-5" />
        </div>
        <div>
          <p className="text-xs text-text-secondary font-medium">{label}</p>
          <p className="text-xl font-bold text-text-primary">{value}</p>
        </div>
      </CardContent>
    </Card>
  );
}

// ── Integration card ──────────────────────────────────────────────────────────

function IntegrationCard({
  integration,
  onConfigure,
}: {
  integration: AccountingIntegration;
  onConfigure: (id: number) => void;
}) {
  const meta = PROVIDER_META[integration.provider];

  return (
    <Card className="hover:shadow-md transition-shadow">
      <CardContent className="p-5">
        {/* Header */}
        <div className="flex items-start justify-between mb-3">
          <div>
            <p className="font-semibold text-text-primary text-base">
              {providerLabel(integration.provider)}
            </p>
            <p className="text-xs text-text-secondary mt-0.5">{meta?.description ?? ""}</p>
          </div>
          <IntegrationStatusBadge status={integration.status} />
        </div>

        {/* Details row */}
        <div className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-text-secondary mb-3">
          <span>
            <span className="font-medium text-text-primary">Mode:</span>{" "}
            {integration.sync_mode.replace("_", " ")}
          </span>
          <span>
            <span className="font-medium text-text-primary">Last sync:</span>{" "}
            {fmtTimestamp(integration.last_synced_at)}
          </span>
        </div>

        {/* Error strip */}
        {integration.last_error_message && (
          <div className="flex items-start gap-1.5 bg-red-50 border border-red-100 rounded px-2.5 py-1.5 mb-3">
            <AlertTriangle className="h-3.5 w-3.5 text-danger shrink-0 mt-px" />
            <p className="text-xs text-red-700 truncate">{integration.last_error_message}</p>
          </div>
        )}

        {/* Actions */}
        <div className="flex gap-2">
          <Button
            size="sm"
            onClick={() => onConfigure(integration.id)}
            className="flex-1"
          >
            <Settings className="mr-1.5 h-3.5 w-3.5" />
            Configure
          </Button>
          <Button
            size="sm"
            variant="outline"
            onClick={() => (window.location.href = `/accounting/sync-records?integration_id=${integration.id}`)}
            className="flex-1"
          >
            <Activity className="mr-1.5 h-3.5 w-3.5" />
            Sync Log
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}

// ── Coming-soon placeholder card ──────────────────────────────────────────────

function PlaceholderCard({ provider }: { provider: string }) {
  const meta = PROVIDER_META[provider]!;
  return (
    <Card className="opacity-60">
      <CardContent className="p-5">
        <div className="flex items-start justify-between mb-2">
          <p className="font-semibold text-text-primary">{providerLabel(provider)}</p>
          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-background-subtle text-text-secondary border border-border">
            Coming soon
          </span>
        </div>
        <p className="text-xs text-text-secondary">{meta.description}</p>
      </CardContent>
    </Card>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function IntegrationsPage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [integrations, setIntegrations] = useState<AccountingIntegration[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const data = await fetchIntegrations(token, orgId);
      setIntegrations(data);
    } catch {
      setError("Failed to load integrations.");
    } finally {
      setLoading(false);
    }
  }, [token, orgId]);

  useEffect(() => { load(); }, [load]);

  const [creating, setCreating] = useState(false);

  const handleSetUpTally = async () => {
    if (!token || !orgId || creating) return;
    setCreating(true);
    try {
      const integration = await createIntegration(
        { provider: "tally", sync_mode: "batch_export" },
        token,
        orgId
      );
      router.push(`/accounting/integrations/${integration.id}`);
    } catch (err: any) {
      const msg = err?.response?.data?.errors?.[0] ?? "Failed to create integration.";
      setError(msg);
      setCreating(false);
    }
  };

  const configuredProviders = integrations.map((i) => i.provider);
  const comingSoonProviders = Object.keys(PROVIDER_META).filter(
    (p) => PROVIDER_META[p].phase === "coming_soon" && !configuredProviders.includes(p)
  );

  // Summary stats
  const connected = integrations.filter((i) => i.status === "connected").length;
  const withErrors = integrations.filter((i) => i.status === "error").length;

  return (
    <div>
      {/* ── Stats strip ── */}
      {!loading && integrations.length > 0 && (
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
          <StatCard icon={CheckCircle2} label="Connected"    value={connected}              color="bg-accent/15 text-accent" />
          <StatCard icon={AlertTriangle} label="Errors"      value={withErrors}             color="bg-red-100 text-danger" />
          <StatCard icon={Activity}      label="Total"       value={integrations.length}    color="bg-primary/10 text-primary" />
          <StatCard icon={Clock}         label="Last sync"
            value={
              integrations
                .map((i) => i.last_synced_at)
                .filter(Boolean)
                .sort()
                .at(-1)
                ? fmtTimestamp(
                    integrations
                      .map((i) => i.last_synced_at)
                      .filter(Boolean)
                      .sort()
                      .at(-1)!
                  )
                : "Never"
            }
            color="bg-yellow-50 text-warning"
          />
        </div>
      )}

      {/* ── Loading skeleton ── */}
      {loading && (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {[1, 2, 3].map((n) => (
            <Card key={n}>
              <CardContent className="p-5 space-y-3">
                <div className="h-5 w-32 bg-border rounded animate-pulse" />
                <div className="h-3 w-48 bg-border/60 rounded animate-pulse" />
                <div className="h-8 w-full bg-border/40 rounded animate-pulse" />
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* ── Error ── */}
      {error && (
        <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-lg px-4 py-3 text-sm text-red-700">
          <XCircle className="h-4 w-4 shrink-0" />
          {error}
        </div>
      )}

      {/* ── Configured integrations ── */}
      {!loading && integrations.length > 0 && (
        <section className="mb-8">
          <h2 className="text-sm font-semibold text-text-secondary uppercase tracking-wider mb-3">
            Configured Providers
          </h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {integrations.map((i) => (
              <IntegrationCard
                key={i.id}
                integration={i}
                onConfigure={(id) => router.push(`/accounting/integrations/${id}`)}
              />
            ))}
          </div>
        </section>
      )}

      {/* ── Empty state (no integrations configured yet) ── */}
      {!loading && !error && integrations.length === 0 && (
        <Card className="mb-8">
          <CardContent className="flex flex-col items-center justify-center py-16 text-center gap-3">
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-primary/10">
              <Activity className="h-7 w-7 text-primary" />
            </div>
            <h3 className="font-semibold text-text-primary text-lg">No integrations yet</h3>
            <p className="text-sm text-text-secondary max-w-sm">
              Connect your accounting software to start syncing invoices, payments, and
              ledgers automatically.
            </p>
            <Button
              variant="outline"
              className="mt-2"
              onClick={handleSetUpTally}
              disabled={creating}
            >
              {creating ? (
                <>
                  <span className="mr-1.5 h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent inline-block" />
                  Setting up…
                </>
              ) : (
                <>
                  <Plus className="mr-1.5 h-4 w-4" />
                  Set up Tally Integration
                </>
              )}
            </Button>
          </CardContent>
        </Card>
      )}

      {/* ── Coming-soon placeholders ── */}
      {comingSoonProviders.length > 0 && (
        <section>
          <h2 className="text-sm font-semibold text-text-secondary uppercase tracking-wider mb-3">
            More Integrations — Coming Soon
          </h2>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {comingSoonProviders.map((p) => (
              <PlaceholderCard key={p} provider={p} />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
