"use client";

import Link from "next/link";
import { useState } from "react";
import { TrackedLink } from "@/components/tracked-link";

/* Data */
const trustMetrics = [
  { value: "Credit-first", label: "Dispatch Control" },
  { value: "Collections", label: "Aging Priority" },
  { value: "Multi-branch", label: "Owner Visibility" },
  { value: "GST-ready", label: "India Operations" },
];

const challenges = [
	{ icon: "📋", title: "Manual Order Taking",     before: "Sales reps taking orders via calls and WhatsApp",        after: "Structured digital order capture with auto-validation" },
	{ icon: "📦", title: "Inventory Mismatch",      before: "Stock levels unknown until physical count",              after: "Real-time branch-wise inventory with low-stock alerts" },
	{ icon: "💸", title: "Outstanding Collections", before: "Finance teams chasing dues with no clear priority list", after: "Aging-based priority with one-click follow-up actions" },
	{ icon: "🚚", title: "Delivery Delays",         before: "No visibility on trip progress until calls",             after: "Live dispatch board with stop-level delivery status" },
	{ icon: "⚠️", title: "Credit Risk",             before: "Orders approved without checking credit limits",         after: "Automated credit gates before every order approval" },
	{ icon: "🏢", title: "Branch Visibility",       before: "Owner blind to what each branch is doing",              after: "Unified command center across all branches and teams" },
];

const whyCards = [
	{ icon: "📱", title: "Offline-Capable Field Ops", outcome: "Built for field execution", body: "Sales and delivery workflows are designed for field teams, with sync patterns for low-connectivity environments." },
	{ icon: "🏢", title: "Multi-Branch Control",      outcome: "One operating model",        body: "Run branch-level execution with central visibility for owners and operations leaders." },
	{ icon: "🛡️", title: "Credit-First Workflow",     outcome: "Reduce risky dispatch",      body: "Apply policy-based credit checks before order approval and dispatch." },
	{ icon: "📦", title: "Inventory Visibility",       outcome: "Branch-wise stock clarity", body: "Track on-hand, reserved, and available inventory at product and branch level." },
	{ icon: "🚚", title: "Delivery Execution",         outcome: "Stop-level tracking",        body: "Manage dispatch trips and stop updates with delivery confirmation controls." },
	{ icon: "💰", title: "Collections Discipline",     outcome: "Aging-aware recovery",       body: "Track payment schedules and aging to prioritize follow-ups." },
	{ icon: "🧾", title: "GST Workflows",              outcome: "India-ready operations",    body: "Support GST-related operational workflows including HSN/SAC and invoice processes." },
	{ icon: "🔌", title: "Integration-Ready",         outcome: "Scale without rework",       body: "Use built-in integration framework patterns for accounting and downstream systems." },
];

const industries = [
  { name: "FMCG Distribution",       desc: "High-volume beat operations with retailer CRM and credit control.", icon: "🛒" },
	{ name: "Rice Distribution",       desc: "SKU-level stock tracking for bulk staple distributor workflows.",   icon: "🌾" },
	{ name: "Pharma Distribution",     desc: "Batch tracking, expiry management, and compliant invoicing.",      icon: "💊" },
	{ name: "Electronics Distribution",desc: "Serialized stock, warranty dispatch, and route-wise delivery.",   icon: "⚡" },
	{ name: "Wholesale Distribution",  desc: "Multi-category order management with trade credit workflows.",    icon: "🏪" },
	{ name: "Multi-Branch Networks",   desc: "Central governance with branch-level execution autonomy.",        icon: "🏢" },
];

const workflowSteps = [
  { step: "Retailer", color: "#1B4332" },
  { step: "Order", color: "#0369A1" },
  { step: "Credit Check", color: "#713F12" },
  { step: "Approval", color: "#166534" },
  { step: "Inventory Allocation", color: "#1B4332" },
  { step: "Dispatch", color: "#0C4A6E" },
  { step: "Delivery", color: "#166534" },
  { step: "Collection", color: "#166534" },
];

