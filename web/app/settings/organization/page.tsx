"use client";

import { useState, useEffect, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { AppShell } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/alert";
import {
  ChevronRight, Save, Loader2,
  GitBranch, Plus, MapPin, Pencil,
  ShoppingCart, Truck, RotateCcw, CreditCard, ClipboardCheck,
  Building2, Workflow,
} from "lucide-react";
import { AddBranchModal, EditBranchModal, BranchForEdit } from "@/components/add-branch-modal";
import { useOrgBranch } from "@/lib/org-branch-context";
import { engagementEvents } from "@/lib/analytics";
import { usePincodeLookup } from "@/lib/use-pincode-lookup";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────
interface OrgProfile {
  id: number;
  name: string;
  slug: string;
  gst_number: string;
  pan: string;
  address: string;
  city: string;
  state: string;
  pincode: string;
  contact_email: string;
  contact_phone: string;
  logo_url: string;
  timezone: string;
  currency: string;
  settings: Record<string, unknown>;
}

interface WorkflowSettings {
  order_approval_mode:              "automatic" | "manager_approval" | "above_threshold";
  order_approval_threshold:         string;
  order_edit_window_minutes:        string;
  dispatch_requires_pick_list:      boolean;
  dispatch_requires_delivery_proof: boolean;
  dispatch_auto_confirm_on_invoice: boolean;
  return_approval_required:         boolean;
  return_window_days:               string;
  credit_auto_approve_below_pct:    string;
  credit_block_on_overdue_days:     string;
  invoice_auto_generate:            boolean;
  invoice_payment_terms_days:       string;
  invoice_prefix:                   string;
  // Accounting sync automation
  sync_auto_on_order_approved:      boolean;
  sync_auto_on_order_delivered:     boolean;
  sync_auto_on_payment_received:    boolean;
  sync_auto_on_collection:          boolean;
  sync_schedule_cron:               string;
  sync_batch_size:                  string;
  sync_include_stock_movements:     boolean;
}

const WF_DEFAULTS: WorkflowSettings = {
  order_approval_mode:              "automatic",
  order_approval_threshold:         "0",
  order_edit_window_minutes:        "30",
  dispatch_requires_pick_list:      false,
  dispatch_requires_delivery_proof: false,
  dispatch_auto_confirm_on_invoice: false,
  return_approval_required:         true,
  return_window_days:               "7",
  credit_auto_approve_below_pct:    "80",
  credit_block_on_overdue_days:     "30",
  invoice_auto_generate:            true,
  invoice_payment_terms_days:       "30",
  invoice_prefix:                   "INV",
  sync_auto_on_order_approved:      false,
  sync_auto_on_order_delivered:     false,
  sync_auto_on_payment_received:    false,
  sync_auto_on_collection:          false,
  sync_schedule_cron:               "disabled",
  sync_batch_size:                  "100",
  sync_include_stock_movements:     false,
};

// ─── Reusable sub-components ──────────────────────────────────────────────────
function FieldSkeleton() {
  return (
    <div className="space-y-1.5">
      <div className="h-3 w-20 rounded bg-border animate-pulse" />
      <div className="h-9 w-full rounded-lg bg-border/60 animate-pulse" />
    </div>
  );
}

function CardSkeleton({ rows = 3 }: { rows?: number }) {
  return (
    <Card>
      <CardHeader>
        <div className="h-4 w-32 rounded bg-border animate-pulse" />
      </CardHeader>
      <CardContent className="space-y-3">
        {Array.from({ length: rows }).map((_, i) => (
          <FieldSkeleton key={i} />
        ))}
      </CardContent>
    </Card>
  );
}

function SectionCard({ icon, title, description, children }: {
  icon: React.ReactNode; title: string; description: string; children: React.ReactNode;
}) {
  return (
    <Card>
      <CardHeader className="pb-2">
        <CardTitle className="flex items-center gap-2 text-sm font-semibold">
          {icon}{title}
        </CardTitle>
        <p className="text-xs text-text-secondary mt-0.5">{description}</p>
      </CardHeader>
      <CardContent className="space-y-4">{children}</CardContent>
    </Card>
  );
}

function Toggle({ label, description, checked, onChange }: {
  label: string; description?: string; checked: boolean; onChange: (v: boolean) => void;
}) {
  return (
    <label className="flex items-start justify-between gap-4 cursor-pointer">
      <div>
        <p className="text-sm font-medium text-text-primary">{label}</p>
        {description && <p className="text-xs text-text-secondary mt-0.5">{description}</p>}
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        onClick={() => onChange(!checked)}
        className={`relative shrink-0 mt-0.5 h-5 w-9 rounded-full transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-accent
          ${checked ? "bg-accent" : "bg-border"}`}
      >
        <span className={`absolute top-0.5 left-0.5 h-4 w-4 rounded-full bg-white shadow transition-transform
          ${checked ? "translate-x-4" : "translate-x-0"}`} />
      </button>
    </label>
  );
}

function SelectField({ label, value, options, onChange }: {
  label: string; value: string;
  options: { value: string; label: string }[];
  onChange: (v: string) => void;
}) {
  return (
    <div>
      <label className="mb-1 block text-xs font-medium text-text-primary">{label}</label>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full rounded-lg border border-border bg-white px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
      >
        {options.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
      </select>
    </div>
  );
}

// ─── Tabs ─────────────────────────────────────────────────────────────────────
const TABS = [
  { key: "profile",  label: "Profile",  icon: Building2 },
  { key: "workflow", label: "Workflow", icon: Workflow },
  { key: "branches", label: "Branches", icon: GitBranch },
] as const;
type TabKey = typeof TABS[number]["key"];

// ─── Inner component (needs useSearchParams inside Suspense boundary) ─────────
function OrganizationPageInner() {
  const router       = useRouter();
  const searchParams = useSearchParams();
  const initialTab   = (searchParams.get("tab") as TabKey) ?? "profile";
  const [activeTab, setActiveTab] = useState<TabKey>(
    TABS.some((t) => t.key === initialTab) ? initialTab : "profile"
  );

  // Profile state
  const [org, setOrg]                           = useState<OrgProfile | null>(null);
  const [profileForm, setProfileForm]           = useState<Partial<OrgProfile>>({});
  const [profileSaving, setProfileSaving]       = useState(false);
  const [profileSuccess, setProfileSuccess]     = useState(false);
  const [profileError, setProfileError]         = useState<string | null>(null);

  // Workflow state
  const [wfForm, setWfForm]         = useState<WorkflowSettings>(WF_DEFAULTS);
  const [wfSaving, setWfSaving]     = useState(false);
  const [wfSuccess, setWfSuccess]   = useState(false);
  const [wfError, setWfError]       = useState<string | null>(null);

  // Shared
  const [loading,    setLoading]    = useState(false);
  const [fetchError, setFetchError] = useState<string | null>(null);

  const { token, orgId, orgsLoading, branches, branchesLoading, refetchBranches } = useOrgBranch();
  const [showAddBranch, setShowAddBranch]     = useState(false);
  const [editingBranch, setEditingBranch]     = useState<BranchForEdit | null>(null);

  const { city: pcCity, state: pcState, loading: pincodeLoading } = usePincodeLookup(profileForm.pincode ?? "");

  // Auto-fill city & state when pincode lookup resolves
  useEffect(() => {
    if (pcCity) setProfileForm((f) => ({ ...f, city: pcCity }));
    if (pcState) setProfileForm((f) => ({ ...f, state: pcState }));
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pcCity, pcState]);

  // ── Single fetch hydrates both profile + workflow ─────────────────────────
  useEffect(() => {
    if (!token || !orgId) return;
    let cancelled = false;
    setLoading(true);
    setFetchError(null);

    fetch(`${API_URL}/api/v1/organizations/${orgId}/settings`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((json) => {
        if (cancelled) return;
        if (json.data) {
          setOrg(json.data);
          setProfileForm(json.data);
          const s: Record<string, unknown> = json.data.settings ?? {};
          setWfForm({
            order_approval_mode:              (s.order_approval_mode as WorkflowSettings["order_approval_mode"]) ?? WF_DEFAULTS.order_approval_mode,
            order_approval_threshold:         String(s.order_approval_threshold    ?? WF_DEFAULTS.order_approval_threshold),
            order_edit_window_minutes:        String(s.order_edit_window_minutes   ?? WF_DEFAULTS.order_edit_window_minutes),
            dispatch_requires_pick_list:      Boolean(s.dispatch_requires_pick_list      ?? WF_DEFAULTS.dispatch_requires_pick_list),
            dispatch_requires_delivery_proof: Boolean(s.dispatch_requires_delivery_proof ?? WF_DEFAULTS.dispatch_requires_delivery_proof),
            dispatch_auto_confirm_on_invoice: Boolean(s.dispatch_auto_confirm_on_invoice ?? WF_DEFAULTS.dispatch_auto_confirm_on_invoice),
            return_approval_required:         Boolean(s.return_approval_required         ?? WF_DEFAULTS.return_approval_required),
            return_window_days:               String(s.return_window_days           ?? WF_DEFAULTS.return_window_days),
            credit_auto_approve_below_pct:    String(s.credit_auto_approve_below_pct ?? WF_DEFAULTS.credit_auto_approve_below_pct),
            credit_block_on_overdue_days:     String(s.credit_block_on_overdue_days  ?? WF_DEFAULTS.credit_block_on_overdue_days),
            invoice_auto_generate:            Boolean(s.invoice_auto_generate      ?? WF_DEFAULTS.invoice_auto_generate),
            invoice_payment_terms_days:       String(s.invoice_payment_terms_days  ?? WF_DEFAULTS.invoice_payment_terms_days),
            invoice_prefix:                   String(s.invoice_prefix              ?? WF_DEFAULTS.invoice_prefix),
            sync_auto_on_order_approved:      Boolean(s.sync_auto_on_order_approved      ?? WF_DEFAULTS.sync_auto_on_order_approved),
            sync_auto_on_order_delivered:     Boolean(s.sync_auto_on_order_delivered     ?? WF_DEFAULTS.sync_auto_on_order_delivered),
            sync_auto_on_payment_received:    Boolean(s.sync_auto_on_payment_received    ?? WF_DEFAULTS.sync_auto_on_payment_received),
            sync_auto_on_collection:          Boolean(s.sync_auto_on_collection          ?? WF_DEFAULTS.sync_auto_on_collection),
            sync_schedule_cron:               String(s.sync_schedule_cron           ?? WF_DEFAULTS.sync_schedule_cron),
            sync_batch_size:                  String(s.sync_batch_size              ?? WF_DEFAULTS.sync_batch_size),
            sync_include_stock_movements:     Boolean(s.sync_include_stock_movements     ?? WF_DEFAULTS.sync_include_stock_movements),
          });
        } else {
          setFetchError((json.errors ?? []).join(", ") || "Failed to load organization settings.");
        }
      })
      .catch(() => { if (!cancelled) setFetchError("Network error. Please try again."); })
      .finally(() => { if (!cancelled) setLoading(false); });

    return () => { cancelled = true; };
  }, [token, orgId]);

  // ── Tab switching (updates URL query param) ───────────────────────────────
  const switchTab = (tab: TabKey) => {
    setActiveTab(tab);
    const params = new URLSearchParams(searchParams.toString());
    if (tab === "profile") params.delete("tab"); else params.set("tab", tab);
    const qs = params.toString();
    router.replace(`/settings/organization${qs ? `?${qs}` : ""}`, { scroll: false });
  };

  // ── Save profile ──────────────────────────────────────────────────────────
  const saveProfile = async () => {
    if (!token || !orgId) return;
    setProfileSaving(true);
    setProfileError(null);
    setProfileSuccess(false);
    try {
      const res = await fetch(`${API_URL}/api/v1/organizations/${orgId}/settings`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify(profileForm),
      });
      const json = await res.json();
      if (res.ok) {
        setOrg(json.data);
        setProfileForm(json.data ?? {});
        setProfileSuccess(true);
        
        // Track settings update
        engagementEvents.updateSettings("organization_profile", org?.name ?? "", json.data?.name ?? "");
        
        setTimeout(() => setProfileSuccess(false), 3000);
      } else {
        setProfileError((json.errors ?? []).join(", ") || "Failed to save.");
      }
    } finally {
      setProfileSaving(false);
    }
  };

  // ── Save workflow ─────────────────────────────────────────────────────────
  const saveWorkflow = async () => {
    if (!token || !orgId) return;
    setWfSaving(true);
    setWfError(null);
    setWfSuccess(false);
    try {
      const res = await fetch(`${API_URL}/api/v1/organizations/${orgId}/settings`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({ settings: wfForm }),
      });
      const json = await res.json();
      if (res.ok) {
        setWfSuccess(true);
        
        // Track settings update
        engagementEvents.updateSettings("organization_workflow", "previous", "updated");
        
        setTimeout(() => setWfSuccess(false), 3000);
      } else {
        setWfError((json.errors ?? []).join(", ") || "Failed to save.");
      }
    } finally {
      setWfSaving(false);
    }
  };

  // ── Helpers ───────────────────────────────────────────────────────────────
  const setProfile = (key: keyof OrgProfile, value: string) =>
    setProfileForm((f) => ({ ...f, [key]: value }));

  const setProfileSettingKey = (key: string, value: string) =>
    setProfileForm((f) => ({ ...f, settings: { ...(f.settings ?? {}), [key]: value } }));

  const setWf = <K extends keyof WorkflowSettings>(key: K, val: WorkflowSettings[K]) =>
    setWfForm((f) => ({ ...f, [key]: val }));

  // ── Loading skeleton ───────────────────────────────────────────────────────
  if (orgsLoading || loading) {
    return (
      <AppShell title="Organization" hideBreadcrumb>
        <div className="mb-4 h-5 w-48 rounded bg-border animate-pulse" />
        <div className="mb-6 flex gap-1 border-b border-border pb-px">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-9 w-24 rounded-t bg-border/40 animate-pulse mr-1" />
          ))}
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <CardSkeleton rows={4} /><CardSkeleton rows={3} />
          <CardSkeleton rows={2} /><CardSkeleton rows={3} />
        </div>
      </AppShell>
    );
  }

  if (fetchError) {
    return (
      <AppShell title="Organization" hideBreadcrumb>
        <Alert variant="danger" title="Could not load settings" className="mt-4">{fetchError}</Alert>
      </AppShell>
    );
  }

  return (
    <AppShell title="Organization" hideBreadcrumb>
      {/* Breadcrumb + contextual Save */}
      <div className="mb-4 flex items-center justify-between gap-3">
        <nav className="flex items-center gap-1.5 text-sm text-text-secondary">
          <button
            onClick={() => router.push("/settings/organizations")}
            className="hover:text-text-primary transition-colors"
          >
            Organizations
          </button>
          <ChevronRight className="h-3.5 w-3.5 shrink-0" />
          <span className="font-medium text-text-primary">{org?.name ?? "Organization"}</span>
        </nav>
        {activeTab === "profile" && (
          <Button size="sm" onClick={saveProfile} isLoading={profileSaving}>
            <Save className="mr-1.5 h-3.5 w-3.5" /> Save
          </Button>
        )}
        {activeTab === "workflow" && (
          <Button size="sm" onClick={saveWorkflow} isLoading={wfSaving}>
            <Save className="mr-1.5 h-3.5 w-3.5" /> Save
          </Button>
        )}
      </div>

      {/* Tab bar */}
      <div className="mb-6 flex border-b border-border">
        {TABS.map(({ key, label, icon: Icon }) => (
          <button
            key={key}
            onClick={() => switchTab(key)}
            className={`flex items-center gap-1.5 px-4 py-2.5 text-sm font-medium border-b-2 -mb-px transition-colors
              ${activeTab === key
                ? "border-accent text-accent"
                : "border-transparent text-text-secondary hover:text-text-primary hover:border-border"
              }`}
          >
            <Icon className="h-3.5 w-3.5" />
            {label}
          </button>
        ))}
      </div>

      {/* ── Profile tab ──────────────────────────────────────────────────────── */}
      {activeTab === "profile" && (
        <>
          {profileSuccess && (
            <Alert variant="success" title="Saved!" className="mb-4">Organization profile updated.</Alert>
          )}
          {profileError && (
            <Alert variant="danger" title="Error" className="mb-4">{profileError}</Alert>
          )}
          <div className="grid gap-4 sm:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle className="text-sm font-semibold">Organization Info</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <Input
                  label="Organization Name"
                  value={profileForm.name ?? ""}
                  onChange={(e) => setProfile("name", e.target.value)}
                />
                <div className="relative">
                  <Input
                    label="PIN Code"
                    value={profileForm.pincode ?? ""}
                    placeholder="400001"
                    maxLength={6}
                    onChange={(e) => setProfile("pincode", e.target.value.replace(/\D/g, ""))}
                  />
                  {pincodeLoading && (
                    <Loader2 className="absolute right-3 top-7 h-4 w-4 animate-spin text-text-secondary" />
                  )}
                </div>
                <Input
                  label="Address"
                  value={profileForm.address ?? ""}
                  placeholder="Street address"
                  onChange={(e) => setProfile("address", e.target.value)}
                />
                <div className="grid grid-cols-2 gap-3">
                  <Input
                    label="City"
                    value={profileForm.city ?? ""}
                    placeholder="Auto-filled from PIN"
                    onChange={(e) => setProfile("city", e.target.value)}
                  />
                  <Input
                    label="State"
                    value={profileForm.state ?? ""}
                    placeholder="Auto-filled from PIN"
                    onChange={(e) => setProfile("state", e.target.value)}
                  />
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-sm font-semibold">Contact</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <Input
                  label="Contact Email"
                  type="email"
                  value={profileForm.contact_email ?? ""}
                  onChange={(e) => setProfile("contact_email", e.target.value)}
                />
                <Input
                  label="Contact Phone"
                  type="tel"
                  value={profileForm.contact_phone ?? ""}
                  onChange={(e) => setProfile("contact_phone", e.target.value)}
                />
                <Input
                  label="Logo URL"
                  placeholder="https://example.com/logo.png"
                  value={profileForm.logo_url ?? ""}
                  onChange={(e) => setProfile("logo_url", e.target.value)}
                />
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-sm font-semibold">Tax &amp; Compliance</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <Input
                  label="GSTIN"
                  value={profileForm.gst_number ?? ""}
                  helperText="Format: 22AAAAA00001Az5"
                  onChange={(e) => {
                    const val = e.target.value.toUpperCase();
                    setProfile("gst_number", val);
                    if (val.length >= 12) setProfile("pan", val.substring(2, 12));
                  }}
                />
                <Input
                  label="PAN"
                  value={profileForm.pan ?? ""}
                  helperText="Auto-filled from GSTIN"
                  onChange={(e) => setProfile("pan", e.target.value.toUpperCase())}
                />
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-sm font-semibold">Preferences</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div>
                  <label className="mb-1 block text-xs font-medium text-text-primary">Timezone</label>
                  <select
                    value={profileForm.timezone ?? "Asia/Kolkata"}
                    onChange={(e) => setProfile("timezone", e.target.value)}
                    className="w-full rounded-lg border border-border bg-white px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
                  >
                    <option value="Asia/Kolkata">Asia/Kolkata (IST)</option>
                    <option value="UTC">UTC</option>
                    <option value="Asia/Dubai">Asia/Dubai (GST)</option>
                  </select>
                </div>
                <div>
                  <label className="mb-1 block text-xs font-medium text-text-primary">Currency</label>
                  <select
                    value={profileForm.currency ?? "INR"}
                    onChange={(e) => setProfile("currency", e.target.value)}
                    className="w-full rounded-lg border border-border bg-white px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
                  >
                    <option value="INR">INR - Indian Rupee</option>
                    <option value="USD">USD - US Dollar</option>
                    <option value="AED">AED - UAE Dirham</option>
                  </select>
                </div>
                <Input
                  label="Fiscal Year Start"
                  placeholder="April"
                  value={String(profileForm.settings?.fiscal_year_start ?? "")}
                  helperText="Month your fiscal year begins"
                  onChange={(e) => setProfileSettingKey("fiscal_year_start", e.target.value)}
                />
              </CardContent>
            </Card>
          </div>
        </>
      )}

      {/* ── Workflow tab ──────────────────────────────────────────────────────── */}
      {activeTab === "workflow" && (
        <>
          {wfSuccess && (
            <Alert variant="success" title="Saved!" className="mb-4">Workflow settings updated.</Alert>
          )}
          {wfError && (
            <Alert variant="danger" title="Error" className="mb-4">{wfError}</Alert>
          )}
          <div className="grid gap-4 sm:grid-cols-2">
            <SectionCard
              icon={<ShoppingCart className="h-4 w-4 text-accent" />}
              title="Order Approvals"
              description="Control when orders require manual approval before confirmation"
            >
              <SelectField
                label="Approval Mode"
                value={wfForm.order_approval_mode}
                options={[
                  { value: "automatic",        label: "Automatic — all orders auto-confirmed" },
                  { value: "manager_approval", label: "Manager Approval — all orders need sign-off" },
                  { value: "above_threshold",  label: "Above Threshold — approve only high-value orders" },
                ]}
                onChange={(v) => setWf("order_approval_mode", v as WorkflowSettings["order_approval_mode"])}
              />
              {wfForm.order_approval_mode === "above_threshold" && (
                <Input
                  label="Approval Threshold (₹)"
                  type="number"
                  min="0"
                  value={wfForm.order_approval_threshold}
                  helperText="Orders above this amount will be held for approval"
                  onChange={(e) => setWf("order_approval_threshold", e.target.value)}
                />
              )}
              <Input
                label="Order Edit Window (minutes)"
                type="number"
                min="0"
                value={wfForm.order_edit_window_minutes}
                helperText="Minutes a submitted order can still be edited (0 = no edit)"
                onChange={(e) => setWf("order_edit_window_minutes", e.target.value)}
              />
            </SectionCard>

            <SectionCard
              icon={<Truck className="h-4 w-4 text-accent" />}
              title="Dispatch Workflow"
              description="Requirements before and after orders go out for delivery"
            >
              <Toggle
                label="Require Pick List"
                description="A pick list must be generated before dispatch is allowed"
                checked={wfForm.dispatch_requires_pick_list}
                onChange={(v) => setWf("dispatch_requires_pick_list", v)}
              />
              <Toggle
                label="Require Delivery Proof"
                description="Driver must upload proof to mark delivery complete"
                checked={wfForm.dispatch_requires_delivery_proof}
                onChange={(v) => setWf("dispatch_requires_delivery_proof", v)}
              />
              <Toggle
                label="Auto-confirm on Invoice"
                description="Automatically confirm orders when a sales invoice is generated"
                checked={wfForm.dispatch_auto_confirm_on_invoice}
                onChange={(v) => setWf("dispatch_auto_confirm_on_invoice", v)}
              />
            </SectionCard>

            <SectionCard
              icon={<RotateCcw className="h-4 w-4 text-accent" />}
              title="Return Workflow"
              description="Policies for accepting and approving customer return requests"
            >
              <Toggle
                label="Require Return Approval"
                description="Return requests must be reviewed by a manager before acceptance"
                checked={wfForm.return_approval_required}
                onChange={(v) => setWf("return_approval_required", v)}
              />
              <Input
                label="Return Window (days)"
                type="number"
                min="0"
                value={wfForm.return_window_days}
                helperText="Days after delivery within which returns are accepted (0 = always)"
                onChange={(e) => setWf("return_window_days", e.target.value)}
              />
            </SectionCard>

            <SectionCard
              icon={<CreditCard className="h-4 w-4 text-accent" />}
              title="Credit Workflow"
              description="Auto-approval rules and thresholds for credit-related actions"
            >
              <Input
                label="Auto-approve below utilization (%)"
                type="number"
                min="0"
                max="100"
                value={wfForm.credit_auto_approve_below_pct}
                helperText="Orders from customers below this credit utilization % bypass approval"
                onChange={(e) => setWf("credit_auto_approve_below_pct", e.target.value)}
              />
              <Input
                label="Block orders after overdue (days)"
                type="number"
                min="0"
                value={wfForm.credit_block_on_overdue_days}
                helperText="Block new orders when a customer is overdue by more than this many days"
                onChange={(e) => setWf("credit_block_on_overdue_days", e.target.value)}
              />
            </SectionCard>

            <Card className="sm:col-span-2">
              <CardHeader className="pb-2">
                <CardTitle className="flex items-center gap-2 text-sm font-semibold">
                  <ClipboardCheck className="h-4 w-4 text-accent" />
                  Invoicing Defaults
                </CardTitle>
                <p className="text-xs text-text-secondary mt-0.5">Default values applied when generating invoices</p>
              </CardHeader>
              <CardContent>
                <div className="grid gap-4 sm:grid-cols-3">
                  <Input
                    label="Invoice Prefix"
                    value={wfForm.invoice_prefix}
                    placeholder="INV"
                    maxLength={10}
                    helperText="Prefix for invoice numbers (e.g. INV, TAX, BILL)"
                    onChange={(e) => setWf("invoice_prefix", e.target.value.toUpperCase())}
                  />
                  <Input
                    label="Payment Terms (days)"
                    type="number"
                    min="0"
                    value={wfForm.invoice_payment_terms_days}
                    helperText="Days until invoice is overdue if unpaid"
                    onChange={(e) => setWf("invoice_payment_terms_days", e.target.value)}
                  />
                  <div className="flex flex-col justify-center pt-5">
                    <Toggle
                      label="Auto-generate Invoice"
                      description="Automatically generate invoice when an order is confirmed"
                      checked={wfForm.invoice_auto_generate}
                      onChange={(v) => setWf("invoice_auto_generate", v)}
                    />
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="sm:col-span-2">
              <CardHeader className="pb-2">
                <CardTitle className="flex items-center gap-2 text-sm font-semibold">
                  <Workflow className="h-4 w-4 text-accent" />
                  Accounting Sync Automation
                </CardTitle>
                <p className="text-xs text-text-secondary mt-0.5">Automatically sync orders, deliveries, and payments to Tally and other accounting systems</p>
              </CardHeader>
              <CardContent>
                <div className="grid gap-4 sm:grid-cols-2 mb-4">
                  <div className="border-r border-border pr-4">
                    <p className="text-xs font-semibold text-text-secondary mb-3 uppercase">Event Triggers</p>
                    <div className="space-y-2">
                      <Toggle
                        label="Sync on Order Approved"
                        description="Trigger sync when an order is approved"
                        checked={wfForm.sync_auto_on_order_approved}
                        onChange={(v) => setWf("sync_auto_on_order_approved", v)}
                      />
                      <Toggle
                        label="Sync on Order Delivered"
                        description="Trigger sync when delivery is completed"
                        checked={wfForm.sync_auto_on_order_delivered}
                        onChange={(v) => setWf("sync_auto_on_order_delivered", v)}
                      />
                      <Toggle
                        label="Sync on Payment Received"
                        description="Trigger sync when a payment is confirmed"
                        checked={wfForm.sync_auto_on_payment_received}
                        onChange={(v) => setWf("sync_auto_on_payment_received", v)}
                      />
                      <Toggle
                        label="Sync on Collection"
                        description="Trigger sync when money is collected"
                        checked={wfForm.sync_auto_on_collection}
                        onChange={(v) => setWf("sync_auto_on_collection", v)}
                      />
                    </div>
                  </div>

                  <div>
                    <p className="text-xs font-semibold text-text-secondary mb-3 uppercase">Batch & Export Settings</p>
                    <div className="space-y-3">
                      <SelectField
                        label="Batch Schedule"
                        value={wfForm.sync_schedule_cron}
                        options={[
                          { value: "disabled",     label: "Disabled — Manual sync only" },
                          { value: "daily_6pm",    label: "Daily at 6 PM" },
                          { value: "twice_daily",  label: "Twice Daily (9 AM, 6 PM)" },
                          { value: "every_4_hours", label: "Every 4 Hours" },
                        ]}
                        onChange={(v) => setWf("sync_schedule_cron", v)}
                      />
                      <Input
                        label="Batch Size (records)"
                        type="number"
                        min="1"
                        max="5000"
                        value={wfForm.sync_batch_size}
                        helperText="Number of records to include per export file"
                        onChange={(e) => setWf("sync_batch_size", e.target.value)}
                      />
                      <Toggle
                        label="Include Stock Movements"
                        description="Include inventory adjustments in delivery syncs"
                        checked={wfForm.sync_include_stock_movements}
                        onChange={(v) => setWf("sync_include_stock_movements", v)}
                      />
                    </div>
                  </div>
                </div>
                <div className="text-xs text-text-secondary border-t border-border pt-3">
                  💡 <strong>How it works:</strong> Events trigger sync records every 15 minutes. Records are batched and sent to Tally as XML for review before posting. Only enabled events create sync records.
                </div>
              </CardContent>
            </Card>
          </div>

          {/* <div className="mt-6 flex justify-end">
            <Button onClick={saveWorkflow} isLoading={wfSaving}>
              <Save className="mr-1.5 h-4 w-4" /> Save Workflow Settings
            </Button>
          </div> */}
        </>
      )}

      {/* ── Branches tab ─────────────────────────────────────────────────────── */}
      {activeTab === "branches" && (
        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="flex items-center gap-2 text-sm font-semibold">
                <GitBranch className="h-4 w-4 text-accent" />
                Branches
              </CardTitle>
              <Button size="sm" variant="outline" onClick={() => setShowAddBranch(true)}>
                <Plus className="mr-1.5 h-3.5 w-3.5" /> Add Branch
              </Button>
            </div>
          </CardHeader>
          <CardContent className="p-0 pb-2">
            {branchesLoading ? (
              <div className="divide-y divide-border">
                {[1, 2].map((i) => (
                  <div key={i} className="flex items-center gap-3 px-4 py-3 animate-pulse">
                    <div className="h-8 w-8 rounded-lg bg-border shrink-0" />
                    <div className="space-y-1.5 flex-1">
                      <div className="h-3 w-32 rounded bg-border" />
                      <div className="h-3 w-20 rounded bg-border/60" />
                    </div>
                  </div>
                ))}
              </div>
            ) : branches.length === 0 ? (
              <div className="flex flex-col items-center gap-2 py-12 text-center">
                <GitBranch className="h-8 w-8 text-text-secondary/40" />
                <p className="text-sm text-text-secondary">No branches yet.</p>
                <Button size="sm" variant="outline" onClick={() => setShowAddBranch(true)}>
                  <Plus className="mr-1.5 h-3.5 w-3.5" /> Create First Branch
                </Button>
              </div>
            ) : (
              <div className="divide-y divide-border">
                {branches.map((branch) => (
                  <div key={branch.id} className="flex items-center gap-3 px-4 py-3 hover:bg-background-subtle transition-colors">
                    <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-accent/10 text-accent">
                      <GitBranch className="h-4 w-4" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-text-primary leading-snug truncate">{branch.name}</p>
                      <div className="flex items-center gap-3 mt-0.5">
                        <span className="font-mono text-xs text-text-secondary">{branch.code}</span>
                        {branch.city && (
                          <span className="flex items-center gap-1 text-xs text-text-secondary">
                            <MapPin className="h-3 w-3 shrink-0" />{branch.city}
                          </span>
                        )}
                      </div>
                    </div>
                    <button
                      className="h-7 w-7 flex items-center justify-center rounded-md border border-border bg-background hover:bg-muted text-text-secondary hover:text-text-primary transition-colors shrink-0"
                      title="Edit branch"
                      onClick={() => setEditingBranch(branch as BranchForEdit)}
                    >
                      <Pencil className="h-3.5 w-3.5" />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      )}

      <AddBranchModal
        open={showAddBranch}
        onClose={() => setShowAddBranch(false)}
        onCreated={() => { refetchBranches(); setShowAddBranch(false); }}
      />
      <EditBranchModal
        open={editingBranch !== null}
        branch={editingBranch}
        onClose={() => setEditingBranch(null)}
        onSaved={() => { refetchBranches(); setEditingBranch(null); }}
      />
    </AppShell>
  );
}

export default function OrganizationPage() {
  return (
    <Suspense>
      <OrganizationPageInner />
    </Suspense>
  );
}