import type { Metadata } from "next";
import Link from "next/link";
import { TrackedLink } from "@/components/tracked-link";

export const metadata: Metadata = {
  title: "Product Features",
  description: "Explore OrdWave modules for Indian FMCG distributors: order management, credit approvals, inventory visibility, delivery execution, collections, GST workflows, and integrations.",
};

const modules = [
  {
    name: "Order Management",
    headline: "From order booking to dispatch with a structured lifecycle",
    body: "Capture, validate, approve, and dispatch orders through one operational flow. Apply credit and inventory checks before orders move forward.",
    bullets: ["Live order pipeline with stage tracking","Retailer-level order history","Credit and inventory gate before dispatch","Dispatch confirmation with status updates"],
    kpi: "Lifecycle-based execution",
  },
  {
    name: "Inventory Management",
    headline: "Maintain branch-wise inventory visibility and control",
    body: "Track stock movement across branches, trigger low-stock alerts, and manage transfers with traceable updates.",
    bullets: ["Branch-wise real-time stock levels","Low-stock and near-zero alerts","Inter-branch transfer management","Stock movement history per SKU"],
    kpi: "Branch-level stock clarity",
  },
  {
    name: "Credit Management",
    headline: "Reduce risky dispatch with policy-driven credit workflows",
    body: "Apply credit limit enforcement and aging-based hold logic so orders are evaluated before approval and dispatch.",
    bullets: ["Credit limit and aging policy config","Auto-hold on limit breach","Manager approval workflow","Retailer-wise credit scorecard"],
    kpi: "Credit-first approvals",
  },
  {
    name: "Collections",
    headline: "Prioritize overdue follow-ups with aging visibility",
    body: "Give finance teams a clear view of overdue accounts with aging buckets, assignments, and payment tracking.",
    bullets: ["Aging-based priority queue","Rep-wise assignment and tracking","Payment recording and reconciliation","Collection trend analytics"],
    kpi: "Collections discipline",
  },
  {
    name: "Delivery Management",
    headline: "Control dispatch and stop-level delivery execution",
    body: "Plan routes, assign trips, and track deliveries with stop-level updates and proof-of-delivery workflows.",
    bullets: ["Route-wise trip planning","Live dispatch and stop tracking","POD photo and signature capture","Delayed trip alerts"],
    kpi: "Stop-level visibility",
  },
  {
    name: "Analytics",
    headline: "Role-specific dashboards for daily operational decisions",
    body: "Track sales, credit, collections, and branch performance through dashboards designed for owner and manager workflows.",
    bullets: ["Owner KPI command center","Branch comparison reports","Sales rep performance scorecards","Weekly trend summaries"],
    kpi: "Operational visibility",
  },
  {
    name: "Mobile Applications",
    headline: "Mobile workflows for sales, delivery, and collections",
    body: "Field teams get purpose-built apps with sync support for low-connectivity environments.",
    bullets: ["Sales Rep App — offline order capture","Driver App — route and POD","Collection App — payment and receipt","Auto-sync on reconnect"],
    kpi: "Field-ready operations",
  },
];

export default function FeaturesPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">Feature depth</span>
          <h1 className="mt-4 max-w-4xl text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">
            Product modules for FMCG distributor order-to-cash operations
          </h1>
          <p className="mt-4 max-w-3xl text-[#475569]">
            Purpose-built modules covering your order-to-cash cycle — from field order capture to collections follow-through.
          </p>
          <div className="mt-8 flex flex-wrap gap-2">
            {modules.map(m=>(
              <span key={m.name} className="pill">{m.name}</span>
            ))}
          </div>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="space-y-8">
          {modules.map((mod, idx) => (
            <div key={mod.name} className={`card p-8 grid gap-8 lg:grid-cols-2 lg:items-center ${idx % 2 === 1 ? "lg:grid-flow-dense" : ""}`}>
              <div className={idx % 2 === 1 ? "lg:col-start-2" : ""}>
                <span className="pill">{mod.name}</span>
                <h2 className="mt-3 text-2xl font-bold tracking-tight text-[#0F172A]">{mod.headline}</h2>
                <p className="mt-3 text-[#475569]">{mod.body}</p>
                <ul className="mt-5 space-y-2">
                  {mod.bullets.map(b=>(
                    <li key={b} className="flex items-center gap-2.5 text-sm text-[#475569]">
                      <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-[#52B788]" />{b}
                    </li>
                  ))}
                </ul>
                <div className="mt-5 flex items-center gap-4">
                  <span className="inline-flex rounded-full bg-[#DCFCE7] px-3 py-1 text-xs font-semibold text-[#166534]">{mod.kpi}</span>
                  <TrackedLink href="/request-demo" label="Book Demo" section="feature-module" className="text-sm font-semibold text-[#1B4332] hover:underline underline-offset-4">Book Demo →</TrackedLink>
                </div>
              </div>
              {/* Module preview */}
              <div className={`rounded-xl border border-[#E2E8F0] bg-[#F8FAF8] p-5 ${idx % 2 === 1 ? "lg:col-start-1" : ""}`}>
                <p className="text-xs font-semibold text-[#64748B] mb-3">{mod.name} — Live View</p>
                <div className="space-y-2">
                  <div className="h-3 w-3/4 rounded bg-[#1B4332]/15" />
                  <div className="h-3 w-full rounded bg-[#1B4332]/10" />
                  <div className="h-3 w-5/6 rounded bg-[#1B4332]/10" />
                  <div className="mt-3 grid grid-cols-3 gap-2">
                    <div className="rounded-lg bg-white border border-[#E2E8F0] p-3">
                      <div className="h-2 w-full rounded bg-[#E2E8F0] mb-1.5" />
                      <div className="h-5 w-10 rounded bg-[#1B4332]/25" />
                    </div>
                    <div className="rounded-lg bg-white border border-[#E2E8F0] p-3">
                      <div className="h-2 w-full rounded bg-[#E2E8F0] mb-1.5" />
                      <div className="h-5 w-10 rounded bg-[#52B788]/40" />
                    </div>
                    <div className="rounded-lg bg-white border border-[#E2E8F0] p-3">
                      <div className="h-2 w-full rounded bg-[#E2E8F0] mb-1.5" />
                      <div className="h-5 w-10 rounded bg-[#0369A1]/30" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="section-shell pb-20">
        <div className="gradient-dark rounded-3xl p-10 text-center">
          <h2 className="text-3xl font-bold text-white sm:text-4xl">See every module in action with your own data</h2>
          <p className="mt-3 text-[#94A3B8] max-w-xl mx-auto">
            Book a guided product walkthrough for your sales, warehouse, finance, and dispatch teams.
          </p>
          <div className="mt-7 flex flex-wrap justify-center gap-3">
            <TrackedLink href="/request-demo" label="Book Demo" section="features-bottom" className="btn-primary px-7 py-2.5">Book Demo</TrackedLink>
            <TrackedLink href="/pricing" label="View Pricing" section="features-bottom" className="inline-flex items-center rounded-xl border border-white/20 px-7 py-2.5 text-sm font-semibold text-white hover:bg-white/10">View Pricing</TrackedLink>
          </div>
        </div>
      </section>
    </>
  );
}
