import type { Metadata } from "next";
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
