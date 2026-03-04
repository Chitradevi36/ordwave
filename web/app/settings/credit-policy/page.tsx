"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";
import { Breadcrumb } from "@/components/ui/breadcrumb";
import { RotateCcw, Save } from "lucide-react";

// ──────────────────────────────────────────────────────────────────────────────
// Types
// ──────────────────────────────────────────────────────────────────────────────
interface CreditPolicy {
  id: number;
  hard_block_overdue_days: number;
  hard_block_margin_pct: number;
  soft_hold_overdue_days_min: number;
  soft_hold_overdue_days_max: number;
  soft_hold_outstanding_pct: number;
  collection_first_bucket: string;
  approval_sla_hours_manager: number;
  approval_sla_hours_owner: number;
  auto_invoice_trigger: string;
  allow_partial_allocation: boolean;
  updated_at: string;
}

const DEFAULTS: Omit<CreditPolicy, "id" | "updated_at"> = {
  hard_block_overdue_days: 30,
  hard_block_margin_pct: 20,
  soft_hold_overdue_days_min: 15,
  soft_hold_overdue_days_max: 29,
  soft_hold_outstanding_pct: 100,
  collection_first_bucket: "serious",
  approval_sla_hours_manager: 4,
  approval_sla_hours_owner: 8,
  auto_invoice_trigger: "on_delivery",
  allow_partial_allocation: true,
};

const AUTO_INVOICE_OPTIONS = [
  { value: "on_delivery", label: "On Delivery" },
  { value: "on_dispatch", label: "On Dispatch" },
  { value: "on_invoice_creation", label: "On Invoice Creation" },
];

const BUCKET_OPTIONS = [
  { value: "mild",     label: "Mild (1–14 days)" },
  { value: "moderate", label: "Moderate (15–29 days)" },
  { value: "serious",  label: "Serious (30–59 days)" },
  { value: "critical", label: "Critical (60+ days)" },
];

