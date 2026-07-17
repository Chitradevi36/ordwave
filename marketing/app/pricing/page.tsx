import type { Metadata } from "next";
import Link from "next/link";
import { TrackedLink } from "@/components/tracked-link";

export const metadata: Metadata = {
  title: "Pricing",
  description: "Pricing plans for OrdWave OMS for Indian distributors, from early-stage FMCG teams to multi-branch operations.",
};

const tiers = [
  {
    name: "Starter",
    detail: "For single-branch FMCG teams standardizing order-to-cash operations.",
    bullets: ["Order lifecycle visibility", "Basic credit control", "GST-ready invoices", "Sales rep mobile app"],
    badge: "Best for getting started",
    monthly: "₹12,999",
    yearly: "₹10,999",
  },
  {
    name: "Growth",
    detail: "For scaling distributor teams with branch complexity and cross-functional operations.",
    bullets: ["Multi-branch visibility", "Collections tracking", "Delivery execution monitoring", "Advanced analytics"],
    badge: "Most popular",
    monthly: "₹24,999",
    yearly: "₹20,999",
  },
  {
    name: "Enterprise",
    detail: "For advanced governance, integrations, and large multi-entity operations.",
    bullets: ["Advanced controls", "Custom process workflows", "Priority onboarding support", "Dedicated success manager"],
    badge: "For large operations",
    monthly: "Custom",
    yearly: "Custom",
  },
];

