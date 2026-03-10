import type { Metadata } from "next";
import "./globals.css";
import { ClientProviders } from "@/components/providers";

export const metadata: Metadata = {
  title: {
    default: "OrderLane Pro",
    template: "%s | OrderLane Pro",
  },
  description:
    "Offline-first, credit-first order management system for FMCG distributors. Manage orders, deliveries, collections and insights — all in one place.",
  keywords: ["FMCG", "OMS", "order management", "distributor", "sales rep", "delivery"],
  authors: [{ name: "OrderLane Pro" }],
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL ?? "https://app.orderlanepro.dev"),
  openGraph: {
    type:        "website",
    siteName:    "OrderLane Pro",
    title:       "OrderLane Pro — FMCG Distribution Made Simple",
    description: "Offline-first OMS for FMCG distributors. Orders, credit, delivery and collections in one platform.",
    images: [
      {
        url:    "/og-image.png",
        width:  1200,
        height: 630,
        alt:    "OrderLane Pro",
      },
    ],
  },
  twitter: {
    card:        "summary_large_image",
    title:       "OrderLane Pro",
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
    <html lang="en">
      <body>
        <ClientProviders>{children}</ClientProviders>
      </body>
    </html>
  );
}
