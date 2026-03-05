"use client";

import React, { useEffect, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell } from "@/components/layout";
import { Tabs } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { DataTable } from "@/components/ui/data-table";
import { Card, CardContent } from "@/components/ui/card";
import { useOrgBranch } from "@/lib/org-branch-context";
import { AddScheduleModal } from "@/components/beats/add-schedule-modal";
import { BeatRetailersPanel } from "@/components/beats/beat-retailers-panel";
import { Plus, ArrowLeft, MapPin, CalendarCheck, CheckCircle2 } from "lucide-react";

interface Beat {
  id: number;
  name: string;
  code: string;
  active: boolean;
  route_name: string | null;
  notes: string | null;
  schedules: BeatSchedule[];
}

interface BeatSchedule {
  id: number;
  weekday: number;
  weekday_name: string;
  sales_rep_id: number;
  active: boolean;
}

interface VisitLog {
  id: number;
  customer_name: string;
  visit_date: string;
  visit_status: string;
  checkin_at: string | null;
  checkout_at: string | null;
  duration_minutes: number | null;
  skip_reason_code: string | null;
}

const VISIT_STATUS_VARIANT: Record<string, "success" | "secondary" | "default" | "outline"> = {
  completed:  "success",
  skipped:    "secondary",
  checked_in: "default",
  planned:    "outline",
};

