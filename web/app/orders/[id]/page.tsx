"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell } from "@/components/layout";

import { Button } from "@/components/ui/button";
import { Tabs } from "@/components/ui/tabs";
import { Modal } from "@/components/ui/modal";
import { CheckCircle2, XCircle } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { CreditDecisionModal, CreditResult } from "@/components/ui/credit-decision-modal";
import { API_URL } from "@/lib/api/client";
import { LifecycleTab } from "@/components/orders/lifecycle-tab";
import { OrderHero } from "@/components/orders/order-hero";
import { OrderLifecycle } from "@/components/orders/order-lifecycle";
import { NextActionBanner } from "@/components/orders/next-action-banner";
import { OperationalSnapshot, CommercialContext, AmountBreakdown } from "@/components/orders/order-overview-cards";
import { OrderLinesTable } from "@/components/orders/order-lines-table";
import { FulfillmentPanel } from "@/components/orders/order-fulfillment-panel";
import { CreditFinancePanel } from "@/components/orders/order-finance-panel";
import { DocumentsPanel } from "@/components/orders/order-documents-panel";

// ─── Types ────────────────────────────────────────────────────────────────────
interface OrderLine {
  id: number;
  product_id: number;
  product_name: string;
  product_sku: string;
  qty: number;
  unit_price: number;
  discount_pct: number;
  gst_rate: number;
  line_total: number;
  price_source: string;
  scheme_discount_pct?: number;
  scheme_tags?: { scheme_id: number; scheme_code: string; scheme_name: string; reward_type: string }[];
  hsn_code: string | null;
}

interface AuditEntry {
  id: number;
  action: string;
  changes: Record<string, unknown>;
  reason: string | null;
  actor_name: string | null;
  created_at: string;
}

interface FreebieSnap {
  product_id: number;
  product_name: string;
  qty: number;
  unit: string;
}

interface SchemeSnap {
  scheme_id: number;
  scheme_name: string;
  scheme_type: string;
  discount_pct: number;
  freebies: FreebieSnap[];
}

interface TripInfo {
  id: number;
  trip_number: string;
  driver_name?: string;
  vehicle_number?: string;
  dispatch_time?: string;
  delivered_time?: string;
  pod_url?: string;
}

interface InvoiceInfo {
  id: number;
  invoice_number: string;
  created_at: string;
  total_amount: number;
  url?: string;
}

interface PaymentInfo {
  id: number;
  amount: number;
  created_at: string;
}

interface OrderDetail {
  id: number;
  order_number: string;
  status: string;
  credit_decision: string | null;
  credit_reasons: string[];
  credit_snapshot: Record<string, unknown>;
  delivery_date: string | null;
  notes: string | null;
  total_amount: number;
  discount_amount: number;
  submitted_at: string | null;
  approved_at: string | null;
  cancelled_at: string | null;
  cancellation_reason: string | null;
  pick_status: "pending_pick" | "picked" | "pick_confirmed";
  picked_by_id: number | null;
  picked_at: string | null;
  pick_confirmed_by_id: number | null;
  pick_confirmed_at: string | null;
  created_at: string;
  updated_at: string;
  customer: { id: number; name: string; code: string };
  branch: { id: number; name: string };
  created_by: { id: number; name: string };
  lines: OrderLine[];
  timeline: AuditEntry[];
  scheme_snapshot?: SchemeSnap[];
}

// ─── Utilities ────────────────────────────────────────────────────────────────

