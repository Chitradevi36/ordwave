"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { Bell, CheckCircle, XCircle, Save } from "lucide-react";

// ──────────────────────────────────────────────────────────────────────────────
// Notification preference types
// ──────────────────────────────────────────────────────────────────────────────

interface ChannelPrefs {
  email: boolean;
  push:  boolean;
  in_app: boolean;
}

interface NotificationPrefs {
  [eventType: string]: ChannelPrefs;
}

interface PrefGroup {
  label: string;
  events: { key: string; label: string; description: string }[];
}

const PREF_GROUPS: PrefGroup[] = [
  {
    label: "Orders",
    events: [
      { key: "order_submitted",   label: "Order submitted",       description: "When a sales rep submits a new order" },
      { key: "order_approved",    label: "Order approved",        description: "When a manager approves an order" },
      { key: "order_rejected",    label: "Order rejected",        description: "When an order is rejected with a reason" },
      { key: "order_dispatched",  label: "Order dispatched",      description: "When an order is assigned to a delivery trip" },
    ],
  },
  {
    label: "Deliveries",
    events: [
      { key: "trip_dispatched",   label: "Trip dispatched",       description: "Driver is notified when their trip is dispatched" },
      { key: "delivery_completed", label: "Delivery completed",   description: "When a stop is delivered successfully" },
      { key: "delivery_failed",   label: "Delivery failed",       description: "When a delivery attempt fails (exception)" },
    ],
  },
  {
    label: "Payments",
    events: [
      { key: "payment_confirmed", label: "Payment confirmed",     description: "When a payment is confirmed by an accountant" },
      { key: "payment_reversed",  label: "Payment reversed",      description: "When a payment reversal is processed" },
    ],
  },
  {
    label: "Credit",
    events: [
      { key: "credit_blocked",    label: "Customer credit blocked", description: "When a customer is hard-blocked due to overdue" },
      { key: "credit_limit_changed", label: "Credit limit changed", description: "When a customer's credit limit is updated" },
    ],
  },
  {
    label: "Returns",
    events: [
      { key: "return_raised",     label: "Return raised",         description: "When a return request is raised" },
      { key: "return_qc_passed",  label: "Return QC passed",      description: "When return inspection is approved" },
    ],
  },
];

const DEFAULT_PREFS: ChannelPrefs = { email: true, push: true, in_app: true };

function buildDefaults(): NotificationPrefs {
  const prefs: NotificationPrefs = {};
  PREF_GROUPS.forEach((g) => g.events.forEach((e) => { prefs[e.key] = { ...DEFAULT_PREFS }; }));
  return prefs;
}

