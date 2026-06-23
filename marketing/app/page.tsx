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
  title: "OrdWave | Distribution Management Software for FMCG, Wholesale and Super Stockists",
  description: "Manage orders, inventory, credit, collections, dispatch, delivery, and analytics across every branch in real time. Built for Indian distributors.",
  openGraph: {
    title: "OrdWave — Run Your Entire Distribution Business From One Platform",
    description: "Enterprise OMS for FMCG distributors, wholesalers, and multi-branch operations.",
    type: "website",
    siteName: "OrdWave",
  },
  twitter: {
    card: "summary_large_image",
    title: "OrdWave — Distribution Management Software",
    description: "Enterprise OMS for FMCG distributors, wholesalers, and multi-branch operations.",
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
