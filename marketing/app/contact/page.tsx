import type { Metadata } from "next";
import { DemoForm } from "@/components/demo-form";

export const metadata: Metadata = {
  title: "Contact",
  description: "Contact OrdWave for product discussions, implementation planning, and support.",
};

export default function ContactPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-border/60">
        <div className="section-shell section-gap">
          <span className="pill">Get in touch</span>
          <h1 className="mt-4 text-4xl font-bold tracking-tight sm:text-5xl">Let&apos;s map OrdWave to your distribution workflow</h1>
          <p className="mt-4 max-w-3xl text-text-secondary">
            Share your current setup and we will suggest a rollout approach with clear business impact.
          </p>
        </div>
      </section>

      <section className="section-shell section-gap grid gap-8 lg:grid-cols-2">
      <div>
        <div className="grid gap-4 sm:grid-cols-2">
          <div className="premium-card p-5 sm:col-span-2">
            <p className="text-sm font-semibold text-text-primary">What to expect</p>
            <p className="mt-2 text-sm text-text-secondary">A focused conversation on your current workflows, pain points, and rollout priorities.</p>
          </div>
          <div className="premium-card p-5">
            <p className="text-sm font-semibold text-text-primary">Response time</p>
            <p className="mt-2 text-sm text-text-secondary">Typically within one business day.</p>
          </div>
          <div className="premium-card p-5">
            <p className="text-sm font-semibold text-text-primary">Business hours</p>
            <p className="mt-2 text-sm text-text-secondary">9 AM - 6 PM IST, Monday to Saturday.</p>
          </div>
        </div>

        <div className="mt-6 premium-card p-5">
          <p className="text-xs font-semibold uppercase tracking-wide text-primary">Primary contact</p>
          <p className="mt-1 text-sm text-text-primary">support@ordwave.com</p>
          <p className="mt-2 text-sm text-text-secondary">Share your branch count, team size, and current order-to-cash process for a more tailored first call.</p>
        </div>

        <div className="mt-6 space-y-2 text-xs font-semibold uppercase tracking-wide text-primary">
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
