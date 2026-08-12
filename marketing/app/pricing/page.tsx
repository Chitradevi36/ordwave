import type { Metadata } from "next";
import { PricingPageClient } from "./pricing-page-client";

export const metadata: Metadata = {
  title: "Pricing",
  description:
    "Pricing plans for OrdWave's credit-first distributor workflow system, from early-stage branch operations to multi-branch teams.",
};

export default function PricingPage() {
  return <PricingPageClient />;
}
