import {
  HeroSection,
  PainPointsSection,
  IndustrySolutionsSection,
  ProductFeaturesSection,
  HowOrdWaveWorksSection,
  ProductScreensShowcaseSection,
  BenefitsSection,
  ComparisonTableSection,
  TrustSection,
  PricingSection,
  FaqSection,
  FinalCtaSection,
} from "@/components/home-sections";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "OrdWave | Distribution Management Software for FMCG, Wholesale and Super Stockists",
  description:
    "Grow your distribution business with one platform for orders, inventory, credit, collections, delivery, GST invoicing, and multi-branch execution.",
};

export default function HomePage() {
  return (
    <>
      <HeroSection />
      <PainPointsSection />
      <IndustrySolutionsSection />
      <ProductFeaturesSection />
      <HowOrdWaveWorksSection />
      <ProductScreensShowcaseSection />
      <BenefitsSection />
      <ComparisonTableSection />
      <TrustSection />
      <PricingSection />
      <FaqSection />
      <FinalCtaSection />
    </>
  );
}
