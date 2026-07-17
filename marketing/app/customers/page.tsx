import type { Metadata } from "next";
import Link from "next/link";
import { TrackedLink } from "@/components/tracked-link";

export const metadata: Metadata = {
  title: "Customers",
  description: "Customer workflow stories from distributor teams using OrdWave for order-to-cash operations.",
};

const stories = [
  {
    company: "Regional FMCG Distributor",
    person: "Operations Leader",
    role: "Multi-team Operations",
    summary: "Needed better visibility across field orders, credit decisions, and branch execution.",
    metrics: ["Clearer daily pipeline", "Stronger cross-team coordination", "Single operational view"],
  },
  {
    company: "FMCG + Staples Distributor",
    person: "Business Owner",
    role: "Branch Operations",
    summary: "Scaled branch operations while improving dispatch coordination and accountability.",
    metrics: ["Branch-level execution visibility", "Improved dispatch handoffs", "Reduced manual follow-up load"],
  },
  {
    company: "Wholesale Distribution Team",
    person: "Finance Manager",
    role: "Collections & Credit",
    summary: "Needed stronger overdue tracking and better credit discipline before dispatch.",
    metrics: ["Aging-based follow-up", "Cleaner credit review workflow", "Better receivables visibility"],
  },
];

export default function CustomersPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">Customer outcomes</span>
          <h1 className="mt-4 text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">How distributor teams use OrdWave in daily operations</h1>
          <p className="mt-4 max-w-3xl text-[#475569]">
            Learn how teams apply OrdWave across orders, credit, inventory, dispatch, and collections.
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
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Want a workflow similar to your team&apos;s operating model?</h2>
          <p className="mt-3 max-w-2xl text-sm text-white/80 sm:text-base">Book a guided walkthrough and we’ll map OrdWave to your current distributor workflow.</p>
          <div className="mt-6 flex flex-wrap gap-3">
            <TrackedLink href="/request-demo" label="Book Demo" section="customers" className="btn-primary px-6 py-2.5">Book Demo</TrackedLink>
            <TrackedLink href="/pricing" label="View Pricing" section="customers" className="inline-flex items-center rounded-xl border border-white/20 px-6 py-2.5 text-sm font-semibold text-white hover:bg-white/10">View Pricing</TrackedLink>
          </div>
        </div>
      </section>
    </>
  );
}