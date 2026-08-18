"use client";

import { useMemo, useState } from "react";
import { TrackedLink } from "@/components/tracked-link";
import { TrackingBeacon } from "@/components/tracking-beacon";
import { getSignupHref } from "@/lib/site-config";
import { CompactPlanCard } from "../../../shared/pricing/compact-plan-card";
import { ORD_WAVE_PLANS, getDisplayPrice, getPriceHelper, type BillingPeriod } from "../../../shared/pricing/ordwave-plans";

const comparisonRows = [
  ["Order management", "Yes", "Yes", "Yes", "Custom"],
  ["Inventory", "Yes", "Yes", "Yes", "Custom"],
  ["GST-ready invoicing", "Yes", "Yes", "Yes", "Custom"],
  ["Basic credit tracking", "Yes", "Yes", "Yes", "Custom"],
  ["Credit holds and approvals", "No", "Yes", "Yes", "Custom"],
  ["Collections and ageing", "No", "Yes", "Yes", "Custom"],
  ["Delivery + POD", "No", "Yes", "Yes", "Custom"],
  ["Multi-branch operations", "No", "Limited", "Yes", "Custom"],
  ["Stock transfers", "No", "No", "Yes", "Custom"],
  ["Advanced reporting", "No", "No", "Yes", "Custom"],
];

const pricingFaqs = [
  {
    q: "Can I start on Starter and upgrade later?",
    a: "Yes. The pricing page is designed for staged rollout. Start with the right level of operational control now and expand later.",
  },
  {
    q: "Does Enterprise need a sales conversation?",
    a: "Yes. Enterprise is handled through the existing contact flow so rollout scope, workflows, and commercial terms can be reviewed properly.",
  },
  {
    q: "Does annual billing change the monthly equivalent?",
    a: "Yes. The yearly view shows the lower monthly equivalent and the full billed-annually total for Starter, Growth, and Business.",
  },
];

