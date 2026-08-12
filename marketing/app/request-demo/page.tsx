import type { Metadata } from "next";
import { DemoForm } from "@/components/demo-form";
import { TrackedLink } from "@/components/tracked-link";

export const metadata: Metadata = {
  title: "Map My Workflow",
  description: "Request a workflow mapping session for your distributor operations with OrdWave.",
};

export default function RequestDemoPage() {
  return (
    <section className="section-shell section-gap grid gap-8 lg:grid-cols-2">
      <div>
        <span className="pill">Map your current workflow</span>
        <h1 className="mt-4 text-4xl font-bold tracking-tight sm:text-5xl">
          See where OrdWave fits in your order-to-cash workflow
        </h1>
        <p className="mt-3 text-text-secondary">
          Share your current branch setup, team structure, and bottlenecks. We will map where OrdWave can improve
          credit control, dispatch, collections, inventory visibility, and daily execution.
        </p>
        <ul className="mt-6 space-y-2 text-sm text-text-secondary">
          <li>- Review your current order, credit, and dispatch flow</li>
          <li>- Identify the fastest rollout path for your team</li>
          <li>- See where OrdWave fits and where it does not</li>
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
      <DemoForm title="Map My Workflow" subtitle="Tell us your team size, branch setup, and current process." />
    </section>
  );
}
