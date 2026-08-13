import type { Metadata } from "next";
import { TrackedLink } from "@/components/tracked-link";

export const metadata: Metadata = {
  title: "Distribution Workflows",
  description:
    "Illustrative distribution workflows showing how OrdWave helps manage credit holds, collections follow-up, and multi-branch operating visibility.",
  alternates: {
    canonical: "/customers",
  },
};

const workflows = [
  {
    title: "Credit hold before dispatch",
    team: "Owner + finance + dispatch",
    note: "Illustrative workflow",
    problem:
      "Orders are approved and pushed to dispatch before anyone sees that the retailer has already crossed credit exposure or overdue limits.",
    outcome:
      "OrdWave surfaces the order with retailer outstanding and policy context so the team can approve, hold, or block before stock leaves the branch.",
  },
  {
    title: "Daily outstanding follow-up queue",
    team: "Finance + field collections",
    note: "Illustrative workflow",
    problem:
      "The team has ageing data, but follow-up still depends on memory, spreadsheets, and whoever shouts the loudest that day.",
    outcome:
      "OrdWave turns overdue accounts into a practical action queue so collections work becomes visible and prioritised.",
  },
  {
    title: "Multi-branch operating view",
    team: "Business owner + branch managers",
    note: "Illustrative workflow",
    problem:
      "Orders, stock, dispatch, and dues are reviewed across separate calls and files, making it hard to see which branch needs attention first.",
    outcome:
      "OrdWave gives one operating rhythm across branches while preserving branch-level visibility and accountability.",
  },
];

export default function CustomersPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">Distribution workflows</span>
          <h1 className="mt-4 max-w-4xl text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">
            Illustrative workflows buyers usually want to understand first
          </h1>
          <p className="mt-4 max-w-3xl text-base leading-relaxed text-[#475569]">
            These are not presented as customer case studies or testimonials. They are realistic distributor situations used to show how OrdWave handles credit risk, outstanding follow-up, and daily branch execution.
          </p>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="grid gap-5 lg:grid-cols-3">
          {workflows.map((workflow) => (
            <div key={workflow.title} className="card p-6">
              <span className="pill">{workflow.note}</span>
              <h2 className="mt-4 text-xl font-semibold text-[#0F172A]">{workflow.title}</h2>
              <p className="mt-1 text-sm font-medium text-[#1B4332]">{workflow.team}</p>
              <p className="mt-4 text-sm leading-6 text-[#9F1239]">
                <span className="font-semibold">Problem: </span>
                {workflow.problem}
              </p>
              <p className="mt-4 text-sm leading-6 text-[#166534]">
                <span className="font-semibold">With OrdWave: </span>
                {workflow.outcome}
              </p>
            </div>
          ))}
        </div>

        <div className="mt-10 rounded-[32px] bg-[#0F1A13] p-8 text-white sm:p-10">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
            Want to map one of these workflows to your business?
          </h2>
          <p className="mt-3 max-w-2xl text-sm leading-7 text-white/80 sm:text-base">
            Share your order volume, branch count, and credit process. We will show where OrdWave fits and where it does not before you commit to a pilot.
          </p>
          <div className="mt-6 flex flex-wrap gap-3">
            <TrackedLink href="/request-demo" label="Start 30-Day Pilot" section="distribution-workflows" className="btn-primary px-6 py-3">
              Start 30-Day Pilot
            </TrackedLink>
            <TrackedLink href="/fmcg-distributor-software" label="FMCG Distributor Software" section="distribution-workflows" className="btn-ghost border border-white/20 px-6 py-3">
              FMCG Distributor Software
            </TrackedLink>
          </div>
        </div>
      </section>
    </>
  );
}
