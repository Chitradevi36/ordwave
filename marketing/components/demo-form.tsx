"use client";

import { FormEvent, useState } from "react";

type DemoFormProps = {
  title: string;
  subtitle: string;
};

export function DemoForm({ title, subtitle }: DemoFormProps) {
  const [isSubmitted, setIsSubmitted] = useState(false);

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setIsSubmitted(true);
  };

  return (
    <div className="premium-card p-6 sm:p-7">
      <h2 className="text-2xl font-bold leading-tight text-text-primary">{title}</h2>
      <p className="mt-2 text-sm text-text-secondary">{subtitle}</p>

      {isSubmitted && (
        <div className="mt-4 rounded-lg border border-accent bg-green-50 p-3 text-sm font-medium text-primary">
          Thanks. Demo request captured. Connect this form to your CRM webhook in Phase 2.
        </div>
      )}

      <form className="mt-6 space-y-4" onSubmit={handleSubmit}>
        <input required name="name" placeholder="Full name" className="h-11 w-full rounded-lg border border-border px-3 text-sm text-text-primary outline-none transition-all focus:border-primary/40 focus:ring-4 focus:ring-primary/10" />
        <input required type="email" name="email" placeholder="Work email" className="h-11 w-full rounded-lg border border-border px-3 text-sm text-text-primary outline-none transition-all focus:border-primary/40 focus:ring-4 focus:ring-primary/10" />
        <input required name="company" placeholder="Company" className="h-11 w-full rounded-lg border border-border px-3 text-sm text-text-primary outline-none transition-all focus:border-primary/40 focus:ring-4 focus:ring-primary/10" />
        <input required name="phone" placeholder="Phone" className="h-11 w-full rounded-lg border border-border px-3 text-sm text-text-primary outline-none transition-all focus:border-primary/40 focus:ring-4 focus:ring-primary/10" />
        <textarea required name="message" placeholder="Current setup and requirements" className="min-h-[100px] w-full rounded-lg border border-border p-3 text-sm text-text-primary outline-none transition-all focus:border-primary/40 focus:ring-4 focus:ring-primary/10" />
        <button type="submit" className="w-full rounded-lg bg-primary px-4 py-2.5 text-sm font-semibold text-white shadow-[0_8px_20px_rgba(27,67,50,0.25)] transition-colors hover:bg-primary-700">
          Submit
        </button>
      </form>
    </div>
  );
}
