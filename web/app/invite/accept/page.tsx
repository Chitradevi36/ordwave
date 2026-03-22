"use client";

import { Suspense, useState, useEffect } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { CheckCircle2, XCircle, Loader2, Mail, Building2, UserCheck, Calendar } from "lucide-react";
import { API_URL } from "@/lib/api/client";

interface InvitationDetails {
  email: string;
  organization_name: string;
  organization_id: number;
  role_name: string;
  invited_by_name: string;
  expires_at: string;
  user_exists: boolean;
}

function AcceptInvitePageContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const token = searchParams.get("token") ?? "";

  const [status, setStatus] = useState<"loading" | "show-details" | "set-password" | "accepting" | "success" | "error">("loading");
  const [message, setMessage] = useState("");
  const [invitation, setInvitation] = useState<InvitationDetails | null>(null);
  const [orgId, setOrgId] = useState<number | null>(null);
  
  // Form fields for new users
  const [password, setPassword] = useState("");
  const [passwordConfirm, setPasswordConfirm] = useState("");
  const [formError, setFormError] = useState("");

  const authToken = typeof window !== "undefined" ? localStorage.getItem("auth_token") ?? "" : "";

  // Step 1: Validate invitation and fetch details (no auth required)
  useEffect(() => {
    if (!token) {
      setStatus("error");
      setMessage("Invalid or missing invitation token.");
      return;
    }

    const validateInvitation = async () => {
      try {
        const res = await fetch(`${API_URL}/api/v1/invitations/validate?token=${encodeURIComponent(token)}`);
        const json = await res.json();

        if (res.ok && json.data) {
          setInvitation(json.data);
          setStatus("show-details");
        } else {
          setStatus("error");
          setMessage(json.errors?.[0] ?? "Invalid or expired invitation.");
        }
      } catch {
        setStatus("error");
        setMessage("Failed to load invitation details.");
      }
    };

    validateInvitation();
  }, [token]);

  // Handle: New user sets password
  const handleSetPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setFormError("");

    if (!password || !passwordConfirm) {
      setFormError("Please fill in all fields");
      return;
    }

    if (password !== passwordConfirm) {
      setFormError("Passwords do not match");
      return;
    }

    if (password.length < 8) {
      setFormError("Password must be at least 8 characters");
      return;
    }

    if (!invitation) return;

    setStatus("accepting");
    try {
      // Create account + accept invitation in one flow
      const res = await fetch(`${API_URL}/api/v1/invitations/accept_with_signup`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token,
          password,
          password_confirmation: passwordConfirm,
        }),
      });

      const json = await res.json();
      if (res.ok) {
        // Store auth token
        localStorage.setItem("auth_token", json.data.token);
        localStorage.setItem("user", JSON.stringify(json.data.user));
        localStorage.setItem("organization_id", String(json.data.organization_id));
        document.cookie = "auth_present=1; path=/; max-age=86400; SameSite=Lax";

        setStatus("success");
        setOrgId(json.data.organization_id);
        setMessage(`Welcome to ${invitation.organization_name}!`);

        // Reload page to reinitialize context with new credentials
        // This ensures OrgBranchContext fetches organizations/branches before dashboard renders
        setTimeout(() => {
          window.location.href = "/dashboard";
        }, 1500);
      } else {
        setStatus("error");
        setMessage(json.errors?.[0] ?? "Failed to create account.");
      }
    } catch {
      setStatus("error");
      setMessage("Network error. Please try again.");
    }
  };

  // Handle: Existing user logs in then accepts
  const handleExistingUserFlow = () => {
    router.push(`/login?redirect=${encodeURIComponent(`/invite/accept?token=${token}`)}`);
  };

  // Handle: Accept for already-authenticated user
  const handleAcceptIfLoggedIn = async () => {
    if (!authToken) {
      handleExistingUserFlow();
      return;
    }

    setStatus("accepting");
    try {
      const res = await fetch(`${API_URL}/api/v1/invitations/accept`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${authToken}`,
        },
        body: JSON.stringify({ token }),
      });

      const json = await res.json();
      if (res.ok) {
        const orgId = json.data.organization_id;
        // Store the accepted organization in localStorage
        localStorage.setItem("organization_id", String(orgId));
        
        setStatus("success");
        setOrgId(orgId);
        setMessage("Invitation accepted!");

        // Reload page to reinitialize context with new organization
        setTimeout(() => {
          window.location.href = "/dashboard";
        }, 1500);
      } else {
        setStatus("error");
        setMessage(json.errors?.[0] ?? "Failed to accept invitation.");
      }
    } catch {
      setStatus("error");
      setMessage("Network error. Please try again.");
    }
  };

  const handleContinue = () => {
    // Use hard reload to reinitialize context
    window.location.href = "/dashboard";
  };

  // Loading state
  if (status === "loading") {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background-subtle px-4">
        <div className="w-full max-w-md rounded-2xl bg-white p-8 shadow-md text-center">
          <Loader2 className="h-10 w-10 animate-spin text-accent mx-auto mb-4" />
          <p className="text-sm text-text-secondary">Loading invitation details…</p>
        </div>
      </div>
    );
  }

  // Error state
  if (status === "error") {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background-subtle px-4">
        <div className="w-full max-w-md rounded-2xl bg-white p-8 shadow-md">
          <div className="mb-6 flex h-14 w-14 items-center justify-center rounded-full bg-danger/10">
            <XCircle className="h-7 w-7 text-danger" />
          </div>
          <h1 className="mb-2 text-xl font-bold text-text-primary">Unable to process invitation</h1>
          <p className="mb-6 text-sm text-text-secondary">{message}</p>
          <Button variant="outline" className="w-full" onClick={() => router.push("/")}>
            Go Home
          </Button>
        </div>
      </div>
    );
  }

  // Success state
  if (status === "success") {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background-subtle px-4">
        <div className="w-full max-w-md rounded-2xl bg-white p-8 shadow-md">
          <div className="mb-6 flex h-14 w-14 items-center justify-center rounded-full bg-accent/15">
            <CheckCircle2 className="h-7 w-7 text-accent" />
          </div>
          <h1 className="mb-2 text-xl font-bold text-text-primary">Welcome aboard!</h1>
          <p className="mb-6 text-sm text-text-secondary">{message}</p>
          <Button className="w-full" onClick={handleContinue}>
            Go to Dashboard
          </Button>
        </div>
      </div>
    );
  }

  // Show invitation details
  if (!invitation) return null;

  const isExpired = new Date(invitation.expires_at) < new Date();
  const expiresIn = Math.ceil((new Date(invitation.expires_at).getTime() - Date.now()) / 3600000);

  // NEW USER: Show password setup form
  if (status === "set-password") {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background-subtle px-4 py-8">
        <div className="w-full max-w-md rounded-2xl bg-white p-8 shadow-md">
          <div className="mb-6">
            <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-primary/10 mb-4">
              <Building2 className="h-6 w-6 text-primary" />
            </div>
            <h1 className="text-xl font-bold text-text-primary mb-1">Set Your Password</h1>
            <p className="text-sm text-text-secondary">
              Complete your account to join <span className="font-semibold">{invitation.organization_name}</span>
            </p>
          </div>

          {/* Invitation details */}
          <div className="mb-6 p-4 rounded-lg bg-accent/5 border border-accent/10 space-y-2 text-sm">
            <div className="flex items-start gap-2">
              <Mail className="h-4 w-4 text-text-secondary mt-0.5 flex-shrink-0" />
              <div>
                <p className="text-text-secondary">Email</p>
                <p className="font-medium text-text-primary">{invitation.email}</p>
              </div>
            </div>
            <div className="flex items-start gap-2">
              <UserCheck className="h-4 w-4 text-text-secondary mt-0.5 flex-shrink-0" />
              <div>
                <p className="text-text-secondary">Role</p>
                <p className="font-medium text-text-primary capitalize">{invitation.role_name.replace('_', ' ')}</p>
              </div>
            </div>
            <div className="flex items-start gap-2">
              <Calendar className="h-4 w-4 text-text-secondary mt-0.5 flex-shrink-0" />
              <div>
                <p className="text-text-secondary">Expires in</p>
                <p className={`font-medium ${expiresIn < 24 ? 'text-danger' : 'text-text-primary'}`}>
                  {expiresIn > 0 ? `${expiresIn} hours` : 'Expired'}
                </p>
              </div>
            </div>
          </div>

          <form onSubmit={handleSetPassword} className="space-y-4">
            {formError && (
              <div className="p-3 bg-danger/10 border border-danger/20 rounded-lg text-xs text-danger">
                {formError}
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-text-primary mb-2">
                Password
              </label>
              <Input
                type="password"
                placeholder="At least 8 characters"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                disabled={status !== "set-password"}
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-text-primary mb-2">
                Confirm Password
              </label>
              <Input
                type="password"
                placeholder="Confirm password"
                value={passwordConfirm}
                onChange={(e) => setPasswordConfirm(e.target.value)}
                disabled={status !== "set-password"}
              />
            </div>

            <Button
              type="submit"
              disabled={status !== "set-password"}
              className="w-full"
            >
              {status !== "set-password" ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Joining…
                </>
              ) : (
                "Set Password & Join"
              )}
            </Button>
          </form>

          <p className="text-xs text-text-secondary text-center mt-4">
            By joining, you agree to our Terms of Service and Privacy Policy
          </p>
        </div>
      </div>
    );
  }

  // SHOW DETAILS: Ask user to sign in or set password
  return (
    <div className="flex min-h-screen items-center justify-center bg-background-subtle px-4 py-8">
      <div className="w-full max-w-md rounded-2xl bg-white p-8 shadow-md">
        <div className="mb-6">
          <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-primary/10 mb-4">
            <CheckCircle2 className="h-6 w-6 text-primary" />
          </div>
          <h1 className="text-2xl font-bold text-text-primary mb-1">You've been invited!</h1>
          <p className="text-sm text-text-secondary">
            Join <span className="font-semibold">{invitation.organization_name}</span> on OrdWave
          </p>
        </div>

        {/* Invitation card */}
        <div className="mb-6 p-4 rounded-lg bg-accent/5 border border-accent/10 space-y-3">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-semibold text-text-primary">{invitation.organization_name}</p>
              <p className="text-xs text-text-secondary">Invited by {invitation.invited_by_name}</p>
            </div>
          </div>

          <div className="pt-3 border-t border-accent/10 space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-text-secondary">Your role:</span>
              <span className="font-medium capitalize text-text-primary">{invitation.role_name.replace('_', ' ')}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-text-secondary">Email:</span>
              <span className="font-medium text-text-primary">{invitation.email}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-text-secondary">Expires:</span>
              <span className={`font-medium ${isExpired ? 'text-danger' : expiresIn < 24 ? 'text-warning' : 'text-success'}`}>
                {isExpired ? 'Expired' : `${expiresIn}h`}
              </span>
            </div>
          </div>
        </div>

        {/* Action buttons */}
        <div className="space-y-3">
          {!invitation.user_exists ? (
            <Button
              onClick={() => setStatus("set-password")}
              className="w-full"
            >
              Set Password & Join
            </Button>
          ) : (
            <>
              {authToken ? (
                <Button onClick={handleAcceptIfLoggedIn} className="w-full">
                  Accept Invitation
                </Button>
              ) : (
                <Button onClick={handleExistingUserFlow} className="w-full">
                  Sign In & Accept
                </Button>
              )}
            </>
          )}

          <Button
            variant="outline"
            className="w-full"
            onClick={() => router.push("/")}
          >
            Cancel
          </Button>
        </div>

        <p className="text-center text-xs text-text-secondary mt-4">
          Questions? Contact {invitation.invited_by_name}
        </p>
      </div>
    </div>
  );
}

export default function AcceptInvitePage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-background-subtle" />}>
      <AcceptInvitePageContent />
    </Suspense>
  );
}
