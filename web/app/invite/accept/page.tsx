"use client";

import { useState, useEffect } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { CheckCircle2, XCircle, Loader2 } from "lucide-react";
import { API_URL } from "@/lib/api/client";

export default function AcceptInvitePage() {
  const searchParams = useSearchParams();
  const router       = useRouter();
  const token        = searchParams.get("token") ?? "";

  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [message, setMessage] = useState("");
  const [orgId, setOrgId]     = useState<number | null>(null);

  const authToken = typeof window !== "undefined" ? localStorage.getItem("auth_token") ?? "" : "";

  useEffect(() => {
    if (!token) {
      setStatus("error");
      setMessage("Invalid or missing invitation token.");
      return;
    }
    if (!authToken) {
      // Redirect to login with return URL
      router.push(`/login?redirect=/invite/accept?token=${encodeURIComponent(token)}`);
    }
  }, [token, authToken, router]);

  const handleAccept = async () => {
    setStatus("loading");
    try {
      const res  = await fetch(`${API_URL}/api/v1/invitations/accept`, {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization:  `Bearer ${authToken}`,
        },
        body: JSON.stringify({ token }),
      });
      const json = await res.json();
      if (res.ok) {
        setStatus("success");
        setOrgId(json.data?.organization_id ?? null);
        setMessage("You've successfully joined the organization!");
      } else {
        setStatus("error");
        setMessage((json.errors ?? []).join(", ") || "Failed to accept invitation.");
      }
    } catch {
      setStatus("error");
      setMessage("Network error. Please try again.");
    }
  };

  const handleContinue = () => {
    if (orgId) localStorage.setItem("organization_id", String(orgId));
    router.push("/dashboard");
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-background-subtle px-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-8 shadow-md">
        {status === "idle" && (
          <>
            <div className="mb-6 flex h-14 w-14 items-center justify-center rounded-full bg-accent/15">
              <CheckCircle2 className="h-7 w-7 text-accent" />
            </div>
            <h1 className="mb-2 text-xl font-bold text-text-primary">You've been invited!</h1>
            <p className="mb-6 text-sm text-text-secondary">
              Accept this invitation to join the organization on OmniDist.
            </p>
            <Button className="w-full" onClick={handleAccept}>Accept Invitation</Button>
          </>
        )}

        {status === "loading" && (
          <div className="flex flex-col items-center gap-3 py-6">
            <Loader2 className="h-8 w-8 animate-spin text-accent" />
            <p className="text-sm text-text-secondary">Accepting invitation…</p>
          </div>
        )}

        {status === "success" && (
          <>
            <div className="mb-6 flex h-14 w-14 items-center justify-center rounded-full bg-accent/15">
              <CheckCircle2 className="h-7 w-7 text-accent" />
            </div>
            <h1 className="mb-2 text-xl font-bold text-text-primary">Welcome aboard!</h1>
            <p className="mb-6 text-sm text-text-secondary">{message}</p>
            <Button className="w-full" onClick={handleContinue}>Go to Dashboard</Button>
          </>
        )}

        {status === "error" && (
          <>
            <div className="mb-6 flex h-14 w-14 items-center justify-center rounded-full bg-danger/10">
              <XCircle className="h-7 w-7 text-danger" />
            </div>
            <h1 className="mb-2 text-xl font-bold text-text-primary">Unable to accept</h1>
            <p className="mb-6 text-sm text-text-secondary">{message}</p>
            <Button variant="outline" className="w-full" onClick={() => router.push("/dashboard")}>
              Go to Dashboard
            </Button>
          </>
        )}
      </div>
    </div>
  );
}
