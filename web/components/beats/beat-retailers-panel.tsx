"use client";

/**
 * BeatRetailersPanel
 * Full inline management of retailers for a beat schedule:
 *  - Schedule selector (weekday pills)
 *  - Editable retailer list (sequence↑↓, visit_override, remove)
 *  - Customer search to add new entries
 *  - Dirty-state Save button → POST bulk_upsert
 */

import React, { useCallback, useEffect, useRef, useState } from "react";
import { ChevronUp, ChevronDown, Search, Loader2, Trash2, Plus } from "lucide-react";
import { Badge } from "@/components/ui/badge";

// ── Types ─────────────────────────────────────────────────────────────────────

interface BeatSchedule {
  id: number;
  weekday: number;
  weekday_name: string;
  active: boolean;
}

interface RetailerRow {
  customer_id: number;
  customer_name: string;
  customer_code: string;
  sequence_number: number;
  visit_override: "default" | "force_include" | "force_exclude";
  notes: string;
}

interface CustomerResult {
  id: number;
  name: string;
  code: string;
}

interface Props {
  beatId: string;
  schedules: BeatSchedule[];
  initialScheduleId?: number | null;
  token: string;
  orgId: string;
  branchId: string;
}

const OVERRIDE_OPTIONS = [
  { value: "default",       label: "Default"       },
  { value: "force_include", label: "Force Include" },
  { value: "force_exclude", label: "Force Exclude" },
];

const OVERRIDE_VARIANTS: Record<string, "outline" | "success" | "danger"> = {
  default:       "outline",
  force_include: "success",
  force_exclude: "danger",
};

// ── CustomerSearch combobox ───────────────────────────────────────────────────

interface CustomerSearchProps {
  token: string;
  orgId: string;
  branchId: string;
  excludeIds: number[];
  onAdd: (c: CustomerResult) => void;
}