export default function PricingPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">Flexible plans</span>
          <h1 className="mt-4 text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">Pricing designed for distributor growth stages</h1>
          <p className="mt-4 max-w-3xl text-[#475569]">
            Start with your current operating needs and scale into advanced workflows as branch count, users, and complexity grow.
          </p>
          <div className="mt-6 inline-flex rounded-full border border-[#E2E8F0] bg-white p-1 shadow-sm">
            <span className="rounded-full bg-[#1B4332] px-4 py-1.5 text-xs font-semibold text-white">Monthly</span>
            <span className="rounded-full px-4 py-1.5 text-xs font-semibold text-[#64748B]">Yearly — save ~15%</span>
          </div>
        </div>
      </section>

      <section className="section-shell section-gap">
      <div className="grid gap-4 md:grid-cols-3">
        {tiers.map((tier) => (
          <div
            key={tier.name}
            className={`card p-6 ${tier.name === "Growth" ? "ring-2 ring-[#1B4332]/20 shadow-[0_20px_50px_rgba(27,67,50,0.14)]" : ""}`}
          >
            <span className="inline-flex rounded-full bg-[#EFF7F2] px-2.5 py-1 text-xs font-semibold text-[#1B4332]">{tier.badge}</span>
            <h2 className="mt-3 text-xl font-semibold text-[#0F172A]">{tier.name}</h2>
            <div className="mt-3">
              <span className="text-3xl font-bold text-[#0F172A]">{tier.monthly}</span>
              {tier.monthly !== "Custom" && <span className="ml-1 text-sm text-[#64748B]">/month</span>}
              {tier.yearly !== "Custom" && <p className="mt-1 text-xs font-medium text-[#166534]">Yearly from {tier.yearly}/month</p>}
            </div>
            <p className="mt-3 text-sm text-[#475569]">{tier.detail}</p>
            <ul className="mt-5 space-y-2 text-sm text-[#0F172A]">
              {tier.bullets.map((bullet) => (
                <li key={bullet} className="flex items-center gap-2"><span className="h-1.5 w-1.5 rounded-full bg-[#52B788]" />{bullet}</li>
              ))}
            </ul>
            <TrackedLink
              href="/request-demo"
              label={tier.name === "Starter" ? "Start Free Trial" : "Book Demo"}
              section="pricing"
              className={`mt-6 inline-flex rounded-xl px-4 py-2.5 text-sm font-semibold ${tier.name === "Growth" ? "bg-[#1B4332] text-white hover:bg-[#163727]" : "border border-[#E2E8F0] bg-white hover:bg-[#F8FAF8]"}`}
            >
              {tier.name === "Starter" ? "Start Free Trial" : "Book Demo"}
            </TrackedLink>
          </div>
        ))}
      </div>

      <div className="mt-10 grid gap-4 md:grid-cols-3">
        <div className="card p-5">
          <p className="text-sm font-semibold text-[#0F172A]">Implementation support</p>
          <p className="mt-2 text-sm text-[#475569]">Onboarding guidance for sales, warehouse, finance, and dispatch workflows.</p>
        </div>
        <div className="card p-5">
          <p className="text-sm font-semibold text-[#0F172A]">Security and reliability</p>
          <p className="mt-2 text-sm text-[#475569]">Role-aware access, audit-ready workflows, and production-grade hosting support.</p>
        </div>
        <div className="card p-5">
          <p className="text-sm font-semibold text-[#0F172A]">Scale confidence</p>
          <p className="mt-2 text-sm text-[#475569]">Move from one branch to many without replacing tools or rebuilding processes.</p>
        </div>
      </div>

      <div className="mt-10 card overflow-x-auto p-6">
        <h2 className="text-xl font-semibold text-[#0F172A]">Feature comparison</h2>
        <table className="mt-5 min-w-full text-sm">
          <thead>
            <tr className="border-b border-[#E2E8F0] text-left">
              <th className="px-3 py-3 text-xs uppercase tracking-wide text-[#64748B]">Capability</th>
              <th className="px-3 py-3 text-xs uppercase tracking-wide text-[#64748B]">Starter</th>
              <th className="px-3 py-3 text-xs uppercase tracking-wide text-[#64748B]">Growth</th>
              <th className="px-3 py-3 text-xs uppercase tracking-wide text-[#64748B]">Enterprise</th>
            </tr>
          </thead>
          <tbody>
            {[
              ["Order workflow", "✓", "✓", "✓"],
              ["Credit controls", "Basic", "Advanced", "Advanced"],
              ["Branch management", "—", "✓", "✓"],
              ["Mobile apps", "✓", "✓", "✓"],
              ["Custom approvals", "—", "—", "✓"],
              ["Dedicated onboarding", "—", "Optional", "✓"],
            ].map((row) => (
              <tr key={row[0]} className="border-t border-[#E2E8F0]">
                {row.map((cell, index) => (
                  <td key={cell + index} className={`px-3 py-3 ${index === 0 ? "font-medium text-[#0F172A]" : "text-[#475569]"}`}>{cell}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="mt-10 rounded-3xl bg-[#0F1A13] p-8 text-white sm:p-10">
        <div className="grid gap-6 md:grid-cols-[1.4fr_1fr] md:items-center">
          <div>
            <h2 className="text-2xl font-bold sm:text-3xl">Not sure which plan fits?</h2>
            <p className="mt-3 max-w-2xl text-sm text-white/75 sm:text-base">Share your sales reps, orders per day, and branch count. We’ll recommend the right rollout and expected ROI.</p>
          </div>
          <div className="grid grid-cols-3 gap-3 text-center">
            <div className="rounded-2xl border border-white/10 bg-white/5 p-4"><p className="text-sm font-bold text-[#52B788]">Order lifecycle</p><p className="mt-1 text-xs text-white/70">Track from booking to dispatch</p></div>
            <div className="rounded-2xl border border-white/10 bg-white/5 p-4"><p className="text-sm font-bold text-[#52B788]">Credit controls</p><p className="mt-1 text-xs text-white/70">Policy-based approvals</p></div>
            <div className="rounded-2xl border border-white/10 bg-white/5 p-4"><p className="text-sm font-bold text-[#52B788]">Collections</p><p className="mt-1 text-xs text-white/70">Aging-aware follow-up</p></div>
          </div>
        </div>
      </div>

      <div className="mt-10 card p-6">
        <h2 className="text-xl font-semibold text-[#0F172A]">Frequently asked questions</h2>
        <div className="mt-4 space-y-3 text-sm text-[#475569]">
          <p><span className="font-semibold text-[#0F172A]">Do you support multi-branch operations?</span> Yes, plans are designed to scale across branch networks.</p>
          <p><span className="font-semibold text-[#0F172A]">Is GST invoicing included?</span> Yes, GST-ready invoicing workflows are part of the platform.</p>
          <p><span className="font-semibold text-[#0F172A]">Can we start small and upgrade later?</span> Yes, plans can evolve as your team and process complexity grow.</p>
        </div>
      </div>
      </section>
    </>
  );
}
