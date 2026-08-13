"use client";

import { useMemo } from "react";
import { trackEvent } from "@/lib/analytics";
import { siteConfig } from "@/lib/site-config";
import { TrackedLink } from "@/components/tracked-link";

export function DemoVideoSection() {
  const videoUrl = siteConfig.demoVideo.videoUrl;
  const isEmbeddable = useMemo(() => {
    if (!videoUrl) return false;
    return videoUrl.includes("youtube.com") || videoUrl.includes("youtu.be") || videoUrl.includes("vimeo.com");
  }, [videoUrl]);

  const embedUrl = useMemo(() => {
    if (!videoUrl) return "";
    if (videoUrl.includes("youtu.be/")) {
      const id = videoUrl.split("youtu.be/")[1]?.split("?")[0];
      return id ? `https://www.youtube.com/embed/${id}` : "";
    }
    if (videoUrl.includes("youtube.com/watch?v=")) {
      const id = videoUrl.split("watch?v=")[1]?.split("&")[0];
      return id ? `https://www.youtube.com/embed/${id}` : "";
    }
    if (videoUrl.includes("vimeo.com/")) {
      const id = videoUrl.split("vimeo.com/")[1]?.split("?")[0];
      return id ? `https://player.vimeo.com/video/${id}` : "";
    }
    return videoUrl;
  }, [videoUrl]);

  return (
    <section id="demo-video" className="section-gap border-b border-[#E2E8F0] bg-[#F8FAF8]">
      <div className="section-shell">
        <div className="mx-auto max-w-3xl text-center">
          <span className="pill">See OrdWave in action</span>
          <h2 className="mt-4 text-3xl font-bold tracking-tight text-[#0F172A] sm:text-4xl">
            {siteConfig.demoVideo.title}
          </h2>
          <p className="mt-3 text-base text-[#475569]">{siteConfig.demoVideo.description}</p>
        </div>

        <div className="mx-auto mt-10 max-w-5xl overflow-hidden rounded-[28px] border border-[#D8E2DC] bg-white shadow-[0_24px_56px_rgba(15,23,42,0.08)]">
          {isEmbeddable && embedUrl ? (
            <div className="aspect-video w-full bg-[#0F1A13]">
              <iframe
                src={embedUrl}
                title={siteConfig.demoVideo.thumbnailLabel}
                className="h-full w-full"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowFullScreen
                onLoad={() => trackEvent("demo_video_started", { source: "embedded_video" })}
              />
            </div>
          ) : (
            <div className="grid gap-8 p-8 sm:p-10 lg:grid-cols-[1.1fr_0.9fr] lg:items-center">
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#1B4332]">
                  90-second demo slot
                </p>
                <h3 className="mt-3 text-2xl font-bold tracking-tight text-[#0F172A]">
                  Credit check before dispatch is the story buyers need to see first
                </h3>
                <p className="mt-4 text-sm leading-7 text-[#475569] sm:text-base">
                  We have set up this section to host a real product video. Until the recording is published, request a founder-led walkthrough focused on order booking, credit hold, approval, dispatch, invoicing, and collection follow-through.
                </p>
                <div className="mt-6 flex flex-wrap gap-3">
                  <TrackedLink
                    href="/request-demo"
                    label="Watch 90-Second Demo"
                    section="demo-video"
                    onClick={() => trackEvent("demo_video_started", { source: "placeholder_cta" })}
                    className="btn-primary px-6 py-3"
                  >
                    Watch 90-Second Demo
                  </TrackedLink>
                  <TrackedLink href="/request-demo" label="Request Live Walkthrough" section="demo-video" className="btn-secondary px-6 py-3">
                    Request Live Walkthrough
                  </TrackedLink>
                </div>
              </div>
              <div className="rounded-[24px] border border-[#E2E8F0] bg-[linear-gradient(180deg,#F5FAF7_0%,#FFFFFF_100%)] p-6">
                <div className="rounded-2xl border border-[#D5EBDD] bg-white p-5 shadow-sm">
                  <p className="text-xs font-semibold uppercase tracking-[0.16em] text-[#64748B]">Workflow preview</p>
                  <div className="mt-4 space-y-3">
                    {[
                      "Retailer Order",
                      "Credit Check",
                      "Approve / Hold / Block",
                      "Stock Allocation",
                      "Dispatch",
                      "Proof of Delivery",
                      "Invoice",
                      "Collection",
                    ].map((step, index) => (
                      <div key={step} className="flex items-center gap-3">
                        <span className="inline-flex h-7 w-7 items-center justify-center rounded-full bg-[#EFF7F2] text-xs font-bold text-[#1B4332]">
                          {index + 1}
                        </span>
                        <span className="text-sm font-medium text-[#0F172A]">{step}</span>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