export default function BeatDetailPage() {
  const { id }  = useParams<{ id: string }>();
  const router  = useRouter();
  const { orgId, branchId, token } = useOrgBranch();

  const [beat, setBeat]                     = useState<Beat | null>(null);
  const [loading, setLoading]               = useState(true);
  const [selectedScheduleId, setSelectedScheduleId] = useState<number | null>(null);
  const [visitLogs, setVisitLogs]           = useState<VisitLog[]>([]);
  const [logsLoading, setLogsLoading]       = useState(false);
  const [showAddSchedule, setShowAddSchedule] = useState(false);
  const [activeTab, setActiveTab]           = useState("schedule");

  // Toast
  const [toast, setToast] = useState<{ type: "success" | "error"; msg: string } | null>(null);
  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  // ── Fetch beat ───────────────────────────────────────────────────────────
  const fetchBeat = useCallback(async () => {
    if (!orgId) return;
    setLoading(true);
    try {
      const res  = await fetch(`/api/v1/beats/${id}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const data = await res.json();
      setBeat(data.data);
      setSelectedScheduleId((prev) => {
        const schedules: BeatSchedule[] = data.data?.schedules ?? [];
        if (prev && schedules.some((s: BeatSchedule) => s.id === prev)) return prev;
        return schedules[0]?.id ?? null;
      });
    } finally {
      setLoading(false);
    }
  }, [id, orgId, token]);

  useEffect(() => { fetchBeat(); }, [fetchBeat]);

  // ── Fetch visit logs ─────────────────────────────────────────────────────
  const fetchVisitLogs = useCallback(async () => {
    if (!orgId) return;
    setLogsLoading(true);
    try {
      const qs = new URLSearchParams({ per_page: "100" });
      if (branchId) qs.set("branch_id", branchId);
      const res  = await fetch(`/api/v1/visits?${qs}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const data = await res.json();
      setVisitLogs(data.data ?? []);
    } finally {
      setLogsLoading(false);
    }
  }, [orgId, branchId, token]);

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

  if (!beat) {
    return (
      <AppShell>
        <div className="flex flex-col items-center justify-center py-24 gap-3">
          <p className="text-text-secondary">Beat not found.</p>
          <Button variant="outline" onClick={() => router.push("/beats")}>
            <ArrowLeft className="mr-2 h-4 w-4" /> Back to Beats
          </Button>
        </div>
      </AppShell>
    );
  }

  // ── Schedule columns ─────────────────────────────────────────────────────
  const scheduleColumns = [
    {
      key: "weekday_name",
      header: "Day",
      render: (_: unknown, row: BeatSchedule) => (
        <span className="font-medium text-text-primary">{row.weekday_name}</span>
      ),
    },
    {
      key: "active",
      header: "Status",
      render: (_: unknown, row: BeatSchedule) => (
        <Badge variant={row.active ? "success" : "secondary"}>
          {row.active ? "Active" : "Inactive"}
        </Badge>
      ),
    },
    {
      key: "id",
      header: "",
      className: "text-right",
      render: (_: unknown, row: BeatSchedule) => (
        <Button
          size="sm"
          variant={selectedScheduleId === row.id ? "default" : "outline"}
          onClick={() => setSelectedScheduleId(row.id)}
        >
          {selectedScheduleId === row.id ? "Editing retailers" : "Edit retailers"}
        </Button>
      ),
    },
  ];

  // ── Visit log columns ────────────────────────────────────────────────────
  const visitLogColumns = [
    {
      key: "visit_date",
      header: "Date",
      render: (_: unknown, row: VisitLog) => (
        <span className="font-mono text-sm">{row.visit_date}</span>
      ),
    },
    {
      key: "customer_name",
      header: "Customer",
      render: (_: unknown, row: VisitLog) => (
        <span className="font-medium text-text-primary">{row.customer_name}</span>
      ),
    },
    {
      key: "visit_status",
      header: "Status",
      render: (_: unknown, row: VisitLog) => (
        <Badge variant={VISIT_STATUS_VARIANT[row.visit_status] ?? "outline"}>
          {row.visit_status.replace(/_/g, " ")}
        </Badge>
      ),
    },
    {
      key: "duration_minutes",
      header: "Duration",
      render: (_: unknown, row: VisitLog) =>
        row.duration_minutes != null
          ? <span className="text-sm">{row.duration_minutes}m</span>
          : <span className="text-text-secondary">—</span>,
    },
    {
      key: "skip_reason_code",
      header: "Skip Reason",
      render: (_: unknown, row: VisitLog) =>
        row.skip_reason_code
          ? <span className="text-sm capitalize">{row.skip_reason_code.replace(/_/g, " ")}</span>
          : <span className="text-text-secondary">—</span>,
    },
  ];

  // ── Tabs ─────────────────────────────────────────────────────────────────
  const tabs = [
    {
      value: "schedule",
      label: `Schedule (${beat.schedules.length})`,
      content: (
        <div className="space-y-4">
          <div className="flex justify-end">
            <Button onClick={() => setShowAddSchedule(true)}>
              <Plus className="mr-2 h-4 w-4" />
              Add Schedule
            </Button>
          </div>
          <DataTable
            columns={scheduleColumns}
            data={beat.schedules ?? []}
            emptyMessage="No schedules yet. Add a schedule to start assigning retailers."
          />
        </div>
      ),
    },
    {
      value: "retailers",
      label: "Retailers",
      content: (
        <BeatRetailersPanel
          beatId={String(beat.id)}
          schedules={beat.schedules}
          initialScheduleId={selectedScheduleId}
          token={token}
          orgId={orgId}
          branchId={branchId}
        />
      ),
    },
    {
      value: "activity",
      label: "Activity",
      content: (
        <DataTable
          columns={visitLogColumns}
          data={visitLogs}
          isLoading={logsLoading}
          emptyMessage="No visit activity recorded for this beat."
        />
      ),
    },
  ];

  return (
    <AppShell>
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
        onClick={() => router.push("/beats")}
        className="flex items-center gap-1.5 text-sm text-text-secondary hover:text-primary mb-4 transition-colors"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to Beats
      </button>

      {/* Beat header card */}
      <Card className="mb-6">
        <CardContent className="p-5">
          <div className="flex items-start justify-between gap-4 flex-wrap">
            <div className="flex items-start gap-4">
              <div className="rounded-xl bg-primary/10 p-3 shrink-0">
                <CalendarCheck className="h-6 w-6 text-primary" />
              </div>
              <div>
                <div className="flex items-center gap-2 flex-wrap">
                  <h1 className="text-xl font-bold text-text-primary">{beat.name}</h1>
                  <span className="font-mono text-sm text-text-secondary bg-background-subtle px-2 py-0.5 rounded-md">
                    {beat.code}
                  </span>
                  <Badge variant={beat.active ? "success" : "secondary"}>
                    {beat.active ? "Active" : "Inactive"}
                  </Badge>
                </div>
                <div className="mt-1.5 flex items-center gap-4 flex-wrap text-sm text-text-secondary">
                  {beat.route_name && (
                    <span className="flex items-center gap-1">
                      <MapPin className="h-3.5 w-3.5" />
                      {beat.route_name}
                    </span>
                  )}
                  <span className="flex items-center gap-1">
                    <CheckCircle2 className="h-3.5 w-3.5" />
                    {beat.schedules.length} schedule{beat.schedules.length !== 1 ? "s" : ""}
                  </span>
                </div>
                {beat.notes && (
                  <p className="mt-2 text-sm text-text-secondary">{beat.notes}</p>
                )}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Tabs */}
      <Tabs
        value={activeTab}
        onValueChange={(v) => {
          setActiveTab(v);
          if (v === "activity") fetchVisitLogs();
        }}
        items={tabs}
      />

      {/* Modals */}
      <AddScheduleModal
        beatId={String(beat.id)}
        open={showAddSchedule}
        onClose={() => setShowAddSchedule(false)}
        onCreated={() => {
          setShowAddSchedule(false);
          fetchBeat();
          showToast("success", "Schedule added");
        }}
        token={token}
        orgId={orgId}
        branchId={branchId}
      />
    </AppShell>
  );
}
