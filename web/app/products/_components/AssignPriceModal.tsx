"use client";

import { useState, useEffect } from "react";
import { X, PackagePlus, FolderOpen, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

// ─── Types ────────────────────────────────────────────────────────────────────
interface PriceList {
  id:          number;
  name:        string;
  list_type:   string;
  branch_id:   number | null;
  branch_name?: string;
}

interface Props {
  productId:   number;
  productName: string;
  token:       string;
  orgId:       string;
  branchId:    string; // "" = all branches
  onClose:     () => void;
  onAssigned:  () => void;
}

const SELECT_CLS =
  "w-full px-3 py-2 text-sm border border-border rounded-md bg-white focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary";

// ─── AssignPriceModal ─────────────────────────────────────────────────────────
export function AssignPriceModal({
  productId, productName, token, orgId, branchId, onClose, onAssigned,
}: Props) {
  const [priceLists,  setPriceLists]  = useState<PriceList[]>([]);
  const [listLoading, setListLoading] = useState(true);
  const [priceListId, setPriceListId] = useState("");
  const [unitPrice,   setUnitPrice]   = useState("");
  const [minQty,      setMinQty]      = useState("");
  const [discountPct, setDiscountPct] = useState("");
  const [saving,      setSaving]      = useState(false);
  const [errors,      setErrors]      = useState<string[]>([]);

  // Load price lists, defaulting to current branch if set
  useEffect(() => {
    const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };
    const url = branchId
      ? `http://localhost:3001/api/v1/price_lists?branch_id=${branchId}&per_page=50`
      : `http://localhost:3001/api/v1/price_lists?per_page=50`;
    setListLoading(true);
    fetch(url, { headers })
      .then((r) => r.json())
      .then((j) => {
        const lists: PriceList[] = j.data ?? [];
        setPriceLists(lists);
        // Pre-select standard list, or first one available
        const standard = lists.find((l) => l.list_type === "standard") ?? lists[0];
        if (standard) setPriceListId(String(standard.id));
      })
      .catch(() => {/* silently handle */})
      .finally(() => setListLoading(false));
  }, [token, orgId, branchId]);

  const handleSave = async () => {
    if (!priceListId || !unitPrice) {
      setErrors(["Price list and unit price are required."]);
      return;
    }
    setSaving(true);
    setErrors([]);
    try {
      const res = await fetch(
        `http://localhost:3001/api/v1/price_lists/${priceListId}/items`,
        {
          method:  "POST",
          headers: {
            "Content-Type":      "application/json",
            Authorization:       `Bearer ${token}`,
            "X-Organization-Id": orgId,
          },
          body: JSON.stringify({
            price_list_item: {
              product_id:   productId,
              unit_price:   parseFloat(unitPrice),
              ...(minQty      && { min_qty:      parseInt(minQty)           }),
              ...(discountPct && { discount_pct: parseFloat(discountPct)    }),
            },
          }),
        },
      );
      const json = await res.json();
      if (res.ok) {
        onAssigned();
      } else {
        setErrors(json.errors ?? ["Failed to assign to price list."]);
      }
    } finally {
      setSaving(false);
    }
  };

  // Close on backdrop click
  const handleBackdrop = (e: React.MouseEvent<HTMLDivElement>) => {
    if (e.target === e.currentTarget) onClose();
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      onMouseDown={handleBackdrop}
    >
      <div className="w-full max-w-md rounded-lg bg-white border border-border shadow-xl">

        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-border">
          <div>
            <h2 className="text-base font-semibold text-text-primary">Assign to Price List</h2>
            <p className="mt-0.5 text-xs text-text-secondary truncate max-w-xs">{productName}</p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-md text-text-secondary hover:text-text-primary hover:bg-background-subtle"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        {/* Body */}
        <div className="px-5 py-4 space-y-4">
          {errors.length > 0 && (
            <div className="rounded-md bg-danger/10 border border-danger/20 px-3 py-2">
              {errors.map((e, i) => (
                <p key={i} className="text-sm text-danger">{e}</p>
              ))}
            </div>
          )}

          {listLoading ? (
            <p className="text-sm text-text-secondary py-2">Loading price lists…</p>
          ) : priceLists.length === 0 ? (

            /* ── Empty state ─────────────────────────────────────────────── */
            <div className="rounded-md border border-border bg-background-subtle p-5 text-center">
              <FolderOpen className="mx-auto h-8 w-8 text-text-secondary mb-2" />
              <p className="text-sm font-medium text-text-primary mb-1">No price lists found</p>
              <p className="text-xs text-text-secondary mb-4">
                {branchId
                  ? "No Standard price list found for this branch."
                  : "No price lists have been created for this organisation yet."}
              </p>
              <Button
                size="sm"
                variant="outline"
                onClick={() => { onClose(); window.location.href = "/products/price-lists"; }}
              >
                <Plus className="h-3.5 w-3.5 mr-1.5" />
                Create Standard Price List
              </Button>
            </div>

          ) : (
            <>
              {/* Price list selector */}
              <div>
                <label className="text-sm font-medium text-text-primary mb-1 block">
                  Price List <span className="text-danger">*</span>
                </label>
                <select
                  value={priceListId}
                  onChange={(e) => setPriceListId(e.target.value)}
                  className={SELECT_CLS}
                >
                  {priceLists.map((pl) => (
                    <option key={pl.id} value={pl.id}>
                      {pl.name}
                      {pl.branch_name ? ` — ${pl.branch_name}` : ""}
                      {" "}({pl.list_type})
                    </option>
                  ))}
                </select>
              </div>

              {/* Unit Price */}
              <div>
                <label className="text-sm font-medium text-text-primary mb-1 block">
                  Unit Price (₹) <span className="text-danger">*</span>
                </label>
                <Input
                  type="number"
                  min="0"
                  step="0.01"
                  value={unitPrice}
                  onChange={(e) => setUnitPrice(e.target.value)}
                  placeholder="0.00"
                  required
                />
              </div>

              {/* Min Qty + Discount */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-sm font-medium text-text-primary mb-1 block">Min Qty</label>
                  <Input
                    type="number"
                    min="1"
                    value={minQty}
                    onChange={(e) => setMinQty(e.target.value)}
                    placeholder="1"
                  />
                </div>
                <div>
                  <label className="text-sm font-medium text-text-primary mb-1 block">Discount %</label>
                  <Input
                    type="number"
                    min="0"
                    max="100"
                    step="0.01"
                    value={discountPct}
                    onChange={(e) => setDiscountPct(e.target.value)}
                    placeholder="0"
                  />
                </div>
              </div>
            </>
          )}
        </div>

        {/* Footer — only shown when there are price lists to assign to */}
        {!listLoading && priceLists.length > 0 && (
          <div className="flex items-center justify-end gap-3 px-5 py-4 border-t border-border">
            <Button type="button" variant="outline" onClick={onClose} disabled={saving}>
              Cancel
            </Button>
            <Button
              onClick={handleSave}
              disabled={saving || !unitPrice || !priceListId}
              isLoading={saving}
            >
              <PackagePlus className="h-4 w-4 mr-2" />
              {saving ? "Saving…" : "Assign & Continue"}
            </Button>
          </div>
        )}
      </div>
    </div>
  );
}
