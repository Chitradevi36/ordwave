"use client";

import Link from "next/link";
import { useState, useEffect, useCallback } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
// Bank reconciliation imports
import { useBankTransactions } from "@/lib/api/hooks/useBankTransactions";
import type { BankTransaction, TxnTab, TxnStatus } from "@/types/bankReconciliation";
import { ReviewDrawer } from "@/components/bank-reconciliation/ReviewDrawer";
import { ImportScreen } from "@/components/bank-reconciliation/ImportScreen";
import { Upload, Search, Plus, Download, Wallet, Building2 } from "lucide-react";

import { DataTable, Column } from "@/components/ui/data-table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useOrgBranch } from "@/lib/org-branch-context";
import CreatePaymentModal from "@/components/payments/create-payment-modal";
import { collectionEvents } from "@/lib/analytics";
import { useCreditRisk } from "@/lib/api/hooks/useCreditRisk";

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

// ── Bank Reconciliation constants ─────────────────────────────────────────────

const TXN_TABS: { key: TxnTab; label: string; status: TxnStatus }[] = [
  { key: "auto_matched", label: "Auto Matched", status: "auto_matched" },
  { key: "suggested",    label: "Needs Review",  status: "suggested"   },
  { key: "unmatched",    label: "Unmatched",     status: "unmatched"   },
  { key: "matched",      label: "History",       status: "matched"     },
  { key: "ignored",      label: "Ignored",       status: "ignored"     },
];

const TXN_STATUS_VARIANT: Record<string, "success" | "warning" | "danger" | "secondary" | "default"> = {
  auto_matched: "success",
  suggested:    "warning",
  unmatched:    "danger",
  matched:      "default",
  ignored:      "secondary",
};

function ScoreBadge({ score }: { score: number }) {
  const variant = score >= 95 ? "success" : score >= 80 ? "warning" : "danger";
  return <Badge variant={variant}>{score.toFixed(0)}</Badge>;
}

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

interface QueueCustomerAction {
  id: number;
  name: string;
  overdueAmount: number;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const fmtCurrency = (n: number) =>
  `₹ ${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2 })}`;

const fmtDate = (d: string | null) =>
  d ? new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) : "—";

// ── Page ──────────────────────────────────────────────────────────────────────

