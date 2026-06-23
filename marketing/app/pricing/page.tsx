import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Pricing",
  description: "Pricing plans for OrdWave OMS for growing and multi-branch distributor operations.",
};

const tiers = [
  {
    name: "Starter",
    detail: "For small teams moving away from manual order and collection tracking.",
    bullets: ["Order lifecycle visibility", "Basic credit control", "GST-ready invoices"],
    badge: "Good for getting started",
  },
  {
    name: "Growth",
    detail: "For scaling distributors with branch operations, dispatch teams, and finance workflows.",
    bullets: ["Multi-branch visibility", "Collections tracking", "Delivery execution monitoring"],
    badge: "Most popular",
  },
  {
    name: "Enterprise",
    detail: "For advanced governance, role control, and high-scale operations across entities.",
    bullets: ["Advanced controls", "Custom process workflows", "Priority onboarding support"],
    badge: "For large operations",
  },
];

export default function PricingPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-border/60">
        <div className="section-shell section-gap">
          <span className="pill">Flexible plans</span>
          <h1 className="mt-4 text-4xl font-bold tracking-tight sm:text-5xl">Pricing designed for distributor growth stages</h1>
          <p className="mt-4 max-w-3xl text-text-secondary">
            Start with what your team needs today and scale into advanced workflows as your business expands.
          </p>
        </div>
      </section>

      <section className="section-shell section-gap">
      <div className="grid gap-4 md:grid-cols-3">
        {tiers.map((tier) => (
          <div
            key={tier.name}
            className={`premium-card p-6 ${tier.name === "Growth" ? "ring-2 ring-primary/30" : ""}`}
          >
            <span className="inline-flex rounded-full bg-primary/10 px-2.5 py-1 text-xs font-semibold text-primary">{tier.badge}</span>
            <h2 className="text-lg font-semibold">{tier.name}</h2>
            <p className="mt-2 text-sm text-text-secondary">{tier.detail}</p>
            <ul className="mt-4 space-y-2 text-sm text-text-primary">
              {tier.bullets.map((bullet) => (
                <li key={bullet}>• {bullet}</li>
              ))}
            </ul>
            <Link
              href="/request-demo"
              className={`mt-6 inline-flex rounded-lg px-4 py-2.5 text-sm font-semibold ${tier.name === "Growth" ? "bg-primary text-white hover:bg-primary-700" : "border border-border hover:bg-background-subtle"}`}
            >
              Talk to Sales
            </Link>
          </div>
        ))}
      </div>

      <div className="mt-10 grid gap-4 md:grid-cols-3">
        <div className="premium-card p-5">
          <p className="text-sm font-semibold">Implementation support</p>
          <p className="mt-2 text-sm text-text-secondary">Onboarding guidance for sales, warehouse, finance, and dispatch workflows.</p>
        </div>
        <div className="premium-card p-5">
          <p className="text-sm font-semibold">Security and reliability</p>
          <p className="mt-2 text-sm text-text-secondary">Role-aware access, audit-ready workflows, and production-grade hosting support.</p>
        </div>
        <div className="premium-card p-5">
          <p className="text-sm font-semibold">Scale confidence</p>
          <p className="mt-2 text-sm text-text-secondary">Move from one branch to many without replacing tools or rebuilding processes.</p>
        </div>
      </div>

      <div className="mt-10 premium-card p-6">
        <h2 className="text-xl font-semibold">Frequently asked questions</h2>
        <div className="mt-4 space-y-3 text-sm text-text-secondary">
          <p><span className="font-semibold text-text-primary">Do you support multi-branch operations?</span> Yes, plans are designed to scale across branch networks.</p>
          <p><span className="font-semibold text-text-primary">Is GST invoicing included?</span> Yes, GST-ready invoicing workflows are part of the platform.</p>
          <p><span className="font-semibold text-text-primary">Can we start small and upgrade later?</span> Yes, plans can evolve as your team and process complexity grow.</p>
        </div>
      </div>
      </section>
    </>
  );
}
