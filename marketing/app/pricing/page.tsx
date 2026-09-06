import type { Metadata } from "next";
import { PricingPageClient } from "./pricing-page-client";

export const metadata: Metadata = {
  title: "OrdWave Pricing | Distribution Management Software",
  description:
    "Simple pricing for distributors. Start with a 30-day pilot and join the OrdWave Founding Distributor Program for Growth features at ₹499/month.",
};

export default function PricingPage() {
  return <PricingPageClient />;
}
