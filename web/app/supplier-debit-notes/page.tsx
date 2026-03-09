"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { Plus } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

interface SupplierDebitNote {
  id:            number;
  note_number:   string;
  note_date:     string;
  status:        "draft" | "issued" | "void";
  reason:        string | null;
  total_amount:  number;
  currency:      string;
  created_at:    string;
  supplier:      { id: number; name: string; code: string };
  branch:        { id: number; name: string };
  purchase_invoice: { id: number; invoice_number: string } | null;
}

const STATUS_VARIANT: Record<string, "secondary" | "warning" | "success" | "danger"> = {
  draft:  "secondary",
  issued: "success",
  void:   "danger",
};

const fmtDate = (d: string) =>
  new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });

const fmt = (n: number) =>
  `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

// ── Page ──────────────────────────────────────────────────────────────────────

export default function SupplierDebitNotesPage() {
  const router           = useRouter();
  const { token, orgId } = useOrgBranch();

  const [notes, setNotes]       = useState<SupplierDebitNote[]>([]);
  const [loading, setLoading]   = useState(true);
  const [error, setError]       = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<"all" | "draft" | "issued" | "void">("all");
  const [search, setSearch]     = useState("");

  const fetchNotes = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const params = new URLSearchParams();
      if (statusFilter !== "all") params.set("status", statusFilter);
      if (search.trim()) params.set("q", search.trim());
      const res = await fetch(`${API_URL}/api/v1/supplier_debit_notes?${params}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      const body = await res.json();
      if (!res.ok) throw new Error(body.errors?.join(", ") || "Failed to load debit notes");
      setNotes(body.data ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId, statusFilter, search]);

  useEffect(() => { fetchNotes(); }, [fetchNotes]);

  return (
    <AppShell breadcrumbs={[
      { label: "Finance",               href: "/finance" },
      { label: "Supplier Debit Notes" },
    ]}>
      <PageHeader
        title="Supplier Debit Notes"
        subtitle="Track debit notes raised against suppliers"
        actions={[
          { label: "New Debit Note", onClick: () => router.push("/supplier-debit-notes/new"), icon: Plus },
        ]}
      />

      {/* Filters */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="flex rounded-md border overflow-hidden text-sm">
          {(["all", "draft", "issued", "void"] as const).map((s) => (
            <button
              key={s}
              onClick={() => setStatusFilter(s)}
              className={`px-3 py-1.5 capitalize transition-colors ${
                statusFilter === s
                  ? "bg-primary text-primary-foreground font-medium"
                  : "bg-background text-text-secondary hover:bg-muted/40"
              }`}
            >
              {s}
            </button>
          ))}
        </div>
        <input
          type="search"
          placeholder="Search note number or supplier…"
          className="h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary w-64"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {error && (
        <div className="rounded-md bg-destructive/10 border border-destructive/30 px-4 py-3 text-sm text-destructive">
          {error}
        </div>
      )}

      {loading ? (
        <div className="py-12 text-center text-sm text-text-secondary">Loading…</div>
      ) : (
        <div className="rounded-lg border overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-muted/40">
              <tr>
                {["Note #", "Date", "Supplier", "Branch", "Linked Invoice", "Amount", "Status"].map((h) => (
                  <th key={h} className="px-3 py-2.5 text-left text-xs font-semibold text-text-secondary">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y">
              {notes.length === 0 ? (
                <tr>
                  <td colSpan={7} className="px-3 py-12 text-center text-text-secondary">
                    No supplier debit notes found
                  </td>
                </tr>
              ) : notes.map((n) => (
                <tr
                  key={n.id}
                  className="hover:bg-muted/20 cursor-pointer"
                  onClick={() => router.push(`/supplier-debit-notes/${n.id}`)}
                >
                  <td className="px-3 py-3 font-mono text-xs font-medium text-primary">{n.note_number}</td>
                  <td className="px-3 py-3 text-text-secondary">{fmtDate(n.note_date)}</td>
                  <td className="px-3 py-3">
                    <div className="font-medium">{n.supplier.name}</div>
                    <div className="text-xs text-text-secondary">{n.supplier.code}</div>
                  </td>
                  <td className="px-3 py-3 text-text-secondary">{n.branch.name}</td>
                  <td className="px-3 py-3 font-mono text-xs">
                    {n.purchase_invoice?.invoice_number ?? "—"}
                  </td>
                  <td className="px-3 py-3 font-semibold">{fmt(n.total_amount)}</td>
                  <td className="px-3 py-3">
                    <Badge variant={STATUS_VARIANT[n.status] ?? "secondary"} className="capitalize">
                      {n.status}
                    </Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </AppShell>
  );
}
