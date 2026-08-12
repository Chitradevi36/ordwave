"use client";

import { useState } from "react";
import { TrackedLink } from "@/components/tracked-link";

const tiers = [
  {
    name: "Starter",
    stage: "Single-branch control",
    badge: "For first rollout",
    monthly: "Rs 12,999",
    yearly: "Rs 10,999",
    description:
      "For distributors replacing scattered WhatsApp, manual approvals, and spreadsheet follow-up with one dependable operating flow.",
    bestFor: ["1 branch", "Founders and branch managers", "Early process standardization"],
    includes: [
      "Order lifecycle visibility",
      "Basic credit control",
      "GST-ready invoicing workflows",
      "Sales rep mobile app",
      "Core onboarding support",
    ],
    accent: "border-[#D5EBDD] bg-white",
    featured: false,
  },
  {
    name: "Growth",
    stage: "Multi-team execution",
    badge: "Most chosen",
    monthly: "Rs 24,999",
    yearly: "Rs 20,999",
    description:
      "For growing teams that need tighter coordination across sales, warehouse, finance, dispatch, and branch operations.",
    bestFor: ["2 to 5 branches", "Ops and finance coordination", "Daily collection visibility"],
    includes: [
      "Multi-branch visibility",
      "Advanced credit and collections workflows",
      "Delivery execution monitoring",
      "Role-based dashboards and analytics",
      "Priority rollout guidance",
    ],
    accent: "border-[#1B4332] bg-[linear-gradient(180deg,#F7FBF9_0%,#FFFFFF_60%)]",
    featured: true,
  },
  {
    name: "Enterprise",
    stage: "Governed scale",
    badge: "Custom rollout",
    monthly: "Custom",
    yearly: "Custom",
    description:
      "For larger distributor networks that need custom approvals, deeper governance, and integration-led expansion.",
    bestFor: ["5+ branches", "Advanced approval structures", "Integration-heavy environments"],
    includes: [
      "Custom process workflows",
      "Advanced approval controls",
      "Integration planning support",
      "Dedicated success manager",
      "Enterprise onboarding track",
    ],
    accent: "border-[#D8DEE9] bg-white",
    featured: false,
  },
];

const capabilityRows = [
  ["Order workflow", "Core", "Advanced", "Advanced + tailored"],
  ["Credit controls", "Basic", "Advanced", "Advanced + policy tailoring"],
  ["Collections workflow", "Basic follow-up", "Aging-driven queue", "Advanced orchestration"],
  ["Branch visibility", "Single branch", "Multi-branch", "Multi-entity ready"],
  ["Delivery tracking", "Core", "Expanded", "Expanded + custom needs"],
  ["Mobile apps", "Sales", "Sales + ops", "Full rollout"],
  ["Implementation support", "Included", "Priority", "Dedicated"],
  ["Custom approvals", "No", "Limited", "Yes"],
];

const rolloutSteps = [
  {
    title: "Stage 1",
    label: "Stabilize order flow",
    body: "Clean up order intake, role handoffs, and dispatch readiness so the branch stops running on memory and WhatsApp.",
  },
  {
    title: "Stage 2",
    label: "Tighten credit and collections",
    body: "Bring credit holds, aging follow-up, and accountability into a daily operational rhythm.",
  },
  {
    title: "Stage 3",
    label: "Scale across branches",
    body: "Standardize the operating model across branches without losing local execution clarity.",
  },
];

const faqs = [
  {
    q: "Can we start with one branch and expand later?",
    a: "Yes. The pricing structure is intentionally staged so teams can prove the workflow in one branch first, then expand without redoing the operating model.",
  },
  {
    q: "Is onboarding included?",
    a: "Yes. Every plan includes onboarding support. The depth increases by plan, from core setup help to dedicated rollout guidance.",
  },
  {
    q: "Do you support GST and distributor-specific operations?",
    a: "Yes. OrdWave is positioned around Indian distributor workflows including GST-ready invoicing, credit control, dispatch, and collections processes.",
  },
  {
    q: "How do we know which plan fits us?",
    a: "The fastest way is to share branch count, order volume, field team size, and the bottlenecks hurting you most. We then recommend the cleanest rollout path.",
  },
];

