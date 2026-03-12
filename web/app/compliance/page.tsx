"use client";

import { useState, Suspense } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import { AppShell } from "@/components/layout";
import Gstr1Tab          from "./_tabs/Gstr1Tab";
import Gstr2bTab         from "./_tabs/Gstr2bTab";
import Gstr3bTab         from "./_tabs/Gstr3bTab";
import ReconciliationTab from "./_tabs/ReconciliationTab";
import VarianceTab       from "./_tabs/VarianceTab";
import AmendmentsTab     from "./_tabs/AmendmentsTab";

// -- Helpers --------------------------------------------------------------------

const _now         = new Date();
const currentYear  = _now.getFullYear();
const currentMonth = _now.getMonth() + 1;
const defaultMonth = currentMonth === 1 ? 12 : currentMonth - 1;
const defaultYear  = currentMonth === 1 ? currentYear - 1 : currentYear;

const MONTHS = [
  "January","February","March","April","May","June",
  "July","August","September","October","November","December",
];
const YEARS = Array.from({ length: 4 }, (_, i) => currentYear - i);

const sel = "h-9 rounded-md border border-border bg-background px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary";

// -- Tab definitions ------------------------------------------------------------

const TABS = [
  { key: "gstr1",          label: "GSTR-1",        subtitle: "Generate and download GST Return 1 data" },
  { key: "gstr2b",         label: "GSTR-2B",        subtitle: "Import GSTR-2B JSON and reconcile with purchase books" },
  { key: "gstr3b",         label: "GSTR-3B",        subtitle: "Compute monthly summary return from books" },
  { key: "reconciliation", label: "Reconciliation", subtitle: "Review and resolve discrepancies between books and portal" },
  { key: "variance",       label: "Variance",       subtitle: "Compare GSTR-1 / GSTR-2B / GSTR-3B for filing readiness" },
  { key: "amendments",     label: "Amendments",     subtitle: "Documents changed after filing, include in GSTR-1A" },
] as const;

type TabKey = typeof TABS[number]["key"];

// -- Inner component (needs Suspense boundary for useSearchParams) -------------

function ComplianceContent() {
  const searchParams = useSearchParams();
  const router       = useRouter();

  const tabParam  = searchParams.get("tab") as TabKey | null;
  const activeTab: TabKey = TABS.find(t => t.key === tabParam) ? tabParam! : "gstr1";

  const [month, setMonth] = useState(defaultMonth);
  const [year,  setYear]  = useState(defaultYear);

  const setTab = (key: TabKey) => router.replace(`/compliance?tab=${key}`);

  const tabMeta = TABS.find(t => t.key === activeTab)!;

  return (
    <AppShell title="GSTR Filing" hideBreadcrumb>
      {/* -- Header + period selector in one row -------------------------- */}
      <div className="flex items-center justify-between gap-4 mb-6 flex-wrap">
        <div>
          <h1 className="text-xl font-semibold text-text-primary">GST Compliance</h1>
          <p className="text-sm text-text-secondary">{tabMeta.subtitle}</p>
        </div>
        <div className="flex items-center gap-2 flex-shrink-0">
          <label className="text-sm font-medium text-text-secondary">Month</label>
          <select className={sel} value={month} onChange={e => setMonth(Number(e.target.value))}>
            {MONTHS.map((m, i) => <option key={i + 1} value={i + 1}>{m}</option>)}
          </select>
          <label className="text-sm font-medium text-text-secondary">Year</label>
          <select className={sel} value={year} onChange={e => setYear(Number(e.target.value))}>
            {YEARS.map(y => <option key={y} value={y}>{y}</option>)}
          </select>
          <span className="text-xs text-text-secondary px-2 py-1 rounded bg-muted border whitespace-nowrap">
            {MONTHS[month - 1]} {year}
          </span>
        </div>
      </div>

      {/* -- Tab strip ---------------------------------------------------- */}
      <div className="border-b mb-6">
        <nav className="flex gap-0 overflow-x-auto">
          {TABS.map(tab => (
            <button
              key={tab.key}
              onClick={() => setTab(tab.key)}
              className={`px-5 py-2.5 text-sm font-medium border-b-2 whitespace-nowrap transition-colors ${
                activeTab === tab.key
                  ? "border-primary text-primary"
                  : "border-transparent text-text-secondary hover:text-text-primary hover:border-border"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </nav>
      </div>

      {/* -- Active tab --------------------------------------------------- */}
      {activeTab === "gstr1"          && <Gstr1Tab          month={month} year={year} />}
      {activeTab === "gstr2b"         && <Gstr2bTab         month={month} year={year} />}
      {activeTab === "gstr3b"         && <Gstr3bTab         month={month} year={year} />}
      {activeTab === "reconciliation" && <ReconciliationTab month={month} year={year} />}
      {activeTab === "variance"       && <VarianceTab       month={month} year={year} />}
      {activeTab === "amendments"     && <AmendmentsTab     month={month} year={year} />}
    </AppShell>
  );
}

// -- Page (Suspense wrapper required by useSearchParams) ------------------------

export default function CompliancePage() {
  return (
    <Suspense fallback={null}>
      <ComplianceContent />
    </Suspense>
  );
}
