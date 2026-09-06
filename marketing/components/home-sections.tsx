import Link from "next/link";
import { TrackedLink } from "@/components/tracked-link";
import { TrackingBeacon } from "@/components/tracking-beacon";
import { WhatsappCta } from "@/components/whatsapp-cta";
import { siteConfig } from "@/lib/site-config";

const problemPoints = [
  "Orders still come through calls and WhatsApp",
  "Outstanding is checked separately, if at all",
  "Warehouse gets told to dispatch before finance is aligned",
  "Collections follow-up depends on memory, calls, and spreadsheets",
];

const benefitPoints = [
  "Structured retailer orders with live credit context",
  "Approval, hold, or block before goods leave the warehouse",
  "Inventory, dispatch, proof of delivery, invoice, and collections stay connected",
  "Owners get one operating view across branches and teams",
];

const capabilityCards = [
  {
    title: "Credit-aware order control",
    body: "Check outstanding, overdue days, and credit policy before dispatch decisions are made.",
  },
  {
    title: "Retailer outstanding visibility",
    body: "Give sales, finance, and owners a shared view of who owes money and what needs follow-up first.",
  },
  {
    title: "Connected inventory and dispatch",
    body: "Keep stock allocation and dispatch handoffs connected to order status and approval decisions.",
  },
  {
    title: "Proof of delivery and invoicing",
    body: "Move from dispatch to delivery confirmation and invoicing with cleaner operational visibility.",
  },
  {
    title: "Collections discipline",
    body: "Turn ageing into an actionable collection queue instead of a passive report.",
  },
  {
    title: "Multi-branch operational visibility",
    body: "See what is happening across branches without depending on stitched-together calls and MIS files.",
  },
];

const faqs = [
  {
    q: "Who is OrdWave built for right now?",
    a: "OrdWave is currently focused on Indian FMCG, food, rice, and wholesale distributors dealing with retailer credit, branch operations, and daily order-to-dispatch coordination.",
  },
  {
    q: "How is OrdWave different from Tally or Excel?",
    a: "Tally and Excel are useful for accounting and records. OrdWave is built to control what happens before accounting: order capture, credit checks, approval, dispatch, delivery, invoicing, and collections follow-through.",
  },
  {
    q: "Can we start with one branch first?",
    a: "Yes. The intended rollout path is to start with one branch, stabilize the workflow, then expand to additional branches.",
  },
  {
    q: "Do you support GST-related operational data?",
    a: "Yes. The product includes GST-oriented invoicing and compliance-related operational data flows. We do not position it as a GST filing replacement on the marketing site.",
  },
];

export { faqs as homepageFaqs };

