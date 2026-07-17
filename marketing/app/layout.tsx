import type { Metadata, Viewport } from "next";
import Script from "next/script";
import "./globals.css";
import { MarketingFooter } from "@/components/footer";
import { MarketingNavbar } from "@/components/navbar";
import { GA_MEASUREMENT_ID } from "@/lib/analytics";
import { MarketingProviders } from "@/components/providers";

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
    <html lang="en" suppressHydrationWarning>
      <body>
        {GA_MEASUREMENT_ID && (
          <Script src={`https://www.googletagmanager.com/gtag/js?id=${GA_MEASUREMENT_ID}`} strategy="afterInteractive" />
        )}
        {GA_MEASUREMENT_ID && (
          <Script id="marketing-ga4-init" strategy="afterInteractive">
            {`
              window.dataLayer = window.dataLayer || [];
              function gtag(){dataLayer.push(arguments);}
              gtag('js', new Date());
              gtag('config', '${GA_MEASUREMENT_ID}', { send_page_view: false });
            `}
          </Script>
        )}
        <MarketingNavbar />
        <MarketingProviders>
          <main>{children}</main>
        </MarketingProviders>
        <MarketingFooter />
      </body>
    </html>
  );
}
