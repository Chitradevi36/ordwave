"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { ChevronLeft, FileOutput, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { useOrgBranch } from "@/lib/org-branch-context";
import {
  fetchIntegrations,
  createExportFile,
  type AccountingIntegration,
} from "@/lib/api/accounting";
import { providerLabel } from "../../_utils";

const EXPORT_TYPES = [
  { value: "all",              label: "All (Masters + Vouchers)" },
  { value: "invoices",         label: "Sales Invoices" },
  { value: "payments",         label: "Payments / Collections" },
  { value: "credit_notes",     label: "Credit Notes" },
  { value: "purchase_invoices",label: "Purchase Invoices" },
  { value: "masters",          label: "Masters (Customers, Suppliers, Products)" },
];

interface FormState {
  accounting_integration_id: string;
  export_type: string;
  date_from: string;
  date_to: string;
  branch_id: string;
}

export default function NewExportFilePage() {
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [integrations, setIntegrations] = useState<AccountingIntegration[]>([]);
  const [loading, setLoading]   = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError]       = useState<string | null>(null);

  const [form, setForm] = useState<FormState>({
    accounting_integration_id: "",
    export_type: "all",
    date_from: "",
    date_to: "",
    branch_id: "",
  });

  const setField = (key: keyof FormState, value: string) =>
    setForm((prev) => ({ ...prev, [key]: value }));

  const load = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const data = await fetchIntegrations(token, orgId);
      setIntegrations(data.filter((i) => ["connected", "error"].includes(i.status)));
      if (data.length > 0) setField("accounting_integration_id", String(data[0].id));
    } catch { setError("Failed to load integrations."); }
    finally { setLoading(false); }
  }, [token, orgId]);

  useEffect(() => { load(); }, [load]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !orgId) return;
    if (!form.accounting_integration_id) {
      setError("Please select an integration.");
      return;
    }
    setError(null);
    setSubmitting(true);
    try {
      const payload: Parameters<typeof createExportFile>[0] = {
        accounting_integration_id: Number(form.accounting_integration_id),
        export_type: form.export_type,
      };
      if (form.date_from) payload.date_from = form.date_from;
      if (form.date_to)   payload.date_to   = form.date_to;
      if (form.branch_id) payload.branch_id = Number(form.branch_id);
      const created = await createExportFile(payload, token, orgId);
      router.push(`/accounting/export-files/${created.id}`);
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { errors?: string[] } } })?.response?.data?.errors?.[0] ??
        "Failed to create export. Check all fields.";
      setError(msg);
    } finally {
      setSubmitting(false);
    }
  };

  const selectCls = "w-full h-10 rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary";
  const labelCls  = "block text-xs font-medium text-text-secondary mb-1";

  return (
    <div className="max-w-2xl">
      {/* Header */}
      <div className="mb-6">
        <button
          onClick={() => router.push("/accounting/export-files")}
          className="flex items-center gap-1 text-xs text-text-secondary hover:text-text-primary mb-2 transition-colors"
        >
          <ChevronLeft className="h-3.5 w-3.5" />
          Export Center
        </button>
        <h2 className="text-xl font-bold text-text-primary">New Batch Export</h2>
        <p className="text-sm text-text-secondary mt-1">
          Generate a Tally XML export file. The job runs in the background — you can
          monitor progress from the Export Center.
        </p>
      </div>

      {loading ? (
        <Card>
          <CardContent className="p-6 space-y-3">
            {[1, 2, 3].map((n) => <div key={n} className="h-9 bg-border/50 rounded animate-pulse" />)}
          </CardContent>
        </Card>
      ) : (
        <form onSubmit={handleSubmit}>
          <Card>
            <CardHeader className="pb-4">
              <CardTitle className="text-base">Export Settings</CardTitle>
            </CardHeader>
            <CardContent className="pt-0 space-y-4">

              {/* Integration */}
              <div>
                <label className={labelCls}>Integration / Provider *</label>
                <select
                  required
                  value={form.accounting_integration_id}
                  onChange={(e) => setField("accounting_integration_id", e.target.value)}
                  className={selectCls}
                >
                  <option value="">Select integration…</option>
                  {integrations.map((i) => (
                    <option key={i.id} value={String(i.id)}>
                      {providerLabel(i.provider)} — {i.status}
                    </option>
                  ))}
                </select>
                {integrations.length === 0 && (
                  <p className="text-xs text-danger mt-1">
                    No connected integrations found. Configure an integration first.
                  </p>
                )}
              </div>

              {/* Export type */}
              <div>
                <label className={labelCls}>Export Type *</label>
                <select
                  required
                  value={form.export_type}
                  onChange={(e) => setField("export_type", e.target.value)}
                  className={selectCls}
                >
                  {EXPORT_TYPES.map((t) => (
                    <option key={t.value} value={t.value}>{t.label}</option>
                  ))}
                </select>
              </div>

              {/* Date range */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={labelCls}>Date From (optional)</label>
                  <Input
                    type="date"
                    value={form.date_from}
                    onChange={(e) => setField("date_from", e.target.value)}
                    className="h-10 text-sm"
                  />
                </div>
                <div>
                  <label className={labelCls}>Date To (optional)</label>
                  <Input
                    type="date"
                    value={form.date_to}
                    onChange={(e) => setField("date_to", e.target.value)}
                    className="h-10 text-sm"
                  />
                </div>
              </div>

              {/* Helper text */}
              <p className="text-xs text-text-secondary">
                Leave dates blank to export all records in the scope. For masters
                (customers, suppliers, products), date range is ignored.
              </p>

              {/* Error */}
              {error && (
                <div className="flex items-center gap-2 bg-red-50 border border-red-200 rounded-md px-3 py-2 text-sm text-red-700">
                  {error}
                </div>
              )}

            </CardContent>
          </Card>

          <div className="flex items-center justify-end gap-3 mt-4">
            <Button
              type="button"
              variant="outline"
              onClick={() => router.push("/accounting/export-files")}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={submitting || integrations.length === 0}>
              {submitting ? (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              ) : (
                <FileOutput className="mr-2 h-4 w-4" />
              )}
              Start Export Job
            </Button>
          </div>
        </form>
      )}
    </div>
  );
}
