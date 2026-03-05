"use client";

import React, { useEffect, useState } from "react";
import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";

interface Props {
  open: boolean;
  onClose: () => void;
  onCreated: () => void;
}

export function CreateRouteModal({ open, onClose, onCreated }: Props) {
  const { token, orgId, branchId, branches } = useOrgBranch();

  const [name,        setName]        = useState("");
  const [code,        setCode]        = useState("");
  const [selectedBranch, setSelectedBranch] = useState<string>(branchId ?? "");
  const [submitting,  setSubmitting]  = useState(false);
  const [errors,      setErrors]      = useState<string[]>([]);

  // Sync: prefer the active branchId; fall back to first branch in list
  useEffect(() => {
    setSelectedBranch((prev) => {
      if (prev) return prev;                      // user already picked one
      if (branchId) return branchId;              // specific branch active in topbar
      return String(branches[0]?.id ?? "");        // fall back to first branch
    });
  }, [branchId, branches]);

  // Auto-generate code from name
  useEffect(() => {
    if (!name) { setCode(""); return; }
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
    setName(""); setCode(""); setErrors([]);
    setSelectedBranch(branchId ?? "");
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim() || !code.trim()) return;
    if (!selectedBranch) {
      setErrors(["Please select a branch."]);
      return;
    }
    setErrors([]);
    setSubmitting(true);
    try {
      const res = await fetch("/api/v1/routes", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId ?? "",
        },
        body: JSON.stringify({
          route: {
            name:      name.trim(),
            code:      code.toUpperCase().trim(),
            branch_id: Number(selectedBranch),
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
    <Modal
      open={open}
      onClose={() => { resetForm(); onClose(); }}
      title="New Route"
      size="sm"
    >
      <form onSubmit={handleSubmit} className="space-y-4 mt-2">
        {errors.length > 0 && (
          <div className="rounded-md bg-red-50 border border-red-200 px-3 py-2 text-sm text-danger space-y-1">
            {errors.map((e) => <p key={e}>{e}</p>)}
          </div>
        )}

        <Input
          label="Route Name *"
          placeholder="e.g. North Zone Route"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
        />

        <div>
          <label className="text-sm font-medium text-text-primary mb-1.5 block">
            Code *
          </label>
          <input
            className="h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm font-mono text-text-primary placeholder:text-text-secondary focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
            placeholder="NZ-ROUTE"
            value={code}
            onChange={(e) => setCode(e.target.value.toUpperCase())}
            required
          />
          <p className="text-xs text-text-secondary mt-1">
            Uppercase letters, numbers and hyphens only — auto-filled from name.
          </p>
        </div>

        {branches && branches.length > 0 && (
          <div>
            <label className="text-sm font-medium text-text-primary mb-1.5 block">
              Branch {branches.length > 1 ? "*" : ""}
            </label>
            <select
              value={selectedBranch}
              onChange={(e) => setSelectedBranch(e.target.value)}
              className="h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary"
            >
              {!selectedBranch && (
                <option value="" disabled>Select a branch…</option>
              )}
              {branches.map((b) => (
                <option key={b.id} value={String(b.id)}>{b.name}</option>
              ))}
            </select>
          </div>
        )}

        <div className="flex justify-end gap-2 pt-2">
          <Button
            type="button"
            variant="outline"
            onClick={() => { resetForm(); onClose(); }}
            disabled={submitting}
          >
            Cancel
          </Button>
          <Button type="submit" isLoading={submitting} disabled={submitting || !name.trim() || !code.trim()}>
            Create Route
          </Button>
        </div>
      </form>
    </Modal>
  );
}
