import type { Metadata, Viewport } from "next";
import Script from "next/script";
import "./globals.css";
import { MarketingFooter } from "@/components/footer";
import { MarketingNavbar } from "@/components/navbar";
import { GA_MEASUREMENT_ID } from "@/lib/analytics";
import { MarketingProviders } from "@/components/providers";
import { WhatsappCta } from "@/components/whatsapp-cta";

export const metadata: Metadata = {
  title: {
    default: "OrdWave",
    template: "%s | OrdWave",
  },
  description:
    "OrdWave helps Indian distributors stop risky dispatches, collect outstanding faster, and keep orders, credit, stock, delivery, and collections connected.",
  metadataBase: new URL(process.env.NEXT_PUBLIC_MARKETING_URL ?? "https://ordwave.com"),
  keywords: [
    "distribution management software",
    "FMCG distributor software",
    "order management system",
    "inventory and collections software",
    "multi branch OMS",
    "GST invoicing software",
    "distributor credit management software",
  ],
  openGraph: {
    type: "website",
    siteName: "OrdWave",
    title: "OrdWave - Credit-aware order execution for distributors",
    description: "Prevent risky dispatches. Collect outstanding faster. Keep orders, credit, stock, and delivery connected.",
    url: "/",
  },
  twitter: {
    card: "summary_large_image",
    title: "OrdWave - Stop Risky Dispatches. Collect Faster.",
    description: "Connect orders with retailer outstanding, credit limits, inventory, and delivery status before dispatch.",
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
        <WhatsappCta variant="floating" />
        <MarketingFooter />
      </body>
    </html>
  );
}
