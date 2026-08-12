import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terms of Service",
  description:
    "Review the terms governing access to and use of the OrdWave website, platform, content, and related services.",
};

const sections = [
  {
    title: "Acceptance of Terms",
    body: [
      "These Terms of Service govern your access to and use of the OrdWave website, platform, content, and related services.",
      "By accessing or using OrdWave, you agree to be bound by these terms. If you do not agree, you should not use the website or services.",
    ],
  },
  {
    title: "Use of Services",
    body: [
      "You may use OrdWave only for lawful business purposes and in accordance with these terms.",
      "You agree not to misuse the service, interfere with its operation, attempt unauthorized access, or use the service in a way that could harm OrdWave, its customers, or other users.",
    ],
  },
  {
    title: "Accounts and Access",
    body: [
      "Some features may require an account, invitation, or approved access. You are responsible for maintaining the confidentiality of account credentials and for activities conducted under your account.",
      "You must provide accurate information when requesting access, onboarding, demos, or support.",
    ],
  },
  {
    title: "Customer Data",
    body: [
      "You retain responsibility for the business and personal data you submit to OrdWave through your use of the platform.",
      "You represent that you have the necessary rights and permissions to provide such data and to authorize OrdWave to process it in connection with the services.",
    ],
  },
  {
    title: "Intellectual Property",
    body: [
      "OrdWave and its related content, software, branding, designs, workflows, and materials are owned by OrdWave or its licensors and are protected by applicable intellectual property laws.",
      "Except as expressly permitted, you may not copy, modify, distribute, reverse engineer, or create derivative works from the service or its content.",
    ],
  },
  {
    title: "Fees and Commercial Terms",
    body: [
      "Paid plans, pricing, onboarding scope, and service commitments may be governed by separate order forms, proposals, subscription terms, or commercial agreements.",
      "If there is a conflict between these general terms and a signed commercial agreement, the signed commercial agreement will control for that customer relationship.",
    ],
  },
  {
    title: "Disclaimers",
    body: [
      "OrdWave is provided on an as-available and as-applicable basis except where specific commitments are stated in a separate written agreement.",
      "To the maximum extent permitted by law, OrdWave disclaims implied warranties including merchantability, fitness for a particular purpose, and non-infringement.",
    ],
  },
  {
    title: "Limitation of Liability",
    body: [
      "To the maximum extent permitted by law, OrdWave will not be liable for indirect, incidental, special, consequential, exemplary, or punitive damages, or for loss of profits, revenues, goodwill, or data.",
      "Any liability arising from the use of OrdWave will be limited as permitted under applicable law and any governing commercial agreement.",
    ],
  },
  {
    title: "Termination",
    body: [
      "We may suspend or terminate access if we reasonably believe these terms have been violated, if use poses a security or legal risk, or if required by law.",
      "You may stop using the services at any time, subject to any separate contractual commitments that may apply.",
    ],
  },
  {
    title: "Changes to Terms",
    body: [
      "We may update these Terms of Service from time to time. Updated terms will be posted on this page and may include a revised effective date.",
    ],
  },
  {
    title: "Contact",
    body: [
      "If you have questions about these Terms of Service, please contact OrdWave through the contact details or form available on our website.",
    ],
  },
];

export default function TermsOfServicePage() {
  return (
    <>
      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">Legal</span>
          <h1 className="mt-4 max-w-4xl text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">
            Terms of Service
          </h1>
          <p className="mt-4 max-w-3xl text-base leading-relaxed text-[#475569] sm:text-lg">
            These terms describe the general rules, responsibilities, and limits that apply when you access or use the OrdWave website, platform, and related services.
          </p>
          <p className="mt-4 text-sm font-medium text-[#1B4332]">Effective date: August 12, 2026</p>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="mx-auto max-w-4xl space-y-6">
          <div className="card p-6 sm:p-8">
            <p className="text-sm leading-7 text-[#475569]">
              These Terms of Service are intended as a general website and platform policy. Customer-specific onboarding, pricing, implementation scope, and commercial commitments may also be covered by separate written agreements.
            </p>
          </div>

          {sections.map((section) => (
            <div key={section.title} className="card p-6 sm:p-8">
              <h2 className="text-2xl font-bold tracking-tight text-[#0F172A]">{section.title}</h2>
              <div className="mt-4 space-y-4">
                {section.body.map((paragraph) => (
                  <p key={paragraph} className="text-sm leading-7 text-[#475569] sm:text-base">
                    {paragraph}
                  </p>
                ))}
              </div>
            </div>
          ))}
        </div>
      </section>
    </>
  );
}