const mobileApps = [
	{ name: "Sales Rep App",  icon: "📱", desc: "Offline-ready order booking, retailer profile, and target tracking for field sales.",     features: ["Offline order capture","Retailer outlet CRM","Daily target visibility","Route-wise navigation"] },
	{ name: "Driver App",     icon: "🚚", desc: "Route-optimized delivery list with stop-level status and proof-of-delivery capture.",      features: ["Trip assignment","Stop-level navigation","POD photo capture","Return management"] },
	{ name: "Collection App", icon: "💰", desc: "Prioritized dues list with payment recording, receipt generation, and reconciliation.",    features: ["Aging-based priority","Multi-mode payment","Digital receipt","Reconciliation sync"] },
];

const proofCards = [
  { title: "Credit hold before dispatch", team: "Owner + finance", problem: "Orders move to dispatch even when the retailer has crossed limit or aging rules.", outcome: "Orders are held for approval before stock leaves the branch." },
  { title: "Daily collection queue", team: "Finance + field reps", problem: "Everyone knows money is overdue, but nobody knows which account should be chased first.", outcome: "Aging buckets turn overdue accounts into a practical follow-up list." },
  { title: "Branch-level operating view", team: "Owner + branch managers", problem: "Sales, stock, dispatch, and dues are reviewed in separate files and calls.", outcome: "Each branch runs the same order-to-cash workflow with central visibility." },
];

const comparisons = [
  { cap: "Credit hold before dispatch", excel: "Manual", tally: "Limited", ow: "Policy-based" },
  { cap: "Aging-based collection queue", excel: "Manual", tally: "Reports only", ow: "Daily action list" },
  { cap: "Order to delivery workflow", excel: "Scattered", tally: "Accounting-first", ow: "Operational flow" },
  { cap: "Branch-wise stock visibility", excel: "Delayed", tally: "Partial", ow: "Branch-level" },
  { cap: "Field team mobile workflows", excel: "None", tally: "None", ow: "Sales, delivery, collection" },
  { cap: "Owner operating dashboard", excel: "Manual MIS", tally: "Accounting view", ow: "Orders, credit, dues, dispatch" },
  { cap: "Mobile Apps", excel: "None", tally: "None", ow: "Yes - Offline" },
  { cap: "GST invoice workflow", excel: "Manual", tally: "Strong", ow: "Operationally connected" },
  { cap: "Tally/accounting handoff", excel: "Manual", tally: "Native", ow: "Integration-ready" },
];

const faqs = [
  { q: "Who is OrdWave built for right now?", a: "OrdWave is currently focused on Indian FMCG distributor workflows, and the platform architecture is designed to extend to additional distributor categories." },
  { q: "How is OrdWave different from Tally or Excel?", a: "Tally and Excel are useful for accounting and records. OrdWave focuses on operational execution across orders, credit, dispatch, delivery, and collections." },
  { q: "Do you support credit approvals and controls?", a: "Yes. OrdWave supports policy-based credit checks and approval workflows before dispatch." },
  { q: "Do you support GST-related workflows?", a: "Yes. OrdWave supports GST-oriented operations including HSN/SAC handling and invoice/compliance workflows." },
  { q: "Can we roll out one branch first and scale later?", a: "Yes. Teams commonly begin with one branch and then expand after the process is stable." },
];

