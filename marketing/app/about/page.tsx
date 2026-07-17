import type { Metadata } from "next";
import Link from "next/link";
import { TrackedLink } from "@/components/tracked-link";

export const metadata: Metadata = {
  title: "About",
  description: "About OrdWave, an FMCG-first order-to-cash platform for Indian distributors built to expand across distributor categories.",
};

export default function AboutPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">About the product</span>
          <h1 className="mt-4 text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">Built for Indian FMCG distributors, designed to scale beyond FMCG</h1>
          <p className="mt-4 max-w-3xl text-[#475569]">
            OrdWave is an order-to-cash platform built for distributor operations. We currently focus on FMCG
            workflows in India and are building an extensible foundation for additional distributor verticals.
          </p>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="grid gap-4 md:grid-cols-3">
          <div className="card p-6">
            <p className="text-xs font-semibold uppercase tracking-wide text-[#1B4332]">Principle</p>
            <p className="mt-1 text-sm font-semibold text-[#0F172A]">Execution-first design</p>
            <p className="mt-2 text-sm text-[#475569]">Workflows designed to improve daily execution across sales, dispatch, and finance handoffs.</p>
          </div>
          <div className="card p-6">
            <p className="text-xs font-semibold uppercase tracking-wide text-[#1B4332]">Principle</p>
            <p className="mt-1 text-sm font-semibold text-[#0F172A]">Credit-first discipline</p>
            <p className="mt-2 text-sm text-[#475569]">Built-in controls that help teams protect cash flow and reduce overdue risk.</p>
          </div>
          <div className="card p-6">
            <p className="text-xs font-semibold uppercase tracking-wide text-[#1B4332]">Principle</p>
            <p className="mt-1 text-sm font-semibold text-[#0F172A]">Branch-ready scale</p>
            <p className="mt-2 text-sm text-[#475569]">Run one branch or many with central visibility and branch-level accountability.</p>
          </div>
        </div>

        <div className="mt-10 grid gap-4 md:grid-cols-2">
          <div className="card p-6 sm:p-8">
            <h2 className="text-2xl font-semibold text-[#0F172A]">Why we exist</h2>
            <p className="mt-3 text-sm text-[#475569] sm:text-base">
              Distribution teams often run on fragmented tools that increase delays, misalignment, and collection risk.
              OrdWave brings these workflows together so teams can execute with clarity and speed.
            </p>
          </div>
          <div className="card p-6 sm:p-8">
            <h2 className="text-2xl font-semibold text-[#0F172A]">What we optimize for</h2>
            <p className="mt-3 text-sm text-[#475569] sm:text-base">
              Faster onboarding, dependable daily execution, and stronger control over order flow,
              branch coordination, and working capital discipline.
            </p>
          </div>
        </div>

        <div className="mt-10 grid gap-4 lg:grid-cols-[1.2fr_1fr]">
          <div className="card p-6 sm:p-8">
            <p className="text-xs font-semibold uppercase tracking-wide text-[#1B4332]">Founder story</p>
            <h2 className="mt-2 text-2xl font-semibold text-[#0F172A]">Why a distribution-native product had to exist</h2>
            <p className="mt-3 text-sm text-[#475569] sm:text-base">
              Many distributors have accounting software, but few have one execution layer for field orders,
              credit approvals, dispatch coordination, delivery flows, and collections. OrdWave was created to close that gap.
            </p>
            <p className="mt-3 text-sm text-[#475569] sm:text-base">
              The vision is simple: give founders and operations leaders dependable visibility and control,
              without heavyweight ERP complexity.
            </p>
          </div>
          <div className="card p-6 sm:p-8">
            <p className="text-xs font-semibold uppercase tracking-wide text-[#1B4332]">Roadmap</p>
            <ul className="mt-3 space-y-3 text-sm text-[#475569]">
              <li><span className="font-semibold text-[#0F172A]">Now:</span> FMCG-focused order-to-cash workflows for Indian distributors</li>
              <li><span className="font-semibold text-[#0F172A]">Next:</span> Deeper operational automation and richer analytics</li>
              <li><span className="font-semibold text-[#0F172A]">Later:</span> Wider distributor-category templates beyond FMCG</li>
            </ul>
          </div>
        </div>

        <div className="mt-10 rounded-3xl bg-[#0F1A13] p-8 text-white sm:p-10">
          <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">See if OrdWave fits your operating model</h2>
          <p className="mt-3 max-w-2xl text-sm text-white/90 sm:text-base">
            Share your current setup and we will map where OrdWave can deliver the fastest operational gains.
          </p>
          <div className="mt-6">
            <TrackedLink href="/request-demo" label="Talk to us" section="about" className="btn-primary px-5 py-2.5">Talk to us</TrackedLink>
          </div>
        </div>
      </section>
    </>
  );
}
