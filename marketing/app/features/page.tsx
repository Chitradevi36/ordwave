import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Features",
  description: "Explore OrdWave features for order management, retailer CRM, credit control, inventory, delivery tracking, collections, GST invoicing, and analytics.",
};

const features = [
  {
    title: "Order Management",
    detail: "Move orders from booking to dispatch with clean workflow states and fewer operational misses.",
  },
  {
    title: "Retailer CRM",
    detail: "Track outlet profile, route, payment behavior, and engagement context for smarter sales execution.",
  },
  {
    title: "Credit Control",
    detail: "Apply rule-based credit checks so teams can approve confidently and avoid high-risk exposure.",
  },
  {
    title: "Inventory Management",
    detail: "Keep branch-level stock accurate with transfer visibility, alerts, and real-time inventory checks.",
  },
  {
    title: "Delivery Tracking",
    detail: "See trip progress and stop-level status to resolve delays early and improve fulfillment quality.",
  },
  {
    title: "Payments and Collections",
    detail: "Centralize dues and collection status so finance teams act faster with clearer follow-up priorities.",
  },
  {
    title: "GST-ready Invoicing",
    detail: "Generate compliant invoices quickly with workflows built for Indian distributor operations.",
  },
  {
    title: "Reports and Analytics",
    detail: "Turn daily operations into decision-ready visibility across sales, credit, collections, and branch performance.",
  },
];

export default function FeaturesPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-border/60">
        <div className="section-shell section-gap">
          <span className="pill">Feature depth</span>
          <h1 className="mt-4 max-w-4xl text-4xl font-bold tracking-tight sm:text-5xl">
            Everything your distribution team needs, from order capture to collections
          </h1>
          <p className="mt-4 max-w-3xl text-text-secondary">
            OrdWave unifies sales, finance, warehouse, and dispatch workflows so operations run with less manual follow-up
            and better decision visibility.
          </p>

          <div className="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <div className="premium-card p-4">
              <p className="text-xs text-text-secondary">Order errors reduced</p>
              <p className="mt-1 text-2xl font-bold text-primary">24%</p>
            </div>
            <div className="premium-card p-4">
              <p className="text-xs text-text-secondary">Collection follow-up speed</p>
              <p className="mt-1 text-2xl font-bold text-primary">+31%</p>
            </div>
            <div className="premium-card p-4">
              <p className="text-xs text-text-secondary">Dispatch visibility</p>
              <p className="mt-1 text-2xl font-bold text-primary">Real-time</p>
            </div>
            <div className="premium-card p-4">
              <p className="text-xs text-text-secondary">Branch operations</p>
              <p className="mt-1 text-2xl font-bold text-primary">Unified</p>
            </div>
          </div>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="mb-8 flex flex-wrap gap-2">
          <span className="pill">Built for Indian distributors</span>
          <span className="pill">GST-ready workflows</span>
          <span className="pill">Credit-first operations</span>
          <span className="pill">Offline-ready field teams</span>
        </div>

        <div className="grid gap-4 md:grid-cols-2">
          {features.map((feature) => (
            <div key={feature.title} className="premium-card p-6">
              <p className="text-xs font-semibold uppercase tracking-wide text-primary">Module</p>
              <h2 className="mt-1 text-xl font-semibold">{feature.title}</h2>
              <p className="mt-2 text-sm text-text-secondary">{feature.detail}</p>
              <ul className="mt-4 space-y-1.5 text-sm text-text-primary">
                <li>• Faster day-to-day execution</li>
                <li>• Better team-level accountability</li>
                <li>• Clear business impact tracking</li>
              </ul>
              <div className="mt-5">
                <Link href="/request-demo" className="text-sm font-semibold text-primary underline-offset-4 hover:underline">Book a Demo</Link>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="section-shell pb-16 sm:pb-20">
        <div className="premium-card bg-primary p-8 text-white sm:p-10">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Want to see these modules in your workflow?</h2>
          <p className="mt-3 max-w-2xl text-sm text-white/90 sm:text-base">
            Book a live walkthrough and get a role-based demo for sales, finance, warehouse, and dispatch teams.
          </p>
          <div className="mt-6 flex flex-wrap gap-3">
            <Link href="/request-demo" className="rounded-lg bg-white px-5 py-2.5 text-sm font-semibold text-primary">Book a Demo</Link>
            <Link href="/pricing" className="rounded-lg border border-white/60 px-5 py-2.5 text-sm font-semibold text-white hover:bg-white/10">View Pricing</Link>
          </div>
        </div>
      </section>
    </>
  );
}