/* Section 1: Hero */
export function HeroSection() {
  return (
    <section className="gradient-hero relative overflow-hidden border-b border-[#E2E8F0]">
      <div className="pointer-events-none absolute -top-32 right-0 h-96 w-96 rounded-full bg-[#52B788]/10 blur-3xl" />
      <div className="pointer-events-none absolute bottom-0 left-0 h-80 w-80 rounded-full bg-[#1B4332]/5 blur-3xl" />
      <div className="section-shell grid items-center gap-12 py-16 sm:py-20 lg:grid-cols-2 lg:py-28">
        <div className="animate-fade-up">
          <span className="pill">Credit-first OMS for Indian distributors</span>
          <h1 className="mt-5 text-4xl font-bold leading-[1.06] tracking-tight text-[#0F172A] sm:text-5xl lg:text-6xl">
            Stop Risky Dispatches. <span className="text-[#1B4332]">Collect Faster.</span>
          </h1>
          <p className="mt-5 max-w-xl text-base leading-relaxed text-[#475569] sm:text-lg">
            OrdWave gives Indian distributors a credit-first order-to-cash system for orders, credit holds, inventory allocation, dispatch, delivery proof, collections, GST workflows, and Tally-ready handoffs.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <TrackedLink href="/request-demo" label="Map My Workflow" section="hero" className="btn-primary px-6 py-3 text-base">Map My Workflow</TrackedLink>
            <TrackedLink href="/pricing" label="View Pricing" section="hero" className="btn-secondary px-6 py-3 text-base">View Pricing</TrackedLink>
          </div>
          <div className="mt-7 flex flex-wrap gap-2">
            {["Credit holds", "Aging follow-ups", "Branch stock", "GST workflows"].map((t) => (
              <span key={t} className="pill">{t}</span>
            ))}
          </div>
        </div>
        <div className="animate-fade-up delay-200 animate-float">
          <div className="screen-chrome">
            <div className="screen-bar">
              <div className="screen-dot bg-[#FF5F57]" />
              <div className="screen-dot bg-[#FEBC2E]" />
              <div className="screen-dot bg-[#28C840]" />
              <span className="ml-3 text-xs text-[#94A3B8]">OrdWave - Owner Console</span>
            </div>
            <div className="bg-white p-5">
              <div className="mb-4 grid grid-cols-4 gap-2.5">
                {[
                  { label: "Credit Holds", value: "12", delta: "Needs approval", up: false },
                  { label: "Overdue Due", value: "Rs 8.4L", delta: "Aging queue", up: false },
                  { label: "Orders Clear", value: "37", delta: "Ready to dispatch", up: true },
                  { label: "Branch Stock", value: "Live", delta: "On-hand + reserved", up: true },
                ].map((k) => (
                  <div key={k.label} className="rounded-xl border border-[#E2E8F0] bg-[#F8FAF8] p-2.5">
                    <p className="text-[10px] text-[#64748B]">{k.label}</p>
                    <p className="text-base font-bold text-[#0F172A]">{k.value}</p>
                    <p className={`text-[10px] font-semibold ${k.up ? "text-[#166534]" : "text-[#92400E]"}`}>{k.delta}</p>
                  </div>
                ))}
              </div>
              <div className="mb-4 overflow-hidden rounded-xl border border-[#E2E8F0]">
                <div className="border-b border-[#E2E8F0] bg-[#F8FAF8] px-3 py-2">
                  <p className="text-xs font-semibold text-[#475569]">Credit-Gated Order Pipeline</p>
                </div>
                <table className="min-w-full text-xs">
                  <thead>
                    <tr className="bg-[#F8FAF8]">
                      <th className="px-3 py-2 text-left text-[10px] font-semibold text-[#64748B]">Retailer</th>
                      <th className="px-3 py-2 text-left text-[10px] font-semibold text-[#64748B]">Due</th>
                      <th className="px-3 py-2 text-left text-[10px] font-semibold text-[#64748B]">Status</th>
                    </tr>
                  </thead>
                  <tbody>
                    {[
                      { r: "Retailer A", a: "Rs 0", s: "Dispatch clear", sc: "bg-[#DCFCE7] text-[#166534]" },
                      { r: "Retailer B", a: "Rs 42K", s: "Credit hold", sc: "bg-[#FEF3C7] text-[#92400E]" },
                      { r: "Retailer C", a: "Rs 18K", s: "Manager approval", sc: "bg-[#E0F2FE] text-[#0369A1]" },
                    ].map((row) => (
                      <tr key={row.r} className="border-t border-[#E2E8F0]">
                        <td className="px-3 py-2 font-medium text-[#0F172A]">{row.r}</td>
                        <td className="px-3 py-2 text-[#475569]">{row.a}</td>
                        <td className="px-3 py-2"><span className={`inline-flex rounded-full px-2 py-0.5 text-[10px] font-semibold ${row.sc}`}>{row.s}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="rounded-xl border border-[#E2E8F0] p-3">
                <p className="mb-2 text-xs font-semibold text-[#475569]">Collections & Aging Trend</p>
                <div className="flex h-12 items-end gap-1.5">
                  {[35, 48, 42, 60, 55, 72, 84].map((v, i) => (
                    <div key={i} className="flex-1 rounded-t bg-[#52B788]/70" style={{ height: `${v}%` }} />
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

/* Section 2: Trusted By */
export function TrustedBySection() {
  return (
    <section className="border-b border-[#E2E8F0] bg-white py-12">
      <div className="section-shell">
        <p className="mb-8 text-center text-[11px] font-semibold uppercase tracking-widest text-[#94A3B8]">
          Built around the problems that actually cost distributors money
        </p>
        <div className="grid grid-cols-2 gap-6 sm:grid-cols-4">
          {trustMetrics.map((m) => (
            <div key={m.label} className="text-center">
              <p className="text-2xl font-bold text-[#1B4332] sm:text-3xl">{m.value}</p>
              <p className="mt-1 text-xs text-[#64748B]">{m.label}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* Section 3: Challenges */
export function ChallengesSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0] bg-[#F8FAF8]">
      <div className="section-shell">
        <div className="max-w-2xl">
          <span className="pill">Distributor challenges</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">The leaks OrdWave closes first</h2>
          <p className="mt-3 text-base text-[#475569]">The expensive problems are rarely accounting problems. They are dispatch, credit, stock, and follow-up problems.</p>
        </div>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {challenges.map((c) => (
            <div key={c.title} className="card p-6">
              <div className="mb-3 text-2xl font-bold text-[#1B4332]">{c.icon}</div>
              <h3 className="text-base font-semibold text-[#0F172A]">{c.title}</h3>
              <div className="mt-4 space-y-2.5">
                <div className="rounded-lg bg-[#FFF1F2] px-3 py-2 text-xs text-[#9F1239]">
                  <span className="font-semibold">Before: </span>{c.before}
                </div>
                <div className="rounded-lg bg-[#F0FDF4] px-3 py-2 text-xs text-[#166534]">
                  <span className="font-semibold">With OrdWave: </span>{c.after}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* Section 4: Product Overview */
export function ProductOverviewSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0]">
      <div className="section-shell">
        <div className="max-w-2xl">
          <span className="pill">Product overview</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">One workflow from credit check to cash collection</h2>
          <p className="mt-3 text-base text-[#475569]">From order capture to collection follow-through - one connected operational platform.</p>
        </div>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {[
            { mod: "Order Management", desc: "Structured order flow from booking to dispatch with credit and stock checks.", kpi: "Workflow-driven execution" },
            { mod: "Inventory Management", desc: "Branch-wise stock with transfer, alert, and adjustment workflows.", kpi: "Branch-level control" },
            { mod: "Credit & Collections", desc: "Credit checks with aging-based collection prioritization.", kpi: "Cash-discipline operations" },
            { mod: "Delivery Management", desc: "Trip planning, stop-level dispatch tracking, and proof workflows.", kpi: "Dispatch clarity" },
            { mod: "Business Analytics", desc: "Owner and manager dashboards for daily operational decisions.", kpi: "Role-specific visibility" },
            { mod: "Mobile Applications", desc: "Field workflows for sales, delivery, and collections with sync support.", kpi: "Field-ready execution" },
          ].map((m) => (
            <div key={m.mod} className="card flex flex-col p-6">
              <h3 className="text-base font-semibold text-[#0F172A]">{m.mod}</h3>
              <p className="mt-2 flex-1 text-sm text-[#475569]">{m.desc}</p>
              <span className="mt-4 inline-flex self-start rounded-full bg-[#DCFCE7] px-2.5 py-1 text-xs font-semibold text-[#166534]">{m.kpi}</span>
            </div>
          ))}
        </div>
        <div className="mt-10 text-center">
          <Link href="/features" className="btn-secondary px-6 py-2.5">Explore all features -></Link>
        </div>
      </div>
    </section>
  );
}

/* Section 5: Why OrdWave */
export function WhyOrdWaveSection() {
  return (
    <section className="bg-grid section-gap border-b border-[#E2E8F0] bg-[#F8FAF8]">
      <div className="section-shell">
        <div className="max-w-2xl">
          <span className="pill">Why choose OrdWave</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">Built for how distributors actually work</h2>
          <p className="mt-3 text-base text-[#475569]">Not a generic ERP. Not a basic billing tool. A purpose-built execution system.</p>
        </div>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {whyCards.map((c) => (
            <div key={c.title} className="card p-6">
              <div className="mb-3 text-3xl font-bold text-[#1B4332]">{c.icon}</div>
              <h3 className="text-sm font-semibold text-[#0F172A]">{c.title}</h3>
              <p className="mt-2 text-xs text-[#475569]">{c.body}</p>
              <p className="mt-3 text-xs font-bold text-[#1B4332]">{c.outcome}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* Section 6: Industries */
export function IndustriesHomeSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0]">
      <div className="section-shell">
        <div className="max-w-2xl">
          <span className="pill">Industry solutions</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">Designed for every distributor category</h2>
          <p className="mt-3 text-base text-[#475569]">OrdWave adapts to your distribution model - not the other way around.</p>
        </div>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {industries.map((ind) => (
            <Link key={ind.name} href="/industries" className="card group block p-6">
              <div className="mb-3 text-3xl font-bold text-[#1B4332]">{ind.icon}</div>
              <h3 className="text-base font-semibold text-[#0F172A] group-hover:text-[#1B4332]">{ind.name}</h3>
              <p className="mt-2 text-sm text-[#475569]">{ind.desc}</p>
              <span className="mt-4 inline-flex text-xs font-semibold text-[#1B4332] group-hover:underline">View solution -></span>
            </Link>
          ))}
        </div>
      </div>
    </section>
  );
}

/* Section 7: How It Works */
export function HowItWorksSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0] bg-[#F8FAF8]">
      <div className="section-shell">
        <div className="mx-auto max-w-2xl text-center">
          <span className="pill">Workflow</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">From retailer order to cash collection</h2>
          <p className="mt-3 text-base text-[#475569]">One connected flow powered by OrdWave.</p>
        </div>
        <div className="mt-10 flex flex-wrap items-center justify-center gap-2">
          {workflowSteps.map((s, i) => (
            <div key={s.step} className="flex items-center gap-2">
              <div className="rounded-xl border border-[#E2E8F0] bg-white px-4 py-2.5 text-sm font-semibold shadow-sm" style={{ color: s.color }}>
                <span className="mr-1.5 text-[10px] font-bold opacity-50">{i + 1}</span>{s.step}
              </div>
              {i < workflowSteps.length - 1 && <span className="text-lg font-bold text-[#52B788]">-&gt;</span>}
            </div>
          ))}
        </div>
        <div className="mt-12 grid gap-4 sm:grid-cols-3">
          {[
            { title: "Before OrdWave", items: ["WhatsApp + Excel chaos", "Manual credit checks", "Unknown delivery status", "No collection visibility"] },
            { title: "With OrdWave", items: ["Structured order workflow", "Automated credit gates", "Live dispatch tracking", "Aging-based collection queue"] },
            { title: "Business Impact", items: ["Clearer cross-team handoffs", "Fewer approval blind spots", "Better branch accountability", "Stronger collection discipline"] },
          ].map((col) => (
            <div key={col.title} className="card p-6">
              <h4 className="mb-3 text-sm font-semibold text-[#0F172A]">{col.title}</h4>
              <ul className="space-y-2">
                {col.items.map((item) => (
                  <li key={item} className="flex items-start gap-2 text-sm text-[#475569]">
                    <span className="mt-0.5 h-1.5 w-1.5 shrink-0 rounded-full bg-[#52B788]" />{item}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* Section 8: Mobile Apps */
export function MobileAppsSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0]">
      <div className="section-shell">
        <div className="max-w-2xl">
          <span className="pill">Mobile-first field execution</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">Apps built for sales, delivery, and collections</h2>
          <p className="mt-3 text-base text-[#475569]">Your field teams work faster when their tools work offline.</p>
        </div>
        <div className="mt-10 grid gap-5 sm:grid-cols-3">
          {mobileApps.map((app) => (
            <div key={app.name} className="card p-6">
              <div className="mx-auto mb-5 w-28">
                <div className="overflow-hidden rounded-2xl border-4 border-[#0F172A] bg-white shadow-xl">
                  <div className="flex h-4 items-center justify-center bg-[#0F172A]">
                    <div className="h-1.5 w-8 rounded-full bg-[#475569]" />
                  </div>
                  <div className="space-y-1.5 bg-[#F8FAF8] p-2">
                    <div className="h-2.5 w-full rounded bg-[#1B4332]/20" />
                    <div className="h-2.5 w-4/5 rounded bg-[#1B4332]/15" />
                    <div className="mt-2 grid grid-cols-2 gap-1">
                      <div className="h-6 rounded border border-[#d0e9db] bg-[#EFF7F2]" />
                      <div className="h-6 rounded border border-[#d0e9db] bg-[#EFF7F2]" />
                    </div>
                    <div className="h-2.5 w-3/4 rounded bg-[#1B4332]/15" />
                    <div className="h-2.5 w-full rounded bg-[#1B4332]/10" />
                  </div>
                </div>
              </div>
              <div className="mb-2 text-center text-3xl font-bold text-[#1B4332]">{app.icon}</div>
              <h3 className="text-center text-base font-semibold text-[#0F172A]">{app.name}</h3>
              <p className="mt-2 text-center text-sm text-[#475569]">{app.desc}</p>
              <ul className="mt-4 space-y-1.5">
                {app.features.map((f) => (
                  <li key={f} className="flex items-center gap-2 text-xs text-[#475569]">
                    <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#52B788]" />{f}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* Section 9: Analytics */
export function AnalyticsSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0] bg-[#F8FAF8]">
      <div className="section-shell">
        <div className="max-w-2xl">
          <span className="pill">Business analytics</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">Decisions backed by real-time data</h2>
          <p className="mt-3 text-base text-[#475569]">Sales trends, collection efficiency, inventory health, and branch performance in one dashboard.</p>
        </div>
        <div className="mt-10 grid gap-5 lg:grid-cols-2">
          <div className="card overflow-hidden">
            <div className="flex items-center justify-between border-b border-[#E2E8F0] px-5 py-3">
              <p className="text-sm font-semibold text-[#0F172A]">Analytics - 30 Days</p>
              <span className="inline-flex rounded-full bg-[#DCFCE7] px-2.5 py-1 text-xs font-semibold text-[#166534]">Live</span>
            </div>
            <div className="space-y-4 p-5">
              {[
                { label: "Sales Revenue", value: "Rs 1.2Cr", pct: 84, color: "#1B4332" },
                { label: "Collection Eff.", value: "78%", pct: 78, color: "#52B788" },
                { label: "Delivery Acc.", value: "94.2%", pct: 94, color: "#0369A1" },
                { label: "Stock Turnover", value: "12x", pct: 70, color: "#7C3AED" },
              ].map((row) => (
                <div key={row.label}>
                  <div className="mb-1 flex items-center justify-between">
                    <span className="text-xs text-[#64748B]">{row.label}</span>
                    <span className="text-xs font-bold text-[#0F172A]">{row.value}</span>
                  </div>
                  <div className="h-2 w-full rounded-full bg-[#E2E8F0]">
                    <div className="h-2 rounded-full" style={{ width: `${row.pct}%`, background: row.color }} />
                  </div>
                </div>
              ))}
            </div>
          </div>
          <div className="grid content-start grid-cols-2 gap-4">
            {[
              { metric: "Sales Trends", sub: "Daily and weekly revenue breakdown by branch, rep, and category" },
              { metric: "Collection KPIs", sub: "Follow-up efficiency, aging buckets, and rep-wise performance" },
              { metric: "Inventory Health", sub: "Turnover rate, dead stock alerts, and reorder point tracking" },
              { metric: "Delivery Metrics", sub: "On-time rate, delayed trips, and POD confirmation rates" },
            ].map((item) => (
              <div key={item.metric} className="card p-5">
                <h4 className="text-sm font-semibold text-[#0F172A]">{item.metric}</h4>
                <p className="mt-1.5 text-xs text-[#64748B]">{item.sub}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

/* Section 10: Testimonials */
export function TestimonialsSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0]">
      <div className="section-shell">
        <div className="mx-auto max-w-2xl text-center">
          <span className="pill">Workflow proof</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">Use cases buyers can recognize in five seconds</h2>
        </div>
        <div className="mt-10 grid gap-5 md:grid-cols-3">
          {proofCards.map((t) => (
            <div key={t.title} className="card flex flex-col p-6">
              <span className="pill self-start">{t.team}</span>
              <h3 className="mt-4 text-base font-semibold text-[#0F172A]">{t.title}</h3>
              <p className="mt-3 text-sm text-[#9F1239]"><span className="font-semibold">Problem: </span>{t.problem}</p>
              <p className="mt-3 text-sm text-[#166534]"><span className="font-semibold">With OrdWave: </span>{t.outcome}</p>
            </div>
          ))}
        </div>
        <div className="mt-10 text-center">
          <Link href="/features" className="btn-secondary px-6 py-2.5">See workflow modules</Link>
        </div>
      </div>
    </section>
  );
}

/* Section 11: ROI Calculator */
export function RoiCalculatorSection() {
  const [reps, setReps] = useState(10);
  const [orders, setOrders] = useState(50);
  const [branches, setBranches] = useState(2);

  const hoursSaved = Math.round(reps * orders * 0.04 * 22);
  const revenueImpact = Math.round(orders * reps * branches * 12);
  const collectionGain = Math.round(branches * orders * 0.08 * 100) / 100;

  return (
    <section className="gradient-dark section-gap">
      <div className="section-shell">
        <div className="mx-auto max-w-3xl">
          <div className="text-center">
            <span className="inline-flex items-center gap-1.5 rounded-full border border-[#52B788]/40 bg-[#52B788]/10 px-3.5 py-1.5 text-xs font-semibold text-[#52B788]">ROI Calculator</span>
            <h2 className="mt-4 text-3xl font-bold tracking-tight text-white sm:text-4xl">How much can OrdWave save your business?</h2>
            <p className="mt-3 text-[#94A3B8]">Move the sliders to see your estimated impact.</p>
          </div>
          <div className="mt-10 rounded-2xl border border-white/10 bg-white/5 p-8 backdrop-blur-md">
            <div className="grid gap-6 sm:grid-cols-3">
              {[
                { label: "Sales Reps", val: reps, setter: setReps, min: 1, max: 100, step: 1 },
                { label: "Orders/Day", val: orders, setter: setOrders, min: 10, max: 500, step: 10 },
                { label: "Branches", val: branches, setter: setBranches, min: 1, max: 20, step: 1 },
              ].map((inp) => (
                <div key={inp.label}>
                  <label className="mb-2 block text-xs font-semibold text-[#94A3B8]">{inp.label}</label>
                  <input type="range" min={inp.min} max={inp.max} step={inp.step} value={inp.val} onChange={(e) => inp.setter(Number(e.target.value))} className="w-full accent-[#52B788]" />
                  <p className="mt-1 text-xl font-bold text-white">{inp.val}</p>
                </div>
              ))}
            </div>
            <div className="mt-8 grid gap-4 sm:grid-cols-3">
              {[
                { label: "Hours Saved / Month", value: `${hoursSaved.toLocaleString()}h`, note: "From automated order workflows" },
                { label: "Revenue Impact", value: `Rs ${(revenueImpact / 100000).toFixed(1)}L`, note: "From faster order execution" },
                { label: "Collection Gain", value: `Rs ${collectionGain.toFixed(1)}L`, note: "From prioritized follow-ups" },
              ].map((r) => (
                <div key={r.label} className="rounded-xl border border-[#52B788]/25 bg-[#52B788]/10 p-4 text-center">
                  <p className="text-2xl font-bold text-[#52B788]">{r.value}</p>
                  <p className="mt-1 text-xs font-semibold text-white">{r.label}</p>
                  <p className="mt-0.5 text-[11px] text-[#94A3B8]">{r.note}</p>
                </div>
              ))}
            </div>
          </div>
          <div className="mt-8 text-center">
            <TrackedLink href="/request-demo" label="Get a custom ROI analysis" section="roi-calculator" className="btn-primary px-8 py-3 text-base">Get a custom ROI analysis</TrackedLink>
          </div>
        </div>
      </div>
    </section>
  );
}

/* Comparison Table */
export function ComparisonTableSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0]">
      <div className="section-shell">
        <div className="max-w-2xl">
          <span className="pill">Honest comparison</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">OrdWave vs Excel vs Tally in daily operations</h2>
          <p className="mt-3 text-base text-[#475569]">Tally is excellent for accounting. OrdWave is for the messy daily work before accounting is ready: credit holds, dispatches, dues, stock, and field follow-up.</p>
        </div>
        <div className="mt-10 card overflow-x-auto">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="border-b border-[#E2E8F0]">
                <th className="px-5 py-3.5 text-left text-xs font-semibold uppercase tracking-wider text-[#64748B]">Capability</th>
                <th className="px-5 py-3.5 text-left text-xs font-semibold uppercase tracking-wider text-[#64748B]">Excel</th>
                <th className="px-5 py-3.5 text-left text-xs font-semibold uppercase tracking-wider text-[#64748B]">Tally</th>
                <th className="bg-[#EFF7F2] px-5 py-3.5 text-left text-xs font-bold uppercase tracking-wider text-[#1B4332]">OrdWave</th>
              </tr>
            </thead>
            <tbody>
              {comparisons.map((row) => (
                <tr key={row.cap} className="border-t border-[#E2E8F0]">
                  <td className="px-5 py-3 font-medium text-[#0F172A]">{row.cap}</td>
                  <td className="px-5 py-3 text-[#64748B]">{row.excel}</td>
                  <td className="px-5 py-3 text-[#64748B]">{row.tally}</td>
                  <td className="bg-[#EFF7F2] px-5 py-3 font-semibold text-[#1B4332]">{row.ow}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}

/* FAQ */
export function FaqSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0] bg-[#F8FAF8]">
      <div className="section-shell">
        <div className="mx-auto max-w-3xl">
          <div className="mb-10 text-center">
            <span className="pill">FAQ</span>
            <h2 className="mt-4 text-3xl font-bold tracking-tight sm:text-4xl">Frequently asked questions</h2>
          </div>
          <div className="space-y-3">
            {faqs.map((faq) => (
              <div key={faq.q} className="card p-6">
                <h3 className="text-sm font-semibold text-[#0F172A]">{faq.q}</h3>
                <p className="mt-2 text-sm text-[#475569]">{faq.a}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

/* Section 12: Final CTA */
export function FinalCtaSection() {
  return (
    <section className="section-gap">
      <div className="section-shell">
        <div className="gradient-dark relative overflow-hidden rounded-3xl p-10 text-center sm:p-16">
          <div className="pointer-events-none absolute -top-24 left-1/2 h-72 w-72 -translate-x-1/2 rounded-full bg-[#52B788]/15 blur-3xl" />
          <span className="relative inline-flex items-center gap-1.5 rounded-full border border-[#52B788]/30 bg-[#52B788]/10 px-3.5 py-1.5 text-xs font-semibold text-[#52B788]">
            Start with your real workflow
          </span>
          <h2 className="relative mt-5 text-3xl font-bold tracking-tight text-white sm:text-4xl lg:text-5xl">
            Ready to Stop Dispatching<br className="hidden sm:block" /> Blind?
          </h2>
          <p className="relative mx-auto mt-4 max-w-xl text-base text-[#94A3B8]">
            Map your order, credit, stock, dispatch, and collections process. We will show where OrdWave fits and where it does not.
          </p>
          <div className="relative mt-8 flex flex-wrap justify-center gap-4">
            <TrackedLink href="/request-demo" label="Map My Workflow" section="final-cta" className="btn-primary px-8 py-3 text-base">Map My Workflow</TrackedLink>
            <TrackedLink href="/pricing" label="View Pricing" section="final-cta" className="inline-flex items-center justify-center gap-2 rounded-xl border border-white/20 px-8 py-3 text-base font-semibold text-white/90 transition-all hover:bg-white/10">View Pricing</TrackedLink>
          </div>
          <div className="relative mt-8 flex flex-wrap justify-center gap-5 text-xs text-[#64748B]">
            <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-[#52B788]" />Workflow review first</span>
            <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-[#52B788]" />Sample data walkthrough</span>
            <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-[#52B788]" />Setup plan included</span>
            <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-[#52B788]" />Onboarding included</span>
          </div>
        </div>
      </div>
    </section>
  );
}

/* Legacy aliases (keeps all existing import references working) */
export { ChallengesSection as PainPointsSection };
export { ProductOverviewSection as CoreFeaturesSection };
export { IndustriesHomeSection as UseCasesSection };
export { WhyOrdWaveSection as BenefitsSection };
export { AnalyticsSection as ProductPreviewSection };
export { RoiCalculatorSection as PricingPreviewSection };
export { IndustriesHomeSection as IndustrySolutionsSection };
export { ChallengesSection as ProductFeaturesSection };
export { HowItWorksSection as HowOrdWaveWorksSection };
export { MobileAppsSection as ProductScreensShowcaseSection };
export { ComparisonTableSection as ComparisonSection };
