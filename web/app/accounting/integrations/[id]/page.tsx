"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import {
  ChevronLeft, Save, TestTube2, Link2, Link2Off,
  Plus, Trash2, CheckCircle2, XCircle, Loader2,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { useOrgBranch } from "@/lib/org-branch-context";
import {
  fetchIntegration,
  updateIntegration,
  testIntegrationConfig,
  markIntegrationConnected,
  markIntegrationDisconnected,
  fetchMappings,
  upsertMapping,
  deleteMapping,
  type AccountingIntegration,
  type AccountingMapping,
} from "@/lib/api/accounting";
import { IntegrationStatusBadge, providerLabel, fmtDatetime } from "../../_utils";

// ── Config field groups for Tally ─────────────────────────────────────────────

const CONFIG_GROUPS = [
  {
    title: "Connection",
    fields: [
      { key: "tally_host",     label: "Tally Host",      placeholder: "localhost" },
      { key: "tally_port",     label: "Tally Port",      placeholder: "9000" },
      { key: "company_name",   label: "Company Name",    placeholder: "My Company Ltd" },
      { key: "financial_year", label: "Financial Year",  placeholder: "2025-26" },
    ],
  },
  {
    title: "Default Ledgers",
    fields: [
      { key: "default_sales_ledger",    label: "Default Sales Ledger",    placeholder: "Sales Account" },
      { key: "default_purchase_ledger", label: "Default Purchase Ledger", placeholder: "Purchase Account" },
      { key: "round_off_ledger",        label: "Round Off Ledger",        placeholder: "Round Off" },
    ],
  },
  {
    title: "Ledger Groups",
    fields: [
      { key: "retailers_group_name", label: "Retailers Group",  placeholder: "Sundry Debtors" },
      { key: "suppliers_group_name", label: "Suppliers Group",  placeholder: "Sundry Creditors" },
    ],
  },
  {
    title: "GST Output Ledgers",
    fields: [
      { key: "cgst_output_ledger", label: "CGST Output", placeholder: "Output CGST" },
      { key: "sgst_output_ledger", label: "SGST Output", placeholder: "Output SGST" },
      { key: "igst_output_ledger", label: "IGST Output", placeholder: "Output IGST" },
    ],
  },
  {
    title: "GST Input Ledgers",
    fields: [
      { key: "cgst_input_ledger", label: "CGST Input", placeholder: "Input CGST" },
      { key: "sgst_input_ledger", label: "SGST Input", placeholder: "Input SGST" },
      { key: "igst_input_ledger", label: "IGST Input", placeholder: "Input IGST" },
    ],
  },
  {
    title: "Other Settings",
    fields: [
      { key: "narration_template", label: "Narration Template", placeholder: "Invoice {number} for {customer}" },
    ],
  },
];

const MAPPING_KEYS = [
  "retailers_group", "suppliers_group",
  "sales_ledger", "purchase_ledger", "round_off_ledger",
  "cgst_output_ledger", "sgst_output_ledger", "igst_output_ledger",
  "cgst_input_ledger", "sgst_input_ledger", "igst_input_ledger",
];

// ── Toast ─────────────────────────────────────────────────────────────────────

type ToastType = "success" | "error" | "info";

function Toast({ type, message, onDismiss }: { type: ToastType; message: string; onDismiss: () => void }) {
  const colors: Record<ToastType, string> = {
    success: "bg-[#E8F5EE] border-accent text-[#1B4332]",
    error:   "bg-red-50 border-danger text-red-800",
    info:    "bg-blue-50 border-blue-400 text-blue-800",
  };
  const icons: Record<ToastType, React.ReactNode> = {
    success: <CheckCircle2 className="h-4 w-4 shrink-0" />,
    error:   <XCircle className="h-4 w-4 shrink-0" />,
    info:    <CheckCircle2 className="h-4 w-4 shrink-0" />,
  };
  return (
    <div className={`fixed top-4 right-4 z-50 flex items-center gap-2 rounded-lg border-l-4 px-4 py-3 text-sm shadow-lg max-w-sm ${colors[type]}`}>
      {icons[type]}
      <span className="flex-1">{message}</span>
      <button onClick={onDismiss} className="ml-2 opacity-60 hover:opacity-100">✕</button>
    </div>
  );
}