export function HeroSection() {
  return (
    <section className="gradient-hero relative overflow-hidden border-b border-[#E2E8F0]">
      <div className="pointer-events-none absolute -top-24 right-0 h-80 w-80 rounded-full bg-[#52B788]/10 blur-3xl" />
      <div className="pointer-events-none absolute bottom-0 left-0 h-72 w-72 rounded-full bg-[#1B4332]/8 blur-3xl" />
      <div className="section-shell grid items-center gap-12 py-16 sm:py-20 lg:grid-cols-[1.02fr_0.98fr] lg:py-24">
        <div>
          <span className="pill">Credit-aware order execution for distributors</span>
          <h1 className="mt-5 text-4xl font-bold leading-[1.04] tracking-tight text-[#0F172A] sm:text-5xl lg:text-6xl">
            {siteConfig.positioning.headline}
          </h1>
          <p className="mt-5 max-w-2xl text-base leading-relaxed text-[#475569] sm:text-lg">
            {siteConfig.positioning.subheadline}
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <TrackedLink
              href="/request-demo"
              label="Start 30-Day Pilot"
              section="hero"
              eventName="hero_start_pilot"
              className="btn-primary px-6 py-3 text-base"
            >
              Start 30-Day Pilot
            </TrackedLink>
            {/* <TrackedLink
              href="#demo-video"
              label="Watch 90-Second Demo"
              section="hero"
              eventName="hero_watch_demo"
              className="btn-secondary px-6 py-3 text-base"
            >
              Watch 90-Second Demo
            </TrackedLink> */}
            <WhatsappCta className="px-6 py-3" />
          </div>
          <div className="mt-8 grid gap-3 sm:grid-cols-2">
            {[
              "For FMCG, food, rice, and wholesale distributors in India",
              "Best fit for 1 to 5 branches and retailer credit workflows",
              "Built to stop risky dispatches before stock leaves the warehouse",
              "Founder-led pilot onboarding for early customers",
            ].map((item) => (
              <div key={item} className="flex items-start gap-3 rounded-2xl border border-[#E2E8F0] bg-white/75 px-4 py-3 shadow-sm backdrop-blur">
                <span className="mt-1 h-2 w-2 shrink-0 rounded-full bg-[#52B788]" />
                <span className="text-sm text-[#475569]">{item}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="relative">
          <div className="screen-chrome overflow-hidden rounded-[28px] border border-[#D7E8DD] bg-white">
            <div className="screen-bar">
              <div className="screen-dot bg-[#FF5F57]" />
              <div className="screen-dot bg-[#FEBC2E]" />
              <div className="screen-dot bg-[#28C840]" />
              <span className="ml-3 text-xs text-[#94A3B8]">OrdWave · Example order review</span>
            </div>
            <div className="grid gap-5 p-5 sm:p-6">
              <div className="rounded-[24px] border border-[#F3D0D4] bg-[linear-gradient(180deg,#FFF7F8_0%,#FFFFFF_100%)] p-5">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#92400E]">Order #ORD-10482</p>
                    <h2 className="mt-2 text-2xl font-bold text-[#0F172A]">ABC Stores</h2>
                    <p className="mt-1 text-sm text-[#64748B]">Retailer order received and waiting for credit review</p>
                  </div>
                  <span className="rounded-full bg-[#FDE7EA] px-3 py-1.5 text-xs font-semibold text-[#B42318]">
                    Credit risk
                  </span>
                </div>

                <div className="mt-5 grid gap-3 sm:grid-cols-2">
                  {[
                    ["Order Value", "₹48,500"],
                    ["Outstanding", "₹1,34,000"],
                    ["Credit Limit", "₹1,00,000"],
                    ["Overdue", "23 days"],
                  ].map(([label, value]) => (
                    <div key={label} className="rounded-2xl border border-[#EADADD] bg-white p-4">
                      <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[#94A3B8]">{label}</p>
                      <p className="mt-2 text-xl font-bold text-[#0F172A]">{value}</p>
                    </div>
                  ))}
                </div>

                <div className="mt-5 rounded-2xl border border-[#F5D0D5] bg-[#FFF3F4] p-4">
                  <p className="text-sm font-semibold text-[#B42318]">Dispatch requires approval</p>
                  <p className="mt-1 text-sm text-[#7A271A]">
                    Outstanding is above credit limit and the account has overdue invoices. The order should be reviewed before stock is allocated.
                  </p>
                  <div className="mt-4 flex flex-wrap gap-3">
                    <button type="button" className="rounded-xl bg-[#1B4332] px-4 py-2 text-sm font-semibold text-white">
                      Review Order
                    </button>
                    <span className="rounded-xl border border-[#E2E8F0] bg-white px-4 py-2 text-sm font-medium text-[#475569]">
                      Finance + owner visibility
                    </span>
                  </div>
                </div>
              </div>

              <div className="grid gap-3 sm:grid-cols-3">
                {[
                  { label: "Orders awaiting review", value: "12", tone: "text-[#92400E]" },
                  { label: "Dispatch clear today", value: "37", tone: "text-[#166534]" },
                  { label: "Collections queue", value: "₹8.4L", tone: "text-[#1B4332]" },
                ].map((item) => (
                  <div key={item.label} className="rounded-2xl border border-[#E2E8F0] bg-[#F8FAF8] p-4">
                    <p className="text-xs text-[#64748B]">{item.label}</p>
                    <p className={`mt-2 text-xl font-bold ${item.tone}`}>{item.value}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export function TrustProblemSection() {
  return (
    <section className="border-b border-[#E2E8F0] bg-white py-12">
      <div className="section-shell grid gap-6 lg:grid-cols-[0.8fr_1.2fr] lg:items-center">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.22em] text-[#94A3B8]">
            What OrdWave helps solve first
          </p>
          <h2 className="mt-3 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
            Control the decision before dispatch.
          </h2>
        </div>
        <div className="grid gap-4 sm:grid-cols-3">
          {[
            { value: "Outstanding", label: "visible before dispatch" },
            { value: "Credit policy", label: "evaluated in the order flow" },
            { value: "Collections", label: "tracked after invoice and delivery" },
          ].map((item) => (
            <div key={item.label} className="rounded-2xl border border-[#E2E8F0] bg-[#F8FAF8] p-5">
              <p className="text-xl font-bold text-[#1B4332]">{item.value}</p>
              <p className="mt-2 text-sm text-[#64748B]">{item.label}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

export function BeforeAfterSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0] bg-[#F8FAF8]">
      <div className="section-shell">
        <div className="max-w-3xl">
          <span className="pill">Before vs with OrdWave</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
            Keep accounting software for accounting. Use OrdWave to control what happens before accounting.
          </h2>
          <p className="mt-4 text-base text-[#475569]">
            The pain is usually not ledger entry. It is whether an order should move, whether stock should be committed, and who should chase outstanding before the next dispatch.
          </p>
        </div>

        <div className="mt-10 grid gap-5 lg:grid-cols-2">
          <div className="rounded-[28px] border border-[#F2D7DB] bg-white p-6 shadow-sm">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#9F1239]">Before OrdWave</p>
            <ul className="mt-5 space-y-3">
              {problemPoints.map((point) => (
                <li key={point} className="flex items-start gap-3 text-sm text-[#475569]">
                  <span className="mt-1 inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-[#FFF1F2] text-[11px] font-bold text-[#9F1239]">
                    !
                  </span>
                  <span>{point}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="rounded-[28px] border border-[#D5EBDD] bg-white p-6 shadow-sm">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#166534]">With OrdWave</p>
            <ul className="mt-5 space-y-3">
              {benefitPoints.map((point) => (
                <li key={point} className="flex items-start gap-3 text-sm text-[#475569]">
                  <span className="mt-1 inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-[#EFF7F2] text-[11px] font-bold text-[#166534]">
                    ✓
                  </span>
                  <span>{point}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}

export function WorkflowSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0]">
      <div className="section-shell">
        <div className="max-w-3xl">
          <span className="pill">See OrdWave in action</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
            One credit-aware flow from order booking to collection
          </h2>
          <p className="mt-4 text-base text-[#475569]">
            The most important moment is right after the order is received: retailer outstanding is checked, credit policy is evaluated, and the team knows whether to approve, hold, or block before dispatch.
          </p>
        </div>

        <div className="mt-10 rounded-[32px] border border-[#DCE5DD] bg-white p-6 shadow-[0_18px_40px_rgba(15,23,42,0.06)] sm:p-8">
          <div className="grid gap-4 md:grid-cols-8">
            {[
              "Retailer Order",
              "Credit Check",
              "Approve / Hold / Block",
              "Stock Allocation",
              "Dispatch",
              "Proof of Delivery",
              "Invoice",
              "Collection",
            ].map((step, index) => (
              <div key={step} className="relative">
                <div className="rounded-2xl border border-[#E2E8F0] bg-[#F8FAF8] p-4 text-sm font-semibold text-[#0F172A] shadow-sm">
                  <span className="mb-2 block text-[10px] font-bold uppercase tracking-[0.16em] text-[#94A3B8]">
                    Step {index + 1}
                  </span>
                  {step}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

export function CapabilitiesSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0] bg-[#F8FAF8]">
      <div className="section-shell">
        <div className="max-w-3xl">
          <span className="pill">Key capabilities</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
            Built for distributor owners who need credit, stock, dispatch, and collections in one operating rhythm
          </h2>
        </div>
        <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {capabilityCards.map((item) => (
            <div key={item.title} className="card p-6">
              <h3 className="text-lg font-semibold text-[#0F172A]">{item.title}</h3>
              <p className="mt-3 text-sm leading-6 text-[#475569]">{item.body}</p>
            </div>
          ))}
        </div>
        <div className="mt-8 text-center">
          <Link href="/features" className="btn-secondary px-6 py-3">
            Explore product modules
          </Link>
        </div>
      </div>
    </section>
  );
}

export function FoundingProgramSection() {
  const { foundingProgram } = siteConfig;

  return (
    <section className="section-gap border-b border-[#E2E8F0]">
      <div className="section-shell">
        <TrackingBeacon eventName="founding_offer_viewed" params={{ offer_enabled: foundingProgram.offer.enabled }} />
        <div className="grid gap-8 lg:grid-cols-[1fr_0.9fr] lg:items-center">
          <div>
            <span className="pill">{foundingProgram.badge}</span>
            <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
              {foundingProgram.title}
            </h2>
            <p className="mt-4 max-w-2xl text-base text-[#475569]">{foundingProgram.description}</p>
            {foundingProgram.offer.enabled && (
              <div className="mt-6 inline-flex flex-col rounded-[24px] border border-[#D5EBDD] bg-[#F6FBF8] px-5 py-4">
                <span className="text-xs font-semibold uppercase tracking-[0.18em] text-[#1B4332]">
                  {foundingProgram.offer.name}
                </span>
                <span className="mt-2 text-3xl font-bold text-[#0F172A]">{foundingProgram.offer.priceMonthly}</span>
                <span className="mt-1 text-sm text-[#64748B]">{foundingProgram.offer.note}</span>
              </div>
            )}
          </div>
          <div className="rounded-[28px] border border-[#D7E8DD] bg-[linear-gradient(180deg,#F6FBF8_0%,#FFFFFF_100%)] p-6 shadow-sm sm:p-8">
            <ul className="grid gap-3 sm:grid-cols-2">
              {foundingProgram.benefits.map((benefit) => (
                <li key={benefit} className="flex items-start gap-3 rounded-2xl border border-[#E2E8F0] bg-white p-4 text-sm text-[#475569]">
                  <span className="mt-1 inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-[#EFF7F2] text-[11px] font-bold text-[#166534]">
                    ✓
                  </span>
                  <span>{benefit}</span>
                </li>
              ))}
            </ul>
            <div className="mt-6 flex flex-wrap gap-3">
              <TrackedLink
                href="/request-demo"
                label="Start My Pilot"
                section="founding-program"
                eventName="founding_pilot_clicked"
                className="btn-primary px-6 py-3"
              >
                Start My Pilot
              </TrackedLink>
              <WhatsappCta />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export function IntegrationsSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0] bg-[#F8FAF8]">
      <div className="section-shell">
        <div className="grid gap-8 lg:grid-cols-[0.95fr_1.05fr] lg:items-center">
          <div>
            <span className="pill">Accounting position</span>
            <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
              Keep accounting software for accounting.
            </h2>
            <p className="mt-4 text-base leading-7 text-[#475569]">
              OrdWave is where distributor teams control orders, credit checks, dispatch readiness, delivery proof, invoicing flow, and collection follow-through before accounting becomes the final record.
            </p>
            <p className="mt-4 text-base leading-7 text-[#475569]">
              The repository clearly supports invoicing, compliance-related GST data flows, accounting exports, and accounting integration setup screens. We describe those honestly without promising more than the product currently proves.
            </p>
          </div>
          <div className="rounded-[28px] border border-[#E2E8F0] bg-white p-6 shadow-sm">
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="rounded-2xl border border-[#E2E8F0] bg-[#F8FAF8] p-5">
                <p className="text-xs font-semibold uppercase tracking-[0.16em] text-[#64748B]">OrdWave</p>
                <ul className="mt-4 space-y-2 text-sm text-[#475569]">
                  <li>Order capture and approval</li>
                  <li>Credit checks and hold rules</li>
                  <li>Dispatch and delivery workflow</li>
                  <li>Collections visibility</li>
                </ul>
              </div>
              <div className="rounded-2xl border border-[#E2E8F0] bg-[#F8FAF8] p-5">
                <p className="text-xs font-semibold uppercase tracking-[0.16em] text-[#64748B]">Accounting system</p>
                <ul className="mt-4 space-y-2 text-sm text-[#475569]">
                  <li>Ledger and final books</li>
                  <li>Accounting records</li>
                  <li>Finance-side reconciliation</li>
                  <li>Downstream compliance process</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export function FaqSection() {
  return (
    <section className="section-gap border-b border-[#E2E8F0]">
      <div className="section-shell">
        <div className="mx-auto max-w-3xl">
          <div className="mb-10 text-center">
            <span className="pill">FAQ</span>
            <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
              Questions distributor teams usually ask first
            </h2>
          </div>
          <div className="space-y-3">
            {faqs.map((faq) => (
              <div key={faq.q} className="card p-6">
                <h3 className="text-sm font-semibold text-[#0F172A]">{faq.q}</h3>
                <p className="mt-2 text-sm leading-6 text-[#475569]">{faq.a}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

export function FinalCtaSection() {
  return (
    <section className="section-gap">
      <div className="section-shell">
        <div className="gradient-dark relative overflow-hidden rounded-[32px] p-10 sm:p-14">
          <div className="pointer-events-none absolute -top-20 left-1/2 h-64 w-64 -translate-x-1/2 rounded-full bg-[#52B788]/15 blur-3xl" />
          <div className="relative mx-auto max-w-3xl text-center">
            <span className="inline-flex rounded-full border border-[#52B788]/30 bg-[#52B788]/10 px-3.5 py-1.5 text-xs font-semibold text-[#74C69D]">
              Low-risk first step
            </span>
            <h2 className="mt-5 text-3xl font-bold tracking-tight text-white sm:text-4xl lg:text-5xl">
              Start with a 30-day pilot built around your real workflow
            </h2>
            <p className="mx-auto mt-4 max-w-2xl text-base leading-7 text-white/75">
              We will review your current process, import core business data, set up credit policy logic, and help your team evaluate OrdWave in a real operating environment.
            </p>
            <div className="mt-8 flex flex-wrap justify-center gap-4">
              <TrackedLink
                href="/request-demo"
                label="Start 30-Day Pilot"
                section="final-cta"
                eventName="hero_start_pilot"
                className="btn-primary px-8 py-3 text-base"
              >
                Start 30-Day Pilot
              </TrackedLink>
              <TrackedLink href="/pricing" label="View Pricing" section="final-cta" className="btn-ghost border border-white/20 px-8 py-3 text-base">
                View Pricing
              </TrackedLink>
            </div>
            <div className="mt-8 flex flex-wrap justify-center gap-5 text-xs text-white/65">
              {["30-day assisted pilot", "Hands-on onboarding", "Credit policy setup", "Cancel anytime"].map((item) => (
                <span key={item} className="flex items-center gap-1.5">
                  <span className="h-1.5 w-1.5 rounded-full bg-[#52B788]" />
                  {item}
                </span>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export { BeforeAfterSection as ComparisonSection };
