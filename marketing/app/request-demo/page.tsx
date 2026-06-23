import type { Metadata } from "next";
import { DemoForm } from "@/components/demo-form";

export const metadata: Metadata = {
  title: "Request Demo",
  description: "Book a live OrdWave demo for your distributor operations.",
};

export default function RequestDemoPage() {
  return (
    <section className="section-shell section-gap grid gap-8 lg:grid-cols-2">
      <div>
        <span className="pill">Book a guided walkthrough</span>
        <h1 className="mt-4 text-4xl font-bold tracking-tight sm:text-5xl">See how OrdWave can improve order-to-cash execution</h1>
        <p className="mt-3 text-text-secondary">
          See how OrdWave supports order management, retailer CRM, credit control, inventory,
          delivery tracking, invoicing, collections, and analytics.
        </p>
        <ul className="mt-6 space-y-2 text-sm text-text-secondary">
          <li>• Reduce missed orders and dispatch delays</li>
          <li>• Improve credit and collections control</li>
          <li>• Run multiple branches from one dashboard</li>
        </ul>
      </div>
      <DemoForm title="Book your demo" subtitle="Tell us your team size and current process." />
    </section>
  );
}
