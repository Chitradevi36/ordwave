"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/alert";
import { ChevronRight, Save, Loader2 } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { usePincodeLookup } from "@/lib/use-pincode-lookup";

interface BranchSettings {
  id: number;
  name: string;
  code: string;
  city: string;
  state: string;
  address: string;
  pincode: string;
  active: boolean;
  settings: {
    credit_limit?: number;
    credit_terms_days?: number;
    opening_time?: string;
    closing_time?: string;
    min_order_value?: number;
    days_off?: string;
    payment_modes?: string;
  };
}

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
        <div className="h-4 w-28 rounded bg-border animate-pulse" />
      </CardHeader>
      <CardContent className="space-y-3">
        {Array.from({ length: rows }).map((_, i) => <FieldSkeleton key={i} />)}
      </CardContent>
    </Card>
  );
}

export default function BranchSettingsPage() {
  const params   = useParams();
  const router   = useRouter();
  const branchId = params.id as string;

  const [branch, setBranch]   = useState<BranchSettings | null>(null);
  const [form, setForm]       = useState<Partial<BranchSettings>>({});
  const [loading, setLoading] = useState(false);
  const [saving, setSaving]   = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError]     = useState<string | null>(null);
  const [fetchError, setFetchError] = useState<string | null>(null);

  const { token, orgId } = useOrgBranch();

  const { city: pcCity, state: pcState, loading: pincodeLoading } = usePincodeLookup(form.pincode ?? "");

  // Auto-fill city & state when pincode lookup resolves
  useEffect(() => {
    if (pcCity) set("city", pcCity);
    if (pcState) set("state", pcState);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pcCity, pcState]);

  useEffect(() => {
    if (!token || !orgId || !branchId) return;
    let cancelled = false;

    const doFetch = async () => {
      setLoading(true);
      setFetchError(null);
      try {
        const res  = await fetch(`http://localhost:3001/api/v1/branches/${branchId}/settings`, {
          headers: {
            Authorization:       `Bearer ${token}`,
            "X-Organization-Id": orgId,
          },
        });
        const json = await res.json();
        if (cancelled) return;
        if (res.ok) {
          setBranch(json.data);
          setForm(json.data);
        } else {
          setFetchError((json.errors ?? []).join(", ") || "Failed to load branch settings.");
        }
      } catch {
        if (!cancelled) setFetchError("Network error. Please try again.");
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    doFetch();
    return () => { cancelled = true; };
  }, [token, orgId, branchId]);

  const handleSave = async () => {
    setSaving(true);
    setError(null);
    try {
      const res = await fetch(`http://localhost:3001/api/v1/branches/${branchId}/settings`, {
        method: "PATCH",
        headers: {
          "Content-Type":      "application/json",
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify(form),
      });
      const json = await res.json();
      if (res.ok) {
        setBranch(json.data);
        setForm(json.data);
        setSuccess(true);
        setTimeout(() => setSuccess(false), 3000);
      } else {
        setError((json.errors ?? []).join(", "));
      }
    } finally {
      setSaving(false);
    }
  };

  const set = (key: string, value: string | number) =>
    setForm((f) => ({ ...f, [key]: value }));

  const setSetting = (key: string, value: string | number) =>
    setForm((f) => ({ ...f, settings: { ...(f.settings ?? {}), [key]: value } }));

  // ── Loading skeleton ──────────────────────────────────────────────────────
  if (loading || (!branch && !fetchError)) {
    return (
      <AppShell title="Branch Settings">
        <div className="mb-4">
          <div className="h-4 w-32 rounded bg-border/60 animate-pulse" />
        </div>
        <div className="mb-6">
          <div className="h-6 w-48 rounded bg-border animate-pulse mb-1" />
          <div className="h-4 w-32 rounded bg-border/60 animate-pulse" />
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <CardSkeleton rows={6} />
          <CardSkeleton rows={6} />
        </div>
      </AppShell>
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  if (fetchError) {
    return (
      <AppShell title="Branch Settings">
        <Alert variant="danger" title="Could not load branch settings" className="mt-4">
          {fetchError}
        </Alert>
      </AppShell>
    );
  }

  return (
    <AppShell title="Branch Settings">
      {/* Breadcrumbs + top Save CTA */}
      <div className="mb-4 flex items-center justify-between">
        <nav className="flex items-center gap-1.5 text-sm text-text-secondary">
          <button
            onClick={() => router.push("/settings")}
            className="hover:text-text-primary transition-colors"
          >
            Settings
          </button>
          <ChevronRight className="h-3.5 w-3.5 shrink-0" />
          <span className="font-medium text-text-primary">
            {branch!.name}
          </span>
        </nav>
        <Button size="sm" onClick={handleSave} isLoading={saving}>
          <Save className="mr-1.5 h-3.5 w-3.5" /> Save Changes
        </Button>
      </div>

      <PageHeader
        title={`${branch!.name} — Settings`}
        description={`Branch code: ${branch!.code}`}
      />

      {success && <Alert variant="success" title="Saved!" className="mb-4">Branch settings updated successfully.</Alert>}
      {error   && <Alert variant="danger"  title="Error"   className="mb-4">{error}</Alert>}

      <div className="grid gap-4 sm:grid-cols-2">
        {/* Basic Info */}
        <Card>
          <CardHeader><CardTitle className="text-sm font-semibold">Basic Info</CardTitle></CardHeader>
          <CardContent className="space-y-3">
            <Input label="Branch Name" value={form.name ?? ""}    onChange={(e) => set("name", e.target.value)} />
            <Input label="Branch Code" value={form.code ?? ""}    onChange={(e) => set("code", e.target.value)} />
            <div className="relative">
              <Input
                label="PIN Code"
                value={form.pincode ?? ""}
                placeholder="400001"
                maxLength={6}
                onChange={(e) => set("pincode", e.target.value.replace(/\D/g, ""))}
              />
              {pincodeLoading && (
                <Loader2 className="absolute right-3 top-7 h-4 w-4 animate-spin text-text-secondary" />
              )}
            </div>
            <Input label="Address"     value={form.address ?? ""} placeholder="Street address" onChange={(e) => set("address", e.target.value)} />
            <div className="grid grid-cols-2 gap-3">
              <Input label="City"  value={form.city ?? ""}  placeholder="Auto-filled from PIN" onChange={(e) => set("city",  e.target.value)} />
              <Input label="State" value={form.state ?? ""} placeholder="Auto-filled from PIN" onChange={(e) => set("state", e.target.value)} />
            </div>
          </CardContent>
        </Card>

        {/* Operational Settings */}
        <Card>
          <CardHeader><CardTitle className="text-sm font-semibold">Operational Settings</CardTitle></CardHeader>
          <CardContent className="space-y-3">
            <Input
              label="Credit Limit (₹)"
              type="number"
              value={String(form.settings?.credit_limit ?? "")}
              helperText="Default credit limit for retailers"
              onChange={(e) => setSetting("credit_limit", parseFloat(e.target.value))}
            />
            <Input
              label="Credit Terms (days)"
              type="number"
              value={String(form.settings?.credit_terms_days ?? "")}
              onChange={(e) => setSetting("credit_terms_days", parseInt(e.target.value))}
            />
            <Input
              label="Min Order Value (₹)"
              type="number"
              value={String(form.settings?.min_order_value ?? "")}
              onChange={(e) => setSetting("min_order_value", parseFloat(e.target.value))}
            />
            <Input
              label="Opening Time"
              type="time"
              value={form.settings?.opening_time ?? ""}
              onChange={(e) => setSetting("opening_time", e.target.value)}
            />
            <Input
              label="Closing Time"
              type="time"
              value={form.settings?.closing_time ?? ""}
              onChange={(e) => setSetting("closing_time", e.target.value)}
            />
            <Input
              label="Days Off"
              value={form.settings?.days_off ?? ""}
              helperText="e.g. Sunday, Public Holidays"
              onChange={(e) => setSetting("days_off", e.target.value)}
            />
          </CardContent>
        </Card>
      </div>
    </AppShell>
  );
}
