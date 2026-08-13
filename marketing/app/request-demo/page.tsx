import type { Metadata } from "next";
import { DemoForm } from "@/components/demo-form";
import { TrackedLink } from "@/components/tracked-link";

export const metadata: Metadata = {
  title: "Start 30-Day Pilot",
  description: "Request an OrdWave pilot for your distributor business and get founder-led onboarding around your real workflow.",
  alternates: {
    canonical: "/request-demo",
  },
};

export default function RequestDemoPage() {
  return (
    <section className="section-shell section-gap grid gap-8 lg:grid-cols-2">
      <div>
        <span className="pill">Map your current workflow</span>
        <h1 className="mt-4 text-4xl font-bold tracking-tight sm:text-5xl">
          Start a 30-day pilot around your real distribution workflow
        </h1>
        <p className="mt-3 text-text-secondary">
          Share your branch setup, retailer credit model, and current order process. We will help you evaluate OrdWave against real orders, approvals, dispatch decisions, and collection follow-through.
        </p>
        <ul className="mt-6 space-y-2 text-sm text-text-secondary">
          <li>- 30-day assisted pilot for qualifying distributor teams</li>
          <li>- Retailer and product data import support</li>
          <li>- Credit policy setup and team onboarding</li>
        </ul>
        <div className="mt-6">
          <TrackedLink
            href="/contact"
            label="Contact our team"
            section="request-demo"
            className="rounded-lg bg-white px-5 py-2.5 text-sm font-semibold text-primary"
          >
            Contact our team
          </TrackedLink>
        </div>
      </div>
      <DemoForm
        title="Request My Pilot"
        subtitle="Tell us how orders, credit, and dispatch work today. We typically respond within one business day."
        submitLabel="Request My Pilot"
        successMessage="Thanks. We have your pilot request and will reach out shortly to understand your workflow."
        source="request-demo"
      />
    </section>
  );
}
