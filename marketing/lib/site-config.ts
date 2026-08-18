export const siteConfig = {
  companyName: "OrdWave",
  siteUrl: process.env.NEXT_PUBLIC_MARKETING_URL ?? "https://ordwave.com",
  appUrl: process.env.NEXT_PUBLIC_APP_URL ?? "https://app.ordwave.com",
  supportEmail: "support@ordwave.com",
  positioning: {
    headline: "Stop Risky Dispatches. Collect Faster.",
    subheadline:
      "Connect every retailer order with outstanding balance, credit limit, inventory, and delivery status before goods leave your warehouse.",
    differentiator: "Credit-aware order execution for distributors",
  },
  foundingProgram: {
    badge: "Founding Distributor Program",
    title: "We're onboarding our first distribution businesses",
    description:
      "Get OrdWave configured around your actual workflow with hands-on onboarding from our team.",
    offer: {
      enabled: true,
      name: "Founding Distributor Plan",
      priceMonthly: "₹2,999/month",
      note: "Early customer offer for qualifying pilot accounts",
    },
    benefits: [
      "30-day assisted pilot",
      "Retailer data import",
      "Product data import",
      "Credit policy configuration",
      "Team onboarding",
      "No setup fee",
      "Cancel anytime",
    ],
  },
  demoVideo: {
    title: "See how OrdWave handles an order from booking to collection",
    description:
      "We’re preparing a short walkthrough focused on credit checks, approvals, dispatch, invoicing, and collections. Until the recorded demo is live, we’ll show the workflow in a guided session.",
    videoUrl: process.env.NEXT_PUBLIC_ORDWAVE_DEMO_VIDEO_URL ?? "",
    thumbnailLabel: "90-second product walkthrough",
  },
  whatsapp: {
    phoneNumber: process.env.NEXT_PUBLIC_ORDWAVE_WHATSAPP_NUMBER ?? "",
    prefilledMessage:
      process.env.NEXT_PUBLIC_ORDWAVE_WHATSAPP_MESSAGE ??
      "Hi, I'm interested in seeing how OrdWave could work for our distribution business.",
  },
} as const;

export function getWhatsappHref(): string {
  const { phoneNumber, prefilledMessage } = siteConfig.whatsapp;
  if (!phoneNumber) return "";

  const normalized = phoneNumber.replace(/[^\d]/g, "");
  const text = encodeURIComponent(prefilledMessage);
  return `https://wa.me/${normalized}?text=${text}`;
}

export function getSignupHref(plan?: string | null): string {
  if (!plan) return `${siteConfig.appUrl}/signup`;
  return `${siteConfig.appUrl}/signup?plan=${encodeURIComponent(plan)}`;
}
