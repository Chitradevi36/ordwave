"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { API_URL } from "@/lib/api/client";

import { Truck, User, Package, X, GripVertical, Plus, ChevronRight } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";

interface ApprovedOrder {
  id: number;
  order_number: string;
  total_amount: number;
  customer: { id: number; name: string };
  branch: { id: number; name: string };
  delivery_date: string | null;
}

interface Vehicle {
  id: number;
  registration_number: string;
  vehicle_type: string;
  capacity_units: number | null;
}

interface Driver {
  id: number;
  first_name: string;
  last_name: string;
  full_name?: string;
}

export default function NewTripPage() {
  const router = useRouter();
  const { token, orgId, branchId } = useOrgBranch();

  const [tripDate, setTripDate]   = useState(new Date().toISOString().slice(0, 10));
  const [vehicleId, setVehicleId] = useState("");
  const [driverId, setDriverId]   = useState("");
  const [notes, setNotes]         = useState("");
  const [selectedBranchId, setSelectedBranchId] = useState(branchId || "");

  const [vehicles, setVehicles]   = useState<Vehicle[]>([]);
  const [drivers, setDrivers]     = useState<Driver[]>([]);
  const [orders, setOrders]       = useState<ApprovedOrder[]>([]);
  const [branches, setBranches]   = useState<{ id: number; name: string }[]>([]);

  const [selectedOrders, setSelectedOrders] = useState<ApprovedOrder[]>([]);
  const [orderSearch, setOrderSearch]       = useState("");

  const [saving, setSaving] = useState(false);
  const [errors, setErrors] = useState<string[]>([]);

  const authHeaders = {
    Authorization: `Bearer ${token}`,
    "X-Organization-Id": orgId,
    "Content-Type": "application/json",
  } as Record<string, string>;

  // Fetch reference data
  useEffect(() => {
    if (!token || !orgId) return;
    Promise.all([
      fetch(`${API_URL}/api/v1/vehicles?status=active&per_page=100`, { headers: authHeaders }),
      fetch(`${API_URL}/api/v1/users?role=driver&per_page=100`, { headers: authHeaders }),
      fetch(`${API_URL}/api/v1/branches?per_page=100`, { headers: authHeaders }),
    ]).then(async ([vRes, uRes, bRes]) => {
      if (vRes.ok) { const d = await vRes.json(); setVehicles(d.data ?? []); }
      if (uRes.ok) { const d = await uRes.json(); setDrivers(d.data ?? []); }
      if (bRes.ok) { const d = await bRes.json(); setBranches(d.data ?? []); }
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, orgId]);

  // Fetch approved orders
  const fetchOrders = useCallback(async () => {
    if (!token || !orgId) return;
    const qp = new URLSearchParams({ status: "approved", per_page: "100" });
    if (selectedBranchId) qp.set("branch_id", selectedBranchId);
    if (orderSearch)      qp.set("q", orderSearch);
    const res = await fetch(`${API_URL}/api/v1/sales_orders?${qp}`, { headers: authHeaders });
    if (res.ok) { const d = await res.json(); setOrders(d.data ?? []); }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, orgId, selectedBranchId, orderSearch]);

  useEffect(() => { void fetchOrders(); }, [fetchOrders]);

  function toggleOrder(order: ApprovedOrder) {
    setSelectedOrders((prev) =>
      prev.find((o) => o.id === order.id)
        ? prev.filter((o) => o.id !== order.id)
        : [...prev, order]
    );
  }

  function removeOrder(id: number) {
    setSelectedOrders((prev) => prev.filter((o) => o.id !== id));
  }

  async function handleCreate() {
    if (!selectedOrders.length) {
      setErrors(["Select at least one order"]);
      return;
    }
    setSaving(true);
    setErrors([]);
    try {
      const res = await fetch(`${API_URL}/api/v1/delivery_trips`, {
        method: "POST",
        headers: authHeaders,
        body: JSON.stringify({
          delivery_trip: {
            branch_id:  selectedBranchId || null,
            trip_date:  tripDate,
            vehicle_id: vehicleId || null,
            driver_id:  driverId  || null,
            notes:      notes     || null,
            order_ids:  selectedOrders.map((o) => o.id),
          },
        }),
      });
      const json = await res.json();
      if (res.ok) {
        router.push(`/delivery/${json.data.id}`);
      } else {
        setErrors(json.errors ?? ["Failed to create trip"]);
      }
    } finally {
      setSaving(false);
    }
  }

  const availableOrders = orders.filter(
    (o) => !selectedOrders.find((s) => s.id === o.id)
  );

  return (
    <AppShell breadcrumbs={[
      { label: "Delivery", href: "/delivery" },
      { label: "New Trip" },
    ]}>

      <PageHeader
        title="Create Delivery Trip"
        description="Assign approved orders to a vehicle and driver"
      />

      {errors.length > 0 && (
        <div className="mb-4 rounded-md bg-red-50 border border-red-200 p-3 text-sm text-red-700">
          {errors.map((e, i) => <p key={i}>{e}</p>)}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left — Trip details */}
        <div className="lg:col-span-1 space-y-4">
          <Card className="border border-border shadow-none">
            <CardContent className="py-4 space-y-4">
              <h3 className="font-semibold text-sm text-text-primary flex items-center gap-2">
                <Truck className="h-4 w-4" /> Trip Details
              </h3>

              <div>
                <label className="text-xs font-medium text-text-secondary block mb-1">Branch</label>
                <select
                  className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                  value={selectedBranchId}
                  onChange={(e) => setSelectedBranchId(e.target.value)}
                >
                  <option value="">All branches</option>
                  {branches.map((b) => (
                    <option key={b.id} value={b.id}>{b.name}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-medium text-text-secondary block mb-1">Trip Date *</label>
                <Input
                  type="date"
                  value={tripDate}
                  onChange={(e) => setTripDate(e.target.value)}
                />
              </div>

              <div>
                <label className="text-xs font-medium text-text-secondary block mb-1">Vehicle</label>
                <select
                  className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                  value={vehicleId}
                  onChange={(e) => setVehicleId(e.target.value)}
                >
                  <option value="">— Select vehicle —</option>
                  {vehicles.map((v) => (
                    <option key={v.id} value={v.id}>
                      {v.registration_number} ({v.vehicle_type})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-medium text-text-secondary block mb-1">Driver</label>
                <select
                  className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                  value={driverId}
                  onChange={(e) => setDriverId(e.target.value)}
                >
                  <option value="">— Select driver —</option>
                  {drivers.map((d) => (
                    <option key={d.id} value={d.id}>
                      {d.first_name} {d.last_name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="text-xs font-medium text-text-secondary block mb-1">Notes</label>
                <textarea
                  className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                  rows={2}
                  placeholder="Route notes…"
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                />
              </div>
            </CardContent>
          </Card>

          {/* Selected stops */}
          <Card className="border border-border shadow-none">
            <CardContent className="py-4">
              <h3 className="font-semibold text-sm text-text-primary mb-3 flex items-center gap-2">
                <Package className="h-4 w-4" /> Stops ({selectedOrders.length})
              </h3>
              {selectedOrders.length === 0 ? (
                <p className="text-xs text-text-secondary">No orders selected yet.</p>
              ) : (
                <ol className="space-y-2">
                  {selectedOrders.map((o, idx) => (
                    <li key={o.id} className="flex items-center gap-2 text-sm">
                      <span className="text-xs tabular-nums text-text-secondary w-5 shrink-0">{idx + 1}</span>
                      <span className="flex-1 truncate">{o.customer.name}</span>
                      <span className="text-xs text-text-secondary font-mono">{o.order_number}</span>
                      <button
                        onClick={() => removeOrder(o.id)}
                        className="text-text-secondary hover:text-red-500"
                      >
                        <X className="h-3.5 w-3.5" />
                      </button>
                    </li>
                  ))}
                </ol>
              )}
            </CardContent>
          </Card>

          <Button
            className="w-full"
            disabled={saving || selectedOrders.length === 0}
            onClick={handleCreate}
          >
            {saving ? "Creating…" : "Create Trip"}
          </Button>
        </div>

        {/* Right — Order picker */}
        <div className="lg:col-span-2">
          <Card className="border border-border shadow-none">
            <CardContent className="py-4">
              <div className="flex items-center justify-between mb-3">
                <h3 className="font-semibold text-sm text-text-primary">
                  Approved Orders ({availableOrders.length})
                </h3>
                <Input
                  placeholder="Search…"
                  value={orderSearch}
                  onChange={(e) => setOrderSearch(e.target.value)}
                  className="w-48"
                />
              </div>

              {availableOrders.length === 0 ? (
                <p className="text-sm text-text-secondary py-8 text-center">No approved orders available.</p>
              ) : (
                <div className="divide-y divide-slate-100 max-h-[480px] overflow-y-auto">
                  {availableOrders.map((order) => (
                    <div
                      key={order.id}
                      className="flex items-center gap-3 py-3 px-1 hover:bg-background-subtle cursor-pointer"
                      onClick={() => toggleOrder(order)}
                    >
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium truncate">{order.customer.name}</p>
                        <p className="text-xs text-text-secondary font-mono">{order.order_number}</p>
                      </div>
                      <div className="text-right shrink-0">
                        <p className="text-sm font-semibold tabular-nums">
                          ₹{Number(order.total_amount).toLocaleString("en-IN", { maximumFractionDigits: 0 })}
                        </p>
                        {order.delivery_date && (
                          <p className="text-xs text-text-secondary">
                            {new Date(order.delivery_date).toLocaleDateString("en-IN")}
                          </p>
                        )}
                      </div>
                      <Plus className="h-4 w-4 text-accent shrink-0" />
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </AppShell>
  );
}