export function PricingPageClient() {
  const [billingPeriod, setBillingPeriod] = useState<BillingPeriod>("monthly");
  const plans = useMemo(() => ORD_WAVE_PLANS, []);

  return (
    <>
      <TrackingBeacon eventName="pricing_view" />

      <section className="gradient-mesh relative overflow-hidden border-b border-[#E2E8F0] pt-[72px] sm:pt-20">
        <div className="pointer-events-none absolute right-0 top-0 h-80 w-80 rounded-full bg-[#52B788]/10 blur-3xl" />
        <div className="pointer-events-none absolute bottom-0 left-0 h-72 w-72 rounded-full bg-[#1B4332]/8 blur-3xl" />
        <div className="section-shell grid gap-6 py-12 sm:py-14 lg:py-16">
          <div>
            <span className="pill">Pricing</span>
            <h1 className="mt-5 max-w-4xl text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl lg:text-6xl">
              Choose the plan that fits your distribution workflow
            </h1>
            <p className="mt-3 max-w-2xl text-base leading-relaxed text-[#475569] sm:text-lg">
              Start with the level of control you need now, then validate deeper differences below.
            </p>
            <div className="mt-6 flex flex-wrap gap-3">
              <TrackedLink
                href={getSignupHref("growth")}
                label="Choose Growth"
                section="pricing-hero"
                eventName="pricing_plan_selected"
                eventParams={{ plan: "growth", billing_period: billingPeriod }}
                className="btn-primary px-6 py-3 text-base"
              >
                Choose Growth
              </TrackedLink>
              <a href="#plans" className="btn-secondary px-6 py-3 text-base">
                Compare Plans
              </a>
            </div>
            <p className="mt-4 text-sm font-medium text-[#64748B]">
              Monthly or yearly billing • Upgrade anytime
            </p>
          </div>
        </div>
      </section>

      <section id="plans" className="section-shell scroll-mt-28 py-12 sm:py-14 lg:py-14">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div className="max-w-2xl">
            <span className="pill">Plans</span>
            <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
              Quick comparison in under 10 seconds
            </h2>
            <p className="mt-2 text-base text-[#475569]">
              Compare price, limits and key features.
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
                billingPeriod === "monthly" ? "bg-[#1B4332] text-white" : "text-[#64748B] hover:bg-[#F8FAF8]"
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
                billingPeriod === "yearly" ? "bg-[#1B4332] text-white" : "text-[#64748B] hover:bg-[#F8FAF8]"
              }`}
            >
              Yearly
            </button>
          </div>
        </div>

        <div className="mt-8 grid gap-5 md:grid-cols-2 xl:grid-cols-4 xl:items-stretch">
          {plans.map((plan) => (
            <CompactPlanCard
              key={plan.id}
              badge={plan.badge}
              title={plan.name}
              subtitle={plan.subtitle}
              price={getDisplayPrice(plan, billingPeriod)}
              priceSuffix={plan.monthlyPrice === null ? null : "/month"}
              helperText={getPriceHelper(plan, billingPeriod)}
              limits={plan.limits}
              features={plan.features}
              featured={Boolean(plan.featured)}
              action={
                <TrackedLink
                  href={plan.salesOnly ? "/request-demo" : getSignupHref(plan.signupQueryValue)}
                  label={plan.pricingCtaLabel}
                  section="pricing-card"
                  eventName={plan.salesOnly ? "founding_offer_clicked" : "pricing_plan_selected"}
                  eventParams={plan.salesOnly ? undefined : { plan: plan.id, billing_period: billingPeriod }}
                  className={`inline-flex w-full items-center justify-center rounded-lg px-4 py-2.5 text-sm font-semibold ${
                    plan.featured
                      ? "bg-primary text-white hover:opacity-95"
                      : "border border-border bg-white text-text-primary hover:bg-muted/50"
                  }`}
                >
                  {plan.pricingCtaLabel}
                </TrackedLink>
              }
            />
          ))}
        </div>
      </section>

      <section className="border-y border-[#E2E8F0] bg-[#F8FAF8]">
        <div className="section-shell py-14 sm:py-16 lg:py-[68px]">
          <div className="grid gap-10 lg:grid-cols-[0.8fr_1.4fr] lg:items-start">
            <div>
              <span className="pill">Feature comparison</span>
              <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
                Validate the plan after you shortlist it
              </h2>
              <p className="mt-3 text-base leading-relaxed text-[#475569]">
                The cards are intentionally compact. Use this table to confirm the deeper differences before you move ahead.
              </p>
            </div>

            <div className="overflow-hidden rounded-[28px] border border-[#DCE5DD] bg-white shadow-[0_20px_50px_rgba(15,23,42,0.08)]">
              <table className="min-w-full text-sm">
                <thead>
                  <tr className="border-b border-[#E2E8F0] bg-[#FCFDFC] text-left">
                    <th className="px-5 py-4 text-xs font-semibold uppercase tracking-[0.16em] text-[#64748B]">Capability</th>
                    <th className="px-5 py-4 text-xs font-semibold uppercase tracking-[0.16em] text-[#64748B]">Starter</th>
                    <th className="bg-[#F2F8F4] px-5 py-4 text-xs font-bold uppercase tracking-[0.16em] text-[#1B4332]">Growth</th>
                    <th className="px-5 py-4 text-xs font-semibold uppercase tracking-[0.16em] text-[#64748B]">Business</th>
                    <th className="px-5 py-4 text-xs font-semibold uppercase tracking-[0.16em] text-[#64748B]">Enterprise</th>
                  </tr>
                </thead>
                <tbody>
                  {comparisonRows.map((row) => (
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

      <section className="section-shell py-14 sm:py-16 lg:py-[68px]">
        <div className="grid gap-6 lg:grid-cols-[1.15fr_0.85fr]">
          <div className="gradient-dark relative overflow-hidden rounded-[32px] p-7 text-white sm:p-8">
            <div className="pointer-events-none absolute -right-16 top-0 h-48 w-48 rounded-full bg-[#52B788]/15 blur-3xl" />
            <span className="relative inline-flex rounded-full border border-[#52B788]/30 bg-[#52B788]/10 px-3 py-1 text-xs font-semibold text-[#74C69D]">
              Need help choosing?
            </span>
            <h2 className="relative mt-5 text-3xl font-bold tracking-tight sm:text-4xl">
              We can recommend the right rollout path
            </h2>
            <p className="relative mt-3 max-w-2xl text-sm leading-7 text-white/75 sm:text-base">
              Share your branch count, users, and order volume. We will point you to the smallest plan that fits the workflow.
            </p>
            <div className="relative mt-6">
              <TrackedLink href="/request-demo" label="Get plan recommendation" section="pricing-mid-cta" eventName="workflow_mapping_clicked" className="btn-primary px-7 py-3 text-base">
                Get Plan Recommendation
              </TrackedLink>
            </div>
          </div>

          <div className="rounded-[32px] border border-[#E2E8F0] bg-white p-7 shadow-[0_16px_40px_rgba(15,23,42,0.06)] sm:p-8">
            <span className="pill">FAQ</span>
            <div className="mt-4 space-y-4">
              {pricingFaqs.map((faq) => (
                <div key={faq.q} className="border-b border-[#EEF2F6] pb-4 last:border-b-0 last:pb-0">
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
