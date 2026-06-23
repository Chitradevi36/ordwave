import Link from "next/link";

const painPoints = [
  {
    title: "Excel-based order tracking",
    text: "Multiple sheets across branches cause version conflicts, late dispatches, and missed commitments.",
  },
  {
    title: "WhatsApp order confusion",
    text: "Order details get buried in chats, creating rework, dispatch mistakes, and blame across teams.",
  },
  {
    title: "Manual collections follow-up",
    text: "Finance teams spend hours calling retailers without clear prioritization and aging visibility.",
  },
  {
    title: "Inventory mismatch",
    text: "Branch stock is inaccurate during high velocity movement, causing stockouts and canceled orders.",
  },
  {
    title: "Credit leakage",
    text: "Orders get approved without policy checks, increasing overdue risk and hurting working capital.",
  },
];

const industrySolutions = [
  "FMCG Distribution",
  "Rice Distribution",
  "Pharma Distribution",
  "Electrical Distribution",
  "Wholesale Distribution",
  "Multi Branch Operations",
];

const productFeatures = [
  {
    title: "Order Management",
    text: "Capture orders from field teams, apply workflow states, and prevent execution drop-offs from booking to dispatch.",
    bullets: ["Live order pipeline", "Retailer-level order history", "Status-wise team accountability"],
  },
  {
    title: "Credit & Collections",
    text: "Apply credit rules before dispatch and track overdue recovery with branch-wise and rep-wise visibility.",
    bullets: ["Limit and aging checks", "Collections prioritization", "Escalation workflow"],
  },
  {
    title: "Inventory Management",
    text: "Monitor stock movement in real time, reduce mismatch, and improve fill rates across SKUs and branches.",
    bullets: ["Branch stock visibility", "Low-stock alerts", "Transfer and adjustment logs"],
  },
  {
    title: "Delivery Management",
    text: "Plan dispatches, track route progress, and reduce delayed deliveries with on-field updates.",
    bullets: ["Dispatch board", "Trip progress tracking", "Proof-of-delivery updates"],
  },
  {
    title: "Reports & Analytics",
    text: "Give founders and managers decision-ready visibility across revenue, overdue exposure, and operational throughput.",
    bullets: ["Owner KPI dashboard", "Branch comparison", "Daily team scorecards"],
  },
];

const workflow = ["Sales Rep", "Order", "Credit Check", "Approval", "Warehouse", "Delivery", "Invoice", "Collection"];

const screenCards = [
  { name: "Owner Dashboard", details: "Revenue, overdue, branch health, and daily execution KPIs in one command view." },
  { name: "Order Pipeline", details: "See each order stage from booking to dispatch with pending-action clarity." },
  { name: "Retailer CRM", details: "Track payment behavior, order trends, and outstanding by retailer account." },
  { name: "Inventory Dashboard", details: "Monitor SKU stock by branch with critical alerts and movement history." },
  { name: "Collection Dashboard", details: "Prioritize dues by age, rep, and amount to improve cash conversion." },
  { name: "Driver Mobile App", details: "Route-wise delivery list with status updates and completion confirmation." },
];

const benefitKpis = [
  { metric: "28%", label: "Faster order processing" },
  { metric: "33%", label: "Improved collection follow-up" },
  { metric: "22%", label: "Lower inventory mismatch" },
  { metric: "19%", label: "Reduction in credit exceptions" },
];

const trustItems = ["GST Ready", "Multi Branch", "Mobile + Web", "Secure Cloud", "Daily Backups", "Role Based Access"];

const faqs = [
  {
    q: "How quickly can we go live?",
    a: "Most teams start with one branch and core workflows, then expand branch by branch within weeks.",
  },
  {
    q: "Is OrdWave suitable for super stockists and wholesale networks?",
    a: "Yes. OrdWave supports high-volume order handling, multi-branch operations, and role-based execution.",
  },
  {
    q: "Do you support GST invoicing and Indian workflows?",
    a: "Yes. OrdWave is built for Indian distribution workflows, including GST-ready invoicing and branch operations.",
  },
  {
    q: "Can we onboard sales, warehouse, and finance teams together?",
    a: "Yes. The platform is role-based, so each team gets dedicated workflows with shared operational visibility.",
  },
];

