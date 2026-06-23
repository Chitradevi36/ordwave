import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  const baseUrl = process.env.NEXT_PUBLIC_MARKETING_URL ?? "https://ordwave.com";

  return {
    rules: {
      userAgent: "*",
      allow: ["/", "/features", "/industries", "/customers", "/pricing", "/use-cases", "/about", "/contact", "/request-demo"],
    },
    sitemap: `${baseUrl}/sitemap.xml`,
  };
}

