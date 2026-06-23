import Link from "next/link";

const trustPills = [
  "Built for Indian distributors",
  "GST-ready invoicing",
  "Credit-first operations",
  "Offline-ready field workflows",
];

const featureCards = [
  {
    title: "Order Management",
    body: "Capture, approve, dispatch, and track orders from one flow without WhatsApp and spreadsheet confusion.",
  },
  {
    title: "Retailer CRM",
    body: "Maintain retailer profile, buying history, route assignment, and outstanding status in one clean system.",
  },
  {
    title: "Credit Control",
    body: "Stop risky orders before they impact cash flow with credit holds, alerts, and manager approvals.",
  },
  {
    title: "Inventory Management",
    body: "Track branch-wise stock movement, prevent stockouts, and improve fill rates with live inventory visibility.",
  },
  {
    title: "Delivery Tracking",
    body: "Monitor dispatch and delivery progress in real time so teams resolve delays before customer complaints.",
  },
  {
    title: "Payments & Collections",
    body: "Record collections, reduce overdue follow-ups, and improve daily cash visibility for finance teams.",
  },
  {
    title: "GST-ready Invoicing",
    body: "Issue compliant invoices faster with built-in GST workflows designed for distributor operations.",
  },
  {
    title: "Reports & Analytics",
    body: "Track sales, collections, credit, and branch performance with decision-ready dashboards.",
  },
];