export default function CollectionsPage() {
  const router           = useRouter();
  const searchParams     = useSearchParams();
  const { token, orgId } = useOrgBranch();
  const { data: creditRisk, isLoading: creditRiskLoading } = useCreditRisk();

  // Top-level section: "collections" | "bank"
  const section = searchParams.get("section") === "bank" ? "bank" : "collections";
  function setSection(s: "collections" | "bank") {
    const params = new URLSearchParams(searchParams.toString());
    if (s === "bank") params.set("section", "bank");
    else params.delete("section");
    router.replace(`/collections?${params.toString()}`);
  }

  // ── Collections state ────────────────────────────────────────────────────────
  const [payments, setPayments]     = useState<PaymentSummary[]>([]);
  const [loading, setLoading]       = useState(true);
  const [activeTab, setActiveTab]   = useState("");
  const [search, setSearch]         = useState("");
  const [page, setPage]             = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [counts, setCounts]         = useState<Record<string, number>>({});
  const [showCreate, setShowCreate] = useState(false);
  const [exporting, setExporting]   = useState(false);
  const [queueCustomer, setQueueCustomer] = useState<QueueCustomerAction | null>(null);

  // ── Bank Reconciliation state ─────────────────────────────────────────────
  const [activeTxnTab, setActiveTxnTab]   = useState<TxnTab>("suggested");
  const [txnPage, setTxnPage]             = useState(1);
  const [selectedTxn, setSelectedTxn]     = useState<BankTransaction | null>(null);
  const [showImport, setShowImport]       = useState(false);

  const txnStatusParam = TXN_TABS.find((t) => t.key === activeTxnTab)?.status;
  const { data: txnData, isLoading: txnLoading, refetch: txnRefetch } = useBankTransactions({
    status: txnStatusParam,
    page:   txnPage,
    per_page: 25,
  });
  const transactions = txnData?.data ?? [];
  const txnMeta      = txnData?.meta;

  // ── Collections fetch ────────────────────────────────────────────────────────
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

  const handleExportCsv = useCallback(async () => {
    if (!token || !orgId || exporting) return;
    setExporting(true);
    try {
      const params = new URLSearchParams({ per_page: "5000" });
      if (activeTab) params.set("status", activeTab);
      if (search)    params.set("q", search);
      const res  = await fetch(`/api/v1/payments?${params}`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (!res.ok) return;
      const body = await res.json();
      const rows: PaymentSummary[] = body.data ?? [];
      const header = ["Payment #", "Customer", "Date", "Mode", "Amount", "Allocated", "Unallocated", "Status", "Ref #"].join(",");
      const lines  = rows.map((p) =>
        [p.payment_number, `"${p.customer.name}"`, p.received_date, p.payment_mode,
         p.amount, p.allocated_amount, p.unallocated_amount, p.status, p.reference_number ?? ""].join(",")
      );
      const csv  = [header, ...lines].join("\n");
      const blob = new Blob([csv], { type: "text/csv" });
      const url  = URL.createObjectURL(blob);
      const a    = document.createElement("a");
      a.href     = url;
      a.download = `payments_${new Date().toISOString().slice(0, 10)}.csv`;
      a.click();
      URL.revokeObjectURL(url);

      // Track export event
      collectionEvents.generateFinanceReport("collections", "all", rows.length);
    } finally {
      setExporting(false);
    }
  }, [token, orgId, activeTab, search, exporting]);

  useEffect(() => { fetchPayments(); }, [fetchPayments]);

  // ── Collections columns ──────────────────────────────────────────────────────
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

  // ── Bank Reconciliation columns ──────────────────────────────────────────────
  const txnColumns: Column<BankTransaction>[] = [
    {
      key:    "txn_date",
      header: "Date",
      render: (_, row) => <span className="whitespace-nowrap text-sm">{fmtDate(row.txn_date)}</span>,
    },
    {
      key:    "narration",
      header: "Narration",
      render: (_, row) => (
        <span className="block max-w-xs truncate text-sm" title={row.narration}>{row.narration}</span>
      ),
    },
    {
      key:       "amount",
      header:    "Amount",
      className: "text-right",
      render: (_, row) => <span className="font-semibold text-sm">{fmtCurrency(row.amount)}</span>,
    },
    {
      key:    "status",
      header: "Status",
      render: (_, row) => (
        <Badge variant={TXN_STATUS_VARIANT[row.status] ?? "secondary"}>
          {row.status.replace(/_/g, " ")}
        </Badge>
      ),
    },
    {
      key:    "candidates",
      header: "Suggested Match",
      render: (_, row) => {
        const best = row.candidates.find((c) => c.selected);
        if (!best) return <span className="text-text-secondary">—</span>;
        return (
          <div className="text-sm">
            {best.customer_name && <span className="font-medium">{best.customer_name}</span>}
            {best.invoice_number && <span className="ml-1 text-text-secondary">· {best.invoice_number}</span>}
          </div>
        );
      },
    },
    {
      key:    "match_score",
      header: "Score",
      render: (_, row) => {
        const best = row.candidates.find((c) => c.selected);
        if (!best) return <span className="text-text-secondary">—</span>;
        return <ScoreBadge score={best.score} />;
      },
    },
    {
      key:    "id",
      header: "",
      render: (_, row) => (
        <Button size="sm" variant="outline"
          onClick={(e) => { e.stopPropagation(); setSelectedTxn(row); }}
        >
          Review
        </Button>
      ),
    },
  ];

  const tabTotal = (key: string) =>
    key === "" ? Object.values(counts).reduce((s, v) => s + v, 0) : (counts[key] ?? 0);

  const collectionQueue = [...(creditRisk?.risky_retailers ?? [])]
    .sort((a, b) => {
      if (b.overdue_amount !== a.overdue_amount) return b.overdue_amount - a.overdue_amount;
      return b.overdue_days - a.overdue_days;
    })
    .slice(0, 5);

  return (
    <>
      <AppShell>
        {/* Section switcher - elevated prominence */}
        <div className="bg-background-subtle border-b border-border mb-0">
          <div className="flex gap-0 overflow-x-auto">
            {([
              { key: "collections", label: "Payments & Collections", icon: Wallet },
              { key: "bank",        label: "Bank Reconciliation",    icon: Building2 },
            ] as const).map((s) => {
              const Icon = s.icon;
              return (
                <button
                  key={s.key}
                  onClick={() => setSection(s.key)}
                  className={`flex items-center gap-2 px-6 py-3.5 text-sm font-semibold whitespace-nowrap transition-all border-b-2 group ${
                    section === s.key
                      ? "border-accent text-accent"
                      : "border-transparent text-text-secondary hover:text-text-primary"
                  }`}
                >
                  <Icon className={`h-4 w-4 transition-colors ${
                    section === s.key ? "text-accent" : "text-text-secondary group-hover:text-text-primary"
                  }`} />
                  {s.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* ── Collections section ─────────────────────────────────────────────── */}
        {section === "collections" && (
          <>
            <PageHeader
              title=" "
              actions={[
                { label: exporting ? "Exporting…" : "Export CSV", onClick: handleExportCsv, icon: Download, variant: "outline" as const, disabled: exporting },
                { label: "Record Payment", onClick: () => setShowCreate(true), icon: Plus },
              ]}
            />

            <div className="mb-6 grid grid-cols-1 gap-4 xl:grid-cols-[1.2fr_0.8fr]">
              <div className="rounded-lg border border-border bg-background p-4 shadow-sm">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-sm font-semibold text-text-primary">Collections Action Queue</p>
                    <p className="mt-1 text-xs text-text-secondary">Start with the most overdue accounts and credit holds.</p>
                  </div>
                  <Link href="/insights/credit-risk" className="text-xs font-medium text-accent hover:underline">
                    Full credit view
                  </Link>
                </div>

                <div className="mt-4 space-y-2">
                  {creditRiskLoading ? (
                    [1, 2, 3].map((i) => <div key={i} className="h-20 animate-pulse rounded-lg bg-background-subtle" />)
                  ) : collectionQueue.length === 0 ? (
                    <div className="rounded-lg border border-border bg-background-subtle px-4 py-5 text-sm text-text-secondary">
                      No overdue accounts need action right now.
                    </div>
                  ) : (
                    collectionQueue.map((item) => (
                      <div
                        key={item.id}
                        className="rounded-lg border border-border px-3 py-3 transition-colors hover:bg-background-subtle"
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div className="min-w-0">
                            <div className="flex items-center gap-2">
                              <p className="truncate text-sm font-semibold text-text-primary">{item.customer_name}</p>
                              {item.hold_required && <Badge variant="danger" className="text-[10px]">Hold</Badge>}
                              {item.watchlist && <Badge variant="warning" className="text-[10px]">Watch</Badge>}
                            </div>
                            <p className="text-xs text-text-secondary">
                              {item.customer_code} • {item.overdue_days > 0 ? `${item.overdue_days}d overdue` : "Current"}
                            </p>
                          </div>
                          <div className="ml-4 shrink-0 text-right">
                            <p className="text-xs text-text-secondary">Overdue</p>
                            <p className="text-sm font-bold text-danger">{fmtCurrency(item.overdue_amount)}</p>
                          </div>
                        </div>

                        <div className="mt-3 flex flex-wrap gap-2">
                          <Link
                            href={`/customers/${item.customer_id}`}
                            className="rounded-md border border-border px-2.5 py-1.5 text-xs font-medium text-text-primary hover:bg-background-subtle"
                          >
                            Open account
                          </Link>
                          <button
                            type="button"
                            onClick={() => setQueueCustomer({ id: item.customer_id, name: item.customer_name, overdueAmount: item.overdue_amount })}
                            className="rounded-md bg-primary px-2.5 py-1.5 text-xs font-medium text-white hover:bg-primary-700"
                          >
                            Record payment
                          </button>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="rounded-lg border border-border bg-background p-4 shadow-sm">
                  <p className="text-xs text-text-secondary">Blocked Accounts</p>
                  <p className="mt-1 text-2xl font-bold text-danger">{creditRisk?.summary?.blocked_count ?? 0}</p>
                  <p className="mt-1 text-xs text-text-secondary">Need credit approval before normal dispatch resumes.</p>
                </div>
                <div className="rounded-lg border border-border bg-background p-4 shadow-sm">
                  <p className="text-xs text-text-secondary">Watchlist Accounts</p>
                  <p className="mt-1 text-2xl font-bold text-warning">{creditRisk?.summary?.watchlist_count ?? 0}</p>
                  <p className="mt-1 text-xs text-text-secondary">Accounts to chase before they turn into holds.</p>
                </div>
                <div className="rounded-lg border border-border bg-background p-4 shadow-sm">
                  <p className="text-xs text-text-secondary">Risky Accounts</p>
                  <p className="mt-1 text-2xl font-bold text-text-primary">{creditRisk?.summary?.risky_count ?? 0}</p>
                  <p className="mt-1 text-xs text-text-secondary">Overdue, blocked, or fully utilized accounts.</p>
                </div>
                <div className="rounded-lg border border-border bg-background p-4 shadow-sm">
                  <p className="text-xs text-text-secondary">Total Overdue</p>
                  <p className="mt-1 text-2xl font-bold text-danger">{fmtCurrency(Number(creditRisk?.summary?.total_overdue ?? 0))}</p>
                  <p className="mt-1 text-xs text-text-secondary">Cash exposure to prioritize in today&apos;s queue.</p>
                </div>
              </div>
            </div>

            {/* Status Tabs - enhanced styling */}
            <div className="flex items-center gap-1 border-b border-border border-opacity-50 mb-6 pb-0 overflow-x-auto">
              {STATUS_TABS.map((tab) => (
                <button
                  key={tab.key}
                  onClick={() => { setActiveTab(tab.key); setPage(1); }}
                  className={`flex items-center gap-2 px-4 py-3 text-sm font-semibold whitespace-nowrap transition-all border-b-2 ${
                    activeTab === tab.key
                      ? "border-accent text-accent shadow-sm"
                      : "border-transparent text-text-secondary hover:text-text-primary"
                  }`}
                >
                  {tab.label}
                  <span className={`inline-flex items-center justify-center rounded-full min-w-[20px] h-5 px-1.5 text-[10px] font-bold transition-all ${
                    activeTab === tab.key ? "bg-accent text-white" : "bg-background-subtle text-text-secondary"
                  }`}>
                    {tabTotal(tab.key)}
                  </span>
                </button>
              ))}
            </div>

            {/* Search - enhanced styling */}
            <div className="flex items-center gap-3 mb-6">
              <div className="relative flex-1 min-w-[180px] max-w-sm">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-secondary" />
                <Input
                  placeholder="Search payment # or reference..."
                  className="pl-10 bg-background-subtle border-border focus:bg-background transition-colors"
                  value={search}
                  onChange={(e) => { setSearch(e.target.value); setPage(1); }}
                />
              </div>
            </div>

            {/* Table - enhanced with better styling */}
            <div className="rounded-lg border border-border overflow-hidden shadow-sm">
              <DataTable
                columns={columns}
                data={payments}
                isLoading={loading}
                onRowClick={(row) => router.push(`/collections/${row.id}`)}
                emptyMessage="No payments recorded yet."
              />
            </div>

            {/* Pagination - improved styling */}
            {totalPages > 1 && (
              <div className="flex justify-center items-center gap-3 mt-8 py-4">
                <Button variant="outline" size="sm" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
                  Previous
                </Button>
                <div className="flex items-center gap-2 px-4 py-2 rounded-md bg-background-subtle">
                  <span className="text-sm font-medium text-text-primary">{page}</span>
                  <span className="text-xs text-text-secondary">/</span>
                  <span className="text-sm text-text-secondary">{totalPages}</span>
                </div>
                <Button variant="outline" size="sm" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
                  Next
                </Button>
              </div>
            )}

            {showCreate && (
              <CreatePaymentModal
                onClose={() => setShowCreate(false)}
                onCreated={() => { setShowCreate(false); fetchPayments(); }}
              />
            )}

            {queueCustomer && (
              <CreatePaymentModal
                prefilledCustomer={{ id: queueCustomer.id, name: queueCustomer.name }}
                defaultAmount={queueCustomer.overdueAmount}
                onClose={() => setQueueCustomer(null)}
                onCreated={() => { setQueueCustomer(null); fetchPayments(); }}
              />
            )}
          </>
        )}

        {/* ── Bank Reconciliation section ──────────────────────────────────────── */}
        {section === "bank" && (
          <>
            <PageHeader
              title=" "
              subtitle="Match incoming bank credits to invoices and customer payments."
              actions={[
                { label: "Upload Statement", onClick: () => setShowImport(true), icon: Upload },
              ]}
            />

            {/* Txn status tabs - enhanced styling */}
            <div className="flex gap-1 border-b border-border border-opacity-50 mb-6 pb-0 overflow-x-auto">
              {TXN_TABS.map((tab) => (
                <button
                  key={tab.key}
                  onClick={() => { setActiveTxnTab(tab.key); setTxnPage(1); }}
                  className={`px-5 py-3 text-sm font-semibold whitespace-nowrap transition-all border-b-2 ${
                    activeTxnTab === tab.key
                      ? "border-accent text-accent shadow-sm"
                      : "border-transparent text-text-secondary hover:text-text-primary"
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            <div className="rounded-lg border border-border overflow-hidden shadow-sm">
              <DataTable
                columns={txnColumns}
                data={transactions}
                isLoading={txnLoading}
                onRowClick={(row) => setSelectedTxn(row)}
                emptyMessage="No transactions in this category."
              />
            </div>

            {txnMeta && txnMeta.total_pages > 1 && (
              <div className="flex items-center justify-between mt-8 py-4">
                <span className="text-sm text-text-secondary">
                  {txnMeta.total_count} transactions · <span className="font-medium text-text-primary">Page {txnMeta.current_page}</span> of {txnMeta.total_pages}
                </span>
                <div className="flex gap-2">
                  <Button size="sm" variant="outline" disabled={txnPage <= 1} onClick={() => setTxnPage((p) => p - 1)}>
                    Previous
                  </Button>
                  <Button size="sm" variant="outline" disabled={txnPage >= txnMeta.total_pages} onClick={() => setTxnPage((p) => p + 1)}>
                    Next
                  </Button>
                </div>
              </div>
            )}
          </>
        )}
      </AppShell>

      {/* Bank Reconciliation overlays */}
      {selectedTxn && (
        <ReviewDrawer
          txn={selectedTxn}
          onClose={() => setSelectedTxn(null)}
          onSaved={() => { setSelectedTxn(null); txnRefetch(); }}
        />
      )}
      {showImport && (
        <ImportScreen
          onClose={() => setShowImport(false)}
          onImported={() => { setShowImport(false); txnRefetch(); }}
        />
      )}
    </>
  );
}
