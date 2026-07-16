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
  title: "OrdWave | Order-to-Cash Platform for Indian FMCG Distributors",
  description: "Run FMCG distributor operations on one platform: orders, credit approvals, inventory, delivery execution, collections, GST workflows, and integrations.",
  openGraph: {
    title: "OrdWave — Built for Indian FMCG Distributors",
    description: "FMCG-first order-to-cash platform with credit control, inventory visibility, delivery workflows, collections, and GST-ready operations.",
    type: "website",
    siteName: "OrdWave",
  },
  twitter: {
    card: "summary_large_image",
    title: "OrdWave — FMCG Distributor OMS",
    description: "One platform for orders, credit, inventory, delivery, collections, and GST workflows.",
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