// ──────────────────────────────────────────────────────────────────────────────
// Page
// ──────────────────────────────────────────────────────────────────────────────
export default function CreditPolicyPage() {
  const { token, orgId } = useOrgBranch();
  const [policy,  setPolicy]  = useState<CreditPolicy | null>(null);
  const [form,    setForm]    = useState<Omit<CreditPolicy, "id" | "updated_at">>(DEFAULTS);
  const [loading, setLoading] = useState(false);
  const [saving,  setSaving]  = useState(false);
  const [toast,   setToast]   = useState<{ type: "success" | "error"; msg: string } | null>(null);

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  const fetchPolicy = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const res  = await fetch("http://localhost:3001/api/v1/credit_policy", {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        setPolicy(json.data);
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        const { id, updated_at, ...rest } = json.data;
        setForm(rest);
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId]);

  useEffect(() => { fetchPolicy(); }, [fetchPolicy]);

  const handleChange = (key: keyof typeof form, value: string | number | boolean) => {
    setForm((prev) => ({ ...prev, [key]: value }));
  };

  const handleSave = async () => {
    if (!token || !orgId) return;
    setSaving(true);
    try {
      const res  = await fetch("http://localhost:3001/api/v1/credit_policy", {
        method:  "PATCH",
        headers: {
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ credit_policy: form }),
      });
      const json = await res.json();
      if (res.ok) {
        setPolicy(json.data);
        showToast("success", "Credit policy saved successfully.");
      } else {
        showToast("error", json.errors?.join(", ") ?? "Save failed");
      }
    } finally {
      setSaving(false);
    }
  };

  const handleRestoreDefaults = () => {
    setForm(DEFAULTS);
  };

  return (
    <AppShell title="Credit Policy">
      <Breadcrumb items={[
        { label: "Settings", href: "/settings" },
        { label: "Credit Policy" },
      ]} />
      <PageHeader
        title="Credit Policy"
        description="Configure automated hold and block rules for credit sales."
        actions={[
          {
            label: "Restore Defaults",
            onClick: handleRestoreDefaults,
            variant: "outline" as const,
            icon: RotateCcw,
          },
          {
            label: saving ? "Saving…" : "Save Changes",
            onClick: handleSave,
            icon: Save,
          },
        ]}
      />

      {/* Toast */}
      {toast && (
        <div className={`mb-4 rounded-md border px-4 py-2.5 text-sm ${
          toast.type === "success"
            ? "bg-success/10 border-success/20 text-success"
            : "bg-danger/10 border-danger/20 text-danger"
        }`}>
          {toast.msg}
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center h-40">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      ) : (
        <div className="space-y-6 max-w-2xl">

          {/* Hard Block */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm text-danger">Hard Block Rules</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <Field
                label="Block if overdue ≥ N days"
                hint="Orders are hard-blocked when overdue days reach this threshold."
              >
                <Input
                  type="number" min={0}
                  value={form.hard_block_overdue_days}
                  onChange={(e) => handleChange("hard_block_overdue_days", Number(e.target.value))}
                />
              </Field>
              <Field
                label="Block if outstanding > limit + N%"
                hint="Orders are hard-blocked when outstanding exceeds credit limit by this margin."
              >
                <div className="flex items-center gap-2">
                  <Input
                    type="number" min={0} max={500}
                    value={form.hard_block_margin_pct}
                    onChange={(e) => handleChange("hard_block_margin_pct", Number(e.target.value))}
                  />
                  <span className="text-sm text-text-secondary">%</span>
                </div>
              </Field>
            </CardContent>
          </Card>

          {/* Soft Hold */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm text-warning">Soft Hold Rules</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <Field label="Overdue days band (soft hold)" hint="Orders are soft-held when overdue days fall between min and max.">
                <div className="flex items-center gap-2">
                  <Input
                    type="number" min={0}
                    value={form.soft_hold_overdue_days_min}
                    onChange={(e) => handleChange("soft_hold_overdue_days_min", Number(e.target.value))}
                    placeholder="Min"
                  />
                  <span className="text-text-secondary">–</span>
                  <Input
                    type="number" min={0}
                    value={form.soft_hold_overdue_days_max}
                    onChange={(e) => handleChange("soft_hold_overdue_days_max", Number(e.target.value))}
                    placeholder="Max"
                  />
                </div>
              </Field>
              <Field label="Hold if outstanding ≥ N% of limit" hint="Soft hold when outstanding amount is this percentage or more of the credit limit.">
                <div className="flex items-center gap-2">
                  <Input
                    type="number" min={0} max={200}
                    value={form.soft_hold_outstanding_pct}
                    onChange={(e) => handleChange("soft_hold_outstanding_pct", Number(e.target.value))}
                  />
                  <span className="text-sm text-text-secondary">%</span>
                </div>
              </Field>
            </CardContent>
          </Card>

          {/* Collection & Approval */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Collection & Approval</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <Field label="Collection-first triggers at bucket" hint="Accounts entering this overdue bucket are auto-flagged as collection-first.">
                <select
                  value={form.collection_first_bucket}
                  onChange={(e) => handleChange("collection_first_bucket", e.target.value)}
                  className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
                >
                  {BUCKET_OPTIONS.map((o) => (
                    <option key={o.value} value={o.value}>{o.label}</option>
                  ))}
                </select>
              </Field>
              <Field label="Manager approval SLA (hours)" hint="Credit limit requests must be decided within this time by a manager.">
                <Input
                  type="number" min={1}
                  value={form.approval_sla_hours_manager}
                  onChange={(e) => handleChange("approval_sla_hours_manager", Number(e.target.value))}
                />
              </Field>
              <Field label="Owner approval SLA (hours)" hint="Credit limit requests must be decided within this time by an owner.">
                <Input
                  type="number" min={1}
                  value={form.approval_sla_hours_owner}
                  onChange={(e) => handleChange("approval_sla_hours_owner", Number(e.target.value))}
                />
              </Field>
            </CardContent>
          </Card>

          {/* Invoice & Allocation */}
          <Card>
            <CardHeader>
              <CardTitle className="text-sm">Invoice & Allocation</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <Field label="Auto-invoice trigger" hint="When should invoices be automatically generated?">
                <select
                  value={form.auto_invoice_trigger}
                  onChange={(e) => handleChange("auto_invoice_trigger", e.target.value)}
                  className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
                >
                  {AUTO_INVOICE_OPTIONS.map((o) => (
                    <option key={o.value} value={o.value}>{o.label}</option>
                  ))}
                </select>
              </Field>
              <Field label="Allow partial allocation" hint="Allow partial payment allocation against invoices.">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.allow_partial_allocation}
                    onChange={(e) => handleChange("allow_partial_allocation", e.target.checked)}
                    className="h-4 w-4 rounded border-border accent-accent"
                  />
                  <span className="text-sm text-text-primary">Enabled</span>
                </label>
              </Field>
            </CardContent>
          </Card>

          {policy && (
            <p className="text-xs text-text-secondary">
              Last updated: {new Date(policy.updated_at).toLocaleString("en-IN")}
            </p>
          )}
        </div>
      )}
    </AppShell>
  );
}

// ─── Helper ───────────────────────────────────────────────────────────────────
function Field({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1">
      <label className="text-sm font-medium text-text-primary">{label}</label>
      {hint && <p className="text-xs text-text-secondary">{hint}</p>}
      <div className="mt-1">{children}</div>
    </div>
  );
}