function CustomerSearch({ token, orgId, branchId, excludeIds, onAdd }: CustomerSearchProps) {
  const [query, setQuery]     = useState("");
  const [results, setResults] = useState<CustomerResult[]>([]);
  const [open, setOpen]       = useState(false);
  const [loading, setLoading] = useState(false);
  const debounceRef           = useRef<ReturnType<typeof setTimeout> | null>(null);

  const search = useCallback(
    (q: string) => {
      if (q.trim().length < 1) { setResults([]); setOpen(false); return; }
      setLoading(true);
      const qs = new URLSearchParams({ q, per_page: "20", status: "active" });
      if (branchId) qs.set("branch_id", branchId);
      fetch(`/api/v1/customers?${qs}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      })
        .then((r) => r.json())
        .then((d) => {
          const all: CustomerResult[] = d.data ?? [];
          setResults(all.filter((c) => !excludeIds.includes(c.id)));
          setOpen(true);
        })
        .catch(() => setResults([]))
        .finally(() => setLoading(false));
    },
    [token, orgId, branchId, excludeIds]
  );

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const q = e.target.value;
    setQuery(q);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => search(q), 280);
  }

  function handleSelect(c: CustomerResult) {
    onAdd(c);
    setQuery("");
    setResults([]);
    setOpen(false);
  }

  return (
    <div className="relative">
      <div className="relative">
        <Search className="absolute left-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground pointer-events-none" />
        {loading && (
          <Loader2 className="absolute right-2.5 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground animate-spin" />
        )}
        <input
          type="text"
          value={query}
          onChange={handleChange}
          onFocus={() => query.trim() && setOpen(true)}
          onBlur={() => setTimeout(() => setOpen(false), 150)}
          placeholder="Search customers to add…"
          className="w-full border border-border rounded-md py-2 pl-8 pr-8 text-sm bg-background focus:outline-none focus:ring-2 focus:ring-primary"
        />
      </div>

      {open && results.length > 0 && (
        <ul className="absolute z-10 mt-1 w-full bg-background border border-border rounded-md shadow-lg max-h-52 overflow-y-auto divide-y divide-border">
          {results.map((c) => (
            <li key={c.id}>
              <button
                type="button"
                onMouseDown={() => handleSelect(c)}
                className="w-full text-left px-3 py-2 text-sm hover:bg-muted transition-colors flex items-center gap-2"
              >
                <span className="font-mono text-xs text-muted-foreground">{c.code}</span>
                <span>{c.name}</span>
              </button>
            </li>
          ))}
        </ul>
      )}

      {open && !loading && results.length === 0 && query.trim() && (
        <div className="absolute z-10 mt-1 w-full bg-background border border-border rounded-md shadow-lg px-3 py-2 text-sm text-muted-foreground">
          No matching customers
        </div>
      )}
    </div>
  );
}

// ── Main panel ────────────────────────────────────────────────────────────────

export function BeatRetailersPanel({
  beatId,
  schedules,
  initialScheduleId,
  token,
  orgId,
  branchId,
}: Props) {
  const [selectedId, setSelectedId] = useState<number | null>(
    initialScheduleId ?? schedules[0]?.id ?? null
  );

  // Respond when parent changes the selected schedule (e.g. "Edit retailers" click)
  useEffect(() => {
    if (initialScheduleId != null) setSelectedId(initialScheduleId);
  }, [initialScheduleId]);
  const [rows, setRows] = useState<RetailerRow[]>([]);
  const [original, setOriginal] = useState<RetailerRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving]   = useState(false);
  const [saveError, setSaveError] = useState("");

  // is the current state different from what was last fetched?
  const isDirty = JSON.stringify(rows) !== JSON.stringify(original);

  // ── Fetch retailers for the selected schedule ───────────────────────────
  const fetchRetailers = useCallback(
    async (schedId: number) => {
      setLoading(true);
      try {
        const res = await fetch(
          `/api/v1/beats/${beatId}/schedules/${schedId}/retailers`,
          { headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId } }
        );
        const data = await res.json();
        const r: RetailerRow[] = (data.data ?? []).map((d: RetailerRow) => ({
          customer_id:     d.customer_id,
          customer_name:   d.customer_name,
          customer_code:   d.customer_code,
          sequence_number: d.sequence_number,
          visit_override:  d.visit_override as RetailerRow["visit_override"],
          notes:           d.notes ?? "",
        }));
        setRows(r);
        setOriginal(r);
      } finally {
        setLoading(false);
      }
    },
    [beatId, token, orgId]
  );

  useEffect(() => {
    if (selectedId) fetchRetailers(selectedId);
  }, [selectedId, fetchRetailers]);

  // ── Mutators ──────────────────────────────────────────────────────────────

  function moveUp(idx: number) {
    if (idx === 0) return;
    setRows((prev) => {
      const next = [...prev];
      [next[idx - 1], next[idx]] = [next[idx], next[idx - 1]];
      return next.map((r, i) => ({ ...r, sequence_number: i + 1 }));
    });
  }

  function moveDown(idx: number) {
    setRows((prev) => {
      if (idx >= prev.length - 1) return prev;
      const next = [...prev];
      [next[idx], next[idx + 1]] = [next[idx + 1], next[idx]];
      return next.map((r, i) => ({ ...r, sequence_number: i + 1 }));
    });
  }

  function setOverride(idx: number, value: RetailerRow["visit_override"]) {
    setRows((prev) => prev.map((r, i) => i === idx ? { ...r, visit_override: value } : r));
  }

  function removeRow(idx: number) {
    setRows((prev) => prev.filter((_, i) => i !== idx).map((r, i) => ({ ...r, sequence_number: i + 1 })));
  }

  function addCustomer(c: CustomerResult) {
    if (rows.some((r) => r.customer_id === c.id)) return;
    setRows((prev) => [
      ...prev,
      {
        customer_id:     c.id,
        customer_name:   c.name,
        customer_code:   c.code,
        sequence_number: prev.length + 1,
        visit_override:  "default",
        notes:           "",
      },
    ]);
  }

  // ── Save bulk_upsert ──────────────────────────────────────────────────────

  async function handleSave() {
    if (!selectedId) return;
    setSaving(true);
    setSaveError("");
    try {
      const res = await fetch(
        `/api/v1/beats/${beatId}/schedules/${selectedId}/bulk_upsert`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
            "X-Organization-Id": orgId,
          },
          body: JSON.stringify({
            retailers: rows.map((r, i) => ({
              customer_id:     r.customer_id,
              sequence_number: i + 1,
              visit_override:  r.visit_override,
              notes:           r.notes,
            })),
          }),
        }
      );
      const data = await res.json();
      if (res.ok) {
        await fetchRetailers(selectedId);             // re-sync from server
      } else {
        setSaveError((data.errors ?? []).join(", ") || "Save failed.");
      }
    } finally {
      setSaving(false);
    }
  }

  // ── Render ────────────────────────────────────────────────────────────────

  if (schedules.length === 0) {
    return (
      <div className="py-12 text-center text-muted-foreground text-sm">
        No schedules configured yet. Add a schedule from the Schedule tab first.
      </div>
    );
  }

  const selectedSched = schedules.find((s) => s.id === selectedId);

  return (
    <div className="space-y-4">
      {/* Schedule selector */}
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-sm text-muted-foreground mr-1">Schedule:</span>
        {schedules.map((s) => (
          <button
            key={s.id}
            type="button"
            onClick={() => {
              if (isDirty && !confirm("You have unsaved changes. Switch schedule?")) return;
              setSelectedId(s.id);
            }}
            className={`px-3 py-1.5 rounded-full text-sm font-medium border transition-colors ${
              selectedId === s.id
                ? "bg-primary text-white border-primary"
                : "bg-background border-border text-text-secondary hover:bg-muted"
            }`}
          >
            {s.weekday_name}
            {!s.active && (
              <span className="ml-1.5 text-xs opacity-70">(inactive)</span>
            )}
          </button>
        ))}
      </div>

      {/* Toolbar */}
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">
          {selectedSched
            ? `${rows.length} retailer${rows.length !== 1 ? "s" : ""} · ${selectedSched.weekday_name}`
            : ""}
        </p>
        <button
          type="button"
          disabled={!isDirty || saving}
          onClick={handleSave}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-md text-sm font-medium bg-primary text-white hover:bg-primary/90 disabled:opacity-40 transition-colors"
        >
          {saving && <Loader2 className="h-3.5 w-3.5 animate-spin" />}
          {saving ? "Saving…" : "Save changes"}
        </button>
      </div>

      {saveError && (
        <p className="text-sm text-destructive">{saveError}</p>
      )}

      {/* Retailer list */}
      {loading ? (
        <div className="flex justify-center py-8">
          <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" />
        </div>
      ) : (
        <div className="rounded-lg border border-border overflow-hidden">
          {rows.length === 0 ? (
            <div className="py-8 text-center text-sm text-muted-foreground">
              No retailers assigned. Use the search below to add customers.
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-muted/50 text-left text-muted-foreground text-xs">
                  <th className="px-3 py-2 w-10">#</th>
                  <th className="px-3 py-2">Customer</th>
                  <th className="px-3 py-2 w-40">Visit Override</th>
                  <th className="px-3 py-2 w-20 text-center">Reorder</th>
                  <th className="px-3 py-2 w-10"></th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {rows.map((row, idx) => (
                  <tr key={row.customer_id} className="bg-background hover:bg-muted/30 transition-colors">
                    <td className="px-3 py-2.5 text-muted-foreground font-mono text-xs">
                      {idx + 1}
                    </td>
                    <td className="px-3 py-2.5">
                      <div className="font-medium">{row.customer_name}</div>
                      <div className="text-xs text-muted-foreground font-mono">{row.customer_code}</div>
                    </td>
                    <td className="px-3 py-2.5">
                      <select
                        value={row.visit_override}
                        onChange={(e) =>
                          setOverride(idx, e.target.value as RetailerRow["visit_override"])
                        }
                        className="border border-border rounded px-2 py-1 text-xs bg-background focus:outline-none focus:ring-1 focus:ring-primary w-full"
                      >
                        {OVERRIDE_OPTIONS.map((o) => (
                          <option key={o.value} value={o.value}>
                            {o.label}
                          </option>
                        ))}
                      </select>
                    </td>
                    <td className="px-3 py-2.5">
                      <div className="flex items-center justify-center gap-1">
                        <button
                          type="button"
                          onClick={() => moveUp(idx)}
                          disabled={idx === 0}
                          className="p-0.5 rounded hover:bg-muted disabled:opacity-25"
                          title="Move up"
                        >
                          <ChevronUp className="h-3.5 w-3.5" />
                        </button>
                        <button
                          type="button"
                          onClick={() => moveDown(idx)}
                          disabled={idx === rows.length - 1}
                          className="p-0.5 rounded hover:bg-muted disabled:opacity-25"
                          title="Move down"
                        >
                          <ChevronDown className="h-3.5 w-3.5" />
                        </button>
                      </div>
                    </td>
                    <td className="px-3 py-2.5">
                      <button
                        type="button"
                        onClick={() => removeRow(idx)}
                        className="p-1 rounded hover:bg-destructive/10 hover:text-destructive transition-colors"
                        title="Remove"
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* Add customer search */}
      <div className="flex items-start gap-2">
        <div className="flex-1">
          <CustomerSearch
            token={token}
            orgId={orgId}
            branchId={branchId}
            excludeIds={rows.map((r) => r.customer_id)}
            onAdd={addCustomer}
          />
        </div>
        <div className="text-xs text-muted-foreground pt-2.5 whitespace-nowrap">
          <Plus className="h-3.5 w-3.5 inline mr-0.5" />
          type to search
        </div>
      </div>

      {isDirty && (
        <p className="text-xs text-amber-600 font-medium">
          • Unsaved changes — click &ldquo;Save changes&rdquo; to apply.
        </p>
      )}
    </div>
  );
}
