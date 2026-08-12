import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "Read how OrdWave collects, uses, stores, and protects personal and business information on its website and platform.",
};

const sections = [
  {
    title: "Information We Collect",
    body: [
      "We may collect contact details such as your name, company name, phone number, email address, and any information you submit through demo, contact, or support forms.",
      "We may also collect business context you choose to share with us, such as branch count, order volumes, workflow challenges, or rollout requirements.",
      "Technical information such as browser details, device information, IP address, and usage analytics may be collected to help us operate, secure, and improve the website and platform.",
    ],
  },
  {
    title: "How We Use Information",
    body: [
      "We use information to respond to inquiries, schedule demos, provide onboarding or support, and communicate about OrdWave services.",
      "We may use submitted information to understand your workflow, recommend suitable product configurations, and improve sales, support, and product experiences.",
      "Usage and technical data may be used for analytics, security monitoring, fraud prevention, debugging, and performance improvement.",
    ],
  },
  {
    title: "How We Share Information",
    body: [
      "We do not sell personal information.",
      "We may share information with service providers who help us operate our website, analytics, communications, infrastructure, or customer support, subject to appropriate confidentiality and security controls.",
      "We may also disclose information when required by law, to enforce our agreements, or to protect the rights, safety, and security of OrdWave, our customers, or others.",
    ],
  },
  {
    title: "Data Retention",
    body: [
      "We retain information for as long as needed to fulfill the purpose for which it was collected, comply with legal obligations, resolve disputes, and enforce agreements.",
      "Retention periods may vary depending on whether the information relates to website inquiries, customer accounts, support, security, or legal compliance.",
    ],
  },
  {
    title: "Security",
    body: [
      "We use reasonable administrative, technical, and organizational safeguards designed to protect information against unauthorized access, loss, misuse, or disclosure.",
      "No method of transmission or storage is completely secure, so we cannot guarantee absolute security.",
    ],
  },
  {
    title: "Your Choices",
    body: [
      "You may contact us to request access, correction, or deletion of personal information, subject to legal or contractual limitations.",
      "You may also opt out of non-essential communications by following unsubscribe instructions where available or by contacting us directly.",
    ],
  },
  {
    title: "Children's Privacy",
    body: [
      "OrdWave is intended for business use and is not directed to children. We do not knowingly collect personal information from children.",
    ],
  },
  {
    title: "Policy Updates",
    body: [
      "We may update this Privacy Policy from time to time. Updates will be posted on this page with a revised effective date when appropriate.",
    ],
  },
  {
    title: "Contact Us",
    body: [
      "If you have questions about this Privacy Policy or how your information is handled, please contact OrdWave through the contact options provided on our website.",
    ],
  },
];

export default function PrivacyPolicyPage() {
  return (
    <>
      <section className="gradient-mesh border-b border-[#E2E8F0]">
        <div className="section-shell section-gap">
          <span className="pill">Legal</span>
          <h1 className="mt-4 max-w-4xl text-4xl font-bold tracking-tight text-[#0F172A] sm:text-5xl">
            Privacy Policy
          </h1>
          <p className="mt-4 max-w-3xl text-base leading-relaxed text-[#475569] sm:text-lg">
            This Privacy Policy explains how OrdWave collects, uses, stores, and protects information when you use our website, request a demo, or engage with our platform and services.
          </p>
          <p className="mt-4 text-sm font-medium text-[#1B4332]">Effective date: August 12, 2026</p>
        </div>
      </section>

      <section className="section-shell section-gap">
        <div className="mx-auto max-w-4xl space-y-6">
          <div className="card p-6 sm:p-8">
            <p className="text-sm leading-7 text-[#475569]">
              By using OrdWave, submitting information to us, or interacting with our services, you acknowledge that your information may be handled as described in this Privacy Policy.
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
