"use client";

import { useState, useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Breadcrumb } from "@/components/ui/breadcrumb";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ArrowLeft, SlidersHorizontal } from "lucide-react";
import Link from "next/link";
import { useOrgBranch } from "@/lib/org-branch-context";
import { cn } from "@/lib/utils";

// ─── Types ────────────────────────────────────────────────────────────────────
interface Product { id: number; name: string; sku: string; }
interface Branch  { id: number; name: string; }

const REASON_CODES = [
  "damage_write_off",
  "expiry_write_off",
  "physical_count_correction",
  "theft_loss",
  "sample_issued",
  "opening_stock",
  "other",
];

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function NewAdjustmentPage() {
  const router       = useRouter();
  const searchParams = useSearchParams();
  const { token, orgId } = useOrgBranch();

  const [products,  setProducts]  = useState<Product[]>([]);
  const [branches,  setBranches]  = useState<Branch[]>([]);
  const [productId, setProductId] = useState(searchParams.get("product_id") ?? "");
  const [branchId,  setBranchId]  = useState(searchParams.get("branch_id")  ?? "");
  const [direction, setDirection] = useState<"in" | "out">("in");
  const [quantity,  setQuantity]  = useState("");
  const [reasonCode,setReasonCode]= useState("");
  const [notes,     setNotes]     = useState("");
  const [errors,    setErrors]    = useState<string[]>([]);
  const [loading,   setLoading]   = useState(false);

  // Fetch products + branches
  useEffect(() => {
    if (!token || !orgId) return;
    const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };
    Promise.all([
      fetch("http://localhost:3001/api/v1/products?per_page=500&status=active", { headers })
        .then((r) => r.json()).then((j) => setProducts(j.data ?? [])),
      fetch("http://localhost:3001/api/v1/branches?per_page=200", { headers })
        .then((r) => r.json()).then((j) => setBranches(j.data ?? [])),
    ]);
  }, [token, orgId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token || !orgId) return;

    const qty = parseFloat(quantity);
    if (!productId || !branchId || isNaN(qty) || qty <= 0) {
      setErrors(["Product, branch, and a positive quantity are required."]);
      return;
    }

    setLoading(true);
    setErrors([]);

    try {
      const res = await fetch("http://localhost:3001/api/v1/inventory/adjustments", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({
          adjustment: {
            product_id:  productId,
            branch_id:   branchId,
            direction:   direction,
            quantity:    qty,
            reason_code: reasonCode || null,
            notes:       notes || null,
          },
        }),
      });

      const json = await res.json();

      if (res.ok) {
        router.push(`/inventory/stock/${productId}?branch_id=${branchId}`);
      } else {
        setErrors(json.errors ?? ["An unexpected error occurred."]);
      }
    } catch {
      setErrors(["Network error — please try again."]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <AppShell>
      <Breadcrumb items={[
        { label: "Inventory", href: "/inventory/stock" },
        { label: "Stock Overview", href: "/inventory/stock" },
        { label: "New Adjustment" },
      ]} />
      <PageHeader
        title="New Stock Adjustment"
        description="Manually add or remove inventory"
        actions={[
          { label: "Cancel", onClick: () => router.push("/inventory/stock"), variant: "outline", icon: ArrowLeft },
        ]}
      />

      <div className="max-w-lg">
        <form onSubmit={handleSubmit} className="space-y-5">
          {/* Errors */}
          {errors.length > 0 && (
            <div className="rounded-md border border-destructive bg-destructive/10 p-3 text-sm text-destructive">
              {errors.map((e, i) => <p key={i}>{e}</p>)}
            </div>
          )}

          {/* Product */}
          <div className="space-y-1.5">
            <label className="text-sm font-medium">Product *</label>
            <select
              required
              value={productId}
              onChange={(e) => setProductId(e.target.value)}
              className="w-full h-9 rounded-md border border-input bg-background px-3 text-sm"
            >
              <option value="">Select product…</option>
              {products.map((p) => (
                <option key={p.id} value={p.id}>{p.name} ({p.sku})</option>
              ))}
            </select>
          </div>

          {/* Branch */}
          <div className="space-y-1.5">
            <label className="text-sm font-medium">Branch *</label>
            <select
              required
              value={branchId}
              onChange={(e) => setBranchId(e.target.value)}
              className="w-full h-9 rounded-md border border-input bg-background px-3 text-sm"
            >
              <option value="">Select branch…</option>
              {branches.map((b) => (
                <option key={b.id} value={b.id}>{b.name}</option>
              ))}
            </select>
          </div>

          {/* Direction */}
          <div className="space-y-1.5">
            <label className="text-sm font-medium">Direction *</label>
            <div className="flex gap-2">
              {(["in", "out"] as const).map((d) => (
                <button
                  key={d}
                  type="button"
                  onClick={() => setDirection(d)}
                  className={cn(
                    "flex-1 rounded-md border py-2 text-sm font-medium transition-colors",
                    direction === d
                      ? d === "in"
                        ? "border-emerald-500 bg-emerald-50 text-emerald-700"
                        : "border-rose-500 bg-rose-50 text-rose-700"
                      : "border-input bg-background text-muted-foreground hover:bg-accent"
                  )}
                >
                  {d === "in" ? "➕ Stock In" : "➖ Stock Out"}
                </button>
              ))}
            </div>
          </div>

          {/* Quantity */}
          <div className="space-y-1.5">
            <label className="text-sm font-medium">Quantity *</label>
            <Input
              type="number"
              min="0.001"
              step="0.001"
              required
              placeholder="0.000"
              value={quantity}
              onChange={(e) => setQuantity(e.target.value)}
            />
          </div>

          {/* Reason Code */}
          <div className="space-y-1.5">
            <label className="text-sm font-medium">Reason Code</label>
            <select
              value={reasonCode}
              onChange={(e) => setReasonCode(e.target.value)}
              className="w-full h-9 rounded-md border border-input bg-background px-3 text-sm"
            >
              <option value="">Select reason…</option>
              {REASON_CODES.map((r) => (
                <option key={r} value={r}>{r.replace(/_/g, " ")}</option>
              ))}
            </select>
          </div>

          {/* Notes */}
          <div className="space-y-1.5">
            <label className="text-sm font-medium">Notes</label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="Optional note for audit trail…"
              rows={3}
              className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm resize-none"
            />
          </div>

          {/* Submit */}
          <Button type="submit" disabled={loading} className="w-full">
            {loading ? "Posting adjustment…" : "Post Adjustment"}
          </Button>
        </form>
      </div>
    </AppShell>
  );
}
