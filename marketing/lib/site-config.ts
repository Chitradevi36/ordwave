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
      "Get Growth-level functionality at a locked founding price with hands-on onboarding from our team.",
    offer: {
      enabled: true,
      name: "Founding Growth",
      priceMonthly: "₹499/month",
      normalPriceMonthly: "₹999/month",
      note: "First 10 qualifying distributors only. Price locked for 12 months.",
    },
    benefits: [
      "Growth-level features",
      "30-day assisted pilot",
      "Founder-led onboarding",
      "Direct product feedback channel",
      "Early access to features",
    ],
  },
  demoVideo: {
    title: "See how OrdWave handles an order from booking to collection",
    description:
      "We're preparing a short walkthrough focused on credit checks, approvals, dispatch, invoicing, and collections. Until the recorded demo is live, we'll show the workflow in a guided session.",
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
