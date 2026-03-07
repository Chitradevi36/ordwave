"use client";

import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";

import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";
import { Search, Plus } from "lucide-react";
import CreatePaymentModal from "@/components/payments/create-payment-modal";

// ── Constants ─────────────────────────────────────────────────────────────────

const STATUS_TABS = [
  { key: "",          label: "All" },
  { key: "draft",     label: "Draft" },
  { key: "confirmed", label: "Confirmed" },
  { key: "reversed",  label: "Reversed" },
];

const PAYMENT_MODE_LABELS: Record<string, string> = {
  cash:          "Cash",
  bank_transfer: "Bank Transfer",
  upi:           "UPI",
  cheque:        "Cheque",
  neft:          "NEFT",
  rtgs:          "RTGS",
  adjustment:    "Adjustment",
};

const STATUS_VARIANT: Record<string, "secondary" | "warning" | "success" | "danger"> = {
  draft:     "secondary",
  confirmed: "success",
  reversed:  "danger",
};

// ── Types ─────────────────────────────────────────────────────────────────────

interface PaymentSummary {
  id:                 number;
  payment_number:     string;
  received_date:      string;
  status:             string;
  payment_mode:       string;
  amount:             number;
  allocated_amount:   number;
  unallocated_amount: number;
  reference_number:   string | null;
  created_at:         string;
  customer:           { id: number; name: string };
  branch:             { id: number; code: string };
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const fmtCurrency = (n: number) =>
  `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

const fmtDate = (d: string | null) =>
  d ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—";

// ── Page ──────────────────────────────────────────────────────────────────────

export default function CollectionsPage() {
  const router           = useRouter();
  const { token, orgId } = useOrgBranch();

  const [payments, setPayments]     = useState<PaymentSummary[]>([]);
  const [loading, setLoading]       = useState(true);
  const [activeTab, setActiveTab]   = useState("");
  const [search, setSearch]         = useState("");
  const [page, setPage]             = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [counts, setCounts]         = useState<Record<string, number>>({});
  const [showCreate, setShowCreate] = useState(false);

  const fetchPayments = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(page), per_page: "25" });
      if (activeTab) params.set("status", activeTab);
      if (search)    params.set("q", search);

      const res = await fetch(`/api/v1/payments?${params}`, {
        headers: {
          Authorization:      `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
      });
      const json = await res.json();
      if (res.ok) {
        setPayments(json.data ?? []);
        setTotalPages(json.meta?.total_pages ?? 1);
        setCounts(json.meta?.counts ?? {});
      }
    } finally {
      setLoading(false);
    }
  }, [token, orgId, page, activeTab, search]);

  useEffect(() => { fetchPayments(); }, [fetchPayments]);

  const columns: Column<PaymentSummary>[] = [
    {
      key:    "payment_number",
      header: "Payment #",
      render: (_, p) => <span className="font-mono text-sm font-semibold">{p.payment_number}</span>,
    },
    {
      key:    "customer",
      header: "Retailer",
      render: (_, p) => <span className="font-medium">{p.customer.name}</span>,
    },
    {
      key:    "amount",
      header: "Amount",
      render: (_, p) => <span className="font-semibold">{fmtCurrency(p.amount)}</span>,
    },
    {
      key:    "payment_mode",
      header: "Mode",
      render: (_, p) => PAYMENT_MODE_LABELS[p.payment_mode] ?? p.payment_mode,
    },
    {
      key:    "status",
      header: "Status",
      render: (_, p) => (
        <Badge variant={STATUS_VARIANT[p.status] ?? "secondary"}>
          {p.status.charAt(0).toUpperCase() + p.status.slice(1)}
        </Badge>
      ),
    },
    {
      key:    "received_date",
      header: "Received",
      render: (_, p) => fmtDate(p.received_date),
    },
    {
      key:    "allocated_amount",
      header: "Allocated",
      render: (_, p) => fmtCurrency(p.allocated_amount),
    },
    {
      key:    "unallocated_amount",
      header: "Unallocated",
      render: (_, p) =>
        p.unallocated_amount > 0
          ? <span className="text-amber-600 font-medium">{fmtCurrency(p.unallocated_amount)}</span>
          : <span className="text-text-secondary">—</span>,
    },
  ];

  const tabTotal = (key: string) =>
    key === "" ? Object.values(counts).reduce((s, v) => s + v, 0) : (counts[key] ?? 0);

  return (
    <AppShell>
      <PageHeader
        title="Payments & Collections"
        actions={[{ label: "Record Payment", onClick: () => setShowCreate(true), icon: Plus }]}
      />

      {/* Status Tabs */}
      <div className="flex items-center gap-1 border-b border-border mb-4 overflow-x-auto">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => { setActiveTab(tab.key); setPage(1); }}
            className={`flex items-center gap-1.5 px-4 py-2 text-sm font-medium whitespace-nowrap transition-colors ${
              activeTab === tab.key
                ? "border-b-2 border-accent text-accent"
                : "text-text-secondary hover:text-text-primary"
            }`}
          >
            {tab.label}
            <span className={`inline-flex items-center justify-center rounded-full min-w-[18px] px-1 py-0.5 text-[10px] font-medium ${
              activeTab === tab.key ? "bg-accent/10 text-accent" : "bg-background-subtle text-text-secondary"
            }`}>
              {tabTotal(tab.key)}
            </span>
          </button>
        ))}
      </div>

      {/* Search */}
      <div className="flex items-center gap-2 mb-4">
        <div className="relative flex-1 min-w-[180px] max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
          <Input
            placeholder="Search payment # or reference..."
            className="pl-9"
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1); }}
          />
        </div>
      </div>

      {/* Table */}
      <DataTable
        columns={columns}
        data={payments}
        isLoading={loading}
        onRowClick={(row) => router.push(`/collections/${row.id}`)}
        emptyMessage="No payments recorded yet."
      />

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex justify-center gap-2 mt-6">
          <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
            Previous
          </Button>
          <span className="px-3 py-1.5 text-sm text-text-secondary">
            Page {page} of {totalPages}
          </span>
          <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
            Next
          </Button>
        </div>
      )}

      {/* Create Modal */}
      {showCreate && (
        <CreatePaymentModal
          onClose={() => setShowCreate(false)}
          onCreated={() => { setShowCreate(false); fetchPayments(); }}
        />
      )}
    </AppShell>
  );
}
