import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Product Features",
  description: "Explore OrdWave modules — order management, inventory, credit, collections, delivery, analytics, and mobile apps for FMCG distributors.",
};

const modules = [
  {
    name: "Order Management",
    headline: "From order booking to dispatch — without WhatsApp and Excel chaos",
    body: "Capture, validate, approve, and dispatch orders through a structured workflow. Apply credit checks and inventory verification before every order goes out.",
    bullets: ["Live order pipeline with stage tracking","Retailer-level order history","Credit and inventory gate before dispatch","Dispatch confirmation with status updates"],
    kpi: "28% faster order processing",
  },
  {
    name: "Inventory Management",
    headline: "Know exactly what stock you have at every branch in real time",
    body: "Monitor SKU-level stock movement across branches, trigger low-stock alerts, and manage transfers with full traceability.",
    bullets: ["Branch-wise real-time stock levels","Low-stock and near-zero alerts","Inter-branch transfer management","Stock movement history per SKU"],
    kpi: "22% reduction in stockouts",
  },
  {
    name: "Credit Management",
    headline: "Stop risky orders before they hit your cash flow",
    body: "Automate credit limit enforcement and aging-based hold logic so every order is reviewed against current exposure before approval.",
    bullets: ["Credit limit and aging policy config","Auto-hold on limit breach","Manager approval workflow","Retailer-wise credit scorecard"],
    kpi: "30% reduction in bad debt",
  },
  {
    name: "Collections",
    headline: "Prioritize the right dues and collect faster",
    body: "Give finance teams a clear view of overdue accounts with aging buckets, rep assignments, and one-click follow-up actions.",
    bullets: ["Aging-based priority queue","Rep-wise assignment and tracking","Payment recording and reconciliation","Collection trend analytics"],
    kpi: "33% faster cash recovery",
  },
  {
    name: "Delivery Management",
    headline: "Live trip visibility from dispatch to doorstep",
    body: "Plan routes, assign trips, and track deliveries in real time with stop-level status and proof-of-delivery confirmation.",
    bullets: ["Route-wise trip planning","Live dispatch and stop tracking","POD photo and signature capture","Delayed trip alerts"],
    kpi: "95%+ on-time delivery rate",
  },
  {
    name: "Analytics",
    headline: "Decision-ready dashboards for founders and managers",
    body: "See sales, credit, collections, and branch performance at a glance with role-specific dashboards that update in real time.",
    bullets: ["Owner KPI command center","Branch comparison reports","Sales rep performance scorecards","Weekly trend summaries"],
    kpi: "5x faster operational decisions",
  },
  {
    name: "Mobile Applications",
    headline: "Apps for sales, delivery, and collections that work offline",
    body: "Field teams get purpose-built offline-first apps that sync seamlessly when connectivity returns — zero data loss.",
    bullets: ["Sales Rep App — offline order capture","Driver App — route and POD","Collection App — payment and receipt","Auto-sync on reconnect"],
    kpi: "40% faster field execution",
  },
];

export default function FeaturesPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">Feature depth</span>
          <h1 className="mt-4 max-w-4xl text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">
            Complete product modules for enterprise distribution operations
          </h1>
          <p className="mt-4 max-w-3xl text-[#475569]">
            Purpose-built modules that cover your entire order-to-cash cycle — from field order capture to overdue recovery.
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
                  <Link href="/request-demo" className="text-sm font-semibold text-[#1B4332] hover:underline underline-offset-4">Book Demo →</Link>
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
            <Link href="/request-demo" className="btn-primary px-7 py-2.5">Book Demo</Link>
            <Link href="/pricing" className="inline-flex items-center rounded-xl border border-white/20 px-7 py-2.5 text-sm font-semibold text-white hover:bg-white/10">View Pricing</Link>
          </div>
        </div>
      </section>
    </>
  );
}
