import type { Metadata } from "next";
import Script from "next/script";
import "./globals.css";
import { ClientProviders } from "@/components/providers";
import { GA_MEASUREMENT_ID } from "@/lib/analytics";

export const metadata: Metadata = {
  title: {
    default: "OrdWave",
    template: "%s | OrdWave",
  },
  description:
    "Offline-first, credit-first order management system for FMCG distributors. Manage orders, deliveries, collections and insights — all in one place.",
  keywords: ["FMCG", "OMS", "order management", "distributor", "sales rep", "delivery"],
  authors: [{ name: "OrdWave" }],
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL ?? "https://app.orderlanepro.dev"),
  openGraph: {
    type:        "website",
    siteName:    "OrdWave",
    title:       "OrdWave — FMCG Distribution Made Simple",
    description: "Offline-first OMS for FMCG distributors. Orders, credit, delivery and collections in one platform.",
    images: [
      {
        url:    "/og-image.png",
        width:  1200,
        height: 630,
        alt:    "OrdWave",
      },
    ],
  },
  twitter: {
    card:        "summary_large_image",
    title:       "OrdWave",
    description: "Offline-first OMS for FMCG distributors.",
    images:      ["/og-image.png"],
  },
  manifest: "/manifest.webmanifest",
  icons: {
    icon:    [{ url: "/favicon.ico" }, { url: "/icon-192.png", sizes: "192x192", type: "image/png" }],
    apple:   [{ url: "/apple-touch-icon.png", sizes: "180x180" }],
    shortcut: "/favicon.ico",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head suppressHydrationWarning>
        {GA_MEASUREMENT_ID && (
          <>
            <Script
              src={`https://www.googletagmanager.com/gtag/js?id=${GA_MEASUREMENT_ID}`}
              strategy="afterInteractive"
            />
            <Script id="ga4-init" strategy="afterInteractive">
              {`
                window.dataLayer = window.dataLayer || [];
                function gtag(){dataLayer.push(arguments);}
                gtag('js', new Date());
                gtag('config', '${GA_MEASUREMENT_ID}', { send_page_view: false });
              `}
            </Script>
          </>
        )}
      </head>
      <body suppressHydrationWarning>
        <ClientProviders>{children}</ClientProviders>
      </body>
    </html>
  );
}
