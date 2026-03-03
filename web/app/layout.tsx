import type { Metadata } from "next";
import "./globals.css";

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
      <body>{children}</body>
    </html>
  );
}
