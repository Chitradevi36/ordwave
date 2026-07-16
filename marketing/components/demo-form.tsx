"use client";

import { FormEvent, useState } from "react";

type DemoFormProps = {
  title: string;
  subtitle: string;
};

export function DemoForm({ title, subtitle }: DemoFormProps) {
  const [isSubmitted, setIsSubmitted] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState("");

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSubmitError("");

    const form = event.currentTarget;
    const formData = new FormData(form);

    const payload = {
      name: String(formData.get("name") || "").trim(),
      email: String(formData.get("email") || "").trim(),
      company: String(formData.get("company") || "").trim(),
      phone: String(formData.get("phone") || "").trim(),
      message: String(formData.get("message") || "").trim(),
      source: "marketing-site",
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
        return;
      }

      setIsSubmitted(true);
      form.reset();
    } catch {
      setSubmitError("Unable to submit your request right now. Please try again.");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="premium-card p-6 sm:p-7">
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
        <button disabled={isSubmitting} type="submit" className="w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-semibold text-white shadow-[0_8px_20px_rgba(27,67,50,0.25)] transition-colors hover:bg-primary-700 disabled:opacity-70 disabled:cursor-not-allowed">
          {isSubmitting ? "Submitting..." : "Submit"}
        </button>
      </form>
    </div>
  );
}
