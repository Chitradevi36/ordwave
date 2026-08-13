import Link from "next/link";
import { TrackedLink } from "@/components/tracked-link";

export function MarketingFooter() {
  return (
    <footer className="border-t border-[#E2E8F0] bg-[#F8FAF8]">
      <div className="section-shell py-14">
        <div className="grid gap-10 sm:grid-cols-2 lg:grid-cols-6">
          <div className="sm:col-span-2 lg:col-span-2">
            <Link href="/" className="flex items-center gap-2.5">
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-[#1B4332] text-xs font-bold text-white">OW</div>
              <span className="text-base font-bold text-[#0F172A]">OrdWave</span>
            </Link>
            <p className="mt-3 max-w-xs text-sm leading-relaxed text-[#64748B]">
              Cloud-based distribution management platform for FMCG distributors, wholesalers, and multi-branch operations across India.
            </p>
            <div className="mt-5 flex gap-3">
              <a
                href="https://linkedin.com"
                target="_blank"
                rel="noopener noreferrer"
                aria-label="LinkedIn"
                className="flex h-8 w-8 items-center justify-center rounded-lg border border-[#E2E8F0] bg-white text-[#64748B] transition-colors hover:text-[#1B4332]"
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M16 8a6 6 0 016 6v7h-4v-7a2 2 0 00-2-2 2 2 0 00-2 2v7h-4v-7a6 6 0 016-6zM2 9h4v12H2z" /><circle cx="4" cy="4" r="2" /></svg>
              </a>
              <a
                href="https://twitter.com"
                target="_blank"
                rel="noopener noreferrer"
                aria-label="Twitter"
                className="flex h-8 w-8 items-center justify-center rounded-lg border border-[#E2E8F0] bg-white text-[#64748B] transition-colors hover:text-[#1B4332]"
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M23 3a10.9 10.9 0 01-3.14 1.53 4.48 4.48 0 00-7.86 3v1A10.66 10.66 0 013 4s-4 9 5 13a11.64 11.64 0 01-7 2c9 5 20 0 20-11.5a4.5 4.5 0 00-.08-.83A7.72 7.72 0 0023 3z" /></svg>
              </a>
            </div>
            <p className="mt-5 text-[11px] font-semibold uppercase tracking-widest text-[#52B788]">GST-Ready | Made in India</p>
          </div>

          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#0F172A]">Product</h4>
            <ul className="mt-4 space-y-2.5 text-sm text-[#64748B]">
              <li><TrackedLink href="/features" label="Features" section="footer" className="transition-colors hover:text-[#1B4332]">Features</TrackedLink></li>
              <li><TrackedLink href="/pricing" label="Pricing" section="footer" className="transition-colors hover:text-[#1B4332]">Pricing</TrackedLink></li>
              <li><TrackedLink href="/request-demo" label="Start 30-Day Pilot" section="footer" className="transition-colors hover:text-[#1B4332]">Start 30-Day Pilot</TrackedLink></li>
              <li><TrackedLink href="/pricing" label="Founding Plan" section="footer" className="transition-colors hover:text-[#1B4332]">Founding Plan</TrackedLink></li>
            </ul>
          </div>

          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#0F172A]">Solutions</h4>
            <ul className="mt-4 space-y-2.5 text-sm text-[#64748B]">
              <li><TrackedLink href="/industries" label="FMCG Distribution" section="footer" className="transition-colors hover:text-[#1B4332]">FMCG Distribution</TrackedLink></li>
              <li><TrackedLink href="/industries" label="Rice Distribution" section="footer" className="transition-colors hover:text-[#1B4332]">Rice Distribution</TrackedLink></li>
              <li><TrackedLink href="/industries" label="Wholesale" section="footer" className="transition-colors hover:text-[#1B4332]">Wholesale</TrackedLink></li>
              <li><TrackedLink href="/industries" label="Multi-Branch Ops" section="footer" className="transition-colors hover:text-[#1B4332]">Multi-Branch Ops</TrackedLink></li>
            </ul>
          </div>

          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#0F172A]">Resources</h4>
            <ul className="mt-4 space-y-2.5 text-sm text-[#64748B]">
              <li><TrackedLink href="/customers" label="Distribution Workflows" section="footer" className="transition-colors hover:text-[#1B4332]">Distribution Workflows</TrackedLink></li>
              <li><TrackedLink href="/use-cases" label="Use Cases" section="footer" className="transition-colors hover:text-[#1B4332]">Use Cases</TrackedLink></li>
              <li><TrackedLink href="/fmcg-distributor-software" label="FMCG Distributor Software" section="footer" className="transition-colors hover:text-[#1B4332]">FMCG Distributor Software</TrackedLink></li>
              <li><TrackedLink href="/contact" label="Support" section="footer" className="transition-colors hover:text-[#1B4332]">Support</TrackedLink></li>
            </ul>
          </div>

          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#0F172A]">Company</h4>
            <ul className="mt-4 space-y-2.5 text-sm text-[#64748B]">
              <li><TrackedLink href="/about" label="About" section="footer" className="transition-colors hover:text-[#1B4332]">About</TrackedLink></li>
              <li><TrackedLink href="/contact" label="Contact" section="footer" className="transition-colors hover:text-[#1B4332]">Contact</TrackedLink></li>
              <li><TrackedLink href="/privacy-policy" label="Privacy Policy" section="footer" className="transition-colors hover:text-[#1B4332]">Privacy Policy</TrackedLink></li>
              <li><TrackedLink href="/terms-of-service" label="Terms of Service" section="footer" className="transition-colors hover:text-[#1B4332]">Terms of Service</TrackedLink></li>
            </ul>
          </div>
        </div>
      </div>

      <div className="border-t border-[#E2E8F0]">
        <div className="section-shell flex flex-col items-center justify-between gap-3 py-5 sm:flex-row">
          <p className="text-xs text-[#94A3B8]">Copyright {new Date().getFullYear()} OrdWave. All rights reserved.</p>
          <div className="flex flex-wrap justify-center gap-4 text-xs text-[#94A3B8]">
            <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-[#52B788]" />Secure Cloud</span>
            <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-[#52B788]" />GST Ready</span>
            <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-[#52B788]" />Daily Backups</span>
            <span className="flex items-center gap-1.5"><span className="h-1.5 w-1.5 rounded-full bg-[#52B788]" />Role-Based Access</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