export function HeroSection() {
  return (
    <section className="gradient-mesh relative overflow-hidden border-b border-border/60">
      <div className="pointer-events-none absolute -top-24 right-0 h-72 w-72 rounded-full bg-primary/10 blur-3xl" />
      <div className="pointer-events-none absolute bottom-0 left-0 h-64 w-64 rounded-full bg-accent/20 blur-3xl" />

      <div className="section-shell grid gap-12 py-16 sm:py-20 lg:grid-cols-2 lg:items-center lg:py-24">
        <div className="animate-fade-up">
          <span className="pill">Enterprise OMS for distributors and wholesalers</span>
          <h1 className="mt-4 text-4xl font-bold leading-[1.04] tracking-tight text-text-primary sm:text-5xl lg:text-6xl">
            Grow Your Distribution Business Without Excel, WhatsApp &amp; Credit Chaos
          </h1>
          <p className="mt-5 max-w-xl text-base text-text-secondary sm:text-lg">
            Manage orders, inventory, collections, deliveries, GST invoicing and multi-branch operations from one platform.
          </p>

          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/request-demo" className="rounded-lg bg-primary px-5 py-3 text-sm font-semibold text-white shadow-[0_10px_24px_rgba(27,67,50,0.28)] transition-all hover:-translate-y-[1px] hover:bg-primary-700">
              Start Free Trial
            </Link>
            <Link href="/request-demo" className="rounded-lg border border-border bg-white px-5 py-3 text-sm font-semibold transition-colors hover:bg-background-subtle">
              Book Demo
            </Link>
          </div>

          <div className="mt-6 flex flex-wrap gap-2.5">
            <span className="pill">Built for FMCG and wholesale teams</span>
            <span className="pill">Founder-level visibility</span>
            <span className="pill">Role-based execution</span>
          </div>
        </div>

        <div className="premium-card animate-float relative overflow-hidden p-6 sm:p-7">
          <div className="absolute right-0 top-0 h-24 w-24 rounded-bl-3xl bg-primary/10" />
          <div className="relative">
            <div className="mb-4 flex items-center justify-between">
              <p className="text-sm font-semibold">OrdWave Owner Console</p>
              <span className="rounded-full bg-primary/10 px-2.5 py-1 text-xs font-semibold text-primary">Live</span>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-xl border border-border bg-background-subtle p-3">
                <p className="text-xs text-text-secondary">Order Pipeline</p>
                <p className="mt-1 text-xl font-bold">312</p>
              </div>
              <div className="rounded-xl border border-border bg-background-subtle p-3">
                <p className="text-xs text-text-secondary">Overdue Amount</p>
                <p className="mt-1 text-xl font-bold">₹24.6L</p>
              </div>
              <div className="rounded-xl border border-border bg-background-subtle p-3">
                <p className="text-xs text-text-secondary">Fill Rate</p>
                <p className="mt-1 text-sm font-semibold text-primary">93.4%</p>
              </div>
              <div className="rounded-xl border border-border bg-background-subtle p-3">
                <p className="text-xs text-text-secondary">Credit Holds</p>
                <p className="mt-1 text-sm font-semibold text-amber-700">14 retailers</p>
              </div>
            </div>
            <div className="mt-4 rounded-xl border border-border p-3">
              <p className="text-xs font-semibold text-text-secondary">Dispatch Status</p>
              <div className="mt-2 grid h-20 grid-cols-6 items-end gap-1.5">
                {[32, 48, 56, 66, 74, 84].map((value) => (
                  <div key={value} className="rounded-t bg-primary/70" style={{ height: `${value}%` }} />
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export function PainPointsSection() {
  return (
    <section className="section-shell section-gap">
      <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Customer pain points</h2>
      <p className="mt-3 max-w-3xl text-text-secondary">
        Most distribution teams lose margin and speed due to fragmented tools. OrdWave replaces that chaos with one control layer.
      </p>
      <div className="mt-9 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {painPoints.map((point) => (
          <div key={point.title} className="premium-card animate-fade-up p-6">
            <p className="text-sm font-semibold text-text-primary">{point.title}</p>
            <p className="mt-2 text-sm text-text-secondary">{point.text}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

export function IndustrySolutionsSection() {
  return (
    <section className="soft-grid bg-background-subtle section-gap">
      <div className="section-shell">
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Industry solutions</h2>
        <p className="mt-3 max-w-3xl text-text-secondary">Purpose-built workflows for distributor categories with different operational complexity.</p>
        <div className="mt-9 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {industrySolutions.map((solution) => (
            <div key={solution} className="premium-card p-6">
              <p className="text-lg font-semibold text-text-primary">{solution}</p>
              <p className="mt-2 text-sm text-text-secondary">Configured for order-to-cash control, branch operations, and distributor-grade execution.</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export function ProductFeaturesSection() {
  return (
    <section className="section-shell section-gap">
      <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Product features</h2>
      <p className="mt-3 max-w-3xl text-text-secondary">Operational modules built to improve daily execution and business control for founders and managers.</p>

      <div className="mt-9 grid gap-4 lg:grid-cols-2">
        {productFeatures.map((feature) => (
          <div key={feature.title} className="premium-card p-6 sm:p-7">
            <h3 className="text-xl font-semibold">{feature.title}</h3>
            <p className="mt-2 text-sm text-text-secondary">{feature.text}</p>
            <ul className="mt-4 space-y-1.5 text-sm text-text-primary">
              {feature.bullets.map((bullet) => (
                <li key={bullet}>• {bullet}</li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </section>
  );
}

export function HowOrdWaveWorksSection() {
  return (
    <section className="bg-background-subtle section-gap">
      <div className="section-shell">
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">How OrdWave works</h2>
        <p className="mt-3 max-w-3xl text-text-secondary">One connected flow from order booking to collections closure.</p>

        <div className="mt-9 flex flex-wrap items-center gap-2">
          {workflow.map((step, index) => (
            <div key={step} className="flex items-center gap-2">
              <div className="premium-card px-4 py-2.5 text-sm font-semibold text-text-primary">{step}</div>
              {index < workflow.length - 1 ? <span className="text-primary">→</span> : null}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export function ProductScreensShowcaseSection() {
  return (
    <section className="section-shell section-gap">
      <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Product screens showcase</h2>
      <p className="mt-3 max-w-3xl text-text-secondary">Realistic dashboard illustrations representing daily distributor workflows across teams.</p>

      <div className="mt-9 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {screenCards.map((screen) => (
          <div key={screen.name} className="premium-card overflow-hidden p-5">
            <div className="rounded-xl border border-border bg-background-subtle p-3">
              <div className="mb-2 h-2.5 w-20 rounded bg-primary/25" />
              <div className="space-y-2">
                <div className="h-2.5 w-full rounded bg-primary/15" />
                <div className="h-2.5 w-4/5 rounded bg-primary/15" />
                <div className="h-2.5 w-3/5 rounded bg-primary/15" />
              </div>
              <div className="mt-3 grid grid-cols-3 gap-2">
                <div className="h-12 rounded bg-primary/20" />
                <div className="h-12 rounded bg-primary/20" />
                <div className="h-12 rounded bg-primary/20" />
              </div>
            </div>
            <h3 className="mt-4 text-base font-semibold">{screen.name}</h3>
            <p className="mt-2 text-sm text-text-secondary">{screen.details}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

export function BenefitsSection() {
  return (
    <section className="soft-grid bg-background-subtle section-gap">
      <div className="section-shell">
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Business benefits</h2>
        <p className="mt-3 max-w-3xl text-text-secondary">Track measurable improvements in speed, control, and working capital outcomes.</p>
        <div className="mt-9 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {benefitKpis.map((benefit) => (
            <div key={benefit.label} className="premium-card p-6">
              <p className="text-3xl font-bold text-primary">{benefit.metric}</p>
              <p className="mt-2 text-sm text-text-secondary">{benefit.label}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export function ComparisonTableSection() {
  const rows = [
    ["Centralized order workflow", "Manual", "Partial", "Yes"],
    ["Credit policy control", "No", "Limited", "Yes"],
    ["Multi-branch visibility", "No", "Limited", "Yes"],
    ["Collections prioritization", "Manual", "Basic", "Advanced"],
    ["Role-based access", "No", "Basic", "Granular"],
    ["Real-time dashboards", "No", "No", "Yes"],
  ];

  return (
    <section className="section-shell section-gap">
      <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Excel vs Tally vs OrdWave</h2>
      <p className="mt-3 max-w-3xl text-text-secondary">A practical comparison for teams scaling beyond manual tools.</p>
      <div className="premium-card mt-8 overflow-x-auto p-2 sm:p-4">
        <table className="min-w-full text-left text-sm">
          <thead>
            <tr className="border-b border-border text-text-secondary">
              <th className="px-3 py-3 font-semibold">Capability</th>
              <th className="px-3 py-3 font-semibold">Excel</th>
              <th className="px-3 py-3 font-semibold">Tally</th>
              <th className="px-3 py-3 font-semibold text-primary">OrdWave</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row[0]} className="border-t border-border">
                {row.map((cell, index) => (
                  <td key={cell} className={`px-3 py-3 ${index === 3 ? "font-semibold text-primary" : "text-text-secondary"}`}>
                    {cell}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

export function TrustSection() {
  return (
    <section className="bg-background-subtle section-gap">
      <div className="section-shell">
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Trust and platform readiness</h2>
        <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {trustItems.map((item) => (
            <div key={item} className="premium-card p-5">
              <p className="text-sm font-semibold text-text-primary">{item}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export function PricingSection() {
  const plans = [
    {
      name: "Starter",
      audience: "Single-branch or early growth distributors",
      cta: "Start Free Trial",
    },
    {
      name: "Growth",
      audience: "High-volume teams with multiple roles",
      cta: "Book Demo",
      highlighted: true,
    },
    {
      name: "Enterprise",
      audience: "Multi-branch and governance-heavy operations",
      cta: "Talk to Sales",
    },
  ];

  return (
    <section className="section-shell section-gap">
      <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Pricing</h2>
      <p className="mt-3 max-w-3xl text-text-secondary">Choose the plan based on team size, branch count, and process complexity.</p>
      <div className="mt-9 grid gap-4 lg:grid-cols-3">
        {plans.map((plan) => (
          <div key={plan.name} className={`premium-card p-6 ${plan.highlighted ? "ring-2 ring-primary/25" : ""}`}>
            <p className="text-lg font-semibold">{plan.name}</p>
            <p className="mt-2 text-sm text-text-secondary">{plan.audience}</p>
            <ul className="mt-4 space-y-1.5 text-sm text-text-primary">
              <li>• Role-based workflows</li>
              <li>• Distributor onboarding support</li>
              <li>• Reports and analytics</li>
            </ul>
            <Link
              href="/request-demo"
              className={`mt-6 inline-flex rounded-lg px-4 py-2.5 text-sm font-semibold ${plan.highlighted ? "bg-primary text-white" : "border border-border bg-white"}`}
            >
              {plan.cta}
            </Link>
          </div>
        ))}
      </div>
    </section>
  );
}

export function FaqSection() {
  return (
    <section className="bg-background-subtle section-gap">
      <div className="section-shell">
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Frequently asked questions</h2>
        <div className="mt-8 grid gap-4">
          {faqs.map((faq) => (
            <div key={faq.q} className="premium-card p-6">
              <h3 className="text-base font-semibold text-text-primary">{faq.q}</h3>
              <p className="mt-2 text-sm text-text-secondary">{faq.a}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export function FinalCtaSection() {
  return (
    <section className="section-shell pb-16 sm:pb-20">
      <div className="premium-card overflow-hidden bg-primary p-8 text-white sm:p-10">
        <p className="text-xs font-semibold uppercase tracking-wide text-white/80">Built for serious distributor growth</p>
        <h2 className="mt-2 text-3xl font-bold leading-tight sm:text-4xl">Move your operations from reactive to predictable</h2>
        <p className="mt-3 max-w-2xl text-sm text-white/90 sm:text-base">
          See OrdWave with your own workflows, branch structure, and team roles in a guided product demo.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Link href="/request-demo" className="rounded-lg bg-white px-5 py-2.5 text-sm font-semibold text-primary">
            Start Free Trial
          </Link>
          <Link href="/request-demo" className="rounded-lg border border-white/60 px-5 py-2.5 text-sm font-semibold text-white hover:bg-white/10">
            Book Demo
          </Link>
        </div>
      </div>
    </section>
  );
}
