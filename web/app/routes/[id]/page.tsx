"use client";

import React, { useEffect, useState, useCallback, useRef } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell } from "@/components/layout";
import { Tabs } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { DataTable, Column } from "@/components/ui/data-table";
import { Card, CardContent } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";
import { useOrgBranch } from "@/lib/org-branch-context";
import {
  ArrowLeft, MapPin, Users, CalendarCheck, Pencil, X,
  Check, Trash2, UserPlus, Search, Truck, User as UserIcon,
} from "lucide-react";

// ─── Types ────────────────────────────────────────────────────────────────────
interface RouteVehicle { id: number; registration_number: string; vehicle_type: string }
interface RouteDriver  { id: number; name: string }
interface VehicleOption { id: number; registration_number: string; vehicle_type: string }
interface DriverOption  { id: number; full_name: string }

interface Route {
  id: number;
  name: string;
  code: string;
  active: boolean;
  branch_id: number;
  customers_count: number;
  vehicle?: RouteVehicle | null;
  default_driver?: RouteDriver | null;
}

interface Customer {
  id: number;
  name: string;
  code: string;
  channel: string | null;
  tier: string | null;
  active: boolean;
}

interface Beat {
  id: number;
  name: string;
  code: string;
  active: boolean;
}

// ─── Add-customer search panel ────────────────────────────────────────────────
function AddCustomerPanel({
  routeId, existingIds, token, orgId, branchId, onAdded,
}: {
  routeId: string;
  existingIds: Set<number>;
  token: string | null;
  orgId: string | null;
  branchId: string | null;
  onAdded: (customer: Customer) => void;
}) {
  const [query, setQuery]         = useState("");
  const [results, setResults]     = useState<Customer[]>([]);
  const [searching, setSearching] = useState(false);
  const [adding, setAdding]       = useState<number | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (!query.trim()) { setResults([]); return; }
    debounceRef.current = setTimeout(async () => {
      if (!orgId) return;
      setSearching(true);
      try {
        const qp = new URLSearchParams({ q: query, per_page: "15", status: "active" });
        if (branchId) qp.set("branch_id", branchId);
        const res  = await fetch(`/api/v1/customers?${qp}`, {
          headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        });
        const data = await res.json();
        setResults((data.data ?? []).filter((c: Customer) => !existingIds.has(c.id)));
      } finally {
        setSearching(false);
      }
    }, 300);
  }, [query, orgId, branchId, token, existingIds]);

  async function assign(customer: Customer) {
    if (!orgId) return;
    setAdding(customer.id);
    try {
      await fetch(`/api/v1/customers/${customer.id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({ customer: { route_id: Number(routeId) } }),
      });
      setResults((prev) => prev.filter((c) => c.id !== customer.id));
      onAdded(customer);
    } finally {
      setAdding(null);
    }
  }

  return (
    <div className="rounded-lg border border-border bg-background-subtle p-4 mb-4">
      <p className="text-sm font-medium text-text-primary mb-3 flex items-center gap-1.5">
        <UserPlus className="h-4 w-4 text-primary" /> Add customers to this route
      </p>
      <div className="relative max-w-md">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
        <Input
          placeholder="Search by customer name or code…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className="pl-9"
        />
      </div>

      {searching && (
        <p className="text-xs text-text-secondary mt-2">Searching…</p>
      )}

      {results.length > 0 && (
        <ul className="mt-2 rounded-md border border-border bg-background divide-y divide-border max-h-60 overflow-y-auto">
          {results.map((c) => (
            <li key={c.id} className="flex items-center justify-between px-3 py-2.5 hover:bg-background-subtle">
              <div>
                <span className="font-medium text-sm text-text-primary">{c.name}</span>
                <span className="ml-2 font-mono text-xs text-text-secondary">{c.code}</span>
                {c.channel && (
                  <span className="ml-2 text-xs text-text-secondary capitalize">{c.channel.replace(/_/g, " ")}</span>
                )}
              </div>
              <Button
                size="sm"
                variant="outline"
                disabled={adding === c.id}
                onClick={() => assign(c)}
                className="shrink-0 ml-3"
              >
                {adding === c.id ? "Adding…" : "Add"}
              </Button>
            </li>
          ))}
        </ul>
      )}

      {!searching && query.trim() && results.length === 0 && (
        <p className="text-xs text-text-secondary mt-2">No unassigned customers match "{query}".</p>
      )}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function RouteDetailPage() {
  const { id }  = useParams<{ id: string }>();
  const router  = useRouter();
  const { token, orgId, branchId } = useOrgBranch();

  const [route, setRoute]           = useState<Route | null>(null);
  const [loading, setLoading]       = useState(true);

  // Inline edit state
  const [editing, setEditing]       = useState(false);
  const [editName, setEditName]     = useState("");
  const [editCode, setEditCode]     = useState("");
  const [editActive, setEditActive] = useState(true);
  const [saving, setSaving]         = useState(false);
  const [editVehicleId, setEditVehicleId] = useState<number | null>(null);
  const [editDriverId, setEditDriverId]   = useState<number | null>(null);
  const [vehicles, setVehicles]           = useState<VehicleOption[]>([]);
  const [drivers, setDrivers]             = useState<DriverOption[]>([]);
  const [loadingOpts, setLoadingOpts]     = useState(false);

  const [customers, setCustomers]     = useState<Customer[]>([]);
  const [custLoading, setCustLoading] = useState(false);
  const [custLoaded, setCustLoaded]   = useState(false);
  const [showAddPanel, setShowAddPanel] = useState(false);
  const [removing, setRemoving]       = useState<number | null>(null);

  const [beats, setBeats]           = useState<Beat[]>([]);
  const [beatsLoading, setBeatsLoading] = useState(false);
  const [beatsLoaded, setBeatsLoaded]   = useState(false);

  // Toast
  const [toast, setToast] = useState<{ type: "success" | "error"; msg: string } | null>(null);
  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  // ── Fetch route ──────────────────────────────────────────────────────────
  const fetchRoute = useCallback(async () => {
    if (!orgId) return;
    setLoading(true);
    try {
      const res  = await fetch(`/api/v1/routes/${id}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (!res.ok) { setRoute(null); return; }
      const data = await res.json();
      setRoute(data.data);
    } finally {
      setLoading(false);
    }
  }, [id, orgId, token]);

  useEffect(() => { fetchRoute(); }, [fetchRoute]);

  // ── Fetch vehicle + driver options (loaded on edit open) ────────────────
  const fetchAssignmentOptions = useCallback(async () => {
    if (!orgId) return;
    setLoadingOpts(true);
    try {
      const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };
      const [veRes, drRes] = await Promise.all([
        fetch(`/api/v1/vehicles?status=active&per_page=100`, { headers }),
        fetch(`/api/v1/users?role_name=driver&status=active&per_page=100`, { headers }),
      ]);
      const [veData, drData] = await Promise.all([veRes.json(), drRes.json()]);
      setVehicles(veData.data ?? []);
      setDrivers(drData.data ?? []);
    } finally {
      setLoadingOpts(false);
    }
  }, [orgId, token]);

  // ── Fetch customers (lazy) ───────────────────────────────────────────────
  const fetchCustomers = useCallback(async () => {
    if (!orgId || custLoaded) return;
    setCustLoading(true);
    try {
      const qp = new URLSearchParams({ route_id: id, per_page: "200" });
      if (branchId) qp.set("branch_id", branchId);
      const res  = await fetch(`/api/v1/customers?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const data = await res.json();
      setCustomers(data.data ?? []);
      setCustLoaded(true);
    } finally {
      setCustLoading(false);
    }
  }, [id, orgId, branchId, token, custLoaded]);

  // Load customers automatically when route is ready (default tab)
  useEffect(() => { if (route) fetchCustomers(); }, [route, fetchCustomers]);

  // ── Fetch beats (lazy) ───────────────────────────────────────────────────
  const fetchBeats = useCallback(async () => {
    if (!orgId || beatsLoaded) return;
    setBeatsLoading(true);
    try {
      const qp = new URLSearchParams({ route_id: id, per_page: "100" });
      if (branchId) qp.set("branch_id", branchId);
      const res  = await fetch(`/api/v1/beats?${qp}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const data = await res.json();
      setBeats(data.data ?? []);
      setBeatsLoaded(true);
    } finally {
      setBeatsLoading(false);
    }
  }, [id, orgId, branchId, token, beatsLoaded]);

  // ── Save route edits ─────────────────────────────────────────────────────
  async function saveRoute() {
    if (!orgId) return;
    setSaving(true);
    try {
      const res = await fetch(`/api/v1/routes/${id}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({ route: { name: editName, code: editCode.toUpperCase(), active: editActive,
          vehicle_id: editVehicleId ?? null, default_driver_id: editDriverId ?? null } }),
      });
      const data = await res.json();
      if (res.ok) {
        setRoute((prev) => prev ? { ...prev, ...data.data } : prev);
        setEditing(false);
        showToast("success", "Route updated");
      } else {
        showToast("error", data.errors?.[0] ?? "Failed to save");
      }
    } finally {
      setSaving(false);
    }
  }

  // ── Remove customer from route ───────────────────────────────────────────
  async function removeCustomer(customerId: number) {
    if (!orgId) return;
    setRemoving(customerId);
    try {
      const res = await fetch(`/api/v1/customers/${customerId}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({ customer: { route_id: null } }),
      });
      if (res.ok) {
        setCustomers((prev) => prev.filter((c) => c.id !== customerId));
        setRoute((prev) => prev ? { ...prev, customers_count: prev.customers_count - 1 } : prev);
        showToast("success", "Customer removed from route");
      } else {
        showToast("error", "Failed to remove customer");
      }
    } finally {
      setRemoving(null);
    }
  }

  // ── Loading / error states ───────────────────────────────────────────────
  if (loading) {
    return (
      <AppShell>
        <div className="flex items-center justify-center py-24">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
        </div>
      </AppShell>
    );
  }

  if (!route) {
    return (
      <AppShell>
        <div className="flex flex-col items-center justify-center py-24 gap-3">
          <p className="text-text-secondary">Route not found.</p>
          <Button variant="outline" onClick={() => router.push("/routes")}>
            <ArrowLeft className="mr-2 h-4 w-4" /> Back to Routes
          </Button>
        </div>
      </AppShell>
    );
  }

  const existingIds = new Set(customers.map((c) => c.id));

  // ── Customer columns ──────────────────────────────────────────────────────
  const customerColumns: Column<Customer>[] = [
    {
      key: "code",
      header: "Code",
      render: (_, row) => (
        <button
          onClick={() => router.push(`/customers/${row.id}`)}
          className="font-mono text-sm font-semibold text-primary hover:underline"
        >
          {row.code}
        </button>
      ),
    },
    {
      key: "name",
      header: "Customer Name",
      render: (_, row) => (
        <span className="font-medium text-text-primary">{row.name}</span>
      ),
    },
    {
      key: "channel",
      header: "Channel",
      render: (_, row) =>
        row.channel ? (
          <span className="text-sm capitalize">{row.channel.replace(/_/g, " ")}</span>
        ) : (
          <span className="text-text-secondary">—</span>
        ),
    },
    {
      key: "tier",
      header: "Tier",
      render: (_, row) =>
        row.tier ? <Badge variant="outline">{row.tier}</Badge> : <span className="text-text-secondary">—</span>,
    },
    {
      key: "active",
      header: "Status",
      render: (_, row) => (
        <Badge variant={row.active ? "success" : "secondary"}>
          {row.active ? "Active" : "Inactive"}
        </Badge>
      ),
    },
    {
      key: "id",
      header: "",
      className: "w-12 text-right",
      render: (_, row) => (
        <button
          onClick={(e) => { e.stopPropagation(); removeCustomer(row.id); }}
          disabled={removing === row.id}
          title="Remove from route"
          className="p-1.5 rounded-md text-text-secondary hover:text-danger hover:bg-red-50 transition-colors disabled:opacity-40"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      ),
    },
  ];

  // ── Beat columns ──────────────────────────────────────────────────────────
  const beatColumns: Column<Beat>[] = [
    {
      key: "code",
      header: "Code",
      render: (_, row) => (
        <button
          onClick={() => router.push(`/beats/${row.id}`)}
          className="font-mono text-sm font-semibold text-primary hover:underline"
        >
          {row.code}
        </button>
      ),
    },
    {
      key: "name",
      header: "Beat Name",
      render: (_, row) => <span className="font-medium text-text-primary">{row.name}</span>,
    },
    {
      key: "active",
      header: "Status",
      render: (_, row) => (
        <Badge variant={row.active ? "success" : "secondary"}>
          {row.active ? "Active" : "Inactive"}
        </Badge>
      ),
    },
    {
      key: "id",
      header: "",
      className: "w-16 text-right",
      render: (_, row) => (
        <Button size="sm" variant="ghost" onClick={() => router.push(`/beats/${row.id}`)}>
          View →
        </Button>
      ),
    },
  ];

  // ── Tabs ─────────────────────────────────────────────────────────────────
  const tabs = [
    {
      value: "customers",
      label: `Customers (${customers.length || route.customers_count})`,
      content: (
        <div>
          <div className="flex justify-end mb-3">
            <Button
              size="sm"
              variant={showAddPanel ? "outline" : "default"}
              onClick={() => setShowAddPanel((v) => !v)}
            >
              {showAddPanel ? (
                <><X className="mr-1.5 h-3.5 w-3.5" />Close</>
              ) : (
                <><UserPlus className="mr-1.5 h-3.5 w-3.5" />Add Customers</>
              )}
            </Button>
          </div>

          {showAddPanel && (
            <AddCustomerPanel
              routeId={id}
              existingIds={existingIds}
              token={token}
              orgId={orgId}
              branchId={branchId}
              onAdded={(c) => {
                setCustomers((prev) => [...prev, c]);
                setRoute((prev) => prev ? { ...prev, customers_count: prev.customers_count + 1 } : prev);
                showToast("success", `${c.name} added to route`);
              }}
            />
          )}

          {customers.length === 0 && !custLoading ? (
            <EmptyState
              icon={Users}
              title="No customers on this route"
              description="Use the Add Customers button above to assign customers."
            />
          ) : (
            <DataTable
              columns={customerColumns}
              data={customers}
              isLoading={custLoading}
              onRowClick={(row) => router.push(`/customers/${row.id}`)}
              emptyMessage="No customers found."
            />
          )}
        </div>
      ),
    },
    {
      value: "beats",
      label: `Beats (${beats.length})`,
      content: (
        <div>
          {beats.length === 0 && !beatsLoading ? (
            <EmptyState
              icon={CalendarCheck}
              title="No beats on this route"
              description="Create a beat and assign it to this route."
              action={{ label: "Go to Beats", onClick: () => router.push("/beats") }}
            />
          ) : (
            <DataTable
              columns={beatColumns}
              data={beats}
              isLoading={beatsLoading}
              onRowClick={(row) => router.push(`/beats/${row.id}`)}
              emptyMessage="No beats found."
            />
          )}
        </div>
      ),
    },
  ];

  return (
    <AppShell breadcrumbs={[
      { label: "Routes", href: "/routes" },
      { label: route.name || route.code || "Route" },
    ]}>
      {/* Toast */}
      {toast && (
        <div className={`fixed top-4 right-4 z-50 rounded-lg px-4 py-3 text-sm text-white shadow-lg ${
          toast.type === "success" ? "bg-success" : "bg-danger"
        }`}>
          {toast.msg}
        </div>
      )}

      {/* Back nav */}
      <button
        onClick={() => router.push("/routes")}
        className="flex items-center gap-1.5 text-sm text-text-secondary hover:text-primary mb-4 transition-colors"
      >
        <ArrowLeft className="h-4 w-4" /> Back to Routes
      </button>

      {/* Route header card */}
      <Card className="mb-6">
        <CardContent className="p-5">
          {editing ? (
            /* ── Edit mode ─────────────────────────────────────────────── */
            <div className="space-y-3">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <Input
                  label="Route Name"
                  value={editName}
                  onChange={(e) => setEditName(e.target.value)}
                />
                <div>
                  <label className="text-sm font-medium text-text-primary mb-1.5 block">Code</label>
                  <input
                    className="h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm font-mono text-text-primary focus:outline-none focus:ring-2 focus:ring-primary"
                    value={editCode}
                    onChange={(e) => setEditCode(e.target.value.toUpperCase())}
                  />
                </div>
              </div>
              <div className="flex items-center gap-2">
                <label className="flex items-center gap-2 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={editActive}
                    onChange={(e) => setEditActive(e.target.checked)}
                    className="h-4 w-4 rounded border-border text-primary focus:ring-primary"
                  />
                  <span className="text-sm font-medium text-text-primary">Active</span>
                </label>
              </div>
              {/* ── Delivery assignment ─────────────────────────────────── */}
              <div className="border-t border-border pt-3 mt-1">
                <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-2.5 flex items-center gap-1.5">
                  <Truck className="h-3.5 w-3.5" /> Delivery Assignment
                  {loadingOpts && <span className="ml-1 text-xs font-normal normal-case">(loading…)</span>}
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="text-sm font-medium text-text-primary mb-1.5 block">Vehicle</label>
                    <select
                      value={editVehicleId ?? ""}
                      onChange={(e) => setEditVehicleId(e.target.value ? Number(e.target.value) : null)}
                      disabled={loadingOpts}
                      className="h-10 w-full rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:opacity-60"
                    >
                      <option value="">— No vehicle —</option>
                      {vehicles.map((v) => (
                        <option key={v.id} value={v.id}>
                          {v.registration_number} ({v.vehicle_type})
                        </option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="text-sm font-medium text-text-primary mb-1.5 block">Default Driver</label>
                    <select
                      value={editDriverId ?? ""}
                      onChange={(e) => setEditDriverId(e.target.value ? Number(e.target.value) : null)}
                      disabled={loadingOpts}
                      className="h-10 w-full rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-primary disabled:opacity-60"
                    >
                      <option value="">— No driver —</option>
                      {drivers.map((d) => (
                        <option key={d.id} value={d.id}>{d.full_name}</option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-2 pt-1">
                <Button size="sm" onClick={saveRoute} isLoading={saving} disabled={saving}>
                  <Check className="mr-1.5 h-3.5 w-3.5" /> Save
                </Button>
                <Button size="sm" variant="outline" onClick={() => setEditing(false)} disabled={saving}>
                  Cancel
                </Button>
              </div>
            </div>
          ) : (
            /* ── View mode ─────────────────────────────────────────────── */
            <div className="flex items-start justify-between gap-4 flex-wrap">
              <div className="flex items-start gap-4">
                <div className="rounded-xl bg-primary/10 p-3 shrink-0">
                  <MapPin className="h-6 w-6 text-primary" />
                </div>
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <h1 className="text-xl font-bold text-text-primary">{route.name}</h1>
                    <span className="font-mono text-sm text-text-secondary bg-background-subtle px-2 py-0.5 rounded-md">
                      {route.code}
                    </span>
                    <Badge variant={route.active ? "success" : "secondary"}>
                      {route.active ? "Active" : "Inactive"}
                    </Badge>
                  </div>
                  <p className="mt-1.5 text-sm text-text-secondary flex items-center gap-1">
                    <Users className="h-3.5 w-3.5" />
                    {route.customers_count} customer{route.customers_count !== 1 ? "s" : ""}
                  </p>
                  <div className="mt-2 flex flex-wrap gap-x-5 gap-y-1">
                    <span className="flex items-center gap-1.5 text-sm text-text-secondary">
                      <Truck className="h-3.5 w-3.5 shrink-0" />
                      {route.vehicle ? (
                        <>
                          <span className="font-mono font-semibold text-text-primary">{route.vehicle.registration_number}</span>
                          <span className="capitalize text-xs text-text-secondary">{route.vehicle.vehicle_type}</span>
                        </>
                      ) : <span className="italic text-xs">No vehicle assigned</span>}
                    </span>
                    <span className="flex items-center gap-1.5 text-sm text-text-secondary">
                      <UserIcon className="h-3.5 w-3.5 shrink-0" />
                      {route.default_driver ? (
                        <span className="font-medium text-text-primary">{route.default_driver.name}</span>
                      ) : <span className="italic text-xs">No driver assigned</span>}
                    </span>
                  </div>
                </div>
              </div>
              <Button
                size="sm"
                variant="outline"
                onClick={() => {
                  setEditName(route.name);
                  setEditCode(route.code);
                  setEditActive(route.active);
                  setEditVehicleId(route.vehicle?.id ?? null);
                  setEditDriverId(route.default_driver?.id ?? null);
                  setEditing(true);
                  void fetchAssignmentOptions();
                }}
              >
                <Pencil className="mr-1.5 h-3.5 w-3.5" /> Edit
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Tabs */}
      <Tabs
        defaultValue="customers"
        items={tabs}
        onValueChange={(v) => {
          if (v === "customers") fetchCustomers();
          if (v === "beats")     fetchBeats();
        }}
      />
    </AppShell>
  );
}


