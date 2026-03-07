"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { Modal } from "@/components/ui/modal";
import { EmptyState } from "@/components/ui/empty-state";
import { Truck, Plus, Pencil, Trash2, AlertTriangle } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

interface Vehicle {
  id: number;
  registration_number: string;
  vehicle_type: string;
  capacity_kg: number | null;
  capacity_units: number | null;
  status: string;
  insurance_expiry: string | null;
  fitness_expiry: string | null;
  permit_expiry: string | null;
  default_driver: { id: number; name: string } | null;
  notes: string | null;
}

const VEHICLE_TYPES = ["truck", "tempo", "bike", "van", "auto", "car", "other"];

const BLANK_FORM = {
  registration_number: "",
  vehicle_type: "truck",
  capacity_kg: "",
  capacity_units: "",
  default_driver_id: "",
  insurance_expiry: "",
  fitness_expiry: "",
  permit_expiry: "",
  status: "active",
  notes: "",
};

export default function FleetPage() {
  const { token, orgId } = useOrgBranch();

  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [loading, setLoading]   = useState(true);

  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing]     = useState<Vehicle | null>(null);
  const [form, setForm]           = useState({ ...BLANK_FORM });
  const [saving, setSaving]       = useState(false);
  const [errors, setErrors]       = useState<string[]>([]);

  const [deleteConfirm, setDeleteConfirm] = useState<Vehicle | null>(null);
  const [deleteLoading, setDeleteLoading] = useState(false);

  const authHeaders = {
    Authorization: `Bearer ${token}`,
    "X-Organization-Id": orgId,
    "Content-Type": "application/json",
  } as Record<string, string>;

  const fetchVehicles = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/vehicles?per_page=100`, { headers: authHeaders });
      const json = await res.json();
      if (res.ok) setVehicles(json.data ?? []);
    } finally {
      setLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, orgId]);

  useEffect(() => { void fetchVehicles(); }, [fetchVehicles]);

  function openCreate() {
    setEditing(null);
    setForm({ ...BLANK_FORM });
    setErrors([]);
    setShowModal(true);
  }

  function openEdit(v: Vehicle) {
    setEditing(v);
    setForm({
      registration_number: v.registration_number,
      vehicle_type:        v.vehicle_type,
      capacity_kg:         v.capacity_kg?.toString()    ?? "",
      capacity_units:      v.capacity_units?.toString() ?? "",
      default_driver_id:   v.default_driver?.id?.toString() ?? "",
      insurance_expiry:    v.insurance_expiry ?? "",
      fitness_expiry:      v.fitness_expiry   ?? "",
      permit_expiry:       v.permit_expiry    ?? "",
      status:              v.status,
      notes:               v.notes ?? "",
    });
    setErrors([]);
    setShowModal(true);
  }

  async function handleSave() {
    setSaving(true);
    setErrors([]);
    try {
      const url    = editing ? `${API_URL}/api/v1/vehicles/${editing.id}` : `${API_URL}/api/v1/vehicles`;
      const method = editing ? "PATCH" : "POST";
      const res    = await fetch(url, {
        method,
        headers: authHeaders,
        body:    JSON.stringify({
          vehicle: {
            registration_number: form.registration_number,
            vehicle_type:        form.vehicle_type,
            capacity_kg:         form.capacity_kg      || null,
            capacity_units:      form.capacity_units   || null,
            default_driver_id:   form.default_driver_id || null,
            insurance_expiry:    form.insurance_expiry  || null,
            fitness_expiry:      form.fitness_expiry    || null,
            permit_expiry:       form.permit_expiry     || null,
            status:              form.status,
            notes:               form.notes             || null,
          },
        }),
      });
      const json = await res.json();
      if (res.ok) { setShowModal(false); void fetchVehicles(); }
      else setErrors(json.errors ?? ["Failed to save vehicle"]);
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!deleteConfirm) return;
    setDeleteLoading(true);
    try {
      const res = await fetch(`${API_URL}/api/v1/vehicles/${deleteConfirm.id}`, {
        method: "DELETE", headers: authHeaders,
      });
      const json = await res.json();
      if (res.ok) { setDeleteConfirm(null); void fetchVehicles(); }
      else setErrors(json.errors ?? ["Cannot delete vehicle"]);
    } finally {
      setDeleteLoading(false);
    }
  }

  // Expiry warning helper
  function expiryWarning(dateStr: string | null): boolean {
    if (!dateStr) return false;
    return new Date(dateStr) <= new Date(Date.now() + 30 * 24 * 3600 * 1000);
  }

  const columns: Column<Vehicle>[] = [
    {
      key: "registration_number",
      header: "Registration",
      render: (_cell, v) => <span className="font-mono font-semibold text-sm">{v.registration_number}</span>,
    },
    {
      key: "vehicle_type",
      header: "Type",
      render: (_cell, v) => (
        <span className="capitalize text-sm">{v.vehicle_type}</span>
      ),
    },
    {
      key: "capacity_kg",
      header: "Capacity",
      render: (_cell, v) => (
        <span className="text-sm text-text-secondary tabular-nums">
          {v.capacity_kg ? `${v.capacity_kg} kg` : ""}
          {v.capacity_kg && v.capacity_units ? " / " : ""}
          {v.capacity_units ? `${v.capacity_units} units` : ""}
          {!v.capacity_kg && !v.capacity_units ? "—" : ""}
        </span>
      ),
    },
    {
      key: "status",
      header: "Status",
      render: (_cell, v) => (
        <Badge variant={v.status === "active" ? "success" : "secondary"}>
          {v.status}
        </Badge>
      ),
    },
    {
      key: "insurance_expiry",
      header: "Insurance Exp.",
      render: (_cell, v) => v.insurance_expiry ? (
        <span className={`text-sm ${expiryWarning(v.insurance_expiry) ? "text-amber-600 font-medium" : "text-text-secondary"}`}>
          {new Date(v.insurance_expiry).toLocaleDateString("en-IN")}
          {expiryWarning(v.insurance_expiry) && <AlertTriangle className="inline h-3.5 w-3.5 ml-1 text-amber-500" />}
        </span>
      ) : <span className="text-text-secondary text-sm">—</span>,
    },
    {
      key: "default_driver",
      header: "Default Driver",
      render: (_cell, v) => v.default_driver ? (
        <span className="text-sm">{v.default_driver.name}</span>
      ) : <span className="text-sm text-text-secondary">—</span>,
    },
    {
      key: "id",
      header: "",
      render: (_cell, v) => (
        <div className="flex gap-2 justify-end">
          <Button size="sm" variant="ghost" onClick={() => openEdit(v)}>
            <Pencil className="h-3.5 w-3.5" />
          </Button>
          <Button
            size="sm"
            variant="ghost"
            className="text-red-500 hover:text-red-700"
            onClick={() => setDeleteConfirm(v)}
          >
            <Trash2 className="h-3.5 w-3.5" />
          </Button>
        </div>
      ),
    },
  ];

  return (
    <AppShell breadcrumbs={[
        { label: "Settings", href: "/settings" },
        { label: "Fleet" },
      ]}>
      <PageHeader
        title="Fleet Management"
        subtitle="Manage vehicles used for deliveries"
        actions={[
          {
            label: "Add Vehicle",
            icon: <Plus className="h-4 w-4" />,
            onClick: openCreate,
          },
        ]}
      />

      {loading ? (
        <div className="text-center py-12 text-text-secondary">Loading fleet…</div>
      ) : vehicles.length === 0 ? (
        <EmptyState
          icon={<Truck className="h-10 w-10 text-text-secondary" />}
          title="No vehicles yet"
          description="Add your first vehicle to start planning delivery trips."
          action={
            <Button onClick={openCreate}>
              <Plus className="mr-2 h-4 w-4" /> Add Vehicle
            </Button>
          }
        />
      ) : (
        <DataTable columns={columns} data={vehicles} />
      )}

      {/* Create / Edit modal */}
      <Modal
        open={showModal}
        onClose={() => setShowModal(false)}
        title={editing ? "Edit Vehicle" : "Add Vehicle"}
      >
        <div className="space-y-4">
          {errors.length > 0 && (
            <div className="rounded-md bg-red-50 border border-red-200 p-3 text-sm text-red-700">
              {errors.map((e, i) => <p key={i}>{e}</p>)}
            </div>
          )}

          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="text-xs font-medium text-text-secondary block mb-1">Registration No. *</label>
              <Input
                value={form.registration_number}
                onChange={(e) => setForm({ ...form, registration_number: e.target.value })}
                placeholder="MH01AB1234"
              />
            </div>
            <div>
              <label className="text-xs font-medium text-text-secondary block mb-1">Type *</label>
              <select
                className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                value={form.vehicle_type}
                onChange={(e) => setForm({ ...form, vehicle_type: e.target.value })}
              >
                {VEHICLE_TYPES.map((t) => (
                  <option key={t} value={t} className="capitalize">{t}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-xs font-medium text-text-secondary block mb-1">Capacity (kg)</label>
              <Input
                type="number"
                value={form.capacity_kg}
                onChange={(e) => setForm({ ...form, capacity_kg: e.target.value })}
                placeholder="1000"
              />
            </div>
            <div>
              <label className="text-xs font-medium text-text-secondary block mb-1">Capacity (units)</label>
              <Input
                type="number"
                value={form.capacity_units}
                onChange={(e) => setForm({ ...form, capacity_units: e.target.value })}
                placeholder="500"
              />
            </div>
            <div>
              <label className="text-xs font-medium text-text-secondary block mb-1">Insurance Expiry</label>
              <Input
                type="date"
                value={form.insurance_expiry}
                onChange={(e) => setForm({ ...form, insurance_expiry: e.target.value })}
              />
            </div>
            <div>
              <label className="text-xs font-medium text-text-secondary block mb-1">Fitness Expiry</label>
              <Input
                type="date"
                value={form.fitness_expiry}
                onChange={(e) => setForm({ ...form, fitness_expiry: e.target.value })}
              />
            </div>
            <div>
              <label className="text-xs font-medium text-text-secondary block mb-1">Permit Expiry</label>
              <Input
                type="date"
                value={form.permit_expiry}
                onChange={(e) => setForm({ ...form, permit_expiry: e.target.value })}
              />
            </div>
            <div>
              <label className="text-xs font-medium text-text-secondary block mb-1">Status</label>
              <select
                className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                value={form.status}
                onChange={(e) => setForm({ ...form, status: e.target.value })}
              >
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
              </select>
            </div>
          </div>

          <div>
            <label className="text-xs font-medium text-text-secondary block mb-1">Notes</label>
            <Input
              value={form.notes}
              onChange={(e) => setForm({ ...form, notes: e.target.value })}
              placeholder="Any notes about this vehicle…"
            />
          </div>

          <div className="flex justify-end gap-2 pt-2">
            <Button variant="outline" onClick={() => setShowModal(false)}>Cancel</Button>
            <Button disabled={saving} onClick={handleSave}>
              {saving ? "Saving…" : editing ? "Save Changes" : "Add Vehicle"}
            </Button>
          </div>
        </div>
      </Modal>

      {/* Delete confirmation */}
      <Modal
        open={!!deleteConfirm}
        onClose={() => setDeleteConfirm(null)}
        title="Delete Vehicle"
      >
        <div className="space-y-4">
          <p className="text-sm text-text-secondary">
            Delete vehicle <span className="font-semibold">{deleteConfirm?.registration_number}</span>?
            This cannot be undone if the vehicle has no active trips.
          </p>
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setDeleteConfirm(null)}>Cancel</Button>
            <Button
              variant="danger"
              disabled={deleteLoading}
              onClick={handleDelete}
            >
              {deleteLoading ? "Deleting…" : "Delete"}
            </Button>
          </div>
        </div>
      </Modal>
    </AppShell>
  );
}