function fmtINR(n: number | string) {
  return `₹${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function fmtDate(d: string | null | undefined) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

function fmtDateTime(d: string | null | undefined) {
  if (!d) return "—";
  return new Date(d).toLocaleString("en-IN", {
    day: "2-digit", month: "short", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function OrderDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const { token, orgId } = useOrgBranch();
  const role = useCurrentRole();

  const [order, setOrder]     = useState<OrderDetail | null>(null);
  const [trip, setTrip]       = useState<TripInfo | null>(null);
  const [invoice, setInvoice] = useState<InvoiceInfo | null>(null);
  const [payment, setPayment] = useState<PaymentInfo | null>(null);
  const [loading, setLoading] = useState(true);

  // Modals
  const [approveModal, setApproveModal] = useState(false);
  const [cancelModal,  setCancelModal]  = useState(false);
  const [holdModal,    setHoldModal]    = useState(false);
  const [decision,     setDecision]     = useState<"approved" | "rejected">("approved");
  const [decisionReason, setDecisionReason] = useState("");
  const [cancelReason, setCancelReason] = useState("");
  const [holdReason,   setHoldReason]   = useState("");
  const [acting, setActing] = useState(false);

  // Credit decision modal
  const [creditModal,  setCreditModal]  = useState(false);
  const [creditResult, setCreditResult] = useState<CreditResult | null>(null);

  // Limited edit (delivery_date + notes for submitted/on_hold by manager)
  const [editModal,  setEditModal]  = useState(false);
  const [editDate,   setEditDate]   = useState("");
  const [editNotes,  setEditNotes]  = useState("");

  const [toast, setToast] = useState<{ type: "success" | "error"; msg: string } | null>(null);

  const handlePick         = () => postAction("pick",         {});
  const handleConfirmPick  = () => postAction("confirm_pick", {});

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  const fetch_ = useCallback(async () => {
    if (!token || !orgId || !params.id) return;
    setLoading(true);
    try {
      const headers = {
        Authorization: `Bearer ${token}`,
        "X-Organization-Id": orgId,
      };

      // Fetch order data
      const orderRes = await fetch(`${API_URL}/api/v1/sales_orders/${params.id}`, { headers });
      const orderJson = await orderRes.json();
      
      if (!orderRes.ok) {
        showToast("error", orderJson.errors?.[0] ?? "Failed to load order");
        return;
      }

      const orderData = orderJson.data as OrderDetail;
      setOrder(orderData);

      // Fetch related data in parallel (trip, invoice, payment)
      // These may fail gracefully if not available
      const [tripRes, invoiceRes] = await Promise.all([
        // Try to fetch trip if order is approved or later
        orderData.status !== "draft" && orderData.status !== "submitted" && orderData.status !== "on_hold" && orderData.status !== "rejected"
          ? fetch(`${API_URL}/api/v1/delivery_trips?order_id=${params.id}`, { headers })
          : Promise.resolve(null),
        // Try to fetch invoice if order is delivered or invoiced
        orderData.status === "delivered" || orderData.status === "invoiced" || orderData.status === "paid"
          ? fetch(`${API_URL}/api/v1/sales_invoices?order_id=${params.id}`, { headers })
          : Promise.resolve(null),
      ]);

      if (tripRes) {
        const tripJson = await tripRes.json();
        if (tripRes.ok && tripJson.data && Array.isArray(tripJson.data) && tripJson.data.length > 0) {
          setTrip(tripJson.data[0]);
        }
      }

      if (invoiceRes) {
        const invoiceJson = await invoiceRes.json();
        if (invoiceRes.ok && invoiceJson.data && Array.isArray(invoiceJson.data) && invoiceJson.data.length > 0) {
          const inv = invoiceJson.data[0];
          setInvoice(inv);
          
          // If invoice exists, try to fetch payment
          const paymentRes = await fetch(`${API_URL}/api/v1/payments?invoice_id=${inv.id}`, { headers });
          const paymentJson = await paymentRes.json();
          if (paymentRes.ok && paymentJson.data && Array.isArray(paymentJson.data) && paymentJson.data.length > 0) {
            setPayment(paymentJson.data[0]);
          }
        }
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, params.id]);

  useEffect(() => { void fetch_(); }, [fetch_]);

  const postAction = async (path: string, body: Record<string, unknown>): Promise<boolean> => {
    setActing(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/sales_orders/${params.id}/${path}`, {
        method:  "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });
      const json = await res.json();
      if (res.ok) {
        setOrder(json.data);
        showToast("success", "Done");
        // Refresh related data after action
        setTimeout(() => fetch_(), 300);
        return true;
      } else {
        showToast("error", json.errors?.[0] ?? "Action failed");
        return false;
      }
    } finally {
      setActing(false);
    }
  };

  const handleSubmit = async () => {
    setActing(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/sales_orders/${params.id}/submit`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({}),
      });
      const json = await res.json();

      if (res.ok && json.data) {
        // OK or HOLD — update order, show credit modal
        setOrder(json.data);
        setCreditResult(json.credit ?? null);
        setCreditModal(true);
      } else if (!res.ok && json.code === "credit_blocked") {
        // BLOCKED — order stays draft, refresh to capture credit_snapshot
        await fetch_();
        setCreditResult(json.credit ?? null);
        setCreditModal(true);
      } else {
        showToast("error", json.errors?.[0] ?? "Submit failed");
      }
    } finally {
      setActing(false);
    }
  };
  const handleRefreshPrice = () => postAction("refresh_price", {});

  const handleGenerateInvoice = async () => {
    setActing(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/sales_invoices/generate_from_order`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({ order_id: params.id }),
      });
      const json = await res.json();
      if (res.ok) {
        showToast("success", `Invoice ${json.data?.invoice_number ?? ""} generated`);
        // Refresh invoice data after generation
        await fetch_();
      } else {
        showToast("error", json.errors?.[0] ?? "Invoice generation failed");
      }
    } finally {
      setActing(false);
    }
  };

  const openLimitedEdit = () => {
    if (!order) return;
    setEditDate(order.delivery_date ?? "");
    setEditNotes(order.notes ?? "");
    setEditModal(true);
  };

  const handleLimitedEditSubmit = async () => {
    setActing(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/sales_orders/${params.id}`, {
        method:  "PATCH",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({ order: { delivery_date: editDate || null, notes: editNotes || null } }),
      });
      const json = await res.json();
      if (res.ok) {
        setOrder(json.data);
        setEditModal(false);
        showToast("success", "Order updated");
      } else {
        showToast("error", json.errors?.[0] ?? "Update failed");
      }
    } finally {
      setActing(false);
    }
  };

  const handleApproveSubmit = async () => {
    setActing(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/sales_orders/${params.id}/approve`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({ decision, reason: decisionReason }),
      });
      const json = await res.json();
      if (res.ok) {
        setOrder(json.data);
        setApproveModal(false);
        setDecisionReason("");
        setDecision("approved");
        
        // Refresh data to capture trip if auto-created
        if (decision === "approved") {
          setTimeout(() => fetch_(), 500);
          
          const at = json.data?.auto_trip;
          if (at?.ok && at.action === "new_trip_created") {
            showToast("success", `Order approved · Trip ${at.trip_number} created`);
          } else if (at?.ok && at.action === "added_to_existing") {
            showToast("success", `Order approved · Added to trip ${at.trip_number}`);
          } else {
            showToast("success", "Order approved");
          }
        } else {
          showToast("success", "Order rejected");
        }
      } else {
        showToast("error", json.errors?.[0] ?? "Action failed");
      }
    } finally {
      setActing(false);
    }
  };
  const handleCancelSubmit = async () => {
    const ok = await postAction("cancel", { reason: cancelReason });
    if (ok) { setCancelModal(false); setCancelReason(""); }
  };
  const handleHoldSubmit = async () => {
    const ok = await postAction("hold", { reason: holdReason });
    if (ok) { setHoldModal(false); setHoldReason(""); }
  };

  if (loading) {
    return (
      <AppShell>
        <div className="flex items-center justify-center py-24 text-text-secondary text-sm">
          Loading…
        </div>
      </AppShell>
    );
  }

  if (!order) return null;

  const tabItems = [
    {
      value: "overview",
      label: "Overview",
      content: (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-2 sm:gap-4">
          <OperationalSnapshot
            orderedAt={order.created_at}
            expectedDelivery={order.delivery_date}
            dispatchTrip={trip?.trip_number}
            sourceChannel={undefined}
            salesRep={order.created_by?.name}
          />
          <CommercialContext
            retailer={order.customer.name}
            billingParty={order.customer.code}
            shippingAddress={undefined}
            route={undefined}
            pricingPolicy={undefined}
            creditResult={order.credit_decision ?? undefined}
          />
          <div className="md:col-span-2">
            <AmountBreakdown
              subtotal={Number(order.total_amount) + Number(order.discount_amount)}
              discount={order.discount_amount}
              grandTotal={order.total_amount}
              invoiceAmount={invoice?.total_amount}
              paidAmount={payment?.amount}
              outstandingAmount={invoice ? Number(invoice.total_amount) - (payment?.amount ?? 0) : undefined}
            />
          </div>
        </div>
      ),
    },
    {
      value: "lines",
      label: `Lines (${order.lines.length})`,
      content: (
        <OrderLinesTable
          lines={order.lines}
          onViewProduct={(id) => router.push(`/products/${id}`)}
          onEditLine={(id) => {}}
          editable={order.status === "draft"}
        />
      ),
    },
    {
      value: "fulfillment",
      label: "Fulfillment",
      content: (
        <FulfillmentPanel
          pickStatus={order.pick_status}
          pickedAt={order.picked_at}
          pickedByName={undefined}
          pickConfirmedAt={order.pick_confirmed_at}
          pickConfirmedByName={undefined}
          tripId={trip?.trip_number}
          driverName={trip?.driver_name}
          vehicleNumber={trip?.vehicle_number}
          dispatchTime={trip?.dispatch_time}
          deliveredTime={trip?.delivered_time}
          deliveryPodUrl={trip?.pod_url}
          onViewTrip={(tripId) => router.push(`/delivery/${tripId}`)}
          onDownloadPod={() => trip?.pod_url && window.open(trip.pod_url, "_blank")}
        />
      ),
    },
    {
      value: "credit",
      label: "Credit & Finance",
      content: (
        <CreditFinancePanel
          creditDecision={order.credit_decision}
          creditReasons={order.credit_reasons}
          creditLimit={undefined}
          outstandingAtOrder={undefined}
          creditSnapshot={order.credit_snapshot as Record<string, string | number>}
          invoiceAmount={invoice?.total_amount}
          paidAmount={payment?.amount}
          outstandingAmount={invoice ? Number(invoice.total_amount) - (payment?.amount ?? 0) : undefined}
          onGenerateInvoice={handleGenerateInvoice}
          onRecordPayment={() => {}}
          onCreateCreditNote={() => {}}
          onViewInvoice={() => invoice && router.push(`/sales-invoices/${invoice.id}`)}
        />
      ),
    },
    {
      value: "timeline",
      label: "Timeline",
      content: <LifecycleTab orderId={order.id} token={token!} orgId={orgId!} />,
    },
    {
      value: "documents",
      label: "Documents",
      content: (
        <DocumentsPanel
          documents={[
            { id: String(order.id), type: "order" as const, name: `${order.order_number}.pdf` },
            ...(invoice ? [{ id: String(invoice.id), type: "invoice" as const, name: `INV-${invoice.invoice_number}.pdf`, createdAt: invoice.created_at }] : []),
            ...(trip?.pod_url ? [{ id: String(trip.id), type: "pod" as const, name: `POD-${trip.trip_number}.pdf` }] : []),
          ]}
          onDownload={(id) => {}}
          onPreview={(id) => {}}
        />
      ),
    },
  ];

  return (
    <AppShell breadcrumbs={[
        { label: "Orders", href: "/orders" },
        { label: order.order_number },
      ]}>
      {toast && (
        <div className={`fixed top-4 right-4 z-50 rounded-lg px-4 py-3 text-sm text-white shadow-lg ${
          toast.type === "success" ? "bg-success" : "bg-danger"
        }`}>
          {toast.msg}
        </div>
      )}

      <OrderHero
        orderNumber={order.order_number}
        customerName={order.customer.name}
        branch={order.branch.name}
        status={order.status}
        creditDecision={order.credit_decision}
        totalAmount={order.total_amount}
        actions={[
          // Edit (draft only — full edit)
          ...(order.status === "draft" ? [{
            label: "Edit Order",
            onClick: () => router.push(`/orders/${order.id}/edit`),
            variant: "outline" as const,
          }] : []),
          // Edit logistics (submitted/on_hold — delivery_date + notes only)
          ...(["submitted", "on_hold"].includes(order.status) ? [{
            label: "Edit Logistics",
            onClick: openLimitedEdit,
            variant: "outline" as const,
          }] : []),
          // Submit (draft only)
          ...(order.status === "draft" ? [{
            label: "Submit",
            onClick: handleSubmit,
          }] : []),
          // Refresh prices (draft only)
          ...(order.status === "draft" ? [{
            label: "Refresh Prices",
            onClick: handleRefreshPrice,
            variant: "outline" as const,
          }] : []),
          // Approve/Reject (submitted or on_hold — managers+)
          ...(["submitted", "on_hold"].includes(order.status) ? [{
            label: "Review",
            onClick: () => { setDecision("approved"); setDecisionReason(""); setApproveModal(true); },
          }] : []),
          // Put on Hold (submitted only — managers+)
          ...(order.status === "submitted" ? [{
            label: "Put on Hold",
            onClick: () => { setHoldReason(""); setHoldModal(true); },
            variant: "outline" as const,
          }] : []),
          // Cancel
          ...(!["rejected", "cancelled"].includes(order.status) ? [{
            label: "Cancel Order",
            onClick: () => { setCancelReason(""); setCancelModal(true); },
            variant: "outline" as const,
          }] : []),
          // Create Delivery Trip (approved)
          ...(order.status === "approved" ? [{
            label: "Create Delivery Trip",
            onClick: () => router.push(`/delivery/new?order_id=${order.id}`),
            variant: "outline" as const,
          }] : []),
          // Generate Invoice (delivered)
          ...(order.status === "delivered" ? [{
            label: "Generate Invoice",
            onClick: handleGenerateInvoice,
          }] : []),
          // Mark as Picked (approved + pending_pick — warehouse staff or manager)
          ...(order.status === "approved" && order.pick_status === "pending_pick" &&
              (role === "warehouse_staff" || ["owner","admin","manager"].includes(role ?? "")) ? [{
            label: "Mark as Picked",
            onClick: handlePick,
            variant: "outline" as const,
          }] : []),
          // Confirm Pick (approved + picked — managers only)
          ...(order.status === "approved" && order.pick_status === "picked" &&
              ["owner","admin","manager"].includes(role ?? "") ? [{
            label: "Confirm Pick",
            onClick: handleConfirmPick,
          }] : []),
        ]}
      />

      <OrderLifecycle
        status={order.status}
        createdAt={order.created_at}
        submittedAt={order.submitted_at}
        approvedAt={order.approved_at}
        cancelledAt={order.cancelled_at}
        rejectedAt={null}
        cancellationReason={order.cancellation_reason}
      />

      <NextActionBanner
        status={order.status}
        creditDecision={order.credit_decision}
        creditReasons={order.credit_reasons}
        invoicedAt={null}
        paidAt={null}
        deliveredAt={null}
        onAction={(action) => {
          if (action === "submit") handleSubmit();
          else if (action === "approve") { setDecision("approved"); setApproveModal(true); }
          else if (action === "invoice") handleGenerateInvoice();
          else if (action === "payment") { /* setPaymentModal(true) */ }
        }}
      />

      <Tabs items={tabItems} defaultValue="overview" />

      {/* Approve/Reject Modal */}
      <Modal
        open={approveModal}
        onClose={() => setApproveModal(false)}
        title="Review Order"
      >
        <div className="space-y-3 sm:space-y-4">
          <p className="text-xs sm:text-sm text-text-secondary">
            {order.status === "on_hold"
              ? `Order ${order.order_number} is on hold pending credit review. Approve or reject to proceed.`
              : `Order ${order.order_number} is submitted and awaiting approval. Approve or reject to proceed.`}
          </p>

          <div className="flex flex-col sm:flex-row gap-2 sm:gap-3">
            <button
              onClick={() => setDecision("approved")}
              className={`flex-1 rounded-md border py-2 text-xs sm:text-sm font-medium transition-colors ${
                decision === "approved"
                  ? "border-success bg-success/10 text-success"
                  : "border-border text-text-secondary hover:bg-muted"
              }`}
            >
              <CheckCircle2 className="h-4 w-4 inline mr-1" /> Approve
            </button>
            <button
              onClick={() => setDecision("rejected")}
              className={`flex-1 rounded-md border py-2 text-sm font-medium transition-colors ${
                decision === "rejected"
                  ? "border-danger bg-danger/10 text-danger"
                  : "border-border text-text-secondary hover:bg-muted"
              }`}
            >
              <XCircle className="h-4 w-4 inline mr-1" /> Reject
            </button>
          </div>

          <div>
            <label className="text-xs sm:text-sm font-medium mb-1 block">
              Reason {decision === "rejected" ? "*" : "(optional)"}
            </label>
            <textarea
              value={decisionReason}
              onChange={e => setDecisionReason(e.target.value)}
              rows={3}
              className="w-full rounded-md border border-border px-2 sm:px-3 py-1 sm:py-2 text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder={decision === "approved" ? "Optional note…" : "Reason for rejection…"}
            />
          </div>

          <div className="flex flex-col-reverse sm:flex-row justify-end gap-2 sm:gap-3">
            <Button variant="outline" onClick={() => setApproveModal(false)} className="text-xs sm:text-sm">Cancel</Button>
            <Button
              onClick={handleApproveSubmit}
              disabled={acting || (decision === "rejected" && !decisionReason.trim())}
              className={`text-xs sm:text-sm ${decision === "rejected" ? "bg-danger hover:bg-danger/90" : ""}`}
            >
              Confirm {decision === "approved" ? "Approval" : "Rejection"}
            </Button>
          </div>
        </div>
      </Modal>

      {/* Cancel Modal */}
      <Modal
        open={cancelModal}
        onClose={() => setCancelModal(false)}
        title="Cancel Order"
      >
        <div className="space-y-3 sm:space-y-4">
          <p className="text-xs sm:text-sm text-text-secondary">
            Are you sure you want to cancel order <strong>{order.order_number}</strong>?
            This cannot be undone.
          </p>
          <div>
            <label className="text-xs sm:text-sm font-medium mb-1 block">Reason *</label>
            <textarea
              value={cancelReason}
              onChange={e => setCancelReason(e.target.value)}
              rows={3}
              className="w-full rounded-md border border-border px-2 sm:px-3 py-1 sm:py-2 text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="Reason for cancellation…"
            />
          </div>
          <div className="flex flex-col-reverse sm:flex-row justify-end gap-2 sm:gap-3">
            <Button variant="outline" onClick={() => setCancelModal(false)} className="text-xs sm:text-sm">Back</Button>
            <Button
              className="bg-danger hover:bg-danger/90 text-xs sm:text-sm"
              disabled={acting || !cancelReason.trim()}
              onClick={handleCancelSubmit}
            >
              Confirm Cancel
            </Button>
          </div>
        </div>
      </Modal>

      {/* Hold Modal */}
      <Modal
        open={holdModal}
        onClose={() => setHoldModal(false)}
        title="Put Order on Hold"
        description="The order will move to on-hold status. A manager will need to approve or reject it before it proceeds."
      >
        <div className="space-y-3 sm:space-y-4">
          <div>
            <label className="text-xs sm:text-sm font-medium mb-1 block">Reason *</label>
            <textarea
              value={holdReason}
              onChange={e => setHoldReason(e.target.value)}
              rows={3}
              autoFocus
              className="w-full rounded-md border border-border px-2 sm:px-3 py-1 sm:py-2 text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="e.g. Awaiting stock confirmation, customer query…"
            />
          </div>
          <div className="flex flex-col-reverse sm:flex-row justify-end gap-2 sm:gap-3">
            <Button variant="outline" onClick={() => setHoldModal(false)} className="text-xs sm:text-sm">Cancel</Button>
            <Button
              disabled={acting || !holdReason.trim()}
              onClick={handleHoldSubmit}
              className="text-xs sm:text-sm"
            >
              Confirm Hold
            </Button>
          </div>
        </div>
      </Modal>

      {/* Credit Decision Modal */}
      <CreditDecisionModal
        open={creditModal}
        onClose={() => setCreditModal(false)}
        credit={creditResult}
        orderId={order.id}
        orderNumber={order.order_number}
        customerId={order.customer.id}
      />

      {/* Edit Logistics Modal (submitted/on_hold — delivery date + notes) */}
      <Modal
        open={editModal}
        onClose={() => setEditModal(false)}
        title="Edit Logistics"
        description="Update delivery date and notes. Lines and pricing cannot be changed after submission."
      >
        <div className="space-y-3 sm:space-y-4">
          <div>
            <label className="text-xs sm:text-sm font-medium mb-1 block">Delivery Date</label>
            <input
              type="date"
              value={editDate}
              onChange={e => setEditDate(e.target.value)}
              className="w-full rounded-md border border-border px-2 sm:px-3 py-1 sm:py-2 text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
          <div>
            <label className="text-xs sm:text-sm font-medium mb-1 block">Notes</label>
            <textarea
              rows={3}
              value={editNotes}
              onChange={e => setEditNotes(e.target.value)}
              className="w-full rounded-md border border-border px-2 sm:px-3 py-1 sm:py-2 text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-primary resize-none"
              placeholder="Optional notes…"
            />
          </div>
          <div className="flex flex-col-reverse sm:flex-row justify-end gap-2 sm:gap-3">
            <Button variant="outline" onClick={() => setEditModal(false)} className="text-xs sm:text-sm">Cancel</Button>
            <Button onClick={handleLimitedEditSubmit} disabled={acting} className="text-xs sm:text-sm">
              Save Changes
            </Button>
          </div>
        </div>
      </Modal>
    </AppShell>
  );
}
