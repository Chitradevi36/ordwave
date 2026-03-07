"use client";

import Link from "next/link";
import { Wallet, CreditCard, AlertTriangle, Ban, DollarSign, ChevronRight } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { KpiCard } from "@/components/dashboard/KpiCard";
import type { DashboardData } from "@/lib/api/hooks/useDashboard";

// ── Formatters ──────────────────────────────────────────────────────────────
function fmt(val: string | number | null | undefined, compact = false): string {
  if (val == null) return "—";
  const n = typeof val === "string" ? parseFloat(val) : (val as number);
  if (isNaN(n)) return String(val);
  if (compact) {
    if (n >= 10_00_000) return "₹" + (n / 10_00_000).toFixed(1) + "Cr";
    if (n >= 1_00_000)  return "₹" + (n / 1_00_000).toFixed(1) + "L";
    if (n >= 1_000)     return "₹" + (n / 1_000).toFixed(1) + "K";
  }
  return "₹" + n.toLocaleString("en-IN", { maximumFractionDigits: 0 });
}

interface RiskRowProps {
  label: string;
  value: number | string;
  suffix?: string;
  href: string;
  warn: boolean;
}

function RiskRow({ label, value, suffix = "", href, warn }: RiskRowProps) {
  return (
    <Link
      href={href}
      className="flex items-center justify-between rounded px-2 py-1 hover:bg-background-subtle transition-colors text-sm group"
    >
      <span className="text-text-secondary group-hover:text-text-primary transition-colors">{label}</span>
      <span className={`font-semibold tabular-nums ${warn ? "text-danger" : "text-text-primary"}`}>
        {typeof value === "number" ? value.toLocaleString("en-IN") : value}
        {suffix && <span className="ml-1 text-xs font-normal text-text-secondary">{suffix}</span>}
      </span>
    </Link>
  );
}

const QUICK_LINKS = [
  { label: "Finance Overview",  href: "/finance",                icon: DollarSign },
  { label: "Collections",       href: "/collections",            icon: Wallet },
  { label: "Sales Invoices",    href: "/sales-invoices",         icon: CreditCard },
  { label: "Credit Notes",      href: "/credit-notes",           icon: AlertTriangle },
  { label: "Advance Payments",  href: "/advance-payments",       icon: ChevronRight },
];

interface Props {
  data: DashboardData | undefined;
  isLoading: boolean;
  isError: boolean;
}

export function AccountantView({ data, isLoading, isError }: Props) {
  const collectionRate = Number(data?.collections.collection_rate ?? 0);

  return (
    <div className="space-y-5">
      {/* ── KPI row ──────────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <KpiCard
          label="Collections (MTD)"
          value={isLoading ? "" : fmt(data?.collections.mtd, true)}
          icon={Wallet}
          color="green"
          loading={isLoading}
          error={isError}
        />
        <KpiCard
          label="Outstanding"
          value={isLoading ? "" : fmt(data?.collections.outstanding, true)}
          icon={CreditCard}
          color={data && data.collections.outstanding > 0 ? "amber" : "green"}
          loading={isLoading}
          error={isError}
        />
        <KpiCard
          label="Overdue"
          value={isLoading ? "" : fmt(data?.collections.overdue, true)}
          icon={AlertTriangle}
          color={data && data.collections.overdue > 0 ? "red" : "green"}
          loading={isLoading}
          error={isError}
        />
        <KpiCard
          label="Collection Rate"
          value={isLoading ? "" : collectionRate.toFixed(1) + "%"}
          icon={DollarSign}
          color={collectionRate >= 80 ? "green" : collectionRate >= 60 ? "amber" : "red"}
          loading={isLoading}
          error={isError}
        />
      </div>

      {/* ── Body row: risk + quick links ─────────────────────────────────── */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">

        {/* Credit risk */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-semibold">Credit Risk</CardTitle>
          </CardHeader>
          <CardContent className="space-y-1">
            {isLoading ? (
              <div className="space-y-2">
                {[1, 2, 3].map((i) => <div key={i} className="h-7 w-full rounded bg-gray-100 animate-pulse" />)}
              </div>
            ) : (
              <>
                <RiskRow label="Risky Accounts"  value={data?.credit.risky_accounts ?? 0}   href="/approvals/credit-limits" warn={Boolean(data?.credit.risky_accounts)} />
                <RiskRow label="Blocked Accounts" value={data?.credit.blocked_accounts ?? 0} href="/approvals/credit-limits" warn={Boolean(data?.credit.blocked_accounts)} />
                <RiskRow label="Total Overdue"    value={fmt(data?.credit.total_overdue, true)} href="/finance" warn={Boolean(data?.credit.total_overdue && data.credit.total_overdue > 0)} />
              </>
            )}
          </CardContent>
        </Card>

        {/* Quick links */}
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-semibold">Finance Shortcuts</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <ul className="divide-y divide-border">
              {QUICK_LINKS.map(({ label, href, icon: Icon }) => (
                <li key={href}>
                  <Link
                    href={href}
                    className="flex items-center gap-3 px-5 py-3 hover:bg-background-subtle transition-colors text-sm group"
                  >
                    <Icon className="h-4 w-4 text-text-secondary group-hover:text-accent transition-colors" />
                    <span className="flex-1 text-text-primary">{label}</span>
                    <ChevronRight className="h-3.5 w-3.5 text-text-secondary group-hover:text-accent transition-colors" />
                  </Link>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>
      </div>

      {/* ── Today's summary strip ─────────────────────────────────────────── */}
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm font-semibold">Today at a Glance</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-4 text-center">
            <div>
              <p className="text-lg font-bold text-text-primary">{isLoading ? "—" : fmt(data?.collections.today, true)}</p>
              <p className="text-xs text-text-secondary">Collected Today</p>
            </div>
            <div>
              <p className="text-lg font-bold text-text-primary">{isLoading ? "—" : fmt(data?.revenue.today_invoiced, true)}</p>
              <p className="text-xs text-text-secondary">Invoiced Today</p>
            </div>
            <div>
              <p className={`text-lg font-bold ${data && data.collections.overdue > 0 ? "text-danger" : "text-text-primary"}`}>
                {isLoading ? "—" : fmt(data?.collections.overdue, true)}
              </p>
              <p className="text-xs text-text-secondary">Total Overdue</p>
            </div>
            <div>
              <p className="text-lg font-bold text-text-primary">{isLoading ? "—" : collectionRate.toFixed(1) + "%"}</p>
              <p className="text-xs text-text-secondary">Collection Rate</p>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
