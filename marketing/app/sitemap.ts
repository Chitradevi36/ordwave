import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = process.env.NEXT_PUBLIC_MARKETING_URL ?? "https://ordwave.com";

  const paths = [
    "",
    "/features",
    "/fmcg-distributor-software",
    "/industries",
    "/customers",
    "/pricing",
    "/use-cases",
    "/about",
    "/contact",
    "/privacy-policy",
    "/request-demo",
    "/terms-of-service",
  ];

  return paths.map((path) => ({
    url: `${baseUrl}${path}`,
    lastModified: new Date(),
    changeFrequency: path === "" ? "weekly" : "monthly",
    priority: path === "" ? 1 : 0.8,
  }));
}
