"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";
import {
  CheckCircle2,
  XCircle,
  Calendar,
  List,
  Plus,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
  Clock,
  AlertCircle,
} from "lucide-react";
import CreatePaymentModal from "@/components/payments/create-payment-modal";

// ── Types ──────────────────────────────────────────────────────────────────────

interface CollectionSchedule {
  id:               number;
  scheduled_date:   string;
  amount_expected:  number;
  status:           string;
  notes:            string | null;
  skip_reason:      string | null;
  rescheduled_to:   string | null;
  customer: {
    id:   number;
    name: string;
    code: string;
  };
  branch: {
    id:   number;
    name: string;
    code: string;
  };
  assigned_to: {
    id:   number;
    name: string;
  };
  completed_payment: {
    id:             number;
    payment_number: string;
    amount:         number;
  } | null;
}

// ── Helpers ────────────────────────────────────────────────────────────────────

const fmt = (n: number) =>
  `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

const fmtDate = (d: string) =>
  new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });

const STATUS_VARIANT: Record<string, "secondary" | "success" | "warning" | "danger"> = {
  planned:     "warning",
  completed:   "success",
  partial:     "warning",
  skipped:     "secondary",
  rescheduled: "secondary",
};

const STATUS_TABS = [
  { key: "",            label: "All" },
  { key: "planned",     label: "Planned" },
  { key: "completed",   label: "Completed" },
  { key: "partial",     label: "Partial" },
  { key: "skipped",     label: "Skipped" },
  { key: "rescheduled", label: "Rescheduled" },
];

// Calendar helpers
function getDaysInMonth(year: number, month: number) {
  return new Date(year, month + 1, 0).getDate();
}
function getFirstDayOfMonth(year: number, month: number) {
  return new Date(year, month, 1).getDay();
}

// ── Page ───────────────────────────────────────────────────────────────────────

export default function CollectionSchedulePage() {
  const router           = useRouter();
  const { token, orgId } = useOrgBranch();

  // View mode
  const [viewMode, setViewMode] = useState<"list" | "calendar">("list");

  // Data
  const [schedules, setSchedules]   = useState<CollectionSchedule[]>([]);
  const [loading, setLoading]       = useState(true);
  const [counts, setCounts]         = useState<Record<string, number>>({});
  const [page, setPage]             = useState(1);
  const [totalPages, setTotalPages] = useState(1);

  // Filters
  const [statusFilter, setStatusFilter] = useState("");
  const [dateFrom, setDateFrom]         = useState(
    () => new Date().toISOString().slice(0, 10)
  );
  const [dateTo, setDateTo]   = useState(
    () => {
      const d = new Date();
      d.setDate(d.getDate() + 14);
      return d.toISOString().slice(0, 10);
    }
  );
  const [assignedTo, setAssignedTo] = useState("");
  const [customerId, setCustomerId] = useState("");

  // Calendar state
  const today = new Date();
  const [calYear, setCalYear]   = useState(today.getFullYear());
  const [calMonth, setCalMonth] = useState(today.getMonth());

  // Action modals
  const [skipModal, setSkipModal]         = useState<CollectionSchedule | null>(null);
  const [skipReason, setSkipReason]       = useState("");
  const [rescheduleModal, setRescheduleModal] = useState<CollectionSchedule | null>(null);
  const [rescheduleDate, setRescheduleDate]   = useState("");
  const [collectModal, setCollectModal]   = useState<CollectionSchedule | null>(null);
  const [submitting, setSubmitting]       = useState(false);
  const [actionError, setActionError]     = useState<string | null>(null);

  // Create schedule modal (uses CreatePaymentModal as payment is the core action)
  const [showCreate, setShowCreate] = useState(false);

  const fetchSchedules = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page), per_page: "50" });
      if (statusFilter)  params.set("status", statusFilter);
      if (dateFrom)      params.set("date_from", dateFrom);
      if (dateTo)        params.set("date_to", dateTo);
      if (assignedTo)    params.set("assigned_to_id", assignedTo);
      if (customerId)    params.set("customer_id", customerId);

      const res  = await fetch(`/api/v1/collection_schedules?${params}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        setSchedules(json.data ?? []);
        setTotalPages(json.meta?.total_pages ?? 1);
        setCounts(json.meta?.counts ?? {});
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, statusFilter, dateFrom, dateTo, assignedTo, customerId]);

  useEffect(() => { fetchSchedules(); }, [fetchSchedules]);

  // ── Actions ────────────────────────────────────────────────────────────────

  const handleSkip = async () => {
    if (!skipModal || !skipReason.trim() || !token || !orgId) return;
    setSubmitting(true);
    setActionError(null);
    try {
      const res  = await fetch(`/api/v1/collection_schedules/${skipModal.id}/skip`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({ reason: skipReason }),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.errors?.join(", ") || "Skip failed");
      setSkipModal(null);
      setSkipReason("");
      fetchSchedules();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setSubmitting(false);
    }
  };

  const handleReschedule = async () => {
    if (!rescheduleModal || !rescheduleDate || !token || !orgId) return;
    setSubmitting(true);
    setActionError(null);
    try {
      const res  = await fetch(`/api/v1/collection_schedules/${rescheduleModal.id}/reschedule`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({ scheduled_date: rescheduleDate }),
      });
      const json = await res.json();
      if (!res.ok) throw new Error(json.errors?.join(", ") || "Reschedule failed");
      setRescheduleModal(null);
      setRescheduleDate("");
      fetchSchedules();
    } catch (e) {
      setActionError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setSubmitting(false);
    }
  };

  // ── Calendar helpers ────────────────────────────────────────────────────────

  const schedulesByDate = schedules.reduce<Record<string, CollectionSchedule[]>>((acc, s) => {
    const key = s.scheduled_date.slice(0, 10);
    acc[key]  = [...(acc[key] ?? []), s];
    return acc;
  }, {});

  const daysInMonth    = getDaysInMonth(calYear, calMonth);
  const firstDayOfWeek = getFirstDayOfMonth(calYear, calMonth);
  const MONTH_NAMES    = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  const DAY_NAMES      = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];

  const prevMonth = () => {
    if (calMonth === 0) { setCalYear(y => y - 1); setCalMonth(11); }
    else setCalMonth(m => m - 1);
  };
  const nextMonth = () => {
    if (calMonth === 11) { setCalYear(y => y + 1); setCalMonth(0); }
    else setCalMonth(m => m + 1);
  };

  const tabTotal = (key: string) =>
    key === "" ? Object.values(counts).reduce((s, v) => s + v, 0) : (counts[key] ?? 0);

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <AppShell breadcrumbs={[
      { label: "Finance",     href: "/finance" },
      { label: "Collections", href: "/collections" },
      { label: "Schedule" },
    ]}>
      <div className="max-w-6xl space-y-4">

        {/* Header */}
        <PageHeader
          title="Collection Schedule"
          description="Plan and track field collections for your sales team"
          actions={[
            { label: "Refresh", onClick: fetchSchedules, icon: RefreshCw, variant: "outline" as const },
            { label: "Record Payment", onClick: () => setShowCreate(true), icon: Plus },
          ]}
        />

        {/* View toggle */}
        <div className="flex items-center gap-2">
          <button
            onClick={() => setViewMode("list")}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded text-sm font-medium transition-colors ${
              viewMode === "list" ? "bg-primary text-primary-foreground" : "border hover:bg-muted/50"
            }`}
          >
            <List className="h-4 w-4" /> List
          </button>
          <button
            onClick={() => setViewMode("calendar")}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded text-sm font-medium transition-colors ${
              viewMode === "calendar" ? "bg-primary text-primary-foreground" : "border hover:bg-muted/50"
            }`}
          >
            <Calendar className="h-4 w-4" /> Calendar
          </button>
        </div>

        {/* Filters */}
        <div className="flex flex-wrap items-end gap-3 rounded-lg border bg-card p-4">
          <div className="space-y-1">
            <label className="text-xs font-medium text-text-secondary">From</label>
            <Input
              type="date"
              value={dateFrom}
              onChange={(e) => { setDateFrom(e.target.value); setPage(1); }}
              className="w-36 text-sm"
            />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-text-secondary">To</label>
            <Input
              type="date"
              value={dateTo}
              onChange={(e) => { setDateTo(e.target.value); setPage(1); }}
              className="w-36 text-sm"
            />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-text-secondary">Assigned To (User ID)</label>
            <Input
              placeholder="User ID..."
              value={assignedTo}
              onChange={(e) => { setAssignedTo(e.target.value); setPage(1); }}
              className="w-32 text-sm"
            />
          </div>
          <div className="space-y-1">
            <label className="text-xs font-medium text-text-secondary">Customer ID</label>
            <Input
              placeholder="Customer ID..."
              value={customerId}
              onChange={(e) => { setCustomerId(e.target.value); setPage(1); }}
              className="w-32 text-sm"
            />
          </div>
        </div>

        {/* Status Tabs */}
        <div className="flex items-center gap-1 border-b border-border overflow-x-auto">
          {STATUS_TABS.map((tab) => (
            <button
              key={tab.key}
              onClick={() => { setStatusFilter(tab.key); setPage(1); }}
              className={`flex items-center gap-1.5 px-4 py-2.5 text-sm font-medium whitespace-nowrap transition-colors ${
                statusFilter === tab.key
                  ? "border-b-2 border-primary text-primary"
                  : "text-text-secondary hover:text-text-primary"
              }`}
            >
              {tab.label}
              <span className={`inline-flex items-center justify-center rounded-full min-w-[18px] px-1 py-0.5 text-[10px] font-medium ${
                statusFilter === tab.key ? "bg-primary/10 text-primary" : "bg-background-subtle text-text-secondary"
              }`}>
                {tabTotal(tab.key)}
              </span>
            </button>
          ))}
        </div>

        {/* ── List View ── */}
        {viewMode === "list" && (
          <div className="rounded-lg border overflow-hidden">
            <table className="w-full text-sm">
              <thead className="bg-muted/50">
                <tr>
                  {["Date", "Customer", "Branch", "Assigned To", "Expected", "Status", "Actions"].map((h) => (
                    <th key={h} className="px-4 py-3 text-left font-medium text-text-secondary text-xs uppercase tracking-wider">
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={7} className="px-4 py-10 text-center text-text-secondary">
                      Loading schedules…
                    </td>
                  </tr>
                ) : schedules.length === 0 ? (
                  <tr>
                    <td colSpan={7} className="px-4 py-10 text-center text-text-secondary">
                      No collection schedules found for the selected filters.
                    </td>
                  </tr>
                ) : (
                  schedules.map((s) => {
                    const isPast     = new Date(s.scheduled_date) < new Date(new Date().toDateString());
                    const isOverdue  = s.status === "planned" && isPast;
                    return (
                      <tr key={s.id} className={`border-t hover:bg-muted/20 ${isOverdue ? "bg-red-50/40" : ""}`}>
                        <td className="px-4 py-3">
                          <span className={`font-medium ${isOverdue ? "text-red-600" : ""}`}>
                            {fmtDate(s.scheduled_date)}
                          </span>
                          {isOverdue && (
                            <span className="ml-1.5 inline-flex items-center gap-0.5 text-xs text-red-600">
                              <AlertCircle className="h-3 w-3" /> Overdue
                            </span>
                          )}
                        </td>
                        <td className="px-4 py-3">
                          <div className="font-medium">{s.customer.name}</div>
                          <div className="text-xs text-text-secondary">{s.customer.code}</div>
                        </td>
                        <td className="px-4 py-3 text-text-secondary text-xs">{s.branch.code}</td>
                        <td className="px-4 py-3 text-sm">{s.assigned_to.name}</td>
                        <td className="px-4 py-3 font-semibold">{fmt(s.amount_expected)}</td>
                        <td className="px-4 py-3">
                          <Badge variant={STATUS_VARIANT[s.status] ?? "secondary"}>
                            {s.status.charAt(0).toUpperCase() + s.status.slice(1)}
                          </Badge>
                          {s.completed_payment && (
                            <div className="mt-0.5 text-xs text-green-600">
                              {s.completed_payment.payment_number}
                            </div>
                          )}
                          {s.skip_reason && (
                            <div className="mt-0.5 text-xs text-text-secondary italic">
                              {s.skip_reason}
                            </div>
                          )}
                          {s.rescheduled_to && (
                            <div className="mt-0.5 text-xs text-blue-600">
                              → {fmtDate(s.rescheduled_to)}
                            </div>
                          )}
                        </td>
                        <td className="px-4 py-3">
                          {s.status === "planned" && (
                            <div className="flex items-center gap-1.5">
                              <Button
                                size="sm"
                                variant="outline"
                                className="text-green-700 border-green-200 hover:bg-green-50 h-7 text-xs px-2"
                                onClick={() => setCollectModal(s)}
                              >
                                <CheckCircle2 className="h-3.5 w-3.5 mr-1" />
                                Collect
                              </Button>
                              <Button
                                size="sm"
                                variant="outline"
                                className="h-7 text-xs px-2"
                                onClick={() => { setRescheduleModal(s); setRescheduleDate(""); }}
                              >
                                <Clock className="h-3.5 w-3.5 mr-1" />
                                Reschedule
                              </Button>
                              <Button
                                size="sm"
                                variant="outline"
                                className="text-red-600 border-red-200 hover:bg-red-50 h-7 text-xs px-2"
                                onClick={() => { setSkipModal(s); setSkipReason(""); }}
                              >
                                <XCircle className="h-3.5 w-3.5 mr-1" />
                                Skip
                              </Button>
                            </div>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        )}

        {/* ── Calendar View ── */}
        {viewMode === "calendar" && (
          <div className="rounded-lg border bg-card overflow-hidden">
            {/* Calendar Header */}
            <div className="flex items-center justify-between px-5 py-3 border-b bg-muted/20">
              <button onClick={prevMonth} className="p-1 hover:bg-muted rounded">
                <ChevronLeft className="h-5 w-5" />
              </button>
              <h2 className="font-semibold text-sm">
                {MONTH_NAMES[calMonth]} {calYear}
              </h2>
              <button onClick={nextMonth} className="p-1 hover:bg-muted rounded">
                <ChevronRight className="h-5 w-5" />
              </button>
            </div>

            {/* Day headers */}
            <div className="grid grid-cols-7 border-b">
              {DAY_NAMES.map((d) => (
                <div key={d} className="py-2 text-center text-xs font-medium text-text-secondary">
                  {d}
                </div>
              ))}
            </div>

            {/* Calendar grid */}
            <div className="grid grid-cols-7">
              {/* Empty cells for first week offset */}
              {Array.from({ length: firstDayOfWeek }).map((_, i) => (
                <div key={`empty-${i}`} className="border-b border-r min-h-[80px] bg-muted/10" />
              ))}
              {Array.from({ length: daysInMonth }).map((_, i) => {
                const day    = i + 1;
                const dateStr = `${calYear}-${String(calMonth + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
                const daySchedules = schedulesByDate[dateStr] ?? [];
                const isToday = dateStr === today.toISOString().slice(0, 10);

                return (
                  <div key={day} className={`border-b border-r min-h-[80px] p-1.5 ${isToday ? "bg-primary/5" : ""}`}>
                    <div className={`text-xs font-medium mb-1 w-6 h-6 flex items-center justify-center rounded-full ${
                      isToday ? "bg-primary text-primary-foreground" : "text-text-secondary"
                    }`}>
                      {day}
                    </div>
                    {daySchedules.slice(0, 3).map((s) => (
                      <div
                        key={s.id}
                        className={`text-[10px] px-1 py-0.5 rounded mb-0.5 truncate cursor-pointer ${
                          s.status === "completed" ? "bg-green-100 text-green-800" :
                          s.status === "skipped"   ? "bg-gray-100 text-gray-600" :
                          s.status === "planned" && new Date(s.scheduled_date) < today
                            ? "bg-red-100 text-red-700"
                            : "bg-amber-100 text-amber-800"
                        }`}
                        title={`${s.customer.name} — ${fmt(s.amount_expected)}`}
                      >
                        {s.customer.name}
                      </div>
                    ))}
                    {daySchedules.length > 3 && (
                      <div className="text-[10px] text-text-secondary pl-1">
                        +{daySchedules.length - 3} more
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* Pagination */}
        {viewMode === "list" && totalPages > 1 && (
          <div className="flex justify-center gap-2 pt-2">
            <Button variant="outline" size="sm" disabled={page === 1} onClick={() => setPage(p => p - 1)}>
              Previous
            </Button>
            <span className="flex items-center text-sm text-text-secondary px-2">
              Page {page} of {totalPages}
            </span>
            <Button variant="outline" size="sm" disabled={page === totalPages} onClick={() => setPage(p => p + 1)}>
              Next
            </Button>
          </div>
        )}
      </div>

      {/* ── Skip Modal ── */}
      {skipModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-sm p-6">
            <h2 className="text-lg font-semibold mb-1">Skip Collection</h2>
            <p className="text-sm text-text-secondary mb-3">
              {skipModal.customer.name} · {fmtDate(skipModal.scheduled_date)} · {fmt(skipModal.amount_expected)}
            </p>
            <textarea
              className="w-full border rounded-md px-3 py-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-primary"
              placeholder="Reason for skipping (required)..."
              rows={3}
              value={skipReason}
              onChange={(e) => setSkipReason(e.target.value)}
            />
            {actionError && <p className="text-sm text-red-600 mt-2">{actionError}</p>}
            <div className="flex justify-end gap-2 mt-4">
              <Button variant="outline" onClick={() => { setSkipModal(null); setActionError(null); }}>
                Cancel
              </Button>
              <Button
                className="bg-red-600 hover:bg-red-700 text-white"
                disabled={submitting || !skipReason.trim()}
                onClick={handleSkip}
              >
                {submitting ? "Skipping…" : "Skip"}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* ── Reschedule Modal ── */}
      {rescheduleModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-lg shadow-lg w-full max-w-sm p-6">
            <h2 className="text-lg font-semibold mb-1">Reschedule Collection</h2>
            <p className="text-sm text-text-secondary mb-4">
              {rescheduleModal.customer.name} · {fmtDate(rescheduleModal.scheduled_date)} · {fmt(rescheduleModal.amount_expected)}
            </p>
            <div className="space-y-1">
              <label className="text-sm font-medium">New Date</label>
              <Input
                type="date"
                value={rescheduleDate}
                min={new Date().toISOString().slice(0, 10)}
                onChange={(e) => setRescheduleDate(e.target.value)}
              />
            </div>
            {actionError && <p className="text-sm text-red-600 mt-2">{actionError}</p>}
            <div className="flex justify-end gap-2 mt-4">
              <Button variant="outline" onClick={() => { setRescheduleModal(null); setActionError(null); }}>
                Cancel
              </Button>
              <Button
                disabled={submitting || !rescheduleDate}
                onClick={handleReschedule}
              >
                {submitting ? "Rescheduling…" : "Reschedule"}
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* ── Collect Modal — opens full CreatePaymentModal pre-filled ── */}
      {collectModal && (
        <CreatePaymentModal
          prefilledCustomer={{ id: collectModal.customer.id, name: collectModal.customer.name }}
          defaultAmount={collectModal.amount_expected}
          onClose={() => setCollectModal(null)}
          onCreated={async (paymentId) => {
            // Mark schedule as complete with this payment ID
            if (token && orgId) {
              await fetch(`/api/v1/collection_schedules/${collectModal.id}/complete`, {
                method:  "POST",
                headers: {
                  Authorization:       `Bearer ${token}`,
                  "X-Organization-Id": orgId,
                  "Content-Type":      "application/json",
                },
                body: JSON.stringify({ payment_id: paymentId }),
              });
            }
            setCollectModal(null);
            fetchSchedules();
          }}
        />
      )}

      {showCreate && !collectModal && (
        <CreatePaymentModal
          onClose={() => setShowCreate(false)}
          onCreated={() => { setShowCreate(false); fetchSchedules(); }}
        />
      )}
    </AppShell>
  );
}
