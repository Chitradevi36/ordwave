"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";

import {
  User, Lock, Building2, CheckCircle2, AlertCircle, Eye, EyeOff, ShieldCheck,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

// ─── Types ──────────────────────────────────────────────────────────────────
interface OrgSummary {
  id: number;
  name: string;
  slug: string;
  role: string | null;
}

interface Profile {
  id: number;
  email: string;
  first_name: string;
  last_name: string;
  full_name: string;
  phone: string | null;
  plan: string | null;
  active: boolean;
  created_at: string;
  organizations: OrgSummary[];
}

// ─── Password Strength ──────────────────────────────────────────────────────
function getStrength(password: string): { score: number; label: string; color: string } {
  if (!password) return { score: 0, label: "", color: "" };
  let score = 0;
  if (password.length >= 8)  score++;
  if (password.length >= 12) score++;
  if (/[A-Z]/.test(password)) score++;
  if (/[0-9]/.test(password)) score++;
  if (/[^A-Za-z0-9]/.test(password)) score++;

  if (score <= 1) return { score,  label: "Very weak",  color: "bg-danger" };
  if (score === 2) return { score, label: "Weak",        color: "bg-warning" };
  if (score === 3) return { score, label: "Fair",        color: "bg-yellow-400" };
  if (score === 4) return { score, label: "Strong",      color: "bg-success" };
  return              { score,     label: "Very strong", color: "bg-emerald-600" };
}

function StrengthMeter({ password }: { password: string }) {
  const { score, label, color } = getStrength(password);
  if (!password) return null;
  return (
    <div className="mt-2 space-y-1">
      <div className="flex gap-1">
        {[1, 2, 3, 4, 5].map((i) => (
          <div
            key={i}
            className={`h-1.5 flex-1 rounded-full transition-colors ${i <= score ? color : "bg-border"}`}
          />
        ))}
      </div>
      <p className={`text-xs font-medium ${score <= 1 ? "text-danger" : score <= 2 ? "text-warning" : "text-success"}`}>
        {label}
      </p>
    </div>
  );
}

// ─── Inline helpers ──────────────────────────────────────────────────────────
function FieldLabel({ text, required }: { text: string; required?: boolean }) {
  return (
    <label className="block text-sm font-medium text-text-primary">
      {text}
      {required && <span className="ml-1 text-danger">*</span>}
    </label>
  );
}

function InlineBanner({ type, message }: { type: "success" | "error"; message: string }) {
  return (
    <div
      className={`flex items-center gap-2 rounded-md border px-3 py-2.5 text-sm ${
        type === "success"
          ? "border-success/30 bg-success/10 text-success"
          : "border-danger/30 bg-danger/10 text-danger"
      }`}
    >
      {type === "success"
        ? <CheckCircle2 className="h-4 w-4 shrink-0" />
        : <AlertCircle className="h-4 w-4 shrink-0" />}
      <span>{message}</span>
    </div>
  );
}

// ─── JWT decode (no library needed — just read the payload) ─────────────────
function decodeJwtPayload(token: string): Record<string, unknown> {
  try {
    const base64 = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(atob(base64));
  } catch {
    return {};
  }
}

const PROFILE_CACHE_KEY = "orderlane_profile_cache";

function readProfileCache(): Profile | null {
  try {
    const raw = localStorage.getItem(PROFILE_CACHE_KEY);
    return raw ? (JSON.parse(raw) as Profile) : null;
  } catch {
    return null;
  }
}

function writeProfileCache(p: Profile) {
  try { localStorage.setItem(PROFILE_CACHE_KEY, JSON.stringify(p)); } catch { /* noop */ }
}

// ─── Page ────────────────────────────────────────────────────────────────────
export default function AccountSettingsPage() {
  const { token, orgId } = useOrgBranch();

  // ── Profile state ─────────────────────────────────────────────────────────
  const [profile,        setProfile]        = useState<Profile | null>(null);
  const [profileLoading, setProfileLoading] = useState(false);
  const [firstName,      setFirstName]      = useState("");
  const [lastName,       setLastName]       = useState("");
  const [phone,          setPhone]          = useState("");
  const [profileSaving,  setProfileSaving]  = useState(false);
  const [profileMsg,     setProfileMsg]     = useState<{ type: "success" | "error"; text: string } | null>(null);

  // Derive email from JWT payload instantly (no round-trip needed)
  const jwtEmail = token ? (decodeJwtPayload(token).email as string | undefined) : undefined;

  // Seed from localStorage cache on mount (runs client-side only, avoiding SSR mismatch)
  useEffect(() => {
    const cached = readProfileCache();
    if (cached) {
      setProfile(cached);
      setFirstName(cached.first_name ?? "");
      setLastName(cached.last_name   ?? "");
      setPhone(cached.phone          ?? "");
    }
  }, []);

  // ── Password state ────────────────────────────────────────────────────────
  const [currentPw,     setCurrentPw]     = useState("");
  const [newPw,         setNewPw]         = useState("");
  const [confirmPw,     setConfirmPw]     = useState("");
  const [showCurrentPw, setShowCurrentPw] = useState(false);
  const [showNewPw,     setShowNewPw]     = useState(false);
  const [showConfirmPw, setShowConfirmPw] = useState(false);
  const [pwSaving,      setPwSaving]      = useState(false);
  const [pwMsg,         setPwMsg]         = useState<{ type: "success" | "error"; text: string } | null>(null);

  // ── Fetch profile ─────────────────────────────────────────────────────────
  const fetchProfile = useCallback(async () => {
    if (!token) return;
    setProfileLoading(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/profile`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const json = await res.json();
        const p: Profile = json.data;
        setProfile(p);
        writeProfileCache(p);
        setFirstName(p.first_name ?? "");
        setLastName(p.last_name  ?? "");
        setPhone(p.phone         ?? "");
      }
    } finally {
      setProfileLoading(false);
    }
  }, [token]);

  useEffect(() => { fetchProfile(); }, [fetchProfile]);

  // ── Save profile ──────────────────────────────────────────────────────────
  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token) return;
    setProfileSaving(true);
    setProfileMsg(null);
    try {
      const res = await fetch(`${API_URL}/api/v1/profile`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          ...(orgId ? { "X-Organization-Id": orgId } : {}),
        },
        body: JSON.stringify({ user: { first_name: firstName, last_name: lastName, phone } }),
      });
      const json = await res.json();
      if (res.ok) {
        setProfile((prev) => {
          const updated = prev ? { ...prev, ...json.data } : json.data;
          writeProfileCache(updated);
          return updated;
        });
        setProfileMsg({ type: "success", text: "Profile updated successfully." });
      } else {
        setProfileMsg({ type: "error", text: (json.errors ?? ["Something went wrong"]).join(", ") });
      }
    } finally {
      setProfileSaving(false);
    }
  };

  // ── Change password ───────────────────────────────────────────────────────
  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token) return;

    if (newPw !== confirmPw) {
      setPwMsg({ type: "error", text: "New password confirmation does not match." });
      return;
    }
    if (newPw.length < 8) {
      setPwMsg({ type: "error", text: "New password must be at least 8 characters." });
      return;
    }

    setPwSaving(true);
    setPwMsg(null);
    try {
      const res = await fetch(`${API_URL}/api/v1/profile/change_password`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          current_password:           currentPw,
          new_password:               newPw,
          new_password_confirmation:  confirmPw,
        }),
      });
      const json = await res.json();
      if (res.ok) {
        setPwMsg({ type: "success", text: "Password changed successfully." });
        setCurrentPw(""); setNewPw(""); setConfirmPw("");
      } else {
        setPwMsg({ type: "error", text: (json.errors ?? ["Something went wrong"]).join(", ") });
      }
    } finally {
      setPwSaving(false);
    }
  };

  const pwStrength = getStrength(newPw);
  const canSavePw  = currentPw.length > 0 && newPw.length >= 8 && confirmPw.length > 0 && pwStrength.score >= 2;

  const ROLE_VARIANT: Record<string, "default" | "secondary" | "warning" | "outline"> = {
    owner:   "default",
    admin:   "warning",
    manager: "secondary",
  };

  // ─────────────────────────────────────────────────────────────────────────
  return (
    <AppShell title="Account Settings">

      <PageHeader
        title="Account Settings"
        description="Manage your personal profile and security settings"
      />

      <div className="max-w-2xl space-y-6">

        {/* ── Profile Information ──────────────────────────────────────────── */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <User className="h-4 w-4 text-accent" />
              Profile Information
            </CardTitle>
          </CardHeader>
          <CardContent>
            {profileLoading && !profile ? (
              <div className="space-y-3">
                {[1, 2, 3].map((i) => (
                  <div key={i} className="h-9 rounded-md bg-border animate-pulse" />
                ))}
              </div>
            ) : (
              <form onSubmit={handleSaveProfile} className="space-y-4">
                {profileMsg && <InlineBanner type={profileMsg.type} message={profileMsg.text} />}

                {/* Email — read-only, prefilled from JWT or cached profile */}
                <div className="space-y-1">
                  <FieldLabel text="Email" />
                  <div className="flex h-9 items-center rounded-md border border-border bg-background-subtle px-3 text-sm text-text-secondary select-all">
                    {profile?.email ?? jwtEmail ?? <span className="opacity-40 italic">loading…</span>}
                  </div>
                  <p className="text-xs text-text-secondary">Email cannot be changed. Contact support if needed.</p>
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  <div className="space-y-1">
                    <FieldLabel text="First Name" required />
                    <Input
                      required
                      value={firstName}
                      onChange={(e) => setFirstName(e.target.value)}
                      placeholder="First name"
                    />
                  </div>
                  <div className="space-y-1">
                    <FieldLabel text="Last Name" required />
                    <Input
                      required
                      value={lastName}
                      onChange={(e) => setLastName(e.target.value)}
                      placeholder="Last name"
                    />
                  </div>
                </div>

                <div className="space-y-1">
                  <FieldLabel text="Phone" />
                  <Input
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="+91 9876543210"
                    type="tel"
                  />
                </div>

                <div className="flex items-center justify-between pt-1">
                  <p className="text-xs text-text-secondary">
                    {profile?.created_at
                      ? <>Member since{" "}<span className="font-medium text-text-primary">{new Date(profile.created_at).toLocaleDateString("en-IN", { year: "numeric", month: "long", day: "numeric" })}</span></>
                      : <span className="opacity-40 italic">loading…</span>
                    }
                  </p>
                  <Button type="submit" size="sm" disabled={profileSaving}>
                    {profileSaving ? "Saving…" : "Save Changes"}
                  </Button>
                </div>
              </form>
            )}
          </CardContent>
        </Card>

        {/* ── Change Password ──────────────────────────────────────────────── */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <Lock className="h-4 w-4 text-accent" />
              Change Password
            </CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={handleChangePassword} className="space-y-4">
              {pwMsg && <InlineBanner type={pwMsg.type} message={pwMsg.text} />}

              {/* Current password */}
              <div className="space-y-1">
                <FieldLabel text="Current Password" required />
                <div className="relative">
                  <Input
                    required
                    type={showCurrentPw ? "text" : "password"}
                    value={currentPw}
                    onChange={(e) => setCurrentPw(e.target.value)}
                    placeholder="Enter your current password"
                    className="pr-10"
                    autoComplete="current-password"
                  />
                  <button
                    type="button"
                    onClick={() => setShowCurrentPw((v) => !v)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary"
                    tabIndex={-1}
                  >
                    {showCurrentPw ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </button>
                </div>
              </div>

              {/* New password */}
              <div className="space-y-1">
                <FieldLabel text="New Password" required />
                <div className="relative">
                  <Input
                    required
                    type={showNewPw ? "text" : "password"}
                    value={newPw}
                    onChange={(e) => setNewPw(e.target.value)}
                    placeholder="At least 8 characters"
                    className="pr-10"
                    autoComplete="new-password"
                  />
                  <button
                    type="button"
                    onClick={() => setShowNewPw((v) => !v)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary"
                    tabIndex={-1}
                  >
                    {showNewPw ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </button>
                </div>
                <StrengthMeter password={newPw} />
              </div>

              {/* Confirm new password */}
              <div className="space-y-1">
                <FieldLabel text="Confirm New Password" required />
                <div className="relative">
                  <Input
                    required
                    type={showConfirmPw ? "text" : "password"}
                    value={confirmPw}
                    onChange={(e) => setConfirmPw(e.target.value)}
                    placeholder="Re-enter new password"
                    className="pr-10"
                    autoComplete="new-password"
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirmPw((v) => !v)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary"
                    tabIndex={-1}
                  >
                    {showConfirmPw ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </button>
                </div>
                {/* Match indicator */}
                {newPw && confirmPw && (
                  <p className={`text-xs font-medium mt-1 ${newPw === confirmPw ? "text-success" : "text-danger"}`}>
                    {newPw === confirmPw ? "✓ Passwords match" : "✗ Passwords do not match"}
                  </p>
                )}
              </div>

              {/* Password requirements */}
              <div className="rounded-md bg-background-subtle border border-border px-3 py-2.5 space-y-1">
                <p className="text-xs font-medium text-text-secondary flex items-center gap-1.5">
                  <ShieldCheck className="h-3.5 w-3.5" /> Password requirements
                </p>
                <ul className="space-y-0.5">
                  {[
                    ["At least 8 characters",               newPw.length >= 8],
                    ["At least one uppercase letter (A–Z)",  /[A-Z]/.test(newPw)],
                    ["At least one number (0–9)",            /[0-9]/.test(newPw)],
                    ["At least one special character",       /[^A-Za-z0-9]/.test(newPw)],
                  ].map(([req, met]) => (
                    <li key={req as string} className={`text-xs flex items-center gap-1.5 ${met ? "text-success" : "text-text-secondary"}`}>
                      <span className="text-[10px]">{met ? "✓" : "○"}</span>
                      {req as string}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="flex justify-end pt-1">
                <Button type="submit" size="sm" disabled={!canSavePw || pwSaving}>
                  {pwSaving ? "Updating…" : "Update Password"}
                </Button>
              </div>
            </form>
          </CardContent>
        </Card>

        {/* ── Your Organizations ────────────────────────────────────────────── */}
        {profile && profile.organizations.length > 0 && (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2 text-sm font-semibold">
                <Building2 className="h-4 w-4 text-accent" />
                Your Organizations
              </CardTitle>
            </CardHeader>
            <CardContent className="p-0 pb-2">
              {profile.organizations.map((org, idx) => (
                <div
                  key={org.id}
                  className={`flex items-center justify-between px-4 py-3 ${
                    idx !== profile.organizations.length - 1 ? "border-b border-border" : ""
                  }`}
                >
                  <div>
                    <p className="text-sm font-medium text-text-primary">{org.name}</p>
                    <p className="text-xs text-text-secondary">{org.slug}</p>
                  </div>
                  {org.role && (
                    <Badge variant={ROLE_VARIANT[org.role] ?? "outline"}>
                      {org.role.charAt(0).toUpperCase() + org.role.slice(1)}
                    </Badge>
                  )}
                </div>
              ))}
            </CardContent>
          </Card>
        )}

      </div>
    </AppShell>
  );
}
