import type { Metadata } from "next";
import { DemoForm } from "@/components/demo-form";

export const metadata: Metadata = {
  title: "Contact",
  description: "Contact OrdWave for product discussions, implementation planning, and support.",
};

export default function ContactPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">Get in touch</span>
          <h1 className="mt-4 text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">Let&apos;s map OrdWave to your distribution workflow</h1>
          <p className="mt-4 max-w-3xl text-[#475569]">
            Share your current setup and we will suggest a rollout approach with clear business impact.
          </p>
        </div>
      </section>

      <section className="section-shell section-gap grid gap-8 lg:grid-cols-2">
      <div>
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="card p-5 sm:col-span-2">
            <p className="text-sm font-semibold text-[#0F172A]">What to expect</p>
            <p className="mt-2 text-sm text-[#475569]">A focused conversation on your current workflows, pain points, and rollout priorities.</p>
          </div>
          <div className="card p-5">
            <p className="text-sm font-semibold text-[#0F172A]">Response time</p>
            <p className="mt-2 text-sm text-[#475569]">Typically within one business day.</p>
          </div>
          <div className="card p-5">
            <p className="text-sm font-semibold text-[#0F172A]">Business hours</p>
            <p className="mt-2 text-sm text-[#475569]">9 AM - 6 PM IST, Monday to Saturday.</p>
          </div>
        </div>

        <div className="mt-6 grid gap-4 md:grid-cols-2">
          <div className="card p-5">
            <p className="text-xs font-semibold uppercase tracking-wide text-[#1B4332]">Email</p>
            <p className="mt-1 text-sm font-medium text-[#0F172A]">support@ordwave.com</p>
            <p className="mt-2 text-sm text-[#475569]">Best for product queries, demos, and implementation planning.</p>
          </div>
          <div className="card p-5">
            <p className="text-xs font-semibold uppercase tracking-wide text-[#1B4332]">Phone</p>
            <p className="mt-1 text-sm font-medium text-[#0F172A]">Available on demo request</p>
            <p className="mt-2 text-sm text-[#475569]">We schedule focused calls based on your branch count and current workflow complexity.</p>
          </div>
        </div>

        <div className="mt-6 card p-5">
          <p className="text-sm font-semibold text-[#0F172A]">Common questions before a demo</p>
          <div className="mt-3 space-y-3 text-sm text-[#475569]">
            <p><span className="font-semibold text-[#0F172A]">Can we onboard one branch first?</span> Yes. Most teams start with one branch and scale after the first workflow stabilizes.</p>
            <p><span className="font-semibold text-[#0F172A]">Do you support field teams?</span> Yes. Sales, delivery, and collection workflows are built for field execution.</p>
            <p><span className="font-semibold text-[#0F172A]">Can you map our current process?</span> Yes. The first demo is designed around your current order-to-cash setup.</p>
          </div>
        </div>

        <div className="mt-6 space-y-2 text-xs font-semibold uppercase tracking-wide text-[#1B4332]">
          <p>Built for Indian distributors</p>
          <p>GST-ready invoicing</p>
          <p>Credit-first operations</p>
        </div>
      </div>
      <DemoForm title="Contact our team" subtitle="We typically respond within one business day." />
      </section>
    </>
  );
}
