"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { Receipt, CheckCircle, XCircle, Save } from "lucide-react";

interface InvoiceSettings {
  invoice_prefix?: string;
  invoice_number_format?: string;
  default_payment_terms_days?: number;
  auto_generate_invoice?: boolean;
  auto_invoice_trigger?: string;
  show_bank_details_on_invoice?: boolean;
  invoice_footer_text?: string;
  invoice_terms_text?: string;
}

const AUTO_INVOICE_OPTIONS = [
  { value: "on_delivery",  label: "On Delivery" },
  { value: "on_dispatch",  label: "On Dispatch" },
  { value: "manual",       label: "Manual only" },
];

const NUMBER_FORMAT_OPTIONS = [
  { value: "INV-{YYYY}-{SEQ}",     label: "INV-2026-0001" },
  { value: "INV-{YYMM}-{SEQ}",     label: "INV-2601-0001" },
  { value: "{PREFIX}-{SEQ}",        label: "PREFIX-0001 (uses prefix)" },
  { value: "{PREFIX}/{YYYY}/{SEQ}", label: "PREFIX/2026/0001" },
];

export default function InvoiceSettingsPage() {
  const { token, orgId } = useOrgBranch();

  const [form,    setForm]    = useState<InvoiceSettings>({
    invoice_prefix:                "INV",
    invoice_number_format:         "INV-{YYYY}-{SEQ}",
    default_payment_terms_days:    30,
    auto_generate_invoice:         true,
    auto_invoice_trigger:          "on_delivery",
    show_bank_details_on_invoice:  true,
    invoice_footer_text:           "",
    invoice_terms_text:            "Payment due within {TERMS} days of invoice date.",
  });
  const [loading, setLoading] = useState(false);
  const [saving,  setSaving]  = useState(false);
  const [toast,   setToast]   = useState<{ type: "success" | "error"; msg: string } | null>(null);

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  const fetchSettings = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/organizations/${orgId}/settings`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        const s = json.data?.settings ?? {};
        setForm((prev) => ({
          ...prev,
          invoice_prefix:               s.invoice_prefix               ?? prev.invoice_prefix,
          invoice_number_format:        s.invoice_number_format        ?? prev.invoice_number_format,
          default_payment_terms_days:   s.default_payment_terms_days   ?? prev.default_payment_terms_days,
          auto_generate_invoice:        s.auto_generate_invoice        ?? prev.auto_generate_invoice,
          auto_invoice_trigger:         s.auto_invoice_trigger         ?? prev.auto_invoice_trigger,
          show_bank_details_on_invoice: s.show_bank_details_on_invoice ?? prev.show_bank_details_on_invoice,
          invoice_footer_text:          s.invoice_footer_text          ?? prev.invoice_footer_text,
          invoice_terms_text:           s.invoice_terms_text           ?? prev.invoice_terms_text,
        }));
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId]);

  useEffect(() => { fetchSettings(); }, [fetchSettings]);

  const handleChange = <K extends keyof InvoiceSettings>(key: K, value: InvoiceSettings[K]) => {
    setForm((prev) => ({ ...prev, [key]: value }));
  };

  const handleSave = async () => {
    if (!token || !orgId) return;
    setSaving(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/organizations/${orgId}/settings`, {
        method:  "PATCH",
        headers: {
          Authorization:    `Bearer ${token}`,
          "X-Organization-Id": orgId,
          "Content-Type":   "application/json",
        },
        body: JSON.stringify({ settings: form }),
      });
      const json = await res.json();
      if (res.ok) {
        showToast("success", "Invoice settings saved");
      } else {
        showToast("error", json.errors?.join(", ") ?? "Save failed");
      }
    } finally {
      setSaving(false);
    }
  };

  return (
    <AppShell title="Invoice Settings">
      <PageHeader
        title="Invoice Settings"
        description="Configure numbering, payment terms, and invoice content"
        actions={[
          { label: saving ? "Saving…" : "Save Changes", onClick: handleSave, icon: Save, disabled: saving || loading },
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

      <div className="grid gap-4 lg:grid-cols-2">
        {/* Numbering */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <Receipt className="h-4 w-4 text-accent" />
              Invoice Numbering
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="mb-1 block text-xs font-medium text-text-secondary">Invoice Prefix</label>
              <Input
                value={form.invoice_prefix ?? ""}
                onChange={(e) => handleChange("invoice_prefix", e.target.value)}
                placeholder="INV"
                className="max-w-[180px]"
              />
              <p className="mt-1 text-xs text-text-secondary">Used when format includes {"{PREFIX}"}</p>
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-text-secondary">Number Format</label>
              <select
                value={form.invoice_number_format ?? "INV-{YYYY}-{SEQ}"}
                onChange={(e) => handleChange("invoice_number_format", e.target.value)}
                className="h-9 w-full rounded-md border border-input bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
              >
                {NUMBER_FORMAT_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>{o.label}</option>
                ))}
              </select>
            </div>
          </CardContent>
        </Card>

        {/* Payment Terms */}
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-semibold">Payment Terms</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div>
              <label className="mb-1 block text-xs font-medium text-text-secondary">Default Payment Terms (days)</label>
              <Input
                type="number"
                min={0}
                max={365}
                value={form.default_payment_terms_days ?? 30}
                onChange={(e) => handleChange("default_payment_terms_days", parseInt(e.target.value, 10))}
                className="max-w-[120px]"
              />
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-text-secondary">Terms Text on Invoice</label>
              <textarea
                value={form.invoice_terms_text ?? ""}
                onChange={(e) => handleChange("invoice_terms_text", e.target.value)}
                rows={3}
                placeholder="Payment due within {TERMS} days of invoice date."
                className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
              />
            </div>
          </CardContent>
        </Card>

        {/* Auto-generate */}
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-semibold">Auto-Generation</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <label className="flex items-center justify-between cursor-pointer">
              <div>
                <p className="text-sm font-medium text-text-primary">Auto-generate invoices</p>
                <p className="text-xs text-text-secondary">Automatically create invoices on trigger event</p>
              </div>
              <button
                type="button"
                role="switch"
                aria-checked={form.auto_generate_invoice}
                onClick={() => handleChange("auto_generate_invoice", !form.auto_generate_invoice)}
                className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                  form.auto_generate_invoice ? "bg-accent" : "bg-muted"
                }`}
              >
                <span className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${
                  form.auto_generate_invoice ? "translate-x-4" : "translate-x-0.5"
                }`} />
              </button>
            </label>

            {form.auto_generate_invoice && (
              <div>
                <label className="mb-1 block text-xs font-medium text-text-secondary">Trigger Event</label>
                <select
                  value={form.auto_invoice_trigger ?? "on_delivery"}
                  onChange={(e) => handleChange("auto_invoice_trigger", e.target.value)}
                  className="h-9 w-full rounded-md border border-input bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
                >
                  {AUTO_INVOICE_OPTIONS.map((o) => (
                    <option key={o.value} value={o.value}>{o.label}</option>
                  ))}
                </select>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Invoice Content */}
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-semibold">Invoice Content</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <label className="flex items-center justify-between cursor-pointer">
              <div>
                <p className="text-sm font-medium text-text-primary">Show bank details</p>
                <p className="text-xs text-text-secondary">Display bank account on printed invoices</p>
              </div>
              <button
                type="button"
                role="switch"
                aria-checked={form.show_bank_details_on_invoice}
                onClick={() => handleChange("show_bank_details_on_invoice", !form.show_bank_details_on_invoice)}
                className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
                  form.show_bank_details_on_invoice ? "bg-accent" : "bg-muted"
                }`}
              >
                <span className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${
                  form.show_bank_details_on_invoice ? "translate-x-4" : "translate-x-0.5"
                }`} />
              </button>
            </label>

            <div>
              <label className="mb-1 block text-xs font-medium text-text-secondary">Footer Text</label>
              <textarea
                value={form.invoice_footer_text ?? ""}
                onChange={(e) => handleChange("invoice_footer_text", e.target.value)}
                rows={3}
                placeholder="Thank you for your business!"
                className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
              />
            </div>
          </CardContent>
        </Card>
      </div>
    </AppShell>
  );
}
