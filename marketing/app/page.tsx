import type { Metadata } from "next";
import {
  HeroSection,
  TrustedBySection,
  ChallengesSection,
  ProductOverviewSection,
  WhyOrdWaveSection,
  IndustriesHomeSection,
  HowItWorksSection,
  MobileAppsSection,
  AnalyticsSection,
  TestimonialsSection,
  RoiCalculatorSection,
  ComparisonTableSection,
  FaqSection,
  FinalCtaSection,
} from "@/components/home-sections";

export const metadata: Metadata = {
  title: "OrdWave | Credit-First OMS for Indian FMCG Distributors",
  description:
    "Stop risky dispatches, prioritize overdue collections, and run distributor order-to-cash workflows across branches, inventory, delivery, GST, and Tally-ready operations.",
  openGraph: {
    title: "OrdWave - Credit-First OMS for Indian FMCG Distributors",
    description:
      "Control orders, credit approvals, dispatches, inventory, collections, and GST-ready operations from one distributor workflow system.",
    type: "website",
    siteName: "OrdWave",
  },
  twitter: {
    card: "summary_large_image",
    title: "OrdWave - Credit-First Distributor OMS",
    description:
      "Stop bad-credit dispatches and collect faster with one distributor operations system.",
  },
};

export default function HomePage() {
  return (
    <>
      <HeroSection />
      <TrustedBySection />
      <ChallengesSection />
      <ProductOverviewSection />
      <WhyOrdWaveSection />
      <IndustriesHomeSection />
      <HowItWorksSection />
      <MobileAppsSection />
      <AnalyticsSection />
      <TestimonialsSection />
      <RoiCalculatorSection />
      <ComparisonTableSection />
      <FaqSection />
      <FinalCtaSection />
    </>
  );
}
