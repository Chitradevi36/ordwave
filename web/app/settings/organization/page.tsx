"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/alert";
import { ChevronRight, Save, Loader2 } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { usePincodeLookup } from "@/lib/use-pincode-lookup";
import { API_URL } from "@/lib/api/client";

interface OrgSettings {
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

export default function OrganizationSettingsPage() {
  const router = useRouter();
  const [org, setOrg]               = useState<OrgSettings | null>(null);
  const [form, setForm]             = useState<Partial<OrgSettings>>({});
  const [loading, setLoading]       = useState(false);
  const [saving, setSaving]         = useState(false);
  const [success, setSuccess]       = useState(false);
  const [error, setError]           = useState<string | null>(null);
  const [fetchError, setFetchError] = useState<string | null>(null);

  const { token, orgId, orgsLoading } = useOrgBranch();

  const { city: pcCity, state: pcState, loading: pincodeLoading } = usePincodeLookup(form.pincode ?? "");

  // Auto-fill city & state when pincode lookup resolves
  useEffect(() => {
    if (pcCity) set("city", pcCity);
    if (pcState) set("state", pcState);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pcCity, pcState]);

  useEffect(() => {
    if (!token || !orgId) return;
    let cancelled = false;

    const doFetch = async () => {
      setLoading(true);
      setFetchError(null);
      try {
        const res = await fetch(
          `${API_URL}/api/v1/organizations/${orgId}/settings`,
          {
            headers: {
              Authorization: `Bearer ${token}`,
              "X-Organization-Id": orgId,
            },
          }
        );
        const json = await res.json();
        if (cancelled) return;
        if (res.ok) {
          setOrg(json.data);
          setForm(json.data ?? {});
        } else {
          setFetchError(
            (json.errors ?? []).join(", ") ||
              "Failed to load organization settings."
          );
        }
      } catch {
        if (!cancelled) setFetchError("Network error. Please try again.");
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    doFetch();
    return () => {
      cancelled = true;
    };
  }, [token, orgId]);

  const handleSave = async () => {
    if (!token || !orgId) return;
    setSaving(true);
    setError(null);
    setSuccess(false);
    try {
      const res = await fetch(
        `${API_URL}/api/v1/organizations/${orgId}/settings`,
        {
          method: "PATCH",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
            "X-Organization-Id": orgId,
          },
          body: JSON.stringify(form),
        }
      );
      const json = await res.json();
      if (res.ok) {
        setOrg(json.data);
        setForm(json.data ?? {});
        setSuccess(true);
        setTimeout(() => setSuccess(false), 3000);
      } else {
        setError((json.errors ?? []).join(", "));
      }
    } finally {
      setSaving(false);
    }
  };

  const set = (key: keyof OrgSettings, value: string) =>
    setForm((f) => ({ ...f, [key]: value }));

  const setSettingKey = (key: string, value: string) =>
    setForm((f) => ({
      ...f,
      settings: { ...(f.settings ?? {}), [key]: value },
    }));

  // Still bootstrapping context (orgsLoading) or actively fetching
  if (orgsLoading || loading) {
    return (
      <AppShell title="Organization Settings">
        <div className="mb-6">
          <div className="h-6 w-56 rounded bg-border animate-pulse mb-1" />
          <div className="h-4 w-80 rounded bg-border/60 animate-pulse" />
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <CardSkeleton rows={4} />
          <CardSkeleton rows={3} />
          <CardSkeleton rows={2} />
          <CardSkeleton rows={3} />
        </div>
      </AppShell>
    );
  }

  // Context finished loading but org data still absent (effect hasn't fired yet)
  if (!org && !fetchError) {
    return (
      <AppShell title="Organization Settings">
        <div className="mb-6">
          <div className="h-6 w-56 rounded bg-border animate-pulse mb-1" />
          <div className="h-4 w-80 rounded bg-border/60 animate-pulse" />
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <CardSkeleton rows={4} />
          <CardSkeleton rows={3} />
          <CardSkeleton rows={2} />
          <CardSkeleton rows={3} />
        </div>
      </AppShell>
    );
  }

  // Fetch error
  if (fetchError) {
    return (
      <AppShell title="Organization Settings">
        <Alert variant="danger" title="Could not load settings" className="mt-4">
          {fetchError}
        </Alert>
      </AppShell>
    );
  }

  return (
    <AppShell title="Organization Settings">
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
          <span className="font-medium text-text-primary">Organization</span>
        </nav>
        <Button size="sm" onClick={handleSave} isLoading={saving}>
          <Save className="mr-1.5 h-3.5 w-3.5" /> Save Changes
        </Button>
      </div>

      <PageHeader
        title="Organization Settings"
        description="Manage your organization profile, compliance, and preferences"
      />

      {success && (
        <Alert variant="success" title="Saved!" className="mb-4">
          Organization settings updated.
        </Alert>
      )}
      {error && (
        <Alert variant="danger" title="Error" className="mb-4">
          {error}
        </Alert>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        {/* Basic Info */}
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-semibold">
              Organization Info
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <Input
              label="Organization Name"
              value={form.name ?? ""}
              onChange={(e) => set("name", e.target.value)}
            />
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
            <Input
              label="Address"
              value={form.address ?? ""}
              placeholder="Street address"
              onChange={(e) => set("address", e.target.value)}
            />
            <div className="grid grid-cols-2 gap-3">
              <Input
                label="City"
                value={form.city ?? ""}
                placeholder="Auto-filled from PIN"
                onChange={(e) => set("city", e.target.value)}
              />
              <Input
                label="State"
                value={form.state ?? ""}
                placeholder="Auto-filled from PIN"
                onChange={(e) => set("state", e.target.value)}
              />
            </div>
          </CardContent>
        </Card>

        {/* Contact */}
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-semibold">Contact</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <Input
              label="Contact Email"
              type="email"
              value={form.contact_email ?? ""}
              onChange={(e) => set("contact_email", e.target.value)}
            />
            <Input
              label="Contact Phone"
              type="tel"
              value={form.contact_phone ?? ""}
              onChange={(e) => set("contact_phone", e.target.value)}
            />
            <Input
              label="Logo URL"
              placeholder="https://example.com/logo.png"
              value={form.logo_url ?? ""}
              onChange={(e) => set("logo_url", e.target.value)}
            />
          </CardContent>
        </Card>

        {/* Tax & Compliance */}
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-semibold">
              Tax &amp; Compliance
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <Input
              label="GSTIN"
              value={form.gst_number ?? ""}
              helperText="Format: 22AAAAA00001Az5"
              onChange={(e) => {
                const val = e.target.value.toUpperCase();
                set("gst_number", val);
                if (val.length >= 12) set("pan", val.substring(2, 12));
              }}
            />
            <Input
              label="PAN"
              value={form.pan ?? ""}
              helperText="Auto-filled from GSTIN"
              onChange={(e) => set("pan", e.target.value.toUpperCase())}
            />
          </CardContent>
        </Card>

        {/* Preferences */}
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-semibold">Preferences</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            <div>
              <label className="mb-1 block text-xs font-medium text-text-primary">
                Timezone
              </label>
              <select
                value={form.timezone ?? "Asia/Kolkata"}
                onChange={(e) => set("timezone", e.target.value)}
                className="w-full rounded-lg border border-border bg-white px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
              >
                <option value="Asia/Kolkata">Asia/Kolkata (IST)</option>
                <option value="UTC">UTC</option>
                <option value="Asia/Dubai">Asia/Dubai (GST)</option>
              </select>
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-text-primary">
                Currency
              </label>
              <select
                value={form.currency ?? "INR"}
                onChange={(e) => set("currency", e.target.value)}
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
              value={String(form.settings?.fiscal_year_start ?? "")}
              helperText="Month your fiscal year begins"
              onChange={(e) => setSettingKey("fiscal_year_start", e.target.value)}
            />
          </CardContent>
        </Card>
      </div>
    </AppShell>
  );
}