export function HeroSection() {
  return (
    <section className="gradient-mesh relative overflow-hidden">
      <div className="pointer-events-none absolute -top-24 right-0 h-72 w-72 rounded-full bg-primary/10 blur-3xl" />
      <div className="pointer-events-none absolute bottom-0 left-0 h-64 w-64 rounded-full bg-accent/20 blur-3xl" />

      <div className="section-shell grid gap-12 py-16 sm:py-20 lg:grid-cols-2 lg:items-center lg:py-24">
        <div>
          <div className="pill">Modern OMS for distributors</div>
          <h1 className="mt-4 text-4xl font-bold leading-[1.05] tracking-tight text-text-primary sm:text-5xl lg:text-6xl">
            Replace Excel and WhatsApp chaos with execution control
          </h1>
          <p className="mt-5 max-w-xl text-base text-text-secondary sm:text-lg">
            OrdWave helps distributors reduce missed orders, control retailer credit,
            improve collection visibility, and run multi-branch operations from one dashboard.
          </p>

          <div className="mt-8 flex flex-wrap gap-3">
            <Link href="/request-demo" className="rounded-lg bg-primary px-5 py-3 text-sm font-semibold text-white shadow-[0_10px_24px_rgba(27,67,50,0.28)] transition-all hover:-translate-y-[1px] hover:bg-primary-700">
              Book Demo
            </Link>
            <Link href="/features" className="rounded-lg border border-border bg-white px-5 py-3 text-sm font-semibold hover:bg-background-subtle">
              View Features
            </Link>
          </div>

          <div className="mt-6 flex flex-wrap gap-2.5">
            {trustPills.map((pill) => (
              <span key={pill} className="pill">
                {pill}
              </span>
            ))}
          </div>
        </div>

        <div className="premium-card relative overflow-hidden p-6 sm:p-7">
          <div className="absolute right-0 top-0 h-28 w-28 rounded-bl-3xl bg-primary/10" />
          <div className="relative">
            <div className="mb-4 flex items-center justify-between">
              <p className="text-sm font-semibold text-text-primary">OrdWave Operations Console</p>
              <span className="rounded-full bg-green-100 px-2.5 py-1 text-xs font-semibold text-primary">Live</span>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-xl border border-border bg-background-subtle p-3">
                <p className="text-xs text-text-secondary">Today&apos;s Orders</p>
                <p className="mt-1 text-xl font-bold">128</p>
              </div>
              <div className="rounded-xl border border-border bg-background-subtle p-3">
                <p className="text-xs text-text-secondary">Outstanding Collections</p>
                <p className="mt-1 text-xl font-bold">₹12.4L</p>
              </div>
              <div className="rounded-xl border border-border bg-background-subtle p-3">
                <p className="text-xs text-text-secondary">Delivery Status</p>
                <p className="mt-1 text-sm font-semibold text-primary">82% on-time</p>
              </div>
              <div className="rounded-xl border border-border bg-background-subtle p-3">
                <p className="text-xs text-text-secondary">Credit Holds</p>
                <p className="mt-1 text-sm font-semibold text-amber-700">9 accounts</p>
              </div>
            </div>

            <div className="mt-4 rounded-xl border border-border">
              <div className="flex items-center justify-between border-b border-border px-3 py-2">
                <p className="text-xs font-semibold text-text-secondary">Inventory Alerts</p>
                <span className="text-xs font-semibold text-rose-700">5 critical</span>
              </div>
              <div className="space-y-2 p-3 text-xs">
                <div className="flex items-center justify-between">
                  <span>Ponni Rice 25kg</span>
                  <span className="rounded bg-rose-50 px-2 py-0.5 font-semibold text-rose-700">Low</span>
                </div>
                <div className="flex items-center justify-between">
                  <span>Groundnut Oil 5L</span>
                  <span className="rounded bg-amber-50 px-2 py-0.5 font-semibold text-amber-700">Watch</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export function PainPointsSection() {
  const points = [
    {
      icon: "⚠",
      title: "Missed and delayed orders",
      text: "Order capture across calls and chat creates execution gaps and dispatch delays.",
    },
    {
      icon: "₹",
      title: "Uncontrolled retailer credit",
      text: "Manual checks increase overdue exposure and reduce confidence in new order approvals.",
    },
    {
      icon: "🚚",
      title: "Low delivery visibility",
      text: "Without live trip status, teams react too late to route delays and failed drops.",
    },
    {
      icon: "📉",
      title: "Collections blind spots",
      text: "Finance teams struggle to prioritize follow-ups without centralized outstanding tracking.",
    },
  ];

  return (
    <section className="section-shell section-gap">
      <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Distribution pain points, solved</h2>
      <p className="mt-3 max-w-3xl text-text-secondary">OrdWave gives every team one source of truth across orders, credit, dispatch, and collections.</p>
      <div className="mt-9 grid gap-4 md:grid-cols-2">
        {points.map((point) => (
          <div key={point.title} className="premium-card p-5">
            <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10 text-lg font-bold text-primary">
              {point.icon}
            </div>
            <h3 className="text-lg font-semibold text-text-primary">{point.title}</h3>
            <p className="mt-2 text-sm text-text-secondary">{point.text}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

export function CoreFeaturesSection() {
  return (
    <section className="soft-grid bg-background-subtle section-gap">
      <div className="section-shell">
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Core product capabilities</h2>
        <p className="mt-3 max-w-3xl text-text-secondary">Designed to run distributor operations end-to-end from one cloud platform.</p>
        <div className="mt-9 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {featureCards.map((feature) => (
            <div key={feature.title} className="premium-card h-full p-5">
              <h3 className="text-base font-semibold text-text-primary">{feature.title}</h3>
              <p className="mt-2 text-sm text-text-secondary">{feature.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export function HowItWorksSection() {
  const steps = [
    { title: "Capture orders", body: "Take and track distributor orders in a structured workflow." },
    { title: "Control operations", body: "Apply credit, inventory, and dispatch checks before execution." },
    { title: "Scale outcomes", body: "Invoice faster, collect on time, and improve decisions with analytics." },
  ];

  return (
    <section className="section-shell section-gap">
      <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">How OrdWave works</h2>
      <div className="mt-9 grid gap-4 md:grid-cols-3">
        {steps.map((step, index) => (
          <div key={step.title} className="premium-card p-5">
            <p className="inline-flex rounded-full bg-primary/10 px-2.5 py-1 text-xs font-semibold uppercase tracking-wide text-primary">Step {index + 1}</p>
            <h3 className="mt-2 text-lg font-semibold">{step.title}</h3>
            <p className="mt-2 text-sm text-text-secondary">{step.body}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

export function BenefitsSection() {
  const benefits = [
    { metric: "24%", label: "Lower missed-order incidents" },
    { metric: "31%", label: "Faster collections follow-up" },
    { metric: "18%", label: "Improved on-time dispatch rate" },
    { metric: "1", label: "Unified dashboard across branches" },
  ];

  return (
    <section className="bg-background-subtle section-gap">
      <div className="section-shell">
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Business outcomes and ROI</h2>
        <p className="mt-3 max-w-3xl text-text-secondary">Replace fragmented workflows with predictable, trackable execution across your distribution network.</p>
        <div className="mt-9 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {benefits.map((benefit) => (
            <div key={benefit.label} className="premium-card p-5">
              <p className="text-3xl font-bold text-primary">{benefit.metric}</p>
              <p className="mt-2 text-sm text-text-secondary">{benefit.label}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export function ProductPreviewSection() {
  return (
    <section className="section-shell section-gap">
      <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Product preview</h2>
      <p className="mt-3 max-w-3xl text-text-secondary">
        A realistic view of how teams monitor orders, collections, delivery progress, and inventory alerts in OrdWave.
      </p>

      <div className="premium-card mt-9 overflow-hidden p-4 sm:p-6">
        <div className="mb-4 flex items-center justify-between">
          <div>
            <p className="text-sm font-semibold text-text-primary">Executive Dashboard</p>
            <p className="text-xs text-text-secondary">Chennai Branch • Today</p>
          </div>
          <span className="rounded-full bg-primary/10 px-2.5 py-1 text-xs font-semibold text-primary">Live sync</span>
        </div>

        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <div className="rounded-xl border border-border bg-background-subtle p-3">
            <p className="text-xs text-text-secondary">Today&apos;s Orders</p>
            <p className="mt-1 text-xl font-bold">148</p>
          </div>
          <div className="rounded-xl border border-border bg-background-subtle p-3">
            <p className="text-xs text-text-secondary">Outstanding Collections</p>
            <p className="mt-1 text-xl font-bold">₹18.9L</p>
          </div>
          <div className="rounded-xl border border-border bg-background-subtle p-3">
            <p className="text-xs text-text-secondary">Delivery Status</p>
            <p className="mt-1 text-sm font-semibold text-primary">89% on-time</p>
          </div>
          <div className="rounded-xl border border-border bg-background-subtle p-3">
            <p className="text-xs text-text-secondary">Credit Holds</p>
            <p className="mt-1 text-sm font-semibold text-amber-700">11 retailers</p>
          </div>
          <div className="rounded-xl border border-border bg-background-subtle p-3">
            <p className="text-xs text-text-secondary">Inventory Alerts</p>
            <p className="mt-1 text-sm font-semibold text-rose-700">7 critical SKUs</p>
          </div>
        </div>

        <div className="mt-4 grid gap-4 lg:grid-cols-[1.2fr_1fr]">
          <div className="rounded-xl border border-border">
            <div className="border-b border-border px-4 py-2.5 text-xs font-semibold text-text-secondary">
              Recent operational activity
            </div>
            <div className="overflow-x-auto">
              <table className="min-w-full text-left text-xs">
                <thead className="bg-background-subtle text-text-secondary">
                  <tr>
                    <th className="px-4 py-2">Retailer</th>
                    <th className="px-4 py-2">Order</th>
                    <th className="px-4 py-2">Credit</th>
                    <th className="px-4 py-2">Delivery</th>
                  </tr>
                </thead>
                <tbody>
                  <tr className="border-t border-border">
                    <td className="px-4 py-2">Fresh Mart</td>
                    <td className="px-4 py-2">₹42,100</td>
                    <td className="px-4 py-2"><span className="rounded bg-green-50 px-2 py-0.5 font-semibold text-green-700">Approved</span></td>
                    <td className="px-4 py-2"><span className="rounded bg-blue-50 px-2 py-0.5 font-semibold text-blue-700">In transit</span></td>
                  </tr>
                  <tr className="border-t border-border">
                    <td className="px-4 py-2">Kannan Stores</td>
                    <td className="px-4 py-2">₹27,900</td>
                    <td className="px-4 py-2"><span className="rounded bg-amber-50 px-2 py-0.5 font-semibold text-amber-700">Hold</span></td>
                    <td className="px-4 py-2"><span className="rounded bg-slate-100 px-2 py-0.5 font-semibold text-slate-700">Queued</span></td>
                  </tr>
                  <tr className="border-t border-border">
                    <td className="px-4 py-2">Sai Traders</td>
                    <td className="px-4 py-2">₹18,200</td>
                    <td className="px-4 py-2"><span className="rounded bg-green-50 px-2 py-0.5 font-semibold text-green-700">Approved</span></td>
                    <td className="px-4 py-2"><span className="rounded bg-green-50 px-2 py-0.5 font-semibold text-green-700">Delivered</span></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div className="rounded-xl border border-border p-4">
            <p className="text-xs font-semibold text-text-secondary">Collection trend (7 days)</p>
            <div className="mt-4 grid h-28 grid-cols-7 items-end gap-2">
              {[36, 54, 48, 70, 62, 78, 84].map((v, idx) => (
                <div key={idx} className="rounded-t bg-primary/70" style={{ height: `${v}%` }} />
              ))}
            </div>
            <p className="mt-4 text-xs text-text-secondary">Collections improved this week with better follow-up prioritization.</p>
          </div>
        </div>
      </div>
    </section>
  );
}

export function UseCasesSection() {
  const useCases = [
    {
      title: "FMCG distributors",
      text: "Handle high order volume, beat execution, and branch inventory without manual bottlenecks.",
    },
    {
      title: "Rice and staples distribution",
      text: "Track SKU movement, route-wise dispatch, and credit exposure across retailer segments.",
    },
    {
      title: "Wholesale grocery networks",
      text: "Unify sales, warehouse, and finance workflows for faster order-to-cash execution.",
    },
    {
      title: "Multi-branch operations",
      text: "Run multiple branches from one operational control center with consistent visibility.",
    },
  ];

  return (
    <section className="section-shell section-gap">
      <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Use cases built for real distributors</h2>
      <div className="mt-9 grid gap-4 md:grid-cols-2">
        {useCases.map((item) => (
          <div key={item.title} className="premium-card p-5">
            <h3 className="text-lg font-semibold">{item.title}</h3>
            <p className="mt-2 text-sm text-text-secondary">{item.text}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

export function PricingPreviewSection() {
  const tiers = [
    { name: "Starter", label: "For growing distributor teams" },
    { name: "Growth", label: "For high-volume branch operations" },
    { name: "Enterprise", label: "For multi-entity control and governance" },
  ];

  return (
    <section className="soft-grid bg-background-subtle section-gap">
      <div className="section-shell">
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Pricing preview</h2>
        <p className="mt-3 max-w-3xl text-text-secondary">Choose a plan based on operational scale and process complexity.</p>
        <div className="mt-9 grid gap-4 md:grid-cols-3">
          {tiers.map((tier) => (
            <div key={tier.name} className="premium-card p-6">
              <p className="text-lg font-semibold text-text-primary">{tier.name}</p>
              <p className="mt-2 text-sm text-text-secondary">{tier.label}</p>
              <Link href="/pricing" className="mt-4 inline-block text-sm font-semibold text-primary hover:underline">
                View plan details
              </Link>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export function TestimonialsSection() {
  return (
    <section className="bg-background-subtle section-gap">
      <div className="section-shell">
        <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Trusted by modern distributor teams</h2>
        <p className="mt-3 text-sm text-text-secondary">Placeholder cards for customer quotes.</p>
        <div className="mt-9 grid gap-4 md:grid-cols-3">
          {[1, 2, 3].map((item) => (
            <div key={item} className="premium-card p-5">
              <p className="text-sm">OrdWave helped us improve order execution and collection follow-up across branches.</p>
              <p className="mt-3 text-xs text-text-secondary">Name - Company - Role</p>
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
        <p className="text-xs font-semibold uppercase tracking-wide text-white/80">Ready to buy today</p>
        <h2 className="mt-2 text-3xl font-bold leading-tight sm:text-4xl">Take control of distributor operations with OrdWave</h2>
        <p className="mt-3 max-w-2xl text-sm text-white/90 sm:text-base">
          Replace fragmented tools with one platform to run orders, credit, dispatch, collections, and branch performance.
        </p>
        <div className="mt-6 flex flex-wrap gap-3">
          <Link href="/request-demo" className="rounded-lg bg-white px-5 py-2.5 text-sm font-semibold text-primary">
            Book Demo
          </Link>
          <Link href="/features" className="rounded-lg border border-white/60 px-5 py-2.5 text-sm font-semibold text-white hover:bg-white/10">
            View Features
          </Link>
        </div>
      </div>
    </section>
  );
}
