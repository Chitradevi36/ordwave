"use client";

import { useState, useEffect, useCallback } from "react";
import { AppShell, PageHeader } from "@/components/layout";
import { useOrgBranch } from "@/lib/org-branch-context";
import {
  TrendingUp,
  Wallet,
  AlertTriangle,
  MapPin,
  Package,
  RefreshCw,
} from "lucide-react";

const API = "http://localhost:3001";

function fmt(n: number | undefined | null, prefix = "") {
  if (n == null) return "—";
  return `${prefix}${Number(n).toLocaleString("en-IN")}`;
}

function fmtPct(n: number | undefined | null) {
  if (n == null) return "—";
  return `${Number(n).toFixed(1)}%`;
}

interface OverviewData {
  sales?: {
    count?: number;
    value?: number;
    outstanding?: number;
  };
  collections?: {
    payments_today?: number;
    payments_mtd?: number;
    collection_rate?: number;
    unpaid_invoices_count?: number;
  };
  credit_risk?: {
    risky_count?: number;
    blocked_count?: number;
    total_overdue?: number;
  };
  beat?: {
    visits_completed?: number;
    completion_rate?: number;
    order_conversion_rate?: number;
  };
  inventory?: {
    low_stock_count?: number;
    dead_stock_count?: number;
    total_skus?: number;
  };
}

export default function InsightsOverviewPage() {
  const { token, orgId } = useOrgBranch();
  const [data, setData] = useState<OverviewData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchData = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`${API}/api/v1/analytics/overview`, {
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
      });
      if (!res.ok) throw new Error("Failed to load overview");
      const json = await res.json();
      setData(json.data);
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Unknown error");
    } finally {
      setLoading(false);
    }
  }, [token, orgId]);

  useEffect(() => { void fetchData(); }, [fetchData]);

  const sections = [
    {
      title: "Sales",
      href: "/insights/sales",
      icon: TrendingUp,
      color: "text-primary",
      stats: [
        { label: "Orders",              value: fmt(data?.sales?.count) },
        { label: "Invoice Value",       value: fmt(data?.sales?.value, "₹") },
        { label: "Outstanding",         value: fmt(data?.sales?.outstanding, "₹") },
      ],
    },
    {
      title: "Collections",
      href: "/insights/collections",
      icon: Wallet,
      color: "text-secondary",
      stats: [
        { label: "Collected Today",     value: fmt(data?.collections?.payments_today, "₹") },
        { label: "MTD Collections",     value: fmt(data?.collections?.payments_mtd, "₹") },
        { label: "Collection Rate",     value: fmtPct(data?.collections?.collection_rate) },
        { label: "Unpaid Invoices",     value: fmt(data?.collections?.unpaid_invoices_count) },
      ],
    },
    {
      title: "Credit Risk",
      href: "/insights/credit-risk",
      icon: AlertTriangle,
      color: "text-warning",
      stats: [
        { label: "Risky Accounts",      value: fmt(data?.credit_risk?.risky_count) },
        { label: "Blocked Accounts",    value: fmt(data?.credit_risk?.blocked_count) },
        { label: "Total Overdue",       value: fmt(data?.credit_risk?.total_overdue, "₹") },
      ],
    },
    {
      title: "Beat Performance",
      href: "/insights/beat-performance",
      icon: MapPin,
      color: "text-accent",
      stats: [
        { label: "Visits Completed",    value: fmt(data?.beat?.visits_completed) },
        { label: "Completion Rate",     value: fmtPct(data?.beat?.completion_rate) },
        { label: "Order Conversion",    value: fmtPct(data?.beat?.order_conversion_rate) },
      ],
    },
    {
      title: "Inventory Health",
      href: "/insights/inventory",
      icon: Package,
      color: "text-error",
      stats: [
        { label: "Low Stock SKUs",      value: fmt(data?.inventory?.low_stock_count) },
        { label: "Dead Stock SKUs",     value: fmt(data?.inventory?.dead_stock_count) },
        { label: "Total SKUs Tracked",  value: fmt(data?.inventory?.total_skus) },
      ],
    },
  ];

  return (
    <AppShell title="Insights Overview">
      <PageHeader
        title="Insights"
        description="Operational overview across your business."
        actions={[
          { label: "Refresh", onClick: fetchData, icon: RefreshCw },
        ]}
      />

      {error && (
        <div className="mx-6 mb-4 rounded-md bg-danger/8 border border-danger/20 px-4 py-3 text-sm text-danger">
          {error}
        </div>
      )}

      {loading && !data && (
        <div className="flex items-center justify-center py-16">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      )}

      {(data || !loading) && (
        <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 xl:grid-cols-3 px-6 pb-6">
          {sections.map((section) => {
            const Icon = section.icon;
            return (
              <a key={section.href} href={section.href} className="block group">
                <div className="h-full rounded-lg border border-border bg-surface p-4 transition-shadow group-hover:shadow-md">
                  <div className="flex items-center gap-2 mb-3">
                    <Icon className={`h-5 w-5 ${section.color}`} />
                    <span className="text-base font-semibold text-text-primary">{section.title}</span>
                  </div>
                  <dl className="grid grid-cols-2 gap-3">
                    {section.stats.map((stat) => (
                      <div key={stat.label}>
                        <dt className="text-xs text-text-secondary">{stat.label}</dt>
                        <dd className="text-sm font-semibold text-text-primary mt-0.5">
                          {loading ? <span className="inline-block h-3 w-12 animate-pulse rounded bg-border" /> : stat.value}
                        </dd>
                      </div>
                    ))}
                  </dl>
                </div>
              </a>
            );
          })}
        </div>
      )}
    </AppShell>
  );
}
