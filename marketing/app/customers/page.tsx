import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Customers",
  description: "Customer stories and measurable outcomes from distributor teams using OrdWave.",
};

const stories = [
  {
    company: "PrimeKart Distributors",
    person: "Rajesh Kumar",
    role: "Managing Director",
    summary: "Needed better visibility across field orders, overdue collections, and branch execution.",
    metrics: ["30% faster collections", "24% fewer order exceptions", "1 unified owner dashboard"],
  },
  {
    company: "Lakshmi Traders",
    person: "Suresh Nair",
    role: "Operations Head",
    summary: "Scaled from one branch to four while improving dispatch coordination and daily accountability.",
    metrics: ["4 branches managed centrally", "18% better on-time dispatch", "Reduced manual follow-up"],
  },
  {
    company: "Agro Foods Network",
    person: "Meena Pillai",
    role: "Finance Manager",
    summary: "Struggled with retailer overdue tracking and weak credit discipline before dispatch.",
    metrics: ["3 bad debts prevented", "33% faster payment follow-up", "Better aging visibility"],
  },
];

export default function CustomersPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">Customer outcomes</span>
          <h1 className="mt-4 text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">Case-study style results from real distributor teams</h1>
          <p className="mt-4 max-w-3xl text-[#475569]">
            See how OrdWave improves collection efficiency, delivery accuracy, inventory visibility, and order processing speed.
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
            ["Collection improvement", "+33%"],
            ["Delivery accuracy", "95%+"],
            ["Inventory visibility", "Real-time"],
            ["Order processing speed", "+28%"],
          ].map(([label, value]) => (
            <div key={label} className="card p-5 text-center">
              <p className="text-3xl font-bold text-[#1B4332]">{value}</p>
              <p className="mt-2 text-sm text-[#475569]">{label}</p>
            </div>
          ))}
        </div>

        <div className="mt-10 rounded-3xl bg-[#0F1A13] p-8 text-white sm:p-10">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Want similar outcomes for your distribution team?</h2>
          <p className="mt-3 max-w-2xl text-sm text-white/80 sm:text-base">We’ll show how OrdWave can improve the exact metrics that matter for your current stage.</p>
          <div className="mt-6 flex flex-wrap gap-3">
            <Link href="/request-demo" className="btn-primary px-6 py-2.5">Book Demo</Link>
            <Link href="/pricing" className="inline-flex items-center rounded-xl border border-white/20 px-6 py-2.5 text-sm font-semibold text-white hover:bg-white/10">View Pricing</Link>
          </div>
        </div>
      </section>
    </>
  );
}