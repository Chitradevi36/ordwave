"use client";

import { trackEvent } from "@/lib/analytics";
import { getWhatsappHref } from "@/lib/site-config";

type WhatsappCtaProps = {
  variant?: "floating" | "inline";
  className?: string;
};

export function WhatsappCta({ variant = "inline", className = "" }: WhatsappCtaProps) {
  const href = getWhatsappHref();
  if (!href) return null;

  const baseClassName =
    variant === "floating"
      ? "fixed bottom-5 right-5 z-40 inline-flex items-center gap-2 rounded-full border border-[#D7E8DD] bg-white px-4 py-3 text-sm font-semibold text-[#0F172A] shadow-[0_18px_40px_rgba(15,23,42,0.16)] transition hover:-translate-y-0.5 hover:bg-[#F8FAF8]"
      : "inline-flex items-center gap-2 rounded-xl border border-[#D7E8DD] bg-white px-5 py-2.5 text-sm font-semibold text-[#0F172A] shadow-sm transition hover:bg-[#F8FAF8]";

  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      aria-label="Ask us on WhatsApp"
      onClick={() => trackEvent("whatsapp_clicked", { location: variant })}
      className={`${baseClassName} ${className}`.trim()}
    >
      <span
        aria-hidden="true"
        className="inline-flex h-8 w-8 items-center justify-center rounded-full bg-[#EAF7EF] text-[#1B4332]"
      >
        W
      </span>
      <span>{variant === "floating" ? "Chat with OrdWave" : "Ask us on WhatsApp"}</span>
    </a>
  );
}