// ── Mapping row ───────────────────────────────────────────────────────────────

function MappingRow({
  mappingKey,
  existing,
  onSave,
  onDelete,
}: {
  mappingKey: string;
  existing?: AccountingMapping;
  onSave: (key: string, value: string) => Promise<void>;
  onDelete?: (id: number) => Promise<void>;
}) {
  const [value, setValue] = useState(existing?.mapping_value ?? "");
  const [saving, setSaving] = useState(false);

  const label = mappingKey.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());

  const handleSave = async () => {
    if (!value.trim()) return;
    setSaving(true);
    try { await onSave(mappingKey, value.trim()); } finally { setSaving(false); }
  };

  return (
    <div className="flex items-center gap-2 py-2 border-b border-border last:border-0">
      <span className="w-48 text-sm text-text-secondary shrink-0">{label}</span>
      <Input
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="Enter Tally ledger / group name"
        className="flex-1 h-8 text-sm"
      />
      <Button size="sm" variant="outline" onClick={handleSave} disabled={saving || !value.trim()}>
        {saving ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Save className="h-3.5 w-3.5" />}
      </Button>
      {existing && onDelete && (
        <Button size="sm" variant="ghost" onClick={() => onDelete(existing.id)} className="text-danger hover:bg-red-50">
          <Trash2 className="h-3.5 w-3.5" />
        </Button>
      )}
    </div>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function IntegrationDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [integration, setIntegration] = useState<AccountingIntegration | null>(null);
  const [mappings, setMappings]   = useState<AccountingMapping[]>([]);
  const [config, setConfig]       = useState<Record<string, string>>({});
  const [loading, setLoading]     = useState(true);
  const [saving, setSaving]       = useState(false);
  const [testing, setTesting]     = useState(false);
  const [toast, setToast]         = useState<{ type: ToastType; message: string } | null>(null);

  const showToast = (type: ToastType, message: string) => {
    setToast({ type, message });
    setTimeout(() => setToast(null), 4000);
  };

  const load = useCallback(async () => {
    if (!token || !orgId || !id) return;
    setLoading(true);
    try {
      const [integ, maps] = await Promise.all([
        fetchIntegration(Number(id), token, orgId),
        fetchMappings(Number(id), token, orgId),
      ]);
      setIntegration(integ);
      setMappings(maps);
      // Populate config from config_json
      const cfg: Record<string, string> = {};
      Object.entries(integ.config_json ?? {}).forEach(([k, v]) => {
        cfg[k] = v ?? "";
      });
      setConfig(cfg);
    } catch {
      showToast("error", "Failed to load integration.");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, id]);

  useEffect(() => { load(); }, [load]);

  // ── Save config ────────────────────────────────────────────────────────────

  const handleSave = async () => {
    if (!token || !orgId || !integration) return;
    setSaving(true);
    try {
      const updated = await updateIntegration(
        integration.id,
        { config_json: config },
        token,
        orgId
      );
      setIntegration(updated);
      setConfig(Object.fromEntries(
        Object.entries(updated.config_json ?? {}).map(([k, v]) => [k, v ?? ""])
      ));
      showToast("success", "Configuration saved.");
    } catch {
      showToast("error", "Failed to save — check all required fields.");
    } finally {
      setSaving(false);
    }
  };

  // ── Test config ────────────────────────────────────────────────────────────

  const handleTest = async () => {
    if (!token || !orgId || !integration) return;
    setTesting(true);
    try {
      const result = await testIntegrationConfig(integration.id, token, orgId);
      showToast(result.valid ? "success" : "error", result.message);
    } catch (e: unknown) {
      const msg = (e as { response?: { data?: { errors?: string[] } } })?.response?.data?.errors?.[0] ?? "Validation failed.";
      showToast("error", msg);
    } finally {
      setTesting(false);
    }
  };

  // ── Status actions ─────────────────────────────────────────────────────────

  const handleMarkConnected = async () => {
    if (!token || !orgId || !integration) return;
    try {
      await markIntegrationConnected(integration.id, token, orgId);
      showToast("success", "Marked as connected.");
      load();
    } catch { showToast("error", "Action failed."); }
  };

  const handleMarkDisconnected = async () => {
    if (!token || !orgId || !integration) return;
    try {
      await markIntegrationDisconnected(integration.id, token, orgId);
      showToast("info", "Marked as disconnected.");
      load();
    } catch { showToast("error", "Action failed."); }
  };

  // ── Mappings ──────────────────────────────────────────────────────────────

  const handleSaveMapping = async (key: string, value: string) => {
    if (!token || !orgId || !integration) return;
    await upsertMapping(integration.id, { mapping_key: key, mapping_value: value }, token, orgId);
    const fresh = await fetchMappings(integration.id, token, orgId);
    setMappings(fresh);
    showToast("success", `Mapping "${key}" saved.`);
  };

  const handleDeleteMapping = async (mappingId: number) => {
    if (!token || !orgId || !integration) return;
    await deleteMapping(integration.id, mappingId, token, orgId);
    setMappings((prev) => prev.filter((m) => m.id !== mappingId));
    showToast("info", "Mapping removed.");
  };

  const mappingsByKey = Object.fromEntries(mappings.map((m) => [m.mapping_key, m]));

  // ── Loading ────────────────────────────────────────────────────────────────

  if (loading) {
    return (
      <div className="space-y-4">
        {[1, 2, 3].map((n) => (
          <Card key={n}>
            <CardContent className="p-6 space-y-3">
              <div className="h-5 w-40 bg-border rounded animate-pulse" />
              <div className="grid grid-cols-2 gap-3">
                {[1, 2, 3, 4].map((m) => (
                  <div key={m} className="h-9 bg-border/50 rounded animate-pulse" />
                ))}
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  if (!integration) return null;

  return (
    <>
      {toast && (
        <Toast type={toast.type} message={toast.message} onDismiss={() => setToast(null)} />
      )}

      {/* ── Back + header ── */}
      <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 mb-6">
        <div>
          <button
            onClick={() => router.push("/accounting/integrations")}
            className="flex items-center gap-1 text-xs text-text-secondary hover:text-text-primary mb-2 transition-colors"
          >
            <ChevronLeft className="h-3.5 w-3.5" />
            Integrations
          </button>
          <div className="flex items-center gap-3">
            <h2 className="text-xl font-bold text-text-primary">
              {providerLabel(integration.provider)}
            </h2>
            <IntegrationStatusBadge status={integration.status} />
          </div>
          <p className="text-xs text-text-secondary mt-1">
            Last synced: {fmtDatetime(integration.last_synced_at)} ·{" "}
            Updated: {fmtDatetime(integration.updated_at)}
          </p>
        </div>

        {/* Status actions */}
        <div className="flex gap-2 shrink-0">
          <Button
            size="sm"
            variant="outline"
            onClick={handleTest}
            disabled={testing}
          >
            {testing ? <Loader2 className="mr-1.5 h-3.5 w-3.5 animate-spin" /> : <TestTube2 className="mr-1.5 h-3.5 w-3.5" />}
            Test Config
          </Button>
          {integration.status !== "connected" ? (
            <Button size="sm" variant="outline" onClick={handleMarkConnected} className="text-accent border-accent/50 hover:bg-accent/10">
              <Link2 className="mr-1.5 h-3.5 w-3.5" />
              Mark Connected
            </Button>
          ) : (
            <Button size="sm" variant="outline" onClick={handleMarkDisconnected} className="text-text-secondary">
              <Link2Off className="mr-1.5 h-3.5 w-3.5" />
              Disconnect
            </Button>
          )}
        </div>
      </div>

      {/* ── Error banner ── */}
      {integration.last_error_message && (
        <div className="flex items-start gap-2 bg-red-50 border border-red-200 rounded-lg px-4 py-3 mb-5 text-sm text-red-700">
          <XCircle className="h-4 w-4 shrink-0 mt-px" />
          <div>
            <span className="font-medium">Last error: </span>
            {integration.last_error_message}
          </div>
        </div>
      )}

      <div className="grid lg:grid-cols-3 gap-6">
        {/* ── Left: Config form (2/3 width) ── */}
        <div className="lg:col-span-2 space-y-5">

          {/* Sync mode */}
          <Card className="border-amber-200 bg-amber-50">
            <CardHeader className="pb-3">
              <CardTitle className="text-base text-amber-900">Sync Configuration</CardTitle>
            </CardHeader>
            <CardContent className="pt-0">
              <div className="text-sm text-amber-800 leading-relaxed">
                <p className="mb-2">
                  ✨ Configure automatic syncs on order approvals, deliveries, and payments at{" "}
                  <a
                    href="/settings/organization?tab=workflow"
                    className="font-medium underline hover:no-underline cursor-pointer"
                  >
                    Organization Workflow Settings
                  </a>{" "}
                  → <em>Accounting Sync Automation</em>.
                </p>
              </div>
            </CardContent>
          </Card>

          {/* Config groups */}
          {CONFIG_GROUPS.map((group) => (
            <Card key={group.title}>
              <CardHeader className="pb-3">
                <CardTitle className="text-base">{group.title}</CardTitle>
              </CardHeader>
              <CardContent className="pt-0">
                <div className="grid sm:grid-cols-2 gap-3">
                  {group.fields.map((field) => (
                    <div key={field.key} className="flex flex-col gap-1">
                      <label className="text-xs font-medium text-text-secondary">{field.label}</label>
                      <Input
                        value={config[field.key] ?? ""}
                        onChange={(e) =>
                          setConfig((prev) => ({ ...prev, [field.key]: e.target.value }))
                        }
                        placeholder={field.placeholder}
                        className="h-9 text-sm"
                      />
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          ))}

          {/* Save button */}
          <div className="flex justify-end">
            <Button onClick={handleSave} disabled={saving}>
              {saving ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <Save className="mr-2 h-4 w-4" />}
              Save Configuration
            </Button>
          </div>
        </div>

        {/* ── Right: Summary + mappings (1/3 width) ── */}
        <div className="space-y-5">

          {/* Quick links */}
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-sm text-text-secondary uppercase tracking-wide">Quick Links</CardTitle>
            </CardHeader>
            <CardContent className="pt-0 space-y-2">
              <a
                href={`/accounting/sync-records?integration_id=${integration.id}`}
                className="flex items-center justify-between text-sm text-primary hover:underline py-1"
              >
                View Sync Dashboard
                <span className="text-text-secondary">→</span>
              </a>
              <a
                href={`/accounting/export-files?integration_id=${integration.id}`}
                className="flex items-center justify-between text-sm text-primary hover:underline py-1"
              >
                Export Center
                <span className="text-text-secondary">→</span>
              </a>
            </CardContent>
          </Card>

          {/* Mappings */}
          <Card>
            <CardHeader className="pb-3">
              <CardTitle className="text-base">Ledger Mappings</CardTitle>
              <p className="text-xs text-text-secondary mt-1">
                Override the default ledger / group names from the config above with custom Tally names.
              </p>
            </CardHeader>
            <CardContent className="pt-0">
              {MAPPING_KEYS.map((key) => (
                <MappingRow
                  key={key}
                  mappingKey={key}
                  existing={mappingsByKey[key]}
                  onSave={handleSaveMapping}
                  onDelete={handleDeleteMapping}
                />
              ))}
            </CardContent>
          </Card>
        </div>
      </div>
    </>
  );
}