// ──────────────────────────────────────────────────────────────────────────────
// Toggle switch component
// ──────────────────────────────────────────────────────────────────────────────
function Toggle({ checked, onChange }: { checked: boolean; onChange: () => void }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={onChange}
      className={`relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors ${
        checked ? "bg-accent" : "bg-muted"
      }`}
    >
      <span className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${
        checked ? "translate-x-4" : "translate-x-0.5"
      }`} />
    </button>
  );
}

const CHANNELS: { key: keyof ChannelPrefs; label: string }[] = [
  { key: "in_app", label: "In-app" },
  { key: "push",   label: "Push"   },
  { key: "email",  label: "Email"  },
];

// ──────────────────────────────────────────────────────────────────────────────
// Page
// ──────────────────────────────────────────────────────────────────────────────
export default function NotificationsSettingsPage() {
  const { token, orgId } = useOrgBranch();

  const [prefs,   setPrefs]   = useState<NotificationPrefs>(buildDefaults());
  const [loading, setLoading] = useState(false);
  const [saving,  setSaving]  = useState(false);
  const [toast,   setToast]   = useState<{ type: "success" | "error"; msg: string } | null>(null);

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  const fetchPrefs = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/organizations/${orgId}/settings`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        const saved = json.data?.settings?.notification_preferences;
        if (saved) setPrefs((prev) => ({ ...prev, ...saved }));
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId]);

  useEffect(() => { fetchPrefs(); }, [fetchPrefs]);

  const toggle = (eventKey: string, channel: keyof ChannelPrefs) => {
    setPrefs((prev) => ({
      ...prev,
      [eventKey]: {
        ...(prev[eventKey] ?? DEFAULT_PREFS),
        [channel]: !(prev[eventKey]?.[channel] ?? true),
      },
    }));
  };

  const toggleAll = (channel: keyof ChannelPrefs, value: boolean) => {
    setPrefs((prev) => {
      const next = { ...prev };
      Object.keys(next).forEach((k) => {
        next[k] = { ...next[k], [channel]: value };
      });
      return next;
    });
  };

  const handleSave = async () => {
    if (!token || !orgId) return;
    setSaving(true);
    try {
      const res = await fetch(`${API_URL}/api/v1/organizations/${orgId}/settings`, {
        method:  "PATCH",
        headers: {
          Authorization:    `Bearer ${token}`,
          "X-Organization-Id": orgId,
          "Content-Type":   "application/json",
        },
        body: JSON.stringify({ settings: { notification_preferences: prefs } }),
      });
      const json = await res.json();
      if (res.ok) {
        showToast("success", "Notification preferences saved");
      } else {
        showToast("error", json.errors?.join(", ") ?? "Save failed");
      }
    } finally {
      setSaving(false);
    }
  };

  return (
    <AppShell title="Notification Settings">
      <PageHeader
        title="Notification Settings"
        description="Control which events trigger email, push, and in-app notifications"
        backHref="/settings"
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

      <div className="space-y-4">
        {/* Global toggles */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <Bell className="h-4 w-4 text-accent" />
              Global Channel Toggles
            </CardTitle>
          </CardHeader>
          <CardContent className="flex flex-wrap gap-6">
            {CHANNELS.map((ch) => (
              <div key={ch.key} className="flex items-center gap-2">
                <span className="text-sm font-medium text-text-primary">{ch.label}</span>
                <div className="flex gap-1.5">
                  <button
                    onClick={() => toggleAll(ch.key, true)}
                    className="text-xs text-accent hover:underline"
                  >All on</button>
                  <span className="text-text-secondary">/</span>
                  <button
                    onClick={() => toggleAll(ch.key, false)}
                    className="text-xs text-danger hover:underline"
                  >All off</button>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>

        {loading ? (
          <div className="space-y-4">
            {[1,2,3].map((i) => (
              <Card key={i}>
                <CardHeader><div className="h-4 w-24 rounded bg-border animate-pulse" /></CardHeader>
                <CardContent>
                  {[1,2].map((j) => (
                    <div key={j} className="mb-3 flex items-center justify-between">
                      <div className="space-y-1">
                        <div className="h-3.5 w-36 rounded bg-border animate-pulse" />
                        <div className="h-2.5 w-52 rounded bg-border/60 animate-pulse" />
                      </div>
                      <div className="flex gap-4">
                        {[1,2,3].map((k) => <div key={k} className="h-5 w-9 rounded-full bg-border animate-pulse" />)}
                      </div>
                    </div>
                  ))}
                </CardContent>
              </Card>
            ))}
          </div>
        ) : (
          PREF_GROUPS.map((group) => (
            <Card key={group.label}>
              <CardHeader>
                <CardTitle className="text-sm font-semibold">{group.label}</CardTitle>
              </CardHeader>
              <CardContent className="p-0 pb-2">
                {/* Header row */}
                <div className="flex items-center justify-between border-b border-border px-4 py-2">
                  <span className="text-xs font-medium text-text-secondary">Event</span>
                  <div className="flex gap-6">
                    {CHANNELS.map((ch) => (
                      <span key={ch.key} className="w-9 text-center text-xs font-medium text-text-secondary">
                        {ch.label}
                      </span>
                    ))}
                  </div>
                </div>
                {group.events.map((ev) => (
                  <div
                    key={ev.key}
                    className="flex items-center justify-between px-4 py-3 hover:bg-background-subtle transition-colors"
                  >
                    <div className="mr-4 min-w-0">
                      <p className="text-sm font-medium text-text-primary">{ev.label}</p>
                      <p className="text-xs text-text-secondary">{ev.description}</p>
                    </div>
                    <div className="flex shrink-0 gap-6">
                      {CHANNELS.map((ch) => (
                        <div key={ch.key} className="flex w-9 justify-center">
                          <Toggle
                            checked={prefs[ev.key]?.[ch.key] ?? true}
                            onChange={() => toggle(ev.key, ch.key)}
                          />
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </CardContent>
            </Card>
          ))
        )}
      </div>
    </AppShell>
  );
}
