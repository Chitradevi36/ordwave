"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter, useParams } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Modal } from "@/components/ui/modal";
import { API_URL } from "@/lib/api/client";
import { AccessDeniedError } from "@/components/errors/access-denied-error";

import {
  Truck, User, Package, CheckCircle,
  XCircle, Clock, ChevronRight, ClipboardCheck, AlertOctagon,
  BarChart2, AlertCircle, ChevronDown, IndianRupee,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { dispatchEvents } from "@/lib/analytics";

const EXCEPTION_CODES = [
  { value: "customer_not_available", label: "Customer Not Available" },
  { value: "address_not_found",      label: "Address Not Found" },
  { value: "refused_by_customer",    label: "Refused by Customer" },
  { value: "damaged_goods",          label: "Damaged Goods" },
  { value: "payment_not_ready",      label: "Payment Not Ready" },
  { value: "vehicle_breakdown",      label: "Vehicle Breakdown" },
  { value: "other",                  label: "Other" },
];

const REJECTION_REASON_CODES = [
  { value: "quality_issue",      label: "Quality Issue" },
  { value: "expired_product",    label: "Expired Product" },
  { value: "damaged_packaging",  label: "Damaged Packaging" },
  { value: "wrong_product",      label: "Wrong Product Delivered" },
  { value: "quantity_mismatch",  label: "Quantity Mismatch" },
  { value: "refused_by_customer", label: "Refused by Customer" },
  { value: "other",              label: "Other" },
];

const REJECTION_CONDITIONS = [
  { value: "unopened", label: "Unopened / Sealed" },
  { value: "opened",   label: "Opened" },
  { value: "damaged",  label: "Damaged" },
];

// ─── Types ───────────────────────────────────────────────────────────────────
interface TripDetail {
  id: number;
  trip_number: string;
  trip_date: string;
  status: string;
  notes: string | null;
  cancellation_reason: string | null;
  dispatched_at: string | null;
  completed_at: string | null;
  branch: { id: number; name: string };
  vehicle: { id: number; registration_number: string; vehicle_type: string } | null;
  driver: { id: number; name: string } | null;
  stops: StopSummary[];
}

interface StopSummary {
  id: number;
  sequence: number;
  status: string;
  exception_code: string | null;
  delivered_at: string | null;
  delivery_notes: string | null;
  delivered_value?: number | null;
  sales_order: {
    id: number;
    order_number: string;
    total_amount: number;
    customer: { id: number; name: string; address?: string };
  };
}

interface TripSummary {
  total_stops: number;
  delivered: number;
  partial: number;
  failed: number;
  skipped: number;
  total_order_value: number;
  delivered_value: number;
  returns_value: number;
  cash_collected: number;
  exceptions: { stop_id: number; customer_name: string; exception_code: string }[];
}

const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "success" | "danger" | "outline"> = {
  draft:            "secondary",
  planned:          "default",
  dispatched:       "warning",
  completed:        "success",
  cancelled:        "outline",
  pending:          "secondary",
  delivered:        "success",
  partial_delivery: "warning",
  failed:           "danger",
  skipped:          "outline",
};

const STOP_ICON: Record<string, React.ReactNode> = {
  pending:          <Clock className="h-4 w-4 text-text-secondary" />,
  delivered:        <CheckCircle className="h-4 w-4 text-green-500" />,
  partial_delivery: <Package className="h-4 w-4 text-amber-500" />,
  failed:           <XCircle className="h-4 w-4 text-red-500" />,
  skipped:          <ChevronRight className="h-4 w-4 text-text-secondary" />,
};

export default function TripDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router  = useRouter();
  const { token, orgId } = useOrgBranch();

  const [trip, setTrip]       = useState<TripDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState<{ status: number; message: string } | null>(null);

  const [tripSummary,        setTripSummary]        = useState<TripSummary | null>(null);
  const [summaryLoading,     setSummaryLoading]     = useState(false);
  const [showExceptions,     setShowExceptions]     = useState(false);
  const [completingTrip,     setCompletingTrip]     = useState(false);

  // Cancel modal
  const [showCancel, setShowCancel]     = useState(false);
  const [cancelReason, setCancelReason] = useState("");
  const [cancelLoading, setCancelLoading] = useState(false);
  const [actionError, setActionError]     = useState("");

  // Assign vehicle / driver modal
  const [showAssign, setShowAssign]         = useState(false);
  const [assignVehicleId, setAssignVehicleId] = useState("");
  const [assignDriverId, setAssignDriverId]   = useState("");
  const [assigning, setAssigning]             = useState(false);
  const [assignError, setAssignError]         = useState("");
  const [vehicles, setVehicles]               = useState<{ id: number; registration_number: string; vehicle_type: string }[]>([]);
  const [drivers, setDrivers]                 = useState<{ id: number; first_name: string; last_name: string }[]>([]);

  // Complete Stop modal
  const [completingStop, setCompletingStop] = useState<StopSummary | null>(null);
  const [stopOutcome, setStopOutcome]       = useState<"delivered" | "partial_delivery" | "failed">("delivered");
  const [stopProofType, setStopProofType]   = useState<"override" | "otp">("override");
  const [stopOverrideReason, setStopOverrideReason] = useState("");
  const [stopOtpCode, setStopOtpCode]       = useState("");
  const [stopExCode, setStopExCode]         = useState("");
  const [stopNotes, setStopNotes]           = useState("");
  const [stopLoading, setStopLoading]       = useState(false);
  const [stopError, setStopError]           = useState("");

  // Rejection modal
  const [rejectingStop, setRejectingStop]   = useState<StopSummary | null>(null);
  const [rejectProductId, setRejectProductId] = useState("");
  const [rejectOrderLines, setRejectOrderLines] = useState<{ product_id: number; product_name: string; product_sku: string }[]>([]);
  const [rejectReasonCode, setRejectReasonCode] = useState("");
  const [rejectCondition, setRejectCondition]   = useState("unopened");
  const [rejectQty, setRejectQty]               = useState("");
  const [rejectAutoReturn, setRejectAutoReturn] = useState(true);
  const [rejectNotes, setRejectNotes]           = useState("");
  const [rejectLoading, setRejectLoading]       = useState(false);
  const [rejectError, setRejectError]           = useState("");

  const authHeaders = {
    Authorization: `Bearer ${token}`,
    "X-Organization-Id": orgId,
    "Content-Type": "application/json",
  } as Record<string, string>;

  const fetchTrip = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const res  = await fetch(`${API_URL}/api/v1/delivery_trips/${id}`, { headers: authHeaders });
      const json = await res.json();
      if (!res.ok) {
        setError({
          status: res.status,
          message: json.errors?.[0] ?? "Failed to load delivery trip"
        });
        return;
      }
      setTrip(json.data);
      // Track dispatch view
      dispatchEvents.view(
        String(json.data.id),
        json.data.status,
        json.data.orders?.length ?? 0
      );
    } catch (e) {
      setError({
        status: 500,
        message: e instanceof Error ? e.message : "An error occurred"
      });
    } finally {
      setLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, orgId, id]);

  const fetchSummary = useCallback(async () => {
    if (!token || !orgId) return;
    setSummaryLoading(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/delivery_trips/${id}/summary`, { headers: authHeaders });
      const json = await res.json();
      if (res.ok) setTripSummary(json.data);
    } finally {
      setSummaryLoading(false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token, orgId, id]);

  useEffect(() => { void fetchTrip(); }, [fetchTrip]);

  // Fetch summary when trip is known to be dispatched or completed
  useEffect(() => {
    if (trip && ["dispatched", "completed"].includes(trip.status)) {
      void fetchSummary();
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [trip?.id, trip?.status]);

  async function handleDispatch() {
    setActionError("");
    const res  = await fetch(`${API_URL}/api/v1/delivery_trips/${id}/dispatch`, {
      method: "POST", headers: authHeaders,
    });
    const json = await res.json();
    if (res.ok) {
      // Track dispatch status update
      if (trip) {
        dispatchEvents.updateStatus(
          String(trip.id),
          trip.status,
          "dispatched"
        );
      }
      void fetchTrip();
    }
    else setActionError((json.errors ?? []).join(", "));
  }

  async function handleCompleteTrip() {
    setCompletingTrip(true);
    setActionError("");
    try {
      const res  = await fetch(`${API_URL}/api/v1/delivery_trips/${id}/complete`, {
        method: "POST", headers: authHeaders,
      });
      const json = await res.json();
      if (res.ok) {
        // Track dispatch completion
        if (trip && tripSummary) {
          const deliveryTime = trip.dispatched_at
            ? Math.floor((Date.now() - new Date(trip.dispatched_at).getTime()) / (1000 * 60 * 60))
            : 0;
          dispatchEvents.complete(
            String(trip.id),
            tripSummary.total_stops,
            tripSummary.total_order_value ?? 0,
            deliveryTime
          );
        }
        void fetchTrip();
      }
      else setActionError((json.errors ?? ["Complete failed"]).join(", "));
    } finally {
      setCompletingTrip(false);
    }
  }

  async function handleCancel() {
    if (!cancelReason.trim()) return;
    setCancelLoading(true);
    setActionError("");
    try {
      const res  = await fetch(`${API_URL}/api/v1/delivery_trips/${id}/cancel`, {
        method:  "POST",
        headers: authHeaders,
        body:    JSON.stringify({ delivery_trip: { cancellation_reason: cancelReason } }),
      });
      const json = await res.json();
      if (res.ok) {
        // Track dispatch failure/cancellation
        if (trip) {
          dispatchEvents.failed(
            String(trip.id),
            cancelReason,
            trip.stops?.length ?? 0
          );
        }
        setShowCancel(false);
        void fetchTrip();
      }
      else setActionError((json.errors ?? []).join(", "));
    } finally {
      setCancelLoading(false);
    }
  }

  function openAssign() {
    setAssignVehicleId(trip?.vehicle?.id?.toString() ?? "");
    setAssignDriverId(trip?.driver?.id?.toString() ?? "");
    setAssignError("");
    setShowAssign(true);
    // Lazy-load vehicles + drivers
    if (!vehicles.length) {
      fetch(`${API_URL}/api/v1/vehicles?status=active&per_page=100`, { headers: authHeaders })
        .then((r) => r.json())
        .then((d) => setVehicles(d.data ?? []));
    }
    if (!drivers.length) {
      fetch(`${API_URL}/api/v1/users?role=driver&per_page=100`, { headers: authHeaders })
        .then((r) => r.json())
        .then((d) => setDrivers(d.data ?? []));
    }
  }

  async function handleAssign() {
    setAssigning(true);
    setAssignError("");
    try {
      const body: Record<string, unknown> = {};
      if (assignVehicleId !== (trip?.vehicle?.id?.toString() ?? "")) {
        body.vehicle_id = assignVehicleId || "";
      }
      if (assignDriverId !== (trip?.driver?.id?.toString() ?? "")) {
        body.driver_id = assignDriverId || "";
      }
      const res = await fetch(`${API_URL}/api/v1/delivery_trips/${id}`, {
        method: "PATCH",
        headers: authHeaders,
        body: JSON.stringify({ delivery_trip: body }),
      });
      const json = await res.json();
      if (res.ok) {
        setShowAssign(false);
        void fetchTrip();
      } else {
        setAssignError((json.errors ?? ["Update failed"]).join(", "));
      }
    } finally {
      setAssigning(false);
    }
  }

  function openCompleteStop(stop: StopSummary) {
    setCompletingStop(stop);
    setStopOutcome("delivered");
    setStopProofType("override");
    setStopOverrideReason("");
    setStopOtpCode("");
    setStopExCode("");
    setStopNotes("");
    setStopError("");
  }

  function openRejectStop(stop: StopSummary) {
    setRejectingStop(stop);
    setRejectProductId("");
    setRejectOrderLines([]);
    setRejectReasonCode("");
    setRejectCondition("unopened");
    setRejectQty("");
    setRejectAutoReturn(true);
    setRejectNotes("");
    setRejectError("");
    // Fetch the order's lines so we can show a product dropdown
    if (stop.sales_order?.id && token && orgId) {
      fetch(`${API_URL}/api/v1/sales_orders/${stop.sales_order.id}`, { headers: authHeaders })
        .then((r) => r.json())
        .then((body) => {
          const lines: { product_id: number; product_name: string; product_sku: string }[] =
            (body.data?.lines ?? []).map((l: { product_id: number; product_name: string; product_sku: string }) => ({
              product_id:   l.product_id,
              product_name: l.product_name,
              product_sku:  l.product_sku,
            }));
          setRejectOrderLines(lines);
          if (lines.length === 1) setRejectProductId(String(lines[0].product_id));
        })
        .catch(() => { /* silently ignore — user can type product_id manually */ });
    }
  }

  async function handleCompleteStop() {
    if (!completingStop) return;
    if (stopProofType === "override" && !stopOverrideReason.trim()) {
      setStopError("Override reason is required.");
      return;
    }
    if (stopProofType === "otp" && !stopOtpCode.trim()) {
      setStopError("OTP code is required.");
      return;
    }
    if (stopOutcome === "failed" && !stopExCode) {
      setStopError("Exception code is required when outcome is Failed.");
      return;
    }
    setStopLoading(true);
    setStopError("");
    try {
      const body: Record<string, unknown> = {
        outcome:        stopOutcome,
        proof_type:     stopProofType,
        delivery_notes: stopNotes || undefined,
        exception_code: stopOutcome === "failed" ? stopExCode : undefined,
      };
      if (stopProofType === "override") body.override_reason = stopOverrideReason;
      if (stopProofType === "otp")      body.otp_code        = stopOtpCode;

      const res  = await fetch(
        `${API_URL}/api/v1/delivery_trips/${id}/trip_stops/${completingStop.id}/complete`,
        { method: "POST", headers: authHeaders, body: JSON.stringify(body) }
      );
      const json = await res.json();
      if (res.ok) {
        setCompletingStop(null);
        void fetchTrip();
      } else {
        setStopError((json.errors ?? ["Unknown error"]).join(", "));
      }
    } finally {
      setStopLoading(false);
    }
  }

  async function handleRecordRejection() {
    if (!rejectingStop || !rejectReasonCode || !rejectQty || !rejectProductId) {
      setRejectError("Product, reason code and quantity are required.");
      return;
    }
    setRejectLoading(true);
    setRejectError("");
    try {
      const res = await fetch(
        `${API_URL}/api/v1/delivery_trips/${id}/trip_stops/${rejectingStop.id}/rejections`,
        {
          method:  "POST",
          headers: authHeaders,
          body: JSON.stringify({
            rejection: {
              product_id:   rejectProductId ? Number(rejectProductId) : undefined,
              reason_code:  rejectReasonCode,
              condition:    rejectCondition,
              qty_rejected: Number(rejectQty),
              auto_return:  rejectAutoReturn,
              notes:        rejectNotes || undefined,
            },
          }),
        }
      );
      const json = await res.json();
      if (res.ok) {
        setRejectingStop(null);
        void fetchTrip();
      } else {
        setRejectError((json.errors ?? ["Unknown error"]).join(", "));
      }
    } finally {
      setRejectLoading(false);
    }
  }

  if (loading) return (
    <AppShell>
      <div className="text-center py-20 text-text-secondary">Loading trip…</div>
    </AppShell>
  );

  if (error) {
    return <AccessDeniedError
      status={error.status}
      message={error.message}
      backLink="/delivery"
      resourceType="Delivery Trip"
    />;
  }

  if (!trip) return (
    <AppShell>
      <div className="text-center py-20 text-text-secondary">Trip not found.</div>
    </AppShell>
  );

  const completedCount = trip.stops.filter((s) =>
    ["delivered", "partial_delivery", "failed", "skipped"].includes(s.status)
  ).length;

  const allResolved = trip.stops.length > 0 && trip.stops.every(
    (s) => ["delivered", "partial_delivery", "failed", "skipped"].includes(s.status)
  );

  const exceptionStops = trip.stops.filter((s) => s.exception_code);

  function fmtRupees(n: number) {
    return `₹${n.toLocaleString("en-IN", { minimumFractionDigits: 0, maximumFractionDigits: 2 })}`;
  }

  return (
    <AppShell breadcrumbs={[
      { label: "Operations",     href: "/operations" },
      { label: "Delivery Trips", href: "/delivery" },
      { label: trip.trip_number },
    ]}>
      <PageHeader
        title={trip.trip_number}
        subtitle={`Trip date: ${new Date(trip.trip_date).toLocaleDateString("en-IN")}`}
        actions={[
          ...([ "draft", "planned", "dispatched"].includes(trip.status)
            ? [{ label: "Assign Vehicle / Driver", onClick: openAssign, variant: "outline" as const }]
            : []),
          ...(["draft", "planned"].includes(trip.status)
            ? [{ label: "Dispatch", onClick: handleDispatch }]
            : []),          ...(trip.status === "dispatched" && allResolved
            ? [{ label: completingTrip ? "Completing…" : "Complete Trip", onClick: handleCompleteTrip }]
            : []),          ...(["draft", "planned", "dispatched"].includes(trip.status)
            ? [{ label: "Cancel Trip", onClick: () => { setShowCancel(true); setCancelReason(""); }, variant: "outline" as const }]
            : []),
        ]}
      />

      {actionError && (
        <div className="mb-4 rounded-md bg-red-50 border border-red-200 p-3 text-sm text-red-700">
          {actionError}
        </div>
      )}

      {trip.status === "cancelled" && trip.cancellation_reason && (
        <div className="mb-4 rounded-md bg-amber-50 border border-amber-200 p-3 text-sm text-amber-700 flex items-center gap-2">
          <XCircle className="h-4 w-4 flex-shrink-0" />
          <span><span className="font-medium">Cancelled: </span>{trip.cancellation_reason}</span>
        </div>
      )}

      {/* Trip meta */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <Card className="border border-border shadow-none">
          <CardContent className="py-3 px-4">
            <p className="text-xs text-text-secondary mb-0.5">Status</p>
            <Badge variant={STATUS_VARIANT[trip.status] ?? "secondary"}>
              {trip.status.replace("_", " ")}
            </Badge>
          </CardContent>
        </Card>
        <Card className="border border-border shadow-none">
          <CardContent className="py-3 px-4">
            <p className="text-xs text-text-secondary mb-0.5">Branch</p>
            <p className="text-sm font-medium">{trip.branch.name}</p>
          </CardContent>
        </Card>
        <Card className="border border-border shadow-none">
          <CardContent className="py-3 px-4 flex items-center gap-2">
            <Truck className="h-4 w-4 text-text-secondary" />
            <div>
              <p className="text-xs text-text-secondary mb-0.5">Vehicle</p>
              <p className="text-sm font-medium">
                {trip.vehicle?.registration_number ?? <span className="text-text-secondary">—</span>}
              </p>
            </div>
          </CardContent>
        </Card>
        <Card className="border border-border shadow-none">
          <CardContent className="py-3 px-4 flex items-center gap-2">
            <User className="h-4 w-4 text-text-secondary" />
            <div>
              <p className="text-xs text-text-secondary mb-0.5">Driver</p>
              <p className="text-sm font-medium">
                {trip.driver?.name ?? <span className="text-text-secondary">—</span>}
              </p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Progress bar + status breakdown */}
      <div className="mb-6">
        <div className="flex items-center justify-between text-xs text-text-secondary mb-1">
          <span>{completedCount} of {trip.stops.length} stops done</span>
          <span>{trip.stops.length > 0 ? Math.round((completedCount / trip.stops.length) * 100) : 0}%</span>
        </div>
        {/* Segmented progress bar */}
        <div className="h-3 rounded-full overflow-hidden flex bg-background-subtle">
          {trip.stops.length > 0 && (
            <>
              {(() => {
                const d  = trip.stops.filter((s) => s.status === "delivered").length;
                const p  = trip.stops.filter((s) => s.status === "partial_delivery").length;
                const f  = trip.stops.filter((s) => s.status === "failed").length;
                const sk = trip.stops.filter((s) => s.status === "skipped").length;
                const total = trip.stops.length;
                return (
                  <>
                    {d  > 0 && <div className="h-full bg-green-500  transition-all" style={{ width: `${(d  / total) * 100}%` }} title={`${d} delivered`}  />}
                    {p  > 0 && <div className="h-full bg-amber-500  transition-all" style={{ width: `${(p  / total) * 100}%` }} title={`${p} partial`}    />}
                    {f  > 0 && <div className="h-full bg-red-500    transition-all" style={{ width: `${(f  / total) * 100}%` }} title={`${f} failed`}     />}
                    {sk > 0 && <div className="h-full bg-gray-400   transition-all" style={{ width: `${(sk / total) * 100}%` }} title={`${sk} skipped`}   />}
                  </>
                );
              })()}
            </>
          )}
        </div>
        <div className="flex gap-4 mt-1.5">
          {[
            { key: "delivered",        label: "Delivered",       color: "bg-green-500" },
            { key: "partial_delivery", label: "Partial",         color: "bg-amber-500" },
            { key: "failed",           label: "Failed",          color: "bg-red-500" },
            { key: "skipped",          label: "Skipped",         color: "bg-gray-400" },
            { key: "pending",          label: "Pending",         color: "bg-background-subtle border border-border" },
          ].map(({ key, label, color }) => {
            const cnt = trip.stops.filter((s) => s.status === key).length;
            if (!cnt) return null;
            return (
              <span key={key} className="flex items-center gap-1 text-xs text-text-secondary">
                <span className={`inline-block h-2 w-2 rounded-full ${color}`} />
                {cnt} {label}
              </span>
            );
          })}
        </div>
      </div>

      {/* Stops */}
      <div className="space-y-3">
        <h3 className="text-sm font-semibold text-text-primary">Delivery Stops</h3>
        {trip.stops.length === 0 ? (
          <p className="text-sm text-text-secondary">No stops on this trip.</p>
        ) : (
          trip.stops.map((stop) => (
            <Card key={stop.id} className="border border-border shadow-none">
              <CardContent className="py-3 px-4">
                <div className="flex items-start gap-3">
                  <div className="flex-shrink-0 w-7 h-7 rounded-full bg-background-subtle flex items-center justify-center text-xs font-bold text-text-secondary">
                    {stop.sequence}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <p className="text-sm font-medium">
                        {stop.sales_order.customer.name}
                      </p>
                      <Badge variant={STATUS_VARIANT[stop.status] ?? "secondary"} className="text-xs">
                        {stop.status.replace("_", " ")}
                      </Badge>
                      {stop.exception_code && (
                        <Badge variant="danger" className="text-xs">
                          {stop.exception_code.replace(/_/g, " ")}
                        </Badge>
                      )}
                    </div>
                    <div className="flex gap-4 mt-0.5 text-xs text-text-secondary">
                      <span className="font-mono">{stop.sales_order.order_number}</span>
                      <span>
                        ₹{Number(stop.sales_order.total_amount).toLocaleString("en-IN", { maximumFractionDigits: 0 })}
                      </span>
                      {stop.delivered_at && (
                        <span>Delivered {new Date(stop.delivered_at).toLocaleTimeString("en-IN", { timeStyle: "short" })}</span>
                      )}
                    </div>
                    {stop.delivery_notes && (
                      <p className="text-xs text-text-secondary mt-1 italic">{stop.delivery_notes}</p>
                    )}
                  </div>
                  <div className="shrink-0 flex items-center gap-1">
                    {STOP_ICON[stop.status]}
                    {trip.status === "dispatched" && stop.status === "pending" && (
                      <>
                        <Button
                          size="sm"
                          variant="outline"
                          className="ml-2 text-xs h-7 px-2"
                          onClick={() => openCompleteStop(stop)}
                        >
                          <ClipboardCheck className="h-3 w-3 mr-1" />
                          Complete
                        </Button>
                        <Button
                          size="sm"
                          variant="outline"
                          className="text-xs h-7 px-2 text-destructive border-destructive/40 hover:bg-destructive/10"
                          onClick={() => openRejectStop(stop)}
                        >
                          <AlertOctagon className="h-3 w-3 mr-1" />
                          Reject
                        </Button>
                      </>
                    )}
                    {trip.status === "dispatched" && stop.status === "partial_delivery" && (
                      <Button
                        size="sm"
                        variant="outline"
                        className="ml-2 text-xs h-7 px-2 text-destructive border-destructive/40 hover:bg-destructive/10"
                        onClick={() => openRejectStop(stop)}
                      >
                        <AlertOctagon className="h-3 w-3 mr-1" />
                        Record Rejection
                      </Button>
                    )}
                  </div>
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>

      {trip.notes && (
        <div className="mt-6 rounded-md bg-background-subtle border border-border p-3 text-sm text-text-secondary">
          <span className="font-medium">Notes: </span>{trip.notes}
        </div>
      )}

      {/* Exception Panel */}
      {exceptionStops.length > 0 && (
        <div className="mt-6">
          <button
            onClick={() => setShowExceptions((v) => !v)}
            className="w-full flex items-center justify-between px-4 py-3 rounded-lg border border-red-200 bg-red-50 text-sm font-medium text-red-700 hover:bg-red-100 transition-colors"
          >
            <span className="flex items-center gap-2">
              <AlertCircle className="h-4 w-4" />
              {exceptionStops.length} stop{exceptionStops.length > 1 ? "s" : ""} with exceptions
            </span>
            <ChevronDown className={`h-4 w-4 transition-transform ${showExceptions ? "rotate-180" : ""}`} />
          </button>
          {showExceptions && (
            <div className="mt-2 rounded-lg border border-red-200 bg-white divide-y">
              {exceptionStops.map((s) => (
                <div key={s.id} className="px-4 py-3 flex items-center justify-between">
                  <div>
                    <span className="text-sm font-medium">Stop #{s.sequence} — {s.sales_order.customer.name}</span>
                    <p className="text-xs text-text-secondary font-mono">{s.sales_order.order_number}</p>
                  </div>
                  <Badge variant="danger" className="text-xs">{s.exception_code?.replace(/_/g, " ")}</Badge>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Trip Summary */}
      {(trip.status === "dispatched" || trip.status === "completed") && (
        <div className="mt-6">
          <h3 className="text-sm font-semibold text-text-primary mb-3 flex items-center gap-2">
            <BarChart2 className="h-4 w-4" />
            Trip Summary
          </h3>
          {summaryLoading ? (
            <p className="text-xs text-text-secondary">Loading summary…</p>
          ) : tripSummary ? (
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
              {[
                { label: "Total Value",      value: fmtRupees(tripSummary.total_order_value), icon: IndianRupee, color: "text-text-primary" },
                { label: "Delivered Value",  value: fmtRupees(tripSummary.delivered_value),   icon: CheckCircle, color: "text-green-600"   },
                { label: "Returns Value",    value: fmtRupees(tripSummary.returns_value),     icon: Package,     color: "text-amber-600"   },
                { label: "Cash Collected",   value: fmtRupees(tripSummary.cash_collected),    icon: IndianRupee, color: "text-violet-600"  },
              ].map(({ label, value, icon: Icon, color }) => (
                <Card key={label} className="border border-border shadow-none">
                  <CardContent className="p-3">
                    <div className={`flex items-center gap-1.5 mb-1 ${color}`}>
                      <Icon className="h-3.5 w-3.5" />
                      <span className="text-xs font-medium">{label}</span>
                    </div>
                    <p className="text-sm font-semibold text-text-primary">{value}</p>
                  </CardContent>
                </Card>
              ))}
            </div>
          ) : null}
        </div>
      )}

      {/* Assign Vehicle / Driver modal */}
      <Modal open={showAssign} onClose={() => setShowAssign(false)} title="Assign Vehicle &amp; Driver">
        <div className="space-y-4">
          <div>
            <label className="text-sm font-medium text-text-primary block mb-1">Vehicle</label>
            <select
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
              value={assignVehicleId}
              onChange={(e) => setAssignVehicleId(e.target.value)}
            >
              <option value="">— Unassign —</option>
              {vehicles.map((v) => (
                <option key={v.id} value={v.id}>
                  {v.registration_number} ({v.vehicle_type})
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-sm font-medium text-text-primary block mb-1">Driver</label>
            <select
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
              value={assignDriverId}
              onChange={(e) => setAssignDriverId(e.target.value)}
            >
              <option value="">— Unassign —</option>
              {drivers.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.first_name} {d.last_name}
                </option>
              ))}
            </select>
          </div>
          {assignError && <p className="text-sm text-red-600">{assignError}</p>}
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setShowAssign(false)}>Cancel</Button>
            <Button onClick={handleAssign} disabled={assigning}>
              {assigning ? "Saving…" : "Save Assignment"}
            </Button>
          </div>
        </div>
      </Modal>

      {/* Complete Stop modal */}
      <Modal
        open={!!completingStop}
        onClose={() => setCompletingStop(null)}
        title={`Complete Stop #${completingStop?.sequence ?? ""}`}
      >
        {completingStop && (
          <div className="space-y-4">
            <p className="text-sm text-text-secondary">
              <span className="font-medium">{completingStop.sales_order.customer.name}</span>
              {" · "}<span className="font-mono text-xs">{completingStop.sales_order.order_number}</span>
            </p>

            {/* Outcome */}
            <div>
              <label className="text-sm font-medium text-text-primary block mb-1">Outcome *</label>
              <div className="flex gap-2 flex-wrap">
                {(["delivered", "partial_delivery", "failed"] as const).map((o) => (
                  <button
                    key={o}
                    type="button"
                    onClick={() => { setStopOutcome(o); if (o !== "failed") setStopExCode(""); }}
                    className={`px-3 py-1.5 rounded-md text-sm border transition-colors ${
                      stopOutcome === o
                        ? o === "failed"
                          ? "bg-red-600 text-white border-red-600"
                          : o === "partial_delivery"
                          ? "bg-amber-500 text-white border-amber-500"
                          : "bg-green-600 text-white border-green-600"
                        : "bg-white text-text-primary border-border hover:bg-background-subtle"
                    }`}
                  >
                    {o === "partial_delivery" ? "Partial" : o.charAt(0).toUpperCase() + o.slice(1)}
                  </button>
                ))}
              </div>
            </div>

            {/* Exception code — required when failed */}
            {stopOutcome === "failed" && (
              <div>
                <label className="text-sm font-medium text-text-primary block mb-1">Exception Code *</label>
                <select
                  className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                  value={stopExCode}
                  onChange={(e) => setStopExCode(e.target.value)}
                >
                  <option value="">Select reason…</option>
                  {EXCEPTION_CODES.map((ec) => (
                    <option key={ec.value} value={ec.value}>{ec.label}</option>
                  ))}
                </select>
              </div>
            )}

            {/* Proof type */}
            <div>
              <label className="text-sm font-medium text-text-primary block mb-1">Proof Type *</label>
              <div className="flex gap-2">
                {(["override", "otp"] as const).map((pt) => (
                  <button
                    key={pt}
                    type="button"
                    onClick={() => { setStopProofType(pt); setStopOverrideReason(""); setStopOtpCode(""); }}
                    className={`px-3 py-1.5 rounded-md text-sm border transition-colors ${
                      stopProofType === pt
                        ? "bg-accent text-white border-accent"
                        : "bg-white text-text-primary border-border hover:bg-background-subtle"
                    }`}
                  >
                    {pt === "override" ? "Manager Override" : "OTP"}
                  </button>
                ))}
              </div>
            </div>

            {/* Override reason */}
            {stopProofType === "override" && (
              <div>
                <label className="text-sm font-medium text-text-primary block mb-1">Override Reason *</label>
                <input
                  type="text"
                  className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                  placeholder="e.g. Confirmed by phone call"
                  value={stopOverrideReason}
                  onChange={(e) => setStopOverrideReason(e.target.value)}
                />
              </div>
            )}

            {/* OTP code */}
            {stopProofType === "otp" && (
              <div>
                <label className="text-sm font-medium text-text-primary block mb-1">OTP Code *</label>
                <input
                  type="text"
                  maxLength={6}
                  className="w-full rounded-md border border-border px-3 py-2 text-sm font-mono tracking-widest focus:outline-none focus:ring-2 focus:ring-accent"
                  placeholder="123456"
                  value={stopOtpCode}
                  onChange={(e) => setStopOtpCode(e.target.value.replace(/\D/g, ""))}
                />
              </div>
            )}

            {/* Delivery notes */}
            <div>
              <label className="text-sm font-medium text-text-primary block mb-1">Delivery Notes</label>
              <textarea
                className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                rows={2}
                placeholder="Optional notes…"
                value={stopNotes}
                onChange={(e) => setStopNotes(e.target.value)}
              />
            </div>

            {stopError && <p className="text-sm text-red-600">{stopError}</p>}

            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => setCompletingStop(null)}>Cancel</Button>
              <Button onClick={handleCompleteStop} disabled={stopLoading}>
                {stopLoading ? "Saving…" : "Mark Complete"}
              </Button>
            </div>
          </div>
        )}
      </Modal>

      {/* Rejection Modal */}
      <Modal
        open={!!rejectingStop}
        onClose={() => setRejectingStop(null)}
        title={`Record Rejection — Stop #${rejectingStop?.sequence ?? ""}`}
      >
        {rejectingStop && (
          <div className="space-y-4">
            <p className="text-sm text-text-secondary">
              Customer: <span className="font-medium">{rejectingStop.sales_order.customer.name}</span>
              {" · "}<span className="font-mono text-xs">{rejectingStop.sales_order.order_number}</span>
            </p>

            {/* Product */}
            <div className="space-y-1.5">
              <label className="text-sm font-medium">Product *</label>
              {rejectOrderLines.length > 0 ? (
                <select
                  className="w-full h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                  value={rejectProductId}
                  onChange={(e) => setRejectProductId(e.target.value)}
                >
                  <option value="">— Select product —</option>
                  {rejectOrderLines.map((l) => (
                    <option key={l.product_id} value={l.product_id}>
                      {l.product_name} ({l.product_sku})
                    </option>
                  ))}
                </select>
              ) : (
                <input
                  type="number"
                  placeholder="Product ID"
                  className="w-full h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                  value={rejectProductId}
                  onChange={(e) => setRejectProductId(e.target.value)}
                />
              )}
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-1.5">
                <label className="text-sm font-medium">Reason Code *</label>
                <select
                  className="w-full h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                  value={rejectReasonCode}
                  onChange={(e) => setRejectReasonCode(e.target.value)}
                >
                  <option value="">— Select reason —</option>
                  {REJECTION_REASON_CODES.map((r) => (
                    <option key={r.value} value={r.value}>{r.label}</option>
                  ))}
                </select>
              </div>
              <div className="space-y-1.5">
                <label className="text-sm font-medium">Condition</label>
                <select
                  className="w-full h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                  value={rejectCondition}
                  onChange={(e) => setRejectCondition(e.target.value)}
                >
                  {REJECTION_CONDITIONS.map((c) => (
                    <option key={c.value} value={c.value}>{c.label}</option>
                  ))}
                </select>
              </div>
              <div className="space-y-1.5">
                <label className="text-sm font-medium">Qty Rejected *</label>
                <input
                  type="number"
                  min={1}
                  placeholder="e.g. 5"
                  className="w-full h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                  value={rejectQty}
                  onChange={(e) => setRejectQty(e.target.value)}
                />
              </div>
              <div className="space-y-1.5 flex flex-col justify-center">
                <label className="text-sm font-medium">Auto-create Return</label>
                <label className="flex items-center gap-2 text-sm cursor-pointer">
                  <input
                    type="checkbox"
                    className="h-4 w-4 rounded border-border"
                    checked={rejectAutoReturn}
                    onChange={(e) => setRejectAutoReturn(e.target.checked)}
                  />
                  Automatically create a return order
                </label>
              </div>
              <div className="col-span-2 space-y-1.5">
                <label className="text-sm font-medium">Notes</label>
                <textarea
                  rows={2}
                  placeholder="Optional details…"
                  className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
                  value={rejectNotes}
                  onChange={(e) => setRejectNotes(e.target.value)}
                />
              </div>
            </div>
            {rejectError && <p className="text-sm text-red-600">{rejectError}</p>}
            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => setRejectingStop(null)}>Cancel</Button>
              <Button variant="danger" onClick={handleRecordRejection} disabled={rejectLoading || !rejectProductId || !rejectQty || !rejectReasonCode}>
                {rejectLoading ? "Saving…" : "Record Rejection"}
              </Button>
            </div>
          </div>
        )}
      </Modal>

      {/* Cancel modal */}
      <Modal open={showCancel} onClose={() => setShowCancel(false)} title="Cancel Trip">
        <div className="space-y-4">
          <p className="text-sm text-text-secondary">
            Cancel <span className="font-semibold">{trip.trip_number}</span>? Dispatched orders will revert to Approved.
          </p>
          <div>
            <label className="text-sm font-medium text-text-primary block mb-1">Reason *</label>
            <textarea
              className="w-full rounded-md border border-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-accent"
              rows={3}
              placeholder="e.g. Vehicle breakdown"
              value={cancelReason}
              onChange={(e) => setCancelReason(e.target.value)}
            />
          </div>
          {actionError && <p className="text-sm text-red-600">{actionError}</p>}
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setShowCancel(false)}>Back</Button>
            <Button
              variant="danger"
              disabled={!cancelReason.trim() || cancelLoading}
              onClick={handleCancel}
            >
              {cancelLoading ? "Cancelling…" : "Cancel Trip"}
            </Button>
          </div>
        </div>
      </Modal>
    </AppShell>
  );
}
