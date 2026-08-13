import type { Metadata } from "next";
import { TrackedLink } from "@/components/tracked-link";
import { siteConfig } from "@/lib/site-config";

export const metadata: Metadata = {
  title: "FMCG Distributor Software",
  description:
    "OrdWave is FMCG distributor software for Indian teams that need credit-aware order management, outstanding visibility, dispatch control, collections tracking, and multi-branch execution.",
  alternates: {
    canonical: "/fmcg-distributor-software",
  },
  openGraph: {
    title: "FMCG Distributor Software | OrdWave",
    description:
      "Stop risky dispatches, collect faster, and connect orders, credit, stock, delivery, and collections for FMCG distribution teams.",
    url: "/fmcg-distributor-software",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "FMCG Distributor Software | OrdWave",
    description:
      "Credit-aware order execution for Indian FMCG distributors.",
  },
};

const faqItems = [
  {
    q: "Who is this page for?",
    a: "It is primarily for Indian FMCG, food, and wholesale distributors managing retailer credit, order intake through calls or WhatsApp, branch dispatch coordination, and outstanding follow-up.",
  },
  {
    q: "Does OrdWave replace accounting software?",
    a: "No. OrdWave is positioned as the system for controlling what happens before accounting: order capture, credit checks, dispatch readiness, delivery confirmation, invoicing flow, and collections follow-through.",
  },
  {
    q: "Can we start with one branch first?",
    a: "Yes. The preferred rollout path is to start with one branch and one operating model, then expand after the workflow is stable.",
  },
];

