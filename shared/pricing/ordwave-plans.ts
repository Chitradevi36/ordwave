export type OrdWavePlanId = "starter" | "growth" | "business" | "enterprise";
export type BillingPeriod = "monthly" | "yearly";

export type OrdWavePlanDefinition = {
  id: OrdWavePlanId;
  name: string;
  badge: string;
  subtitle: string;
  monthlyPrice: number | null;
  annualMonthlyEquivalent: number | null;
  annualTotal: number | null;
  limits: string[];
  features: string[];
  featured?: boolean;
  pricingCtaLabel: string;
  signupCtaLabel: string;
  signupQueryValue: OrdWavePlanId;
  backendPlanValue: "starter" | "growth" | "enterprise";
  salesOnly?: boolean;
};

export const ORD_WAVE_PLANS: readonly OrdWavePlanDefinition[] = [
  {
    id: "starter",
    name: "Starter",
    badge: "Start here",
    subtitle: "For small distributors",
    monthlyPrice: 499,
    annualMonthlyEquivalent: 399,
    annualTotal: 4788,
    limits: ["1 branch", "3 users", "300 orders/month"],
    features: ["Order management", "Inventory", "GST-ready invoicing", "Basic credit tracking"],
    pricingCtaLabel: "Start with Starter",
    signupCtaLabel: "Start with Starter",
    signupQueryValue: "starter",
    backendPlanValue: "starter",
  },
  {
    id: "growth",
    name: "Growth",
    badge: "Most Popular",
    subtitle: "For growing distributor teams",
    monthlyPrice: 999,
    annualMonthlyEquivalent: 799,
    annualTotal: 9588,
    limits: ["2 branches", "7 users", "1,000 orders/month"],
    features: ["Everything in Starter", "Credit holds & approvals", "Collections & ageing", "Delivery + POD"],
    featured: true,
    pricingCtaLabel: "Choose Growth",
    signupCtaLabel: "Choose Growth",
    signupQueryValue: "growth",
    backendPlanValue: "growth",
  },
  {
    id: "business",
    name: "Business",
    badge: "Scale operations",
    subtitle: "For multi-branch distributors",
    monthlyPrice: 2499,
    annualMonthlyEquivalent: 1999,
    annualTotal: 23988,
    limits: ["5 branches", "15 users", "3,000 orders/month"],
    features: ["Everything in Growth", "Multi-branch operations", "Stock transfers", "Advanced reporting"],
    pricingCtaLabel: "Choose Business",
    signupCtaLabel: "Choose Business",
    signupQueryValue: "business",
    backendPlanValue: "growth",
  },
  {
    id: "enterprise",
    name: "Enterprise",
    badge: "Custom",
    subtitle: "For larger distributor networks",
    monthlyPrice: null,
    annualMonthlyEquivalent: null,
    annualTotal: null,
    limits: ["Custom scale"],
    features: ["Custom workflows", "Advanced controls", "Integrations", "Dedicated onboarding"],
    pricingCtaLabel: "Talk to Sales",
    signupCtaLabel: "Talk to Sales",
    signupQueryValue: "enterprise",
    backendPlanValue: "enterprise",
    salesOnly: true,
  },
] as const;

export function formatPlanPrice(value: number): string {
  return `₹${value.toLocaleString("en-IN")}`;
}

export function getDisplayPrice(plan: OrdWavePlanDefinition, billingPeriod: BillingPeriod): string {
  if (plan.monthlyPrice === null) return "Custom";
  if (billingPeriod === "yearly" && plan.annualMonthlyEquivalent !== null) {
    return formatPlanPrice(plan.annualMonthlyEquivalent);
  }
  return formatPlanPrice(plan.monthlyPrice);
}

export function getPriceHelper(plan: OrdWavePlanDefinition, billingPeriod: BillingPeriod): string | null {
  if (plan.monthlyPrice === null) return null;
  if (billingPeriod === "yearly" && plan.annualTotal !== null) {
    return `Billed ${formatPlanPrice(plan.annualTotal)} annually`;
  }
  if (plan.annualMonthlyEquivalent !== null) {
    return `${formatPlanPrice(plan.annualMonthlyEquivalent)}/mo billed annually`;
  }
  return null;
}
