"use client";

import Script from "next/script";
import { FormEvent, useEffect, useRef, useState } from "react";
import { trackFormSubmit } from "@/lib/analytics";

type DemoFormProps = {
  title: string;
  subtitle: string;
};

type TurnstileWidgetId = string;

type TurnstileApi = {
  render: (
    container: HTMLElement,
    options: {
      sitekey: string;
      callback: (token: string) => void;
      "expired-callback": () => void;
      "error-callback": () => void;
    }
  ) => TurnstileWidgetId;
  reset: (widgetId?: TurnstileWidgetId) => void;
  remove?: (widgetId: TurnstileWidgetId) => void;
};

declare global {
  interface Window {
    turnstile?: TurnstileApi;
  }
}

export function DemoForm({ title, subtitle }: DemoFormProps) {
  const [isSubmitted, setIsSubmitted] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState("");
  const [captchaToken, setCaptchaToken] = useState("");
  const [isTurnstileReady, setIsTurnstileReady] = useState(false);
  const turnstileContainerRef = useRef<HTMLDivElement | null>(null);
  const turnstileWidgetIdRef = useRef<TurnstileWidgetId>();
  const turnstileSiteKey = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY || "";

  useEffect(() => {
    if (!isTurnstileReady || !turnstileSiteKey || !turnstileContainerRef.current || turnstileWidgetIdRef.current) {
      return;
    }

    turnstileWidgetIdRef.current = window.turnstile?.render(turnstileContainerRef.current, {
      sitekey: turnstileSiteKey,
      callback: (token) => {
        setCaptchaToken(token);
        setSubmitError("");
      },
      "expired-callback": () => setCaptchaToken(""),
      "error-callback": () => {
        setCaptchaToken("");
        setSubmitError("Captcha could not be verified. Please refresh it and try again.");
      },
    });

    return () => {
      if (turnstileWidgetIdRef.current) {
        window.turnstile?.remove?.(turnstileWidgetIdRef.current);
        turnstileWidgetIdRef.current = undefined;
      }
    };
  }, [isTurnstileReady, turnstileSiteKey]);

  const resetCaptcha = () => {
    setCaptchaToken("");

    if (turnstileWidgetIdRef.current) {
      window.turnstile?.reset(turnstileWidgetIdRef.current);
    }
  };

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSubmitError("");

    if (!turnstileSiteKey) {
      setSubmitError("Captcha is not configured. Please contact support.");
      return;
    }

    if (!captchaToken) {
      setSubmitError("Please complete the captcha before submitting.");
      return;
    }

    const form = event.currentTarget;
    const formData = new FormData(form);

    const payload = {
      name: String(formData.get("name") || "").trim(),
      email: String(formData.get("email") || "").trim(),
      company: String(formData.get("company") || "").trim(),
      phone: String(formData.get("phone") || "").trim(),
      message: String(formData.get("message") || "").trim(),
      source: "marketing-site",
      captchaToken,
    };

    try {
      setIsSubmitting(true);
      const response = await fetch(`/api/leads`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      });

      const result = await response.json().catch(() => ({}));

      if (!response.ok) {
        setSubmitError(result.errors?.[0] || "Unable to submit your request right now. Please try again.");
        resetCaptcha();
        return;
      }

      trackFormSubmit({ form_name: "demo_request", source: payload.source });
      setIsSubmitted(true);
      form.reset();
      resetCaptcha();
    } catch {
      setSubmitError("Unable to submit your request right now. Please try again.");
      resetCaptcha();
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="premium-card p-6 sm:p-7">
      <Script
        src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
        strategy="afterInteractive"
        onLoad={() => setIsTurnstileReady(true)}
      />

      <h2 className="text-2xl font-bold leading-tight text-text-primary">{title}</h2>
      <p className="mt-2 text-sm text-text-secondary">{subtitle}</p>

      {isSubmitted && (
        <div className="mt-4 rounded-lg border border-accent bg-green-50 p-3 text-sm font-medium text-primary">
          Thanks. Your request has been sent successfully. Our team will contact you shortly.
        </div>
      )}

      {submitError && (
        <div className="mt-4 rounded-lg border border-red-200 bg-red-50 p-3 text-sm font-medium text-red-700">
          {submitError}
        </div>
      )}

      <form className="mt-6 space-y-4" onSubmit={handleSubmit}>
        <input required disabled={isSubmitting} name="name" placeholder="Full name" className="h-11 w-full rounded-lg border border-border px-3 text-sm text-text-primary outline-none transition-all focus:border-primary/40 focus:ring-4 focus:ring-primary/10 disabled:opacity-60" />
        <input required disabled={isSubmitting} type="email" name="email" placeholder="Work email" className="h-11 w-full rounded-lg border border-border px-3 text-sm text-text-primary outline-none transition-all focus:border-primary/40 focus:ring-4 focus:ring-primary/10 disabled:opacity-60" />
        <input required disabled={isSubmitting} name="company" placeholder="Company" className="h-11 w-full rounded-lg border border-border px-3 text-sm text-text-primary outline-none transition-all focus:border-primary/40 focus:ring-4 focus:ring-primary/10 disabled:opacity-60" />
        <input required disabled={isSubmitting} name="phone" placeholder="Phone" className="h-11 w-full rounded-lg border border-border px-3 text-sm text-text-primary outline-none transition-all focus:border-primary/40 focus:ring-4 focus:ring-primary/10 disabled:opacity-60" />
        <textarea required disabled={isSubmitting} name="message" placeholder="Current setup and requirements" className="min-h-[100px] w-full rounded-lg border border-border p-3 text-sm text-text-primary outline-none transition-all focus:border-primary/40 focus:ring-4 focus:ring-primary/10 disabled:opacity-60" />
        <div ref={turnstileContainerRef} className="min-h-[65px]" />
        <button disabled={isSubmitting || Boolean(turnstileSiteKey && !captchaToken)} type="submit" className="w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-semibold text-white shadow-[0_8px_20px_rgba(27,67,50,0.25)] transition-colors hover:bg-primary-700 disabled:opacity-70 disabled:cursor-not-allowed">
          {isSubmitting ? "Submitting..." : "Submit"}
        </button>
      </form>
    </div>
  );
}
