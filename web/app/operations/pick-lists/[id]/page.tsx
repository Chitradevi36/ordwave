"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert } from "@/components/ui/alert";
import { CheckCircle2, PlayCircle, ArrowLeft } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────
interface PickListItem {
  id: number;
  product_id: number;
  product_name: string;
  product_sku: string;
  bin_location: string | null;
  qty_requested: number;
  qty_picked: number;
  picked_at: string | null;
  fulfilled: boolean;
}

interface PickListDetail {
  id: number;
  pick_number: string;
  status: string;
  started_at: string | null;
  completed_at: string | null;
  created_at: string;
  total_items: number;
  picked_items: number;
  branch: { id: number; name: string };
  sales_order: { id: number; order_number: string };
  picker: { id: number; name: string } | null;
  items: PickListItem[];
}

// ─── Constants ────────────────────────────────────────────────────────────────
const STATUS_VARIANT: Record<string, "default" | "secondary" | "warning" | "success" | "danger" | "outline"> = {
  pending:     "secondary",
  in_progress: "warning",
  completed:   "success",
  cancelled:   "outline",
};

// ─── Helpers ──────────────────────────────────────────────────────────────────
function fmtDateTime(d: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleString("en-IN", {
    day: "2-digit", month: "short", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function PickListDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [pickList, setPickList] = useState<PickListDetail | null>(null);
  const [loading, setLoading]   = useState(true);
  const [acting, setActing]     = useState(false);
  const [qtyInputs, setQtyInputs] = useState<Record<number, string>>({});
  const [toast, setToast] = useState<{ type: "success" | "error"; msg: string } | null>(null);

  const showToast = (type: "success" | "error", msg: string) => {
    setToast({ type, msg });
    setTimeout(() => setToast(null), 3500);
  };

  const fetchPickList = useCallback(async () => {
    if (!token || !orgId || !params.id) return;
    setLoading(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/pick_lists/${params.id}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const json = await res.json();
      if (res.ok) {
        setPickList(json.data);
        // Prefill qty inputs with qty_requested
        const inputs: Record<number, string> = {};
        (json.data.items ?? []).forEach((item: PickListItem) => {
          inputs[item.id] = String(item.qty_requested);
        });
        setQtyInputs(inputs);
      } else {
        showToast("error", json.errors?.[0] ?? "Failed to load pick list");
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, params.id]);

  useEffect(() => { void fetchPickList(); }, [fetchPickList]);

  const handleStart = async () => {
    setActing(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/pick_lists/${params.id}/start`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({}),
      });
      const json = await res.json();
      if (res.ok) { setPickList(json.data); showToast("success", "Picking started"); }
      else        showToast("error", json.errors?.[0] ?? "Failed to start");
    } finally {
      setActing(false);
    }
  };

  const handlePickItem = async (itemId: number) => {
    const qty = Number(qtyInputs[itemId] ?? 0);
    if (isNaN(qty) || qty < 0) return;
    setActing(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/pick_lists/${params.id}/items/${itemId}`, {
        method:  "PATCH",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({ qty_picked: qty }),
      });
      const json = await res.json();
      if (res.ok) {
        setPickList((prev) => {
          if (!prev) return prev;
          const items = prev.items.map((i) =>
            i.id === itemId ? (json.data ?? i) : i,
          );
          const picked = items.filter((i) => i.fulfilled).length;
          return { ...prev, items, picked_items: picked };
        });
        showToast("success", "Item updated");
      } else {
        showToast("error", json.errors?.[0] ?? "Failed to update item");
      }
    } finally {
      setActing(false);
    }
  };

  const handleComplete = async () => {
    setActing(true);
    try {
      const res  = await fetch(`${API_URL}/api/v1/pick_lists/${params.id}/complete`, {
        method:  "POST",
        headers: {
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId!,
          "Content-Type":      "application/json",
        },
        body: JSON.stringify({}),
      });
      const json = await res.json();
      if (res.ok) { setPickList(json.data); showToast("success", "Pick list completed"); }
      else        showToast("error", json.errors?.[0] ?? "Failed to complete");
    } finally {
      setActing(false);
    }
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

  if (!pickList) return null;

  const allPicked    = pickList.items.every((i) => i.fulfilled);
  const canStart     = pickList.status === "pending";
  const canPick      = pickList.status === "in_progress";
  const canComplete  = pickList.status === "in_progress" && allPicked;
  const isComplete   = pickList.status === "completed";

  return (
    <AppShell breadcrumbs={[
      { label: "Operations", href: "/operations" },
      { label: "Pick Lists",  href: "/operations/pick-lists" },
      { label: pickList.pick_number },
    ]}>
      {toast && (
        <div className={`fixed top-4 right-4 z-50 rounded-lg px-4 py-3 text-sm text-white shadow-lg ${
          toast.type === "success" ? "bg-success" : "bg-danger"
        }`}>
          {toast.msg}
        </div>
      )}

      <PageHeader
        title={pickList.pick_number}
        description={`Order ${pickList.sales_order.order_number} · ${pickList.branch.name}`}
        actions={[
          {
            label: "Back to Pick Lists",
            icon: ArrowLeft,
            variant: "outline" as const,
            onClick: () => router.push("/operations/pick-lists"),
          },
          ...(canStart ? [{
            label: "Start Picking",
            icon: PlayCircle,
            onClick: handleStart,
          }] : []),
          ...(canComplete ? [{
            label: "Complete Pick List",
            icon: CheckCircle2,
            onClick: handleComplete,
          }] : []),
        ]}
      />

      {/* Status row */}
      <div className="flex items-center gap-3 mb-4 -mt-2">
        <Badge variant={STATUS_VARIANT[pickList.status] ?? "secondary"}>
          {pickList.status.replace("_", " ")}
        </Badge>
        <span className="text-sm text-text-secondary">
          {pickList.picked_items} / {pickList.total_items} items picked
        </span>
        {pickList.picker && (
          <span className="text-sm text-text-secondary">· Picker: {pickList.picker.name}</span>
        )}
      </div>

      {/* Info cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-5">
        <Card>
          <CardContent className="p-3 text-sm">
            <p className="text-xs text-text-secondary mb-0.5">Order</p>
            <button
              className="font-mono text-primary hover:underline font-semibold"
              onClick={() => router.push(`/orders/${pickList.sales_order.id}`)}
            >
              {pickList.sales_order.order_number}
            </button>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-3 text-sm">
            <p className="text-xs text-text-secondary mb-0.5">Branch</p>
            <p className="font-medium">{pickList.branch.name}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-3 text-sm">
            <p className="text-xs text-text-secondary mb-0.5">Started</p>
            <p className="font-medium">{fmtDateTime(pickList.started_at)}</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-3 text-sm">
            <p className="text-xs text-text-secondary mb-0.5">Completed</p>
            <p className="font-medium">{fmtDateTime(pickList.completed_at)}</p>
          </CardContent>
        </Card>
      </div>

      {/* Complete success banner */}
      {isComplete && (
        <Alert variant="default" title="Pick list completed" className="mb-4">
          All {pickList.total_items} items picked at {fmtDateTime(pickList.completed_at)}.
        </Alert>
      )}

      {/* Pending banner */}
      {canStart && (
        <Alert variant="warning" title="Not started" className="mb-4">
          Click "Start Picking" above to assign yourself and begin picking items.
        </Alert>
      )}

      {/* Items table */}
      <Card>
        <CardHeader>
          <CardTitle className="text-sm">Pick Items ({pickList.total_items})</CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-background-subtle text-left text-xs text-text-secondary">
                  <th className="px-4 py-2.5 font-semibold">SKU</th>
                  <th className="px-4 py-2.5 font-semibold">Product</th>
                  <th className="px-4 py-2.5 font-semibold">Bin</th>
                  <th className="px-4 py-2.5 font-semibold text-right">Requested</th>
                  <th className="px-4 py-2.5 font-semibold text-right">Pick Qty</th>
                  {canPick && <th className="px-4 py-2.5 font-semibold" />}
                </tr>
              </thead>
              <tbody className="divide-y divide-border/60">
                {pickList.items.map((item) => (
                  <tr
                    key={item.id}
                    className={item.fulfilled ? "bg-success/5" : ""}
                  >
                    <td className="px-4 py-3 font-mono text-xs text-text-secondary">{item.product_sku}</td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        {item.fulfilled && (
                          <CheckCircle2 className="h-4 w-4 text-success shrink-0" />
                        )}
                        <span className={item.fulfilled ? "line-through text-text-secondary" : ""}>
                          {item.product_name}
                        </span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-text-secondary">
                      {item.bin_location ?? <span className="italic text-xs">—</span>}
                    </td>
                    <td className="px-4 py-3 text-right font-mono">{item.qty_requested}</td>
                    <td className="px-4 py-3 text-right">
                      {canPick ? (
                        <input
                          type="number"
                          min={0}
                          max={item.qty_requested}
                          value={qtyInputs[item.id] ?? item.qty_requested}
                          onChange={(e) =>
                            setQtyInputs((prev) => ({ ...prev, [item.id]: e.target.value }))
                          }
                          className="w-20 rounded border border-border px-2 py-1 text-sm text-right font-mono focus:outline-none focus:ring-2 focus:ring-primary"
                          disabled={acting}
                        />
                      ) : (
                        <span className="font-mono">{item.qty_picked}</span>
                      )}
                    </td>
                    {canPick && (
                      <td className="px-4 py-3">
                        <button
                          onClick={() => handlePickItem(item.id)}
                          disabled={acting || item.fulfilled}
                          className={`rounded-md px-2.5 py-1.5 text-xs font-medium transition-colors ${
                            item.fulfilled
                              ? "bg-success/10 text-success cursor-default"
                              : "bg-primary/10 text-primary hover:bg-primary/20"
                          }`}
                        >
                          {item.fulfilled ? "Done" : "Pick"}
                        </button>
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      {/* Complete CTA at bottom if all picked but not completed yet */}
      {canComplete && (
        <div className="mt-4 flex justify-end">
          <button
            onClick={handleComplete}
            disabled={acting}
            className="inline-flex items-center gap-2 rounded-lg bg-success px-5 py-2.5 text-sm font-semibold text-white shadow hover:bg-success/90 transition-colors disabled:opacity-60"
          >
            <CheckCircle2 className="h-4 w-4" />
            Complete Pick List
          </button>
        </div>
      )}
    </AppShell>
  );
}
