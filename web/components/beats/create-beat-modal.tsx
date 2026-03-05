"use client";

import React, { useEffect, useState } from "react";
import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";

interface Route {
  id: number;
  name: string;
  code: string;
}

interface Props {
  onClose: () => void;
  onCreated: () => void;
}

export function CreateBeatModal({ onClose, onCreated }: Props) {
  const { token, orgId, branchId, branches } = useOrgBranch();
  const [routes, setRoutes]     = useState<Route[]>([]);
  const [name, setName]         = useState("");
  const [code, setCode]         = useState("");
  const [routeId, setRouteId]   = useState<string>("");
  const [notes, setNotes]       = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [errors, setErrors]     = useState<string[]>([]);

  useEffect(() => {
    if (!orgId) return;
    const qp = new URLSearchParams({ per_page: "100" });
    if (branchId) qp.set("branch_id", branchId);
    fetch(`/api/v1/routes?${qp}`, {
      headers: {
        Authorization: `Bearer ${token}`,
        "X-Organization-Id": orgId,
      },
    })
      .then((r) => r.json())
      .then((d) => setRoutes(d.data ?? []));
  }, [orgId, branchId, token]);

  // Auto-generate code from name
  useEffect(() => {
    if (!name) return;
    setCode(
      name
        .toUpperCase()
        .replace(/[^A-Z0-9\s]/g, "")
        .trim()
        .replace(/\s+/g, "-")
        .slice(0, 20)
    );
  }, [name]);

  function resetForm() {
    setName(""); setCode(""); setRouteId(""); setNotes(""); setErrors([]);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErrors([]);
    setSubmitting(true);
    try {
      const res = await fetch("/api/v1/beats", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId ?? "",
        },
        body: JSON.stringify({
          beat: {
            name,
            code: code.toUpperCase(),
            route_id: routeId || null,
            notes,
            branch_id: Number(branchId) || Number(branches[0]?.id) || undefined,
          },
        }),
      });
      const data = await res.json();
      if (res.ok) {
        resetForm();
        onCreated();
      } else {
        setErrors(data.errors ?? ["Something went wrong."]);
      }
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Modal open onClose={() => { resetForm(); onClose(); }} title="New Beat" size="md">
      <form onSubmit={handleSubmit} className="space-y-4 mt-2">
        {errors.length > 0 && (
          <div className="rounded-md bg-red-50 border border-red-200 px-3 py-2 text-sm text-danger space-y-1">
            {errors.map((e, i) => <p key={i}>{e}</p>)}
          </div>
        )}

        <Input
          label="Beat Name *"
          placeholder="e.g. North Zone Monday Beat"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
        />

        <div>
          <label className="text-sm font-medium text-text-primary mb-1.5 block">Code *</label>
          <input
            className="h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent uppercase"
            value={code}
            onChange={(e) => setCode(e.target.value.toUpperCase())}
            placeholder="e.g. NORTH-MON"
            required
          />
          <p className="text-xs text-text-secondary mt-1">Uppercase letters, numbers, and hyphens only.</p>
        </div>

        <div>
          <label className="text-sm font-medium text-text-primary mb-1.5 block">Route (optional)</label>
          <select
            className="h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary"
            value={routeId}
            onChange={(e) => setRouteId(e.target.value)}
          >
            <option value="">— No route —</option>
            {routes.map((r) => (
              <option key={r.id} value={r.id}>{r.code} – {r.name}</option>
            ))}
          </select>
        </div>

        <div>
          <label className="text-sm font-medium text-text-primary mb-1.5 block">Notes</label>
          <textarea
            className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-primary resize-none"
            rows={3}
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="Optional notes about this beat…"
          />
        </div>

        <div className="flex justify-end gap-2 pt-2">
          <Button type="button" variant="outline" onClick={() => { resetForm(); onClose(); }} disabled={submitting}>
            Cancel
          </Button>
          <Button type="submit" isLoading={submitting} disabled={submitting || !name.trim() || !code.trim()}>
            Create Beat
          </Button>
        </div>
      </form>
    </Modal>
  );
}


interface Route {
  id: number;
  name: string;
  code: string;
}

interface Props {
  onClose: () => void;
  onCreated: () => void;
}

