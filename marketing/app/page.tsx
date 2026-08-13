import type { Metadata } from "next";
import { DemoVideoSection } from "@/components/demo-video-section";
import {
  HeroSection,
  TrustProblemSection,
  BeforeAfterSection,
  WorkflowSection,
  CapabilitiesSection,
  FoundingProgramSection,
  IntegrationsSection,
  FaqSection,
  FinalCtaSection,
  homepageFaqs,
} from "@/components/home-sections";
import { siteConfig } from "@/lib/site-config";

export const metadata: Metadata = {
  title: "OrdWave | Stop Risky Dispatches. Collect Faster.",
  description:
    "Credit-aware order execution for Indian distributors. Stop risky dispatches, collect faster, and keep orders, credit, stock, delivery, and collections connected.",
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: "OrdWave - Stop Risky Dispatches. Collect Faster.",
    description:
      "Connect retailer orders with outstanding balance, credit limit, inventory, and delivery status before goods leave your warehouse.",
    type: "website",
    siteName: "OrdWave",
    url: "/",
  },
  twitter: {
    card: "summary_large_image",
    title: "OrdWave - Credit-aware order execution for distributors",
    description:
      "Prevent risky dispatches. Collect outstanding faster. Keep order, credit, stock, and delivery connected.",
  },
};

export default function HomePage() {
  const organizationSchema = {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: siteConfig.companyName,
    url: siteConfig.siteUrl,
    email: siteConfig.supportEmail,
    logo: `${siteConfig.siteUrl}/logo.svg`,
  };

  const softwareSchema = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: siteConfig.companyName,
    applicationCategory: "BusinessApplication",
    operatingSystem: "Web",
    description: metadata.description,
    url: siteConfig.siteUrl,
    areaServed: "IN",
    audience: {
      "@type": "Audience",
      audienceType: "Indian distributors",
    },
    offers: siteConfig.foundingProgram.offer.enabled
      ? {
          "@type": "Offer",
          name: siteConfig.foundingProgram.offer.name,
          priceCurrency: "INR",
          price: "2999",
        }
      : undefined,
  };

  const faqSchema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: homepageFaqs.map((faq) => ({
      "@type": "Question",
      name: faq.q,
      acceptedAnswer: {
        "@type": "Answer",
        text: faq.a,
      },
    })),
  };

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(organizationSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(softwareSchema) }} />
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }} />
      <HeroSection />
      <TrustProblemSection />
      <BeforeAfterSection />
      <WorkflowSection />
      <CapabilitiesSection />
      <FoundingProgramSection />
      <DemoVideoSection />
      <IntegrationsSection />
      <FaqSection />
      <FinalCtaSection />
    </>
  );
}