function PricingCard({
  tier,
  billingPeriod,
}: {
  tier: (typeof tiers)[number];
  billingPeriod: "monthly" | "yearly";
}) {
  const displayPrice = billingPeriod === "yearly" ? tier.yearly : tier.monthly;
  const showCustom = displayPrice === "Custom";

  return (
    <div
      className={`relative overflow-hidden rounded-[28px] border p-7 shadow-[0_18px_50px_rgba(15,23,42,0.08)] transition-transform duration-200 hover:-translate-y-1 ${tier.accent} ${tier.featured ? "lg:-mt-4" : ""}`}
    >
      {tier.featured && (
        <div className="absolute inset-x-0 top-0 h-1.5 bg-[linear-gradient(90deg,#1B4332_0%,#52B788_100%)]" />
      )}
      <div className="flex items-start justify-between gap-4">
        <div>
          <span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${tier.featured ? "bg-[#1B4332] text-white" : "bg-[#EFF7F2] text-[#1B4332]"}`}>
            {tier.badge}
          </span>
          <h2 className="mt-4 text-2xl font-bold tracking-tight text-[#0F172A]">{tier.name}</h2>
          <p className="mt-1 text-sm font-medium text-[#1B4332]">{tier.stage}</p>
        </div>
        <div className="rounded-2xl border border-[#E2E8F0] bg-white/80 px-4 py-3 text-right backdrop-blur">
          <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-[#94A3B8]">From</p>
          <p className="text-2xl font-bold text-[#0F172A]">{displayPrice}</p>
          {!showCustom && (
            <p className="text-xs text-[#64748B]">
              {billingPeriod === "yearly" ? "per month, billed yearly" : "per month"}
            </p>
          )}
        </div>
      </div>

      {billingPeriod === "yearly" && tier.yearly !== "Custom" && (
        <p className="mt-4 inline-flex rounded-full bg-[#DCFCE7] px-3 py-1 text-xs font-semibold text-[#166534]">
          Save about 15% with annual billing
        </p>
      )}

      {billingPeriod === "monthly" && tier.yearly !== "Custom" && (
        <p className="mt-4 inline-flex rounded-full bg-[#EFF7F2] px-3 py-1 text-xs font-semibold text-[#1B4332]">
          Yearly from {tier.yearly}/month
        </p>
      )}

      <p className="mt-5 text-sm leading-6 text-[#475569]">{tier.description}</p>

      <div className="mt-6 rounded-2xl border border-[#E2E8F0] bg-white/70 p-4">
        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-[#64748B]">Best for</p>
        <div className="mt-3 flex flex-wrap gap-2">
          {tier.bestFor.map((item) => (
            <span key={item} className="rounded-full bg-[#F8FAF8] px-3 py-1.5 text-xs font-medium text-[#475569]">
              {item}
            </span>
          ))}
        </div>
      </div>

      <ul className="mt-6 space-y-3 text-sm text-[#0F172A]">
        {tier.includes.map((item) => (
          <li key={item} className="flex items-start gap-3">
            <span className={`mt-1 inline-flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-[11px] font-bold ${tier.featured ? "bg-[#1B4332] text-white" : "bg-[#EFF7F2] text-[#1B4332]"}`}>
              ✓
            </span>
            <span>{item}</span>
          </li>
        ))}
      </ul>

      <TrackedLink
        href="/request-demo"
        label={`Map My Workflow - ${tier.name}`}
        section="pricing-card"
        className={`mt-8 inline-flex w-full items-center justify-center rounded-xl px-5 py-3 text-sm font-semibold ${
          tier.featured
            ? "bg-[#1B4332] text-white shadow-[0_16px_35px_rgba(27,67,50,0.24)] hover:bg-[#163727]"
            : "border border-[#D8E2DC] bg-white text-[#0F172A] hover:bg-[#F8FAF8]"
        }`}
      >
        Map My Workflow
      </TrackedLink>
    </div>
  );
}

export function PricingPageClient() {
  const [billingPeriod, setBillingPeriod] = useState<"monthly" | "yearly">("monthly");

  return (
    <>
      <section className="gradient-mesh relative overflow-hidden border-b border-[#E2E8F0]">
        <div className="pointer-events-none absolute right-0 top-0 h-80 w-80 rounded-full bg-[#52B788]/10 blur-3xl" />
        <div className="pointer-events-none absolute bottom-0 left-0 h-72 w-72 rounded-full bg-[#1B4332]/8 blur-3xl" />
        <div className="section-shell grid gap-10 py-16 sm:py-20 lg:grid-cols-[1.2fr_0.8fr] lg:items-end lg:py-24">
          <div>
            <span className="pill">Pricing that follows your rollout stage</span>
            <h1 className="mt-5 max-w-4xl text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl lg:text-6xl">
              Start with control.
              <br />
              Scale into discipline.
            </h1>
            <p className="mt-5 max-w-2xl text-base leading-relaxed text-[#475569] sm:text-lg">
              OrdWave pricing is structured around how distributor teams mature: first stabilize order flow, then tighten credit and collections, then scale the model across branches.
            </p>
            <div className="mt-8 flex flex-wrap gap-3">
              <TrackedLink href="/request-demo" label="Map My Workflow" section="pricing-hero" className="btn-primary px-6 py-3 text-base">
                Map My Workflow
              </TrackedLink>
              <a href="#plans" className="btn-secondary px-6 py-3 text-base">
                Compare Plans
              </a>
            </div>
          </div>

          <div className="grid gap-3 sm:grid-cols-3 lg:grid-cols-1">
            {rolloutSteps.map((step, index) => (
              <div key={step.title} className="rounded-2xl border border-[#D8E2DC] bg-white/85 p-5 shadow-[0_14px_30px_rgba(15,23,42,0.07)] backdrop-blur">
                <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-[#94A3B8]">
                  {step.title} · {index + 1}
                </p>
                <h2 className="mt-2 text-lg font-semibold text-[#0F172A]">{step.label}</h2>
                <p className="mt-2 text-sm leading-6 text-[#475569]">{step.body}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section id="plans" className="section-shell section-gap">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div className="max-w-2xl">
            <span className="pill">Plans</span>
            <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
              Choose the operating layer you need now
            </h2>
            <p className="mt-3 text-base text-[#475569]">
              Each plan adds structure where operational leakage usually starts: order flow, credit approvals, branch visibility, delivery control, and collections follow-through.
            </p>
          </div>
          <div
            className="inline-flex rounded-full border border-[#E2E8F0] bg-white p-1 shadow-sm"
            role="tablist"
            aria-label="Billing period"
          >
            <button
              type="button"
              role="tab"
              aria-selected={billingPeriod === "monthly"}
              onClick={() => setBillingPeriod("monthly")}
              className={`rounded-full px-4 py-1.5 text-xs font-semibold transition-colors ${
                billingPeriod === "monthly"
                  ? "bg-[#1B4332] text-white"
                  : "text-[#64748B] hover:bg-[#F8FAF8]"
              }`}
            >
              Monthly
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={billingPeriod === "yearly"}
              onClick={() => setBillingPeriod("yearly")}
              className={`rounded-full px-4 py-1.5 text-xs font-semibold transition-colors ${
                billingPeriod === "yearly"
                  ? "bg-[#1B4332] text-white"
                  : "text-[#64748B] hover:bg-[#F8FAF8]"
              }`}
            >
              Yearly
            </button>
          </div>
        </div>

        <div className="mt-10 grid gap-5 lg:grid-cols-3 lg:items-start">
          {tiers.map((tier) => (
            <PricingCard key={tier.name} tier={tier} billingPeriod={billingPeriod} />
          ))}
        </div>

        <div className="mt-10 grid gap-4 md:grid-cols-3">
          {[
            {
              title: "Implementation support",
              body: "We guide the rollout across sales, warehouse, finance, and dispatch so the platform fits the real branch workflow.",
            },
            {
              title: "No forced big-bang rollout",
              body: "Start with one branch, one process, or one control point first. Expand only after the model is working.",
            },
            {
              title: "Commercial clarity",
              body: "Enterprise pricing is scoped around branch count, workflow depth, approvals, and integration expectations.",
            },
          ].map((item) => (
            <div key={item.title} className="card-flat p-5">
              <h3 className="text-sm font-semibold text-[#0F172A]">{item.title}</h3>
              <p className="mt-2 text-sm leading-6 text-[#475569]">{item.body}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="border-y border-[#E2E8F0] bg-[#F8FAF8]">
        <div className="section-shell section-gap">
          <div className="grid gap-10 lg:grid-cols-[0.9fr_1.1fr] lg:items-start">
            <div>
              <span className="pill">What changes by plan</span>
              <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
                The difference is not features alone. It is operating depth.
              </h2>
              <p className="mt-4 text-base leading-relaxed text-[#475569]">
                The real jump between plans is how much discipline and coordination OrdWave can enforce across teams, branches, and approval points.
              </p>
              <div className="mt-6 space-y-3">
                {[
                  "Starter is about replacing chaos with one consistent order-to-dispatch workflow.",
                  "Growth adds the visibility and controls needed when teams start depending on each other daily.",
                  "Enterprise is for organizations that need tailored approvals, rollout governance, and integration planning.",
                ].map((point) => (
                  <div key={point} className="flex gap-3 rounded-2xl border border-[#E2E8F0] bg-white p-4">
                    <span className="mt-1 h-2.5 w-2.5 shrink-0 rounded-full bg-[#52B788]" />
                    <p className="text-sm leading-6 text-[#475569]">{point}</p>
                  </div>
                ))}
              </div>
            </div>

            <div className="overflow-hidden rounded-[28px] border border-[#DCE5DD] bg-white shadow-[0_20px_50px_rgba(15,23,42,0.08)]">
              <table className="min-w-full text-sm">
                <thead>
                  <tr className="border-b border-[#E2E8F0] bg-[#FCFDFC] text-left">
                    <th className="px-5 py-4 text-xs font-semibold uppercase tracking-[0.16em] text-[#64748B]">Capability</th>
                    <th className="px-5 py-4 text-xs font-semibold uppercase tracking-[0.16em] text-[#64748B]">Starter</th>
                    <th className="bg-[#F2F8F4] px-5 py-4 text-xs font-bold uppercase tracking-[0.16em] text-[#1B4332]">Growth</th>
                    <th className="px-5 py-4 text-xs font-semibold uppercase tracking-[0.16em] text-[#64748B]">Enterprise</th>
                  </tr>
                </thead>
                <tbody>
                  {capabilityRows.map((row) => (
                    <tr key={row[0]} className="border-t border-[#E2E8F0]">
                      {row.map((cell, index) => (
                        <td
                          key={`${row[0]}-${index}`}
                          className={`px-5 py-4 align-top ${
                            index === 0
                              ? "font-medium text-[#0F172A]"
                              : index === 2
                                ? "bg-[#F2F8F4] font-semibold text-[#1B4332]"
                                : "text-[#475569]"
                          }`}
                        >
                          {cell}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="grid gap-6 lg:grid-cols-[1.15fr_0.85fr]">
          <div className="gradient-dark relative overflow-hidden rounded-[32px] p-8 text-white sm:p-10">
            <div className="pointer-events-none absolute -right-16 top-0 h-48 w-48 rounded-full bg-[#52B788]/15 blur-3xl" />
            <span className="relative inline-flex rounded-full border border-[#52B788]/30 bg-[#52B788]/10 px-3 py-1 text-xs font-semibold text-[#74C69D]">
              Buying help
            </span>
            <h2 className="relative mt-5 text-3xl font-bold tracking-tight sm:text-4xl">
              Not sure which plan fits your workflow?
            </h2>
            <p className="relative mt-4 max-w-2xl text-sm leading-7 text-white/75 sm:text-base">
              Share your branch count, order volume, field team size, and where the operational pain is highest. We will recommend the smallest rollout that actually fixes the problem.
            </p>
            <div className="relative mt-8 grid gap-3 sm:grid-cols-3">
              {[
                { value: "Orders", note: "Per day and per branch" },
                { value: "Credit", note: "Approval and aging pain" },
                { value: "Branches", note: "Current and next 12 months" },
              ].map((item) => (
                <div key={item.value} className="rounded-2xl border border-white/10 bg-white/5 p-4">
                  <p className="text-sm font-bold text-[#74C69D]">{item.value}</p>
                  <p className="mt-1 text-xs text-white/70">{item.note}</p>
                </div>
              ))}
            </div>
            <div className="relative mt-8">
              <TrackedLink href="/request-demo" label="Get plan recommendation" section="pricing-mid-cta" className="btn-primary px-7 py-3 text-base">
                Get Plan Recommendation
              </TrackedLink>
            </div>
          </div>

          <div className="rounded-[32px] border border-[#E2E8F0] bg-white p-8 shadow-[0_16px_40px_rgba(15,23,42,0.06)]">
            <span className="pill">FAQ</span>
            <div className="mt-5 space-y-5">
              {faqs.map((faq) => (
                <div key={faq.q} className="border-b border-[#EEF2F6] pb-5 last:border-b-0 last:pb-0">
                  <h3 className="text-sm font-semibold text-[#0F172A]">{faq.q}</h3>
                  <p className="mt-2 text-sm leading-6 text-[#475569]">{faq.a}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
