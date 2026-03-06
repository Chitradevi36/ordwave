"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { DataTable, Column } from "@/components/ui/data-table";
import { Modal } from "@/components/ui/modal";
import { useOrgBranch } from "@/lib/org-branch-context";
import { CheckCircle2, XCircle, ArrowLeftRight } from "lucide-react";
import { API_URL } from "@/lib/api/client";

// ──────────────────────────────────────────────────────────────────────────────
// Types
// ──────────────────────────────────────────────────────────────────────────────
interface LimitRequest {
  id: number;
  credit_account_id: number;
  customer_name: string;
  current_limit: number;
  new_limit: number;
  counter_offer_limit: number | null;
  status: string;
  reason: string;
  requested_by: string;
  decided_by: string | null;
  decided_at: string | null;
  sla_breached_at: string | null;
  created_at: string;
}

interface DecisionForm {
  decision: "approved" | "rejected" | "countered";
  counter_offer_limit: string;
  decision_note: string;
}

const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "outline"> = {
  pending:  "warning",
  approved: "default",
  rejected: "secondary",
  countered: "outline",
};

function fmtINR(n: number | null | undefined) {
  if (n == null) return "—";
  return `₹${n.toLocaleString("en-IN")}`;
}

// ──────────────────────────────────────────────────────────────────────────────
// Page
// ──────────────────────────────────────────────────────────────────────────────
export default function CreditLimitApprovalsPage() {
  const { token, orgId } = useOrgBranch();
  const [requests, setRequests] = useState<LimitRequest[]>([]);
  const [loading,  setLoading]  = useState(false);
  const [filter,   setFilter]   = useState<string>("pending");
  const [selected, setSelected] = useState<LimitRequest | null>(null);
  const [decisionForm, setDecisionForm] = useState<DecisionForm>({
    decision: "approved", counter_offer_limit: "", decision_note: "",
  });
  const [submitting, setSubmitting] = useState(false);
  const [toast, setToast] = useState<{ type: "success" | "error"; msg: string } | null>(null);

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  const fetchRequests = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const q   = filter !== "all" ? `?status=${filter}` : "";
      const res = await fetch(`${API_URL}/api/v1/credit_limit_change_requests${q}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) setRequests(json.data ?? []);
    } finally {
      setLoading(false);
    }
  }, [token, orgId, filter]);

  useEffect(() => { fetchRequests(); }, [fetchRequests]);

  const openDecision = (req: LimitRequest) => {
    setSelected(req);
    setDecisionForm({ decision: "approved", counter_offer_limit: "", decision_note: "" });
  };

  const handleDecision = async () => {
    if (!selected || !token || !orgId) return;
    setSubmitting(true);
    try {
      const body: Record<string, unknown> = {
        decision: decisionForm.decision,
        decision_note: decisionForm.decision_note,
      };
      if (decisionForm.decision === "countered") {
        body.counter_offer_limit = Number(decisionForm.counter_offer_limit);
      }
      const res = await fetch(
        `${API_URL}/api/v1/credit_limit_change_requests/${selected.id}/decision`,
        {
          method:  "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "X-Organization-Id": orgId,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(body),
        }
      );
      const json = await res.json();
      if (res.ok) {
        showToast("success", `Request ${decisionForm.decision}.`);
        setSelected(null);
        fetchRequests();
      } else {
        showToast("error", json.errors?.join(", ") ?? "Decision failed");
      }
    } finally {
      setSubmitting(false);
    }
  };

  const columns: Column<LimitRequest>[] = [
    {
      key: "customer_name",
      header: "Customer",
      render: (_, r) => (
        <div>
          <p className="font-medium text-text-primary">{r.customer_name}</p>
          <p className="text-xs text-text-secondary">Req #{r.id}</p>
        </div>
      ),
    },
    {
      key: "current_limit",
      header: "Current Limit",
      render: (_, r) => fmtINR(r.current_limit),
    },
    {
      key: "new_limit",
      header: "Requested",
      render: (_, r) => (
        <span className="font-medium text-accent">{fmtINR(r.new_limit)}</span>
      ),
    },
    {
      key: "reason",
      header: "Reason",
      render: (_, r) => (
        <span className="text-xs text-text-secondary line-clamp-2">{r.reason}</span>
      ),
    },
    {
      key: "requested_by",
      header: "Requested By",
      render: (_, r) => <span className="text-xs">{r.requested_by}</span>,
    },
    {
      key: "sla_breached_at",
      header: "SLA",
      render: (_, r) => r.sla_breached_at ? (
        <Badge variant="secondary" className="text-danger border-danger/20 bg-danger/10">Breached</Badge>
      ) : r.status === "pending" ? (
        <Badge variant="outline">Within SLA</Badge>
      ) : null,
    },
    {
      key: "status",
      header: "Status",
      render: (_, r) => (
        <Badge variant={STATUS_VARIANT[r.status] ?? "outline"} className="capitalize">
          {r.status}
        </Badge>
      ),
    },
    {
      key: "id",
      header: "",
      render: (_, r) => r.status === "pending" ? (
        <Button size="sm" onClick={() => openDecision(r)}>
          Decide
        </Button>
      ) : null,
    },
  ];

  return (
    <AppShell title="Credit Limit Approvals">
      <PageHeader
        title="Credit Limit Approvals"
        description="Review and decide on credit limit change requests."
      />

      {/* Toast */}
      {toast && (
        <div className={`mb-4 rounded-md border px-4 py-2.5 text-sm ${
          toast.type === "success"
            ? "bg-success/10 border-success/20 text-success"
            : "bg-danger/10 border-danger/20 text-danger"
        }`}>
          {toast.msg}
        </div>
      )}

      {/* Filter tabs */}
      <div className="mb-4 flex gap-2">
        {["pending", "approved", "rejected", "countered", "all"].map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`rounded-full px-3 py-1 text-xs font-medium capitalize transition-colors ${
              filter === f
                ? "bg-accent text-white"
                : "bg-background-subtle text-text-secondary hover:text-text-primary"
            }`}
          >
            {f}
          </button>
        ))}
      </div>

      <Card>
        <CardContent className="p-0">
          <DataTable
            columns={columns}
            data={requests}
            isLoading={loading}
            emptyMessage={`No ${filter === "all" ? "" : filter} requests found.`}
          />
        </CardContent>
      </Card>

      {/* Decision Modal */}
      <Modal
        open={!!selected}
        onClose={() => setSelected(null)}
        title="Credit Limit Decision"
        description={selected ? `${selected.customer_name} — requesting ${fmtINR(selected.new_limit)} (current: ${fmtINR(selected.current_limit)})` : ""}
        size="md"
      >
        {selected && (
          <div className="space-y-4">
            {/* Reason display */}
            <div className="rounded-md bg-background-subtle border border-border px-3 py-2 text-sm text-text-secondary">
              <span className="font-medium text-text-primary">Reason: </span>{selected.reason}
            </div>

            {/* Decision selection */}
            <div className="flex gap-2">
              {(["approved", "rejected", "countered"] as const).map((d) => (
                <button
                  key={d}
                  onClick={() => setDecisionForm((p) => ({ ...p, decision: d }))}
                  className={`flex-1 rounded-md border py-2 text-sm font-medium capitalize transition-colors ${
                    decisionForm.decision === d
                      ? d === "approved" ? "bg-success/10 border-success text-success"
                        : d === "rejected" ? "bg-danger/10 border-danger text-danger"
                        : "bg-warning/10 border-warning text-warning"
                      : "border-border text-text-secondary hover:text-text-primary"
                  }`}
                >
                  {d === "approved" && <CheckCircle2 className="h-3.5 w-3.5 inline mr-1" />}
                  {d === "rejected" && <XCircle className="h-3.5 w-3.5 inline mr-1" />}
                  {d === "countered" && <ArrowLeftRight className="h-3.5 w-3.5 inline mr-1" />}
                  {d}
                </button>
              ))}
            </div>

            {/* Counter offer */}
            {decisionForm.decision === "countered" && (
              <div>
                <label className="text-sm font-medium text-text-primary">Counter Offer Limit *</label>
                <Input
                  type="number"
                  placeholder="Enter counter limit"
                  value={decisionForm.counter_offer_limit}
                  onChange={(e) => setDecisionForm((p) => ({ ...p, counter_offer_limit: e.target.value }))}
                  className="mt-1"
                />
              </div>
            )}

            {/* Note */}
            <div>
              <label className="text-sm font-medium text-text-primary">Decision Note</label>
              <textarea
                value={decisionForm.decision_note}
                onChange={(e) => setDecisionForm((p) => ({ ...p, decision_note: e.target.value }))}
                placeholder="Optional note..."
                rows={2}
                className="mt-1 w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent resize-none"
              />
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <Button variant="outline" onClick={() => setSelected(null)}>Cancel</Button>
              <Button
                onClick={handleDecision}
                disabled={
                  submitting ||
                  (decisionForm.decision === "countered" && !decisionForm.counter_offer_limit)
                }
                className={
                  decisionForm.decision === "approved" ? "bg-success hover:bg-success/90"
                    : decisionForm.decision === "rejected" ? "bg-danger hover:bg-danger/90"
                    : ""
                }
              >
                {submitting ? "Submitting…" : `Confirm ${decisionForm.decision.charAt(0).toUpperCase() + decisionForm.decision.slice(1)}`}
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </AppShell>
  );
}
