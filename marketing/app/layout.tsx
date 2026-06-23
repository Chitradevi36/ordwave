import type { Metadata, Viewport } from "next";
import "./globals.css";
import { MarketingFooter } from "@/components/footer";
import { MarketingNavbar } from "@/components/navbar";

export const metadata: Metadata = {
  title: {
    default: "OrdWave",
    template: "%s | OrdWave",
  },
  description:
    "OrdWave is a cloud-based OMS for distributors covering order management, retailer CRM, inventory, delivery, invoicing, collections, and analytics.",
  metadataBase: new URL(process.env.NEXT_PUBLIC_MARKETING_URL ?? "https://ordwave.com"),
  keywords: [
    "distribution management software",
    "FMCG distributor software",
    "order management system",
    "inventory and collections software",
    "multi branch OMS",
    "GST invoicing software",
  ],
  openGraph: {
    type: "website",
    siteName: "OrdWave",
    title: "OrdWave — Distribution Management Software for Distributors and Wholesalers",
    description: "Manage orders, inventory, collections, credit, dispatch, delivery, and analytics from one platform.",
    url: "/",
  },
  twitter: {
    card: "summary_large_image",
    title: "OrdWave — Distribution Management Software",
    description: "Run your entire distribution business from one platform.",
  },
  alternates: {
    canonical: "/",
  },
  icons: {
    icon: "/logo.svg",
    shortcut: "/logo.svg",
    apple: "/logo.svg",
  },
};

export const viewport: Viewport = {
  themeColor: "#1B4332",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <MarketingNavbar />
        <main>{children}</main>
        <MarketingFooter />
      </body>
    </html>
  );
}
