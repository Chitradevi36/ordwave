import type { Metadata } from "next";
import "./globals.css";
import { ClientProviders } from "@/components/providers";

export const metadata: Metadata = {
  title: "OmniDist OMS",
  description: "Offline-first, Credit-first OMS for FMCG Distributors",
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
