"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { API_URL } from "@/lib/api/client";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Plus, Trash2, Search } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { ANALYTICS_EVENTS, trackBusinessEvent } from "@/lib/analytics";

// ─── Types ────────────────────────────────────────────────────────────────────
interface Branch  { id: number; name: string; }
interface Product { id: number; name: string; sku: string; }

interface TransferLine {
  _key: string;
  product: Product | null;
  productQuery: string;
  productResults: Product[];
  productOpen: boolean;
  qty_requested: string;
}

function newLine(): TransferLine {
  return {
    _key:           crypto.randomUUID(),
    product:        null,
    productQuery:   "",
    productResults: [],
    productOpen:    false,
    qty_requested:  "1",
  };
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function NewTransferPage() {
  const router = useRouter();
  const { token, orgId, branchId: currentBranchId } = useOrgBranch();

  const [branches,          setBranches]          = useState<Branch[]>([]);
  const [sourceBranchId,    setSourceBranchId]    = useState("");
  const [destBranchId,      setDestBranchId]      = useState("");
  const [transferDate,      setTransferDate]      = useState(
    new Date().toISOString().split("T")[0]
  );
  const [notes,             setNotes]             = useState("");
  const [lines,             setLines]             = useState<TransferLine[]>([newLine()]);
  const [errors,            setErrors]            = useState<string[]>([]);
  const [isSubmitting,      setIsSubmitting]      = useState(false);

  // Pre-select current branch as source
  useEffect(() => {
    if (currentBranchId) setSourceBranchId(currentBranchId);
  }, [currentBranchId]);

  // Load branches
  useEffect(() => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/branches?per_page=200`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    }).then((r) => r.json()).then((j) => setBranches(j.data ?? []));
  }, [token, orgId]);

  // Product search
  const searchProducts = useCallback(async (query: string, lineKey: string) => {
    if (query.length < 2 || !token || !orgId) return;
    const p = new URLSearchParams({ q: query, per_page: "20" });
    const res = await fetch(`${API_URL}/api/v1/products?${p}`,
      { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } });
    const json = await res.json();
    setLines((prev) => prev.map((l) =>
      l._key === lineKey ? { ...l, productResults: json.data ?? [], productOpen: true } : l
    ));
  }, [token, orgId]);

  const updateLine = (key: string, patch: Partial<TransferLine>) =>
    setLines((prev) => prev.map((l) => l._key === key ? { ...l, ...patch } : l));

  const removeLine = (key: string) =>
    setLines((prev) => prev.filter((l) => l._key !== key));

  const handleSubmit = async () => {
    setErrors([]);

    const payload = {
      stock_transfer: {
        source_branch_id:      sourceBranchId,
        destination_branch_id: destBranchId,
        transfer_date:         transferDate,
        notes:                 notes || undefined,
        lines: lines
          .filter((l) => l.product !== null)
          .map((l) => ({
            product_id:    l.product!.id,
            qty_requested: parseFloat(l.qty_requested) || 0,
          })),
      },
    };

    setIsSubmitting(true);
    try {
      const res = await fetch(`${API_URL}/api/v1/stock_transfers`, {
        method:  "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization:  `Bearer ${token}`,
          "X-Organization-Id": orgId ?? "",
        },
        body: JSON.stringify(payload),
      });
      const json = await res.json();
      if (res.ok) {
        trackBusinessEvent(ANALYTICS_EVENTS.STOCK_TRANSFER_CREATED, {
          module: "inventory",
          page:   "/inventory/transfers/new",
          items_count: lines.filter((l) => l.product !== null).length,
        });
        router.push(`/inventory/transfers/${json.data.id}`);
      } else {
        setErrors(json.errors ?? ["An error occurred"]);
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <AppShell breadcrumbs={[
      { label: "Inventory Transfers", href: "/inventory/transfers" },
      { label: "New Transfer" },
    ]}>

      <PageHeader
        title="New Stock Transfer"
        description="Create a draft transfer between branches"
        actions={[
          { label: "Cancel", onClick: () => router.push("/inventory/transfers"), variant: "outline" },
        ]}
      />

      <div className="max-w-2xl space-y-6">
        {/* Errors */}
        {errors.length > 0 && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive space-y-1">
            {errors.map((e, i) => <p key={i}>{e}</p>)}
          </div>
        )}

        {/* Branches */}
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <label className="text-sm font-medium">Source Branch *</label>
            <select
              value={sourceBranchId}
              onChange={(e) => setSourceBranchId(e.target.value)}
              className="w-full h-9 rounded-md border border-input bg-background px-3 text-sm"
            >
              <option value="">Select branch…</option>
              {branches.map((b) => <option key={b.id} value={String(b.id)}>{b.name}</option>)}
            </select>
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium">Destination Branch *</label>
            <select
              value={destBranchId}
              onChange={(e) => setDestBranchId(e.target.value)}
              className="w-full h-9 rounded-md border border-input bg-background px-3 text-sm"
            >
              <option value="">Select branch…</option>
              {branches.filter((b) => String(b.id) !== sourceBranchId).map((b) => (
                <option key={b.id} value={String(b.id)}>{b.name}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Transfer date + Notes */}
        <div className="grid grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <label className="text-sm font-medium">Transfer Date *</label>
            <Input type="date" value={transferDate} onChange={(e) => setTransferDate(e.target.value)} />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium">Notes</label>
            <Input placeholder="Optional notes…" value={notes} onChange={(e) => setNotes(e.target.value)} />
          </div>
        </div>

        {/* Lines */}
        <div>
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-semibold">Lines</h3>
            <Button variant="outline" size="sm" onClick={() => setLines((l) => [...l, newLine()])}>
              <Plus className="h-4 w-4 mr-1" /> Add Line
            </Button>
          </div>

          <div className="space-y-3">
            {lines.map((line, idx) => (
              <div key={line._key} className="flex items-start gap-2 p-3 border rounded-md bg-background">
                <span className="text-xs text-text-secondary pt-2 w-5 shrink-0">{idx + 1}.</span>

                {/* Product search */}
                <div className="relative flex-1">
                  <div className="flex items-center gap-2">
                    <Search className="h-3.5 w-3.5 text-text-secondary shrink-0" />
                    <Input
                      className="flex-1 h-8 text-sm"
                      placeholder="Search product or SKU…"
                      value={line.product ? `${line.product.name} (${line.product.sku})` : line.productQuery}
                      onChange={(e) => {
                        updateLine(line._key, { productQuery: e.target.value, product: null });
                        searchProducts(e.target.value, line._key);
                      }}
                      onFocus={() => {
                        if (line.product) updateLine(line._key, { product: null, productQuery: "" });
                      }}
                    />
                  </div>
                  {line.productOpen && line.productResults.length > 0 && (
                    <div className="absolute z-10 mt-1 w-full rounded-md border bg-background shadow-lg max-h-48 overflow-y-auto">
                      {line.productResults.map((p) => (
                        <button
                          key={p.id}
                          className="w-full px-3 py-2 text-left text-sm hover:bg-muted"
                          onClick={() => updateLine(line._key, {
                            product: p, productQuery: "", productResults: [], productOpen: false,
                          })}
                        >
                          <span className="font-medium">{p.name}</span>
                          <span className="ml-2 text-xs text-text-secondary">{p.sku}</span>
                        </button>
                      ))}
                    </div>
                  )}
                </div>

                {/* Qty */}
                <div className="w-24 shrink-0">
                  <Input
                    type="number"
                    min="0.001"
                    step="0.001"
                    className="h-8 text-sm font-mono"
                    placeholder="Qty"
                    value={line.qty_requested}
                    onChange={(e) => updateLine(line._key, { qty_requested: e.target.value })}
                  />
                </div>

                {/* Remove */}
                {lines.length > 1 && (
                  <Button
                    variant="ghost"
                    size="sm"
                    className="h-8 w-8 p-0 text-destructive shrink-0"
                    onClick={() => removeLine(line._key)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Submit */}
        <div className="flex gap-3 pt-2">
          <Button
            onClick={handleSubmit}
            disabled={isSubmitting || !sourceBranchId || !destBranchId}
          >
            {isSubmitting ? "Saving…" : "Save Draft"}
          </Button>
          <Button variant="outline" onClick={() => router.push("/inventory/transfers")}>
            Cancel
          </Button>
        </div>
      </div>
    </AppShell>
  );
}
