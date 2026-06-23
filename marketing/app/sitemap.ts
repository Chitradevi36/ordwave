import type { MetadataRoute } from "next";

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = process.env.NEXT_PUBLIC_MARKETING_URL ?? "https://ordwave.com";

  const paths = [
    "",
    "/features",
    "/pricing",
    "/use-cases",
    "/about",
    "/contact",
    "/request-demo",
  ];

  return paths.map((path) => ({
    url: `${baseUrl}${path}`,
    lastModified: new Date(),
    changeFrequency: path === "" ? "weekly" : "monthly",
    priority: path === "" ? 1 : 0.8,
  }));
}