export default function FmcgDistributorSoftwarePage() {
  const breadcrumbSchema = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Home", item: siteConfig.siteUrl },
      {
        "@type": "ListItem",
        position: 2,
        name: "FMCG Distributor Software",
        item: `${siteConfig.siteUrl}/fmcg-distributor-software`,
      },
    ],
  };

  const faqSchema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faqItems.map((faq) => ({
      "@type": "Question",
      name: faq.q,
      acceptedAnswer: { "@type": "Answer", text: faq.a },
    })),
  };

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumbSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />

      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">FMCG distributor software</span>
          <h1 className="mt-4 max-w-5xl text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">
            FMCG distributor software for teams that need credit visibility before dispatch
          </h1>
          <p className="mt-4 max-w-3xl text-base leading-relaxed text-[#475569] sm:text-lg">
            OrdWave helps Indian FMCG distributors keep retailer orders, outstanding balances, credit decisions, stock allocation, dispatch, invoicing, and collections connected in one operating flow.
          </p>
          <div className="mt-8 flex flex-wrap gap-3">
            <TrackedLink
              href="/request-demo"
              label="Start 30-Day Pilot"
              section="fmcg-hero"
              eventName="industry_page_cta_clicked"
              className="btn-primary px-6 py-3 text-base"
            >
              Start 30-Day Pilot
            </TrackedLink>
            <TrackedLink href="/pricing" label="View Pricing" section="fmcg-hero" className="btn-secondary px-6 py-3 text-base">
              View Pricing
            </TrackedLink>
          </div>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="grid gap-6 lg:grid-cols-2">
          <div className="card p-6 sm:p-8">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#9F1239]">Common FMCG distributor problems</p>
            <ul className="mt-5 space-y-3 text-sm leading-6 text-[#475569]">
              <li>Orders come through calls and WhatsApp without structured approval.</li>
              <li>Outstanding is checked separately from the actual order that needs to be dispatched.</li>
              <li>Warehouse teams act before finance and owners have full credit context.</li>
              <li>Collections follow-up is reactive instead of prioritised from ageing and exposure.</li>
            </ul>
          </div>
          <div className="card p-6 sm:p-8">
            <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#166534]">What OrdWave changes</p>
            <ul className="mt-5 space-y-3 text-sm leading-6 text-[#475569]">
              <li>Retailer orders are reviewed with outstanding, overdue days, and credit policy in the same flow.</li>
              <li>Orders can be approved, held, or blocked before stock leaves the warehouse.</li>
              <li>Inventory allocation, dispatch, proof of delivery, and invoicing stay connected to the order lifecycle.</li>
              <li>Collections tracking gives owners and finance teams a cleaner follow-up rhythm.</li>
            </ul>
          </div>
        </div>
      </section>

      <section className="border-y border-[#E2E8F0] bg-[#F8FAF8]">
        <div className="section-shell section-gap">
          <div className="max-w-3xl">
            <span className="pill">Credit-before-dispatch workflow</span>
            <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
              The order should not move until the credit risk is clear
            </h2>
          </div>
          <div className="mt-10 rounded-[32px] border border-[#DCE5DD] bg-white p-6 shadow-sm sm:p-8">
            <div className="grid gap-4 md:grid-cols-8">
              {[
                "Retailer Order",
                "Outstanding Check",
                "Credit Policy",
                "Approve / Hold / Block",
                "Stock Allocation",
                "Dispatch",
                "Invoice",
                "Collection",
              ].map((step, index) => (
                <div key={step} className="rounded-2xl border border-[#E2E8F0] bg-[#F8FAF8] p-4 text-sm font-semibold text-[#0F172A]">
                  <span className="mb-2 block text-[10px] font-bold uppercase tracking-[0.16em] text-[#94A3B8]">Step {index + 1}</span>
                  {step}
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="grid gap-6 lg:grid-cols-3">
          {[
            {
              title: "Order management for FMCG teams",
              body: "Capture and review orders in one flow instead of spreading the decision across calls, chats, and spreadsheets.",
            },
            {
              title: "Collections and retailer outstanding",
              body: "Give finance and owners a clearer view of overdue accounts and what should be chased first.",
            },
            {
              title: "Inventory and delivery coordination",
              body: "Keep stock allocation, dispatch, delivery proof, and invoicing connected to the same order lifecycle.",
            },
          ].map((item) => (
            <div key={item.title} className="card p-6">
              <h2 className="text-xl font-semibold text-[#0F172A]">{item.title}</h2>
              <p className="mt-3 text-sm leading-6 text-[#475569]">{item.body}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="border-y border-[#E2E8F0] bg-[#F8FAF8]">
        <div className="section-shell section-gap">
          <div className="grid gap-8 lg:grid-cols-[1fr_0.95fr] lg:items-center">
            <div>
              <span className="pill">Accounting fit</span>
              <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
                Work with your existing accounting process
              </h2>
              <p className="mt-4 text-base leading-7 text-[#475569]">
                Many distributor businesses already rely on accounting software for final records. OrdWave is designed to help manage what happens before that: order control, credit awareness, dispatch decisions, invoice flow, and collection visibility.
              </p>
            </div>
            <div className="card p-6 sm:p-8">
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#64748B]">Best fit today</p>
              <ul className="mt-5 space-y-3 text-sm leading-6 text-[#475569]">
                <li>1 to 5 branches</li>
                <li>5 to 30 operational users</li>
                <li>100 to 2,000 retailers</li>
                <li>Retailer credit exposure is a real daily issue</li>
                <li>Orders still rely on calls, WhatsApp, or manual tracking</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="rounded-[32px] border border-[#D7E8DD] bg-[linear-gradient(180deg,#F6FBF8_0%,#FFFFFF_100%)] p-8 shadow-sm sm:p-10">
          <span className="pill">Founding distributor program</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
            Start with a low-risk pilot
          </h2>
          <p className="mt-4 max-w-3xl text-base leading-7 text-[#475569]">
            We are onboarding our first distribution businesses with assisted implementation, data import help, and founder-led support for the first 30 days.
          </p>
          <div className="mt-6 flex flex-wrap gap-3">
            <TrackedLink
              href="/request-demo"
              label="Start My Pilot"
              section="fmcg-pilot"
              eventName="industry_page_cta_clicked"
              className="btn-primary px-6 py-3"
            >
              Start My Pilot
            </TrackedLink>
            <TrackedLink href="/pricing" label="See Pilot Pricing" section="fmcg-pilot" className="btn-secondary px-6 py-3">
              See Pilot Pricing
            </TrackedLink>
          </div>
        </div>
      </section>

      <section className="section-shell pb-20">
        <div className="mx-auto max-w-4xl">
          <span className="pill">FAQ</span>
          <div className="mt-6 space-y-3">
            {faqItems.map((faq) => (
              <div key={faq.q} className="card p-6">
                <h2 className="text-sm font-semibold text-[#0F172A]">{faq.q}</h2>
                <p className="mt-2 text-sm leading-6 text-[#475569]">{faq.a}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
