import type { Metadata } from "next";
import Link from "next/link";
import { TrackedLink } from "@/components/tracked-link";

export const metadata: Metadata = {
  title: "Industries",
  description: "Industry workflows on OrdWave: FMCG-first today, adaptable for rice, pharma, wholesale, electronics, and multi-branch distributor operations.",
};

const industries = [
  {
    name: "FMCG Distribution",
    pain: "High order frequency, route complexity, and retailer credit exposure create daily execution pressure.",
    solution: "OrdWave centralizes order booking, dispatch coordination, credit checks, and collection follow-through for FMCG teams.",
    outcomes: ["Cleaner order handoffs", "Better retailer follow-up discipline", "Improved branch-level visibility"],
  },
  {
    name: "Rice Distribution",
    pain: "Branch-level stock mismatch and dispatch coordination reduce fill rate and increase retailer complaints.",
    solution: "OrdWave gives branch-wise inventory, transfer tracking, and dispatch visibility for high-volume staple distribution.",
    outcomes: ["Lower stock mismatch risk", "Better dispatch predictability", "Clearer branch accountability"],
  },
  {
    name: "Pharma Distribution",
    pain: "Batch complexity, expiry awareness, and controlled delivery workflows demand tighter execution discipline.",
    solution: "OrdWave supports structured workflows, branch control, and role-based approvals for regulated distribution operations.",
    outcomes: ["Better operational discipline", "Consistent approvals", "Improved delivery tracking"],
  },
  {
    name: "Wholesale Distribution",
    pain: "Manual processes across sales, warehouse, and finance create delays and visibility gaps.",
    solution: "OrdWave unifies order-to-cash workflows with credit controls, collections visibility, and team accountability.",
    outcomes: ["Lower manual follow-up load", "Stronger collection follow-through", "Improved working capital discipline"],
  },
  {
    name: "Electronics Distribution",
    pain: "Higher-value inventory and distributed teams increase the cost of every order, dispatch, or credit mistake.",
    solution: "OrdWave improves stock control, dispatch clarity, and retailer-level visibility across branches and categories.",
    outcomes: ["Better high-value inventory control", "Reduced dispatch errors", "Faster issue resolution"],
  },
];

export default function IndustriesPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">Industry solutions</span>
          <h1 className="mt-4 text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">FMCG-first workflows, adaptable for every major distributor category</h1>
          <p className="mt-4 max-w-3xl text-[#475569]">
            Start with FMCG-focused execution workflows and adapt operations for rice, pharma, wholesale, electronics, and multi-branch distributor models.
          </p>
        </div>
      </section>

      <section className="section-shell section-gap space-y-6">
        {industries.map((industry) => (
          <div key={industry.name} className="card p-6 sm:p-8">
            <div className="grid gap-6 lg:grid-cols-[1.1fr_0.9fr] lg:items-start">
              <div>
                <span className="pill">{industry.name}</span>
                <h2 className="mt-3 text-2xl font-bold tracking-tight text-[#0F172A]">Designed for {industry.name.toLowerCase()}</h2>
                <div className="mt-5 space-y-4">
                  <div>
                    <p className="text-xs font-semibold uppercase tracking-wide text-[#9F1239]">Pain points</p>
                    <p className="mt-1 text-sm text-[#475569]">{industry.pain}</p>
                  </div>
                  <div>
                    <p className="text-xs font-semibold uppercase tracking-wide text-[#1B4332]">OrdWave solution</p>
                    <p className="mt-1 text-sm text-[#475569]">{industry.solution}</p>
                  </div>
                </div>
              </div>
              <div>
                <div className="rounded-2xl border border-[#E2E8F0] bg-[#F8FAF8] p-5">
                  <p className="text-xs font-semibold text-[#64748B]">Expected outcomes</p>
                  <ul className="mt-4 space-y-2">
                    {industry.outcomes.map((outcome) => (
                      <li key={outcome} className="flex items-center gap-2 text-sm text-[#0F172A]"><span className="h-1.5 w-1.5 rounded-full bg-[#52B788]" />{outcome}</li>
                    ))}
                  </ul>
                  <div className="mt-5 rounded-xl border border-[#E2E8F0] bg-white p-4">
                    <div className="h-3 w-3/4 rounded bg-[#1B4332]/15" />
                    <div className="mt-2 h-3 w-full rounded bg-[#1B4332]/10" />
                    <div className="mt-2 grid grid-cols-3 gap-2">
                      <div className="h-14 rounded-lg bg-[#EFF7F2]" />
                      <div className="h-14 rounded-lg bg-[#EFF7F2]" />
                      <div className="h-14 rounded-lg bg-[#EFF7F2]" />
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        ))}

        <div className="rounded-3xl bg-[#0F1A13] p-8 text-white sm:p-10">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Want a workflow mapped to your category?</h2>
          <p className="mt-3 max-w-2xl text-sm text-white/80 sm:text-base">Book a demo and we’ll show the exact order-to-cash flow for your team structure and industry model.</p>
          <div className="mt-6">
            <TrackedLink href="/request-demo" label="Book Demo" section="industries" className="btn-primary px-6 py-2.5">Book Demo</TrackedLink>
          </div>
        </div>
      </section>
    </>
  );
}
