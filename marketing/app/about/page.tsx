import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "About",
  description: "About OrdWave and our focus on cloud-based OMS workflows for distributors.",
};

export default function AboutPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-border/60">
        <div className="section-shell section-gap">
          <span className="pill">About the product</span>
          <h1 className="mt-4 text-4xl font-bold tracking-tight sm:text-5xl">Built for the realities of distributor operations</h1>
          <p className="mt-4 max-w-3xl text-text-secondary">
            OrdWave is a cloud-based order management system purpose-built for distributor operations.
            We focus on helping teams run everyday workflows with better control across sales, inventory,
            delivery, invoicing, and collections.
          </p>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="grid gap-4 md:grid-cols-3">
          <div className="premium-card p-6">
            <p className="text-xs font-semibold uppercase tracking-wide text-primary">Principle</p>
            <p className="mt-1 text-sm font-semibold text-text-primary">Execution-first design</p>
            <p className="mt-2 text-sm text-text-secondary">Workflows designed to reduce missed orders and dispatch friction.</p>
          </div>
          <div className="premium-card p-6">
            <p className="text-xs font-semibold uppercase tracking-wide text-primary">Principle</p>
            <p className="mt-1 text-sm font-semibold text-text-primary">Credit-first discipline</p>
            <p className="mt-2 text-sm text-text-secondary">Built-in controls that help teams protect cash flow and reduce overdue risk.</p>
          </div>
          <div className="premium-card p-6">
            <p className="text-xs font-semibold uppercase tracking-wide text-primary">Principle</p>
            <p className="mt-1 text-sm font-semibold text-text-primary">Branch-ready scale</p>
            <p className="mt-2 text-sm text-text-secondary">Operate multiple branches from one command center with clear accountability.</p>
          </div>
        </div>

        <div className="mt-10 grid gap-4 md:grid-cols-2">
          <div className="premium-card p-6 sm:p-8">
            <h2 className="text-2xl font-semibold">Why we exist</h2>
            <p className="mt-3 text-sm text-text-secondary sm:text-base">
              Distribution teams often run on fragmented tools that increase delays, misalignment, and collection risk.
              OrdWave brings these workflows together so teams can execute with clarity and speed.
            </p>
          </div>
          <div className="premium-card p-6 sm:p-8">
            <h2 className="text-2xl font-semibold">What we optimize for</h2>
            <p className="mt-3 text-sm text-text-secondary sm:text-base">
              Faster onboarding, dependable daily execution, and measurable outcomes in order flow,
              branch coordination, and working capital discipline.
            </p>
          </div>
        </div>

        <div className="mt-10 premium-card bg-primary p-8 text-white sm:p-10">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">See if OrdWave fits your operating model</h2>
          <p className="mt-3 max-w-2xl text-sm text-white/90 sm:text-base">
            Share your current setup and we will map where OrdWave can deliver the fastest operational gains.
          </p>
          <div className="mt-6">
            <Link href="/request-demo" className="rounded-lg bg-white px-5 py-2.5 text-sm font-semibold text-primary">Talk to us</Link>
          </div>
        </div>
      </section>
    </>
  );
}
