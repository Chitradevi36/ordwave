import type { Metadata } from "next";
import Link from "next/link";
import { TrackedLink } from "@/components/tracked-link";

export const metadata: Metadata = {
  title: "Customers",
  description: "Workflow proof for distributor teams using OrdWave to control credit, dispatch, inventory, and collections.",
};

const stories = [
  {
    company: "Credit hold workflow",
    person: "Owner review",
    role: "Finance + dispatch",
    summary: "The branch needed orders to stop before dispatch whenever credit limits or overdue rules were crossed.",
    metrics: ["Dispatch blocked on policy breach", "Manager approval before stock leaves", "Fewer risky dispatches"],
  },
  {
    company: "Collections queue",
    person: "Finance lead",
    role: "Receivables follow-up",
    summary: "The team needed a practical daily list of overdue accounts instead of static aging reports.",
    metrics: ["Aging-based action queue", "Rep-wise follow-up ownership", "Cleaner receivables reviews"],
  },
  {
    company: "Branch operating view",
    person: "Business owner",
    role: "Multi-branch control",
    summary: "Leadership wanted one view across orders, stock, dispatch, and dues without chasing separate teams for updates.",
    metrics: ["Branch-wise operating view", "Stronger dispatch accountability", "Central visibility without extra MIS"],
  },
];

export default function CustomersPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">Customer outcomes</span>
          <h1 className="mt-4 text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">Workflow proof for distributor teams evaluating OrdWave</h1>
          <p className="mt-4 max-w-3xl text-[#475569]">
            These are the operational situations buyers usually want to see first: credit holds, collection follow-up, branch visibility, and dispatch control.
          </p>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="grid gap-5 lg:grid-cols-3">
          {stories.map((story) => (
            <div key={story.company} className="card p-6">
              <span className="pill">{story.company}</span>
              <h2 className="mt-4 text-xl font-semibold text-[#0F172A]">{story.person}</h2>
              <p className="text-sm text-[#64748B]">{story.role}</p>
              <p className="mt-4 text-sm text-[#475569]">{story.summary}</p>
              <div className="mt-5 space-y-2">
                {story.metrics.map((metric) => (
                  <div key={metric} className="rounded-xl bg-[#EFF7F2] px-3 py-2 text-sm font-medium text-[#1B4332]">{metric}</div>
                ))}
              </div>
            </div>
          ))}
        </div>

        <div className="mt-10 grid gap-4 md:grid-cols-4">
          {[
            ["Order lifecycle", "Structured"],
            ["Credit controls", "Policy-based"],
            ["Inventory visibility", "Branch-wise"],
            ["Collections", "Aging-aware"],
          ].map(([label, value]) => (
            <div key={label} className="card p-5 text-center">
              <p className="text-xl font-bold text-[#1B4332]">{value}</p>
              <p className="mt-2 text-sm text-[#475569]">{label}</p>
            </div>
          ))}
        </div>

        <div className="mt-10 rounded-3xl bg-[#0F1A13] p-8 text-white sm:p-10">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Want to see your own order-to-cash workflow mapped?</h2>
          <p className="mt-3 max-w-2xl text-sm text-white/80 sm:text-base">Book a guided walkthrough and we will map OrdWave to your current distributor workflow.</p>
          <div className="mt-6 flex flex-wrap gap-3">
            <TrackedLink href="/request-demo" label="Map My Workflow" section="customers" className="btn-primary px-6 py-2.5">Map My Workflow</TrackedLink>
            <TrackedLink href="/pricing" label="View Pricing" section="customers" className="inline-flex items-center rounded-xl border border-white/20 px-6 py-2.5 text-sm font-semibold text-white hover:bg-white/10">View Pricing</TrackedLink>
          </div>
        </div>
      </section>
    </>
  );
}
