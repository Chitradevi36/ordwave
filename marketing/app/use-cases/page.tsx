import type { Metadata } from "next";
import Link from "next/link";
import { TrackedLink } from "@/components/tracked-link";

export const metadata: Metadata = {
  title: "Use Cases",
  description: "Use cases for owners, sales teams, warehouse teams, finance teams, and dispatch teams.",
};

const cases = [
  {
    role: "FMCG distributors",
    value: "Manage high-velocity order cycles, delivery coordination, and retailer-level credit risk in one place.",
  },
  {
    role: "Rice and staples distributors",
    value: "Track SKU movement, branch stock, and route-wise execution with better operational consistency.",
  },
  {
    role: "Wholesale grocery distributors",
    value: "Unify sales, warehouse, and finance workflows to reduce execution leakage and follow-up delays.",
  },
  {
    role: "Multi-branch distributor networks",
    value: "Run all branches from one dashboard with centralized visibility and branch-level accountability.",
  },
];

export default function UseCasesPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-border/60">
        <div className="section-shell section-gap">
          <span className="pill">Industry fit</span>
          <h1 className="mt-4 text-4xl font-bold tracking-tight sm:text-5xl">Use cases across distributor categories</h1>
          <p className="mt-4 max-w-3xl text-text-secondary">
            OrdWave adapts to different distribution models while keeping order-to-cash execution centralized.
          </p>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="grid gap-4 md:grid-cols-2">
          {cases.map((item) => (
            <div key={item.role} className="premium-card p-6">
              <p className="text-xs font-semibold uppercase tracking-wide text-primary">Use case</p>
              <h2 className="mt-1 text-xl font-semibold">{item.role}</h2>
              <p className="mt-2 text-sm text-text-secondary">{item.value}</p>
              <ul className="mt-4 space-y-1.5 text-sm text-text-primary">
                <li>- Better order-to-cash visibility</li>
                <li>- Stronger cross-team coordination</li>
                <li>- Faster issue resolution at branch level</li>
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-10 grid gap-4 md:grid-cols-3">
          <div className="premium-card p-5">
            <p className="text-sm font-semibold">Order reliability</p>
            <p className="mt-2 text-sm text-text-secondary">Reduce missed orders caused by fragmented communication and manual follow-ups.</p>
          </div>
          <div className="premium-card p-5">
            <p className="text-sm font-semibold">Credit discipline</p>
            <p className="mt-2 text-sm text-text-secondary">Control retailer credit exposure before dispatch to protect monthly cash flow.</p>
          </div>
          <div className="premium-card p-5">
            <p className="text-sm font-semibold">Collections visibility</p>
            <p className="mt-2 text-sm text-text-secondary">Prioritize dues and follow-up with confidence from one finance view.</p>
          </div>
        </div>

        <div className="mt-10 premium-card bg-primary p-8 text-white sm:p-10">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Find your exact rollout path</h2>
          <p className="mt-3 max-w-2xl text-sm text-white/90 sm:text-base">
            Map your workflow with us and we will show how OrdWave fits your category, branch structure, and team roles.
          </p>
          <div className="mt-6">
            <TrackedLink href="/request-demo" label="Map My Workflow" section="use-cases" className="rounded-lg bg-white px-5 py-2.5 text-sm font-semibold text-primary">
              Map My Workflow
            </TrackedLink>
          </div>
        </div>
      </section>
    </>
  );
}
