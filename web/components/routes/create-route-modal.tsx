"use client";

import React, { useEffect, useState } from "react";
import { Modal } from "@/components/ui/modal";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";

interface VehicleOption { id: number; registration_number: string; vehicle_type: string }
interface DriverOption  { id: number; full_name: string }

interface Props {
  open: boolean;
  onClose: () => void;
  onCreated: () => void;
}

export function CreateRouteModal({ open, onClose, onCreated }: Props) {
  const { token, orgId, branchId, branches } = useOrgBranch();

  const [name,           setName]           = useState("");
  const [code,           setCode]           = useState("");
  const [selectedBranch, setSelectedBranch] = useState<string>(branchId ?? "");
  const [vehicleId,      setVehicleId]      = useState<string>("");
  const [driverId,       setDriverId]       = useState<string>("");
  const [vehicles,       setVehicles]       = useState<VehicleOption[]>([]);
  const [drivers,        setDrivers]        = useState<DriverOption[]>([]);
  const [loadingOpts,    setLoadingOpts]    = useState(false);
  const [submitting,     setSubmitting]     = useState(false);
  const [errors,         setErrors]         = useState<string[]>([]);

  // Sync: prefer the active branchId; fall back to first branch in list
  useEffect(() => {
    setSelectedBranch((prev) => {
      if (prev) return prev;
      if (branchId) return branchId;
      return String(branches[0]?.id ?? "");
    });
  }, [branchId, branches]);

  // Fetch vehicle + driver options when modal opens
  useEffect(() => {
    if (!open || !orgId) return;
    setLoadingOpts(true);
    const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };
    Promise.all([
      fetch(`/api/v1/vehicles?status=active&per_page=100`, { headers }).then((r) => r.json()),
      fetch(`/api/v1/users?role_name=driver&status=active&per_page=100`, { headers }).then((r) => r.json()),
    ])
      .then(([ve, dr]) => {
        setVehicles(ve.data ?? []);
        setDrivers(dr.data ?? []);
      })
      .finally(() => setLoadingOpts(false));
  }, [open, orgId, token]);

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
    setVehicleId(""); setDriverId("");
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
            name:               name.trim(),
            code:               code.toUpperCase().trim(),
            branch_id:          Number(selectedBranch),
            vehicle_id:         vehicleId ? Number(vehicleId) : null,
            default_driver_id:  driverId  ? Number(driverId)  : null,
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
      size="md"
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
            Uppercase letters, numbers and hyphens only â€” auto-filled from name.
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
                <option value="" disabled>Select a branchâ€¦</option>
              )}
              {branches.map((b) => (
                <option key={b.id} value={String(b.id)}>{b.name}</option>
              ))}
            </select>
          </div>
        )}

        {/* â”€â”€ Delivery assignment â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ */}
        <div className="border-t border-border pt-4">
          <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">
            Delivery Assignment <span className="font-normal normal-case">(optional)</span>
            {loadingOpts && <span className="ml-1.5 animate-pulse">loadingâ€¦</span>}
          </p>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-sm font-medium text-text-primary mb-1.5 block">Vehicle</label>
              <select
                value={vehicleId}
                onChange={(e) => setVehicleId(e.target.value)}
                disabled={loadingOpts}
                className="h-10 w-full rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:opacity-60"
              >
                <option value="">— No vehicle —</option>
                {vehicles.map((v) => (
                  <option key={v.id} value={String(v.id)}>
                    {v.registration_number} ({v.vehicle_type})
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-sm font-medium text-text-primary mb-1.5 block">Default Driver</label>
              <select
                value={driverId}
                onChange={(e) => setDriverId(e.target.value)}
                disabled={loadingOpts}
                className="h-10 w-full rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:opacity-60"
              >
                <option value="">— No driver —</option>
                {drivers.map((d) => (
                  <option key={d.id} value={String(d.id)}>{d.full_name}</option>
                ))}
              </select>
            </div>
          </div>
        </div>

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
