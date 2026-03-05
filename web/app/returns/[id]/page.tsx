"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Breadcrumb, BreadcrumbItem } from "@/components/ui/breadcrumb";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";
import { useOrgBranch } from "@/lib/org-branch-context";
import { RotateCcw, CheckCircle, XCircle, ClipboardCheck, FileText } from "lucide-react";

const STATUS_VARIANT: Record<string, "secondary" | "warning" | "default" | "success" | "danger" | "outline"> = {
  draft:               "secondary",
  submitted:           "warning",
  qc_in_progress:      "warning",
  qc_completed:        "default",
  credit_note_issued:  "success",
  cancelled:           "danger",
};

interface QcLine {
  return_line_id: number;
  qty_resalable:  string;
  qty_damaged:    string;
  qty_expired:    string;
  condition_final: string;
  qc_notes:       string;
}

export default function ReturnDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [rr, setRr]               = useState<any>(null);
  const [loading, setLoading]     = useState(true);
  const [activeTab, setActiveTab] = useState("summary");
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError]         = useState<string | null>(null);

  // Modal state
  const [cancelModal, setCancelModal]   = useState(false);
  const [cancelReason, setCancelReason] = useState("");
  const [qcModal, setQcModal]           = useState(false);
  const [creditModal, setCreditModal]   = useState(false);
  const [creditNotes, setCreditNotes]   = useState("");
  const [qcLines, setQcLines]           = useState<QcLine[]>([]);

  const headers = useCallback(() => ({
    Authorization:      `Bearer ${token}`,
    "X-Organization-Id": orgId!,
    "Content-Type":     "application/json",
  }), [token, orgId]);

  const fetchReturn = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const res = await fetch(`/api/v1/return_requests/${id}`, { headers: headers() });
      if (!res.ok) throw new Error("Not found");
      const body = await res.json();
      setRr(body.data);
      // Init QC lines from return lines
      if (body.data?.lines) {
        setQcLines(
          body.data.lines.map((l: any) => ({
            return_line_id: l.id,
            qty_resalable:  l.qc_item?.qty_resalable?.toString() ?? "",
            qty_damaged:    l.qc_item?.qty_damaged?.toString() ?? "",
            qty_expired:    l.qc_item?.qty_expired?.toString() ?? "",
            condition_final: l.qc_item?.condition_final ?? "resalable",
            qc_notes:       l.qc_item?.qc_notes ?? "",
          }))
        );
      }
    } catch (err) {
      setError("Failed to load return request");
    } finally {
      setLoading(false);
    }
  }, [id, token, orgId, headers]);

  useEffect(() => { fetchReturn(); }, [fetchReturn]);

  // ── Actions ──────────────────────────────────────────────────────────────

  const postAction = async (path: string, body?: object) => {
    setActionLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/v1/return_requests/${id}/${path}`, {
        method: "POST",
        headers: headers(),
        body: body ? JSON.stringify(body) : undefined,
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.errors?.join(", ") || "Action failed");
      setRr(data.data);
      return true;
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "An error occurred");
      return false;
    } finally {
      setActionLoading(false);
    }
  };

  const handleSubmit      = () => postAction("submit");
  const handleStartQc     = () => postAction("start_qc");

  const handleCompleteQc  = async () => {
    const ok = await postAction("complete_qc", {
      qc_lines: qcLines.map((l) => ({
        return_line_id:  l.return_line_id,
        qty_resalable:   parseFloat(l.qty_resalable)  || 0,
        qty_damaged:     parseFloat(l.qty_damaged)    || 0,
        qty_expired:     parseFloat(l.qty_expired)    || 0,
        condition_final: l.condition_final,
        qc_notes:        l.qc_notes,
      })),
    });
    if (ok) { setQcModal(false); fetchReturn(); }
  };

  const handleCancel = async () => {
    if (!cancelReason.trim()) { setError("Cancellation reason is required"); return; }
    const ok = await postAction("cancel", { reason: cancelReason });
    if (ok) { setCancelModal(false); setCancelReason(""); }
  };

  const handleIssueCreditNote = async () => {
    setActionLoading(true);
    setError(null);
    try {
      const res = await fetch(`/api/v1/credit_notes/from_return/${id}/issue`, {
        method: "POST",
        headers: headers(),
        body: JSON.stringify({ notes: creditNotes }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.errors?.join(", ") || "Failed to issue credit note");
      setRr((prev: any) => ({ ...prev, ...data.data?.return_request }));
      fetchReturn();
      setCreditModal(false);
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "An error occurred");
    } finally {
      setActionLoading(false);
    }
  };

  const updateQcLine = (idx: number, field: keyof QcLine, value: string) => {
    const updated = [...qcLines];
    updated[idx] = { ...updated[idx], [field]: value };
    setQcLines(updated);
  };

  if (loading) {
    return (
      <AppShell>
        <div className="p-6 animate-pulse space-y-4">
          <div className="h-8 bg-gray-200 rounded w-48" />
          <div className="h-32 bg-gray-100 rounded" />
        </div>
      </AppShell>
    );
  }

  if (!rr) {
    return (
      <AppShell>
        <div className="text-danger">Return request not found.</div>
      </AppShell>
    );
  }

  const TABS = [
    { key: "summary",     label: "Summary" },
    { key: "lines",       label: `Lines (${rr.lines?.length ?? 0})` },
    { key: "qc",          label: "QC" },
    { key: "credit_note", label: "Credit Note" },
    { key: "timeline",    label: "Timeline" },
  ];

  const breadcrumbs: BreadcrumbItem[] = [
    { label: "Returns",       href: "/returns" },
    { label: rr.return_number },
  ];

  // Build primary actions based on status
  const primaryActions = [];
  if (rr.status === "draft") {
    primaryActions.push({
      label: "Submit",
      onClick: handleSubmit,
      icon: <CheckCircle className="w-4 h-4" />,
      variant: "default" as const,
    });
    primaryActions.push({
      label: "Cancel",
      onClick: () => setCancelModal(true),
      icon: <XCircle className="w-4 h-4" />,
      variant: "outline" as const,
    });
  }
  if (rr.status === "submitted") {
    primaryActions.push({
      label: "Start QC",
      onClick: handleStartQc,
      icon: <ClipboardCheck className="w-4 h-4" />,
      variant: "default" as const,
    });
    primaryActions.push({
      label: "Cancel",
      onClick: () => setCancelModal(true),
      icon: <XCircle className="w-4 h-4" />,
      variant: "outline" as const,
    });
  }
  if (rr.status === "qc_in_progress") {
    primaryActions.push({
      label: "Complete QC",
      onClick: () => { setActiveTab("qc"); setQcModal(true); },
      icon: <ClipboardCheck className="w-4 h-4" />,
      variant: "default" as const,
    });
  }
  if (rr.status === "qc_completed" && !rr.credit_note) {
    primaryActions.push({
      label: "Issue Credit Note",
      onClick: () => setCreditModal(true),
      icon: <FileText className="w-4 h-4" />,
      variant: "default" as const,
    });
  }

  return (
    <AppShell>
      <div className="space-y-4">
        <Breadcrumb items={breadcrumbs} />

        <PageHeader
          title={rr.return_number}
          subtitle={`${rr.customer?.name} • ${rr.branch?.name} • ${new Date(rr.return_date).toLocaleDateString()}`}
          actions={primaryActions}
        />

        {error && (
          <div className="bg-danger/5 border border-danger/20 text-danger rounded-md px-4 py-3 text-sm">
            {error}
          </div>
        )}

        {/* ── Status Badge ── */}
        <div className="flex items-center gap-3">
          <Badge variant={STATUS_VARIANT[rr.status] ?? "secondary"}>
            {rr.status.replace(/_/g, " ")}
          </Badge>
          <span className="text-sm text-text-secondary">
            Source: <span className="capitalize">{rr.source_type}</span>
          </span>
          {rr.item_count && (
            <span className="text-sm text-text-secondary">{rr.item_count} items</span>
          )}
        </div>

        {/* ── Tabs ── */}
        <div className="flex gap-1 border-b">
          {TABS.map((tab) => (
            <button
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              className={`px-4 py-2 text-sm font-medium border-b-2 transition-colors ${
                activeTab === tab.key
                  ? "border-primary text-primary"
                  : "border-transparent text-text-secondary hover:text-text-primary"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* ── Tab Content ── */}

        {/* SUMMARY */}
        {activeTab === "summary" && (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-white border rounded-lg p-5 space-y-3">
              <h4 className="font-semibold text-text-secondary text-sm uppercase tracking-wide">Return Info</h4>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between"><dt className="text-text-secondary">Return #</dt><dd className="font-mono">{rr.return_number}</dd></div>
                <div className="flex justify-between"><dt className="text-text-secondary">Status</dt><dd><Badge variant={STATUS_VARIANT[rr.status] ?? "secondary"}>{rr.status.replace(/_/g, " ")}</Badge></dd></div>
                <div className="flex justify-between"><dt className="text-text-secondary">Return Date</dt><dd>{new Date(rr.return_date).toLocaleDateString()}</dd></div>
                <div className="flex justify-between"><dt className="text-text-secondary">Source</dt><dd className="capitalize">{rr.source_type}</dd></div>
                {rr.submitted_at && <div className="flex justify-between"><dt className="text-text-secondary">Submitted At</dt><dd>{new Date(rr.submitted_at).toLocaleString()}</dd></div>}
                {rr.qc_completed_at && <div className="flex justify-between"><dt className="text-text-secondary">QC Completed</dt><dd>{new Date(rr.qc_completed_at).toLocaleString()}</dd></div>}
                {rr.cancellation_reason && <div className="flex justify-between"><dt className="text-text-secondary">Cancel Reason</dt><dd className="text-danger">{rr.cancellation_reason}</dd></div>}
              </dl>
            </div>

            <div className="bg-white border rounded-lg p-5 space-y-3">
              <h4 className="font-semibold text-text-secondary text-sm uppercase tracking-wide">Customer &amp; Branch</h4>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between"><dt className="text-text-secondary">Customer</dt><dd className="font-medium">{rr.customer?.name}</dd></div>
                <div className="flex justify-between"><dt className="text-text-secondary">Branch</dt><dd>{rr.branch?.name}</dd></div>
              </dl>

              {rr.notes && (
                <>
                  <h4 className="font-semibold text-text-secondary text-sm uppercase tracking-wide pt-2">Notes</h4>
                  <p className="text-sm text-text-secondary">{rr.notes}</p>
                </>
              )}
            </div>

            {rr.credit_note && (
              <div className="md:col-span-2 bg-success/5 border border-success/20 rounded-lg p-5">
                <h4 className="font-semibold text-success mb-2">Credit Note Issued</h4>
                <div className="flex items-center gap-4">
                  <span className="font-mono text-success font-medium">{rr.credit_note.credit_note_number}</span>
                  <Badge variant="success">{rr.credit_note.status}</Badge>
                  <span className="text-success font-semibold">₹ {Number(rr.credit_note.total).toLocaleString("en-IN", { minimumFractionDigits: 2 })}</span>
                </div>
              </div>
            )}
          </div>
        )}

        {/* LINES */}
        {activeTab === "lines" && (
          <div className="overflow-x-auto bg-white border rounded-lg">
            <table className="w-full text-sm">
              <thead className="bg-background-subtle border-b">
                <tr>
                  {["Product", "SKU", "Qty Reported", "Qty Accepted", "Qty Rejected", "Condition", "Reason", "Unit Price", "QC Done"].map((h) => (
                    <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y">
                {(rr.lines ?? []).map((line: any) => (
                  <tr key={line.id} className="hover:bg-background-subtle/50">
                    <td className="px-4 py-3 font-medium">{line.product_name}</td>
                    <td className="px-4 py-3 font-mono text-xs text-text-secondary">{line.product_sku}</td>
                    <td className="px-4 py-3">{line.qty_reported}</td>
                    <td className="px-4 py-3 text-success">{line.qty_accepted}</td>
                    <td className="px-4 py-3 text-danger">{line.qty_rejected}</td>
                    <td className="px-4 py-3 capitalize">{line.condition_reported}</td>
                    <td className="px-4 py-3 capitalize text-xs">{line.reason_code?.replace(/_/g, " ")}</td>
                    <td className="px-4 py-3">{line.unit_price_snapshot ? `₹${line.unit_price_snapshot}` : "—"}</td>
                    <td className="px-4 py-3">{line.qc_item ? <Badge variant="success">Done</Badge> : <Badge variant="secondary">Pending</Badge>}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* QC */}
        {activeTab === "qc" && (
          <div className="space-y-4">
            {rr.status === "qc_in_progress" && (
              <div className="flex justify-end">
                <Button variant="default" onClick={() => setQcModal(true)}>
                  <ClipboardCheck className="w-4 h-4 mr-2" /> Complete QC
                </Button>
              </div>
            )}

            <div className="overflow-x-auto bg-white border rounded-lg">
              <table className="w-full text-sm">
                <thead className="bg-background-subtle border-b">
                  <tr>
                    {["Product", "Qty Reported", "Resalable", "Damaged", "Expired", "Condition Final", "QC Notes"].map((h) => (
                      <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-text-secondary uppercase">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {(rr.lines ?? []).map((line: any) => (
                    <tr key={line.id} className="hover:bg-background-subtle/50">
                      <td className="px-4 py-3 font-medium">{line.product_name}</td>
                      <td className="px-4 py-3">{line.qty_reported}</td>
                      <td className="px-4 py-3 text-success font-medium">{line.qc_item?.qty_resalable ?? "—"}</td>
                      <td className="px-4 py-3 text-warning">{line.qc_item?.qty_damaged ?? "—"}</td>
                      <td className="px-4 py-3 text-danger">{line.qc_item?.qty_expired ?? "—"}</td>
                      <td className="px-4 py-3 capitalize">{line.qc_item?.condition_final ?? "—"}</td>
                      <td className="px-4 py-3 text-text-secondary">{line.qc_item?.qc_notes || "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* CREDIT NOTE */}
        {activeTab === "credit_note" && (
          <div>
            {rr.credit_note ? (
              <div className="bg-white border rounded-lg p-6 space-y-4">
                <div className="flex items-center gap-4">
                  <h3 className="text-lg font-semibold">{rr.credit_note.credit_note_number}</h3>
                  <Badge variant="success">{rr.credit_note.status}</Badge>
                </div>
                <div className="text-2xl font-bold text-success">
                  ₹ {Number(rr.credit_note.total).toLocaleString("en-IN", { minimumFractionDigits: 2 })}
                </div>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => router.push(`/credit-notes/${rr.credit_note.id}`)}
                >
                  View Full Credit Note →
                </Button>
              </div>
            ) : rr.status === "qc_completed" ? (
              <div className="bg-warning/5 border border-warning/20 rounded-lg p-6 text-center">
                <p className="text-warning mb-4">QC is complete. Issue a credit note to credit the customer.</p>
                <Button variant="default" onClick={() => setCreditModal(true)}>
                  <FileText className="w-4 h-4 mr-2" /> Issue Credit Note
                </Button>
              </div>
            ) : (
              <div className="bg-background-subtle border rounded-lg p-6 text-center text-text-secondary">
                Credit note will be available after QC is completed.
              </div>
            )}
          </div>
        )}

        {/* TIMELINE */}
        {activeTab === "timeline" && (
          <div className="space-y-3">
            {(rr.timeline ?? []).length === 0 ? (
              <p className="text-text-secondary text-sm">No audit events yet.</p>
            ) : (
              (rr.timeline ?? []).map((event: any) => (
                <div key={event.id} className="flex gap-3 bg-white border rounded-lg p-4">
                  <div className="w-2 h-2 mt-2 rounded-full bg-border flex-shrink-0" />
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium">{event.action.replace(/_/g, " ")}</span>
                      <span className="text-xs text-text-secondary">{new Date(event.created_at).toLocaleString()}</span>
                    </div>
                    {event.actor && (
                      <p className="text-xs text-text-secondary">by {event.actor}</p>
                    )}
                    {event.reason && (
                      <p className="text-xs text-text-secondary mt-1 italic">"{event.reason}"</p>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        )}

        {/* ── Modals ── */}

        {/* Cancel Modal */}
        <Modal
          open={cancelModal}
          onClose={() => { setCancelModal(false); setCancelReason(""); setError(null); }}
          title="Cancel Return Request"
        >
          <div className="space-y-4">
            <p className="text-sm text-text-secondary">Please provide a reason for cancelling this return request.</p>
            <textarea
              value={cancelReason}
              onChange={(e) => setCancelReason(e.target.value)}
              placeholder="Cancellation reason…"
              rows={3}
              className="w-full border rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary"
            />
            {error && <p className="text-danger text-sm">{error}</p>}
            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => setCancelModal(false)}>Back</Button>
              <Button variant="danger" onClick={handleCancel} disabled={actionLoading}>
                {actionLoading ? "Cancelling…" : "Confirm Cancel"}
              </Button>
            </div>
          </div>
        </Modal>

        {/* QC Modal */}
        <Modal
          open={qcModal}
          onClose={() => { setQcModal(false); setError(null); }}
          title="Complete QC"
        >
          <div className="space-y-4 max-h-[70vh] overflow-y-auto">
            <p className="text-sm text-text-secondary">Enter QC quantities for each product. Resalable items will be returned to on-hand inventory.</p>

            {(rr.lines ?? []).map((line: any, idx: number) => {
              const qc = qcLines[idx] ?? {};
              return (
                <div key={line.id} className="border rounded-md p-4 space-y-3">
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-xs text-text-secondary">{line.product_sku}</span>
                    <span className="font-semibold text-sm">{line.product_name}</span>
                    <span className="ml-auto text-xs text-text-secondary">Reported: {line.qty_reported}</span>
                  </div>

                  <div className="grid grid-cols-3 gap-3">
                    <div>
                      <label className="block text-xs font-medium text-success mb-1">Resalable</label>
                      <input
                        type="number" min="0" step="0.001"
                        value={qc.qty_resalable ?? ""}
                        onChange={(e) => updateQcLine(idx, "qty_resalable", e.target.value)}
                        className="w-full border rounded-md px-2 py-1.5 text-sm border-success/30"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-warning mb-1">Damaged</label>
                      <input
                        type="number" min="0" step="0.001"
                        value={qc.qty_damaged ?? ""}
                        onChange={(e) => updateQcLine(idx, "qty_damaged", e.target.value)}
                        className="w-full border rounded-md px-2 py-1.5 text-sm border-warning/30"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-danger mb-1">Expired</label>
                      <input
                        type="number" min="0" step="0.001"
                        value={qc.qty_expired ?? ""}
                        onChange={(e) => updateQcLine(idx, "qty_expired", e.target.value)}
                        className="w-full border rounded-md px-2 py-1.5 text-sm border-danger/30"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-medium text-text-secondary mb-1">QC Notes</label>
                    <input
                      type="text"
                      value={qc.qc_notes ?? ""}
                      onChange={(e) => updateQcLine(idx, "qc_notes", e.target.value)}
                      placeholder="Optional notes…"
                      className="w-full border rounded-md px-2 py-1.5 text-sm"
                    />
                  </div>
                </div>
              );
            })}

            {error && <p className="text-danger text-sm">{error}</p>}

            <div className="flex justify-end gap-2 pt-2">
              <Button variant="outline" onClick={() => setQcModal(false)}>Cancel</Button>
              <Button variant="default" onClick={handleCompleteQc} disabled={actionLoading}>
                {actionLoading ? "Submitting…" : "Complete QC"}
              </Button>
            </div>
          </div>
        </Modal>

        {/* Issue Credit Note Modal */}
        <Modal
          open={creditModal}
          onClose={() => { setCreditModal(false); setError(null); }}
          title="Issue Credit Note"
        >
          <div className="space-y-4">
            <p className="text-sm text-text-secondary">
              A credit note will be created for all resalable items accepted during QC, using the price snapshots from submission.
            </p>

            <div className="bg-background-subtle rounded border p-3 space-y-1">
              {(rr.lines ?? [])
                .filter((l: any) => l.qc_item?.qty_resalable > 0)
                .map((l: any) => (
                  <div key={l.id} className="flex justify-between text-sm">
                    <span>{l.product_name}</span>
                    <span className="text-text-secondary">× {l.qc_item.qty_resalable} @ ₹{l.unit_price_snapshot}</span>
                  </div>
                ))
              }
            </div>

            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1">Notes (optional)</label>
              <textarea
                value={creditNotes}
                onChange={(e) => setCreditNotes(e.target.value)}
                rows={2}
                placeholder="Add notes to credit note…"
                className="w-full border rounded-md px-3 py-2 text-sm"
              />
            </div>

            {error && <p className="text-danger text-sm">{error}</p>}

            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => setCreditModal(false)}>Cancel</Button>
              <Button variant="default" onClick={handleIssueCreditNote} disabled={actionLoading}>
                {actionLoading ? "Issuing…" : "Issue Credit Note"}
              </Button>
            </div>
          </div>
        </Modal>
      </div>
    </AppShell>
  );
}
