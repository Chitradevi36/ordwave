import Link from "next/link";

export function MarketingFooter() {
  return (
    <footer className="border-t border-[#E2E8F0] bg-[#F8FAF8]">
      {/* Main columns */}
      <div className="section-shell py-14">
        <div className="grid gap-10 sm:grid-cols-2 lg:grid-cols-6">

          {/* Brand */}
          <div className="sm:col-span-2 lg:col-span-2">
            <Link href="/" className="flex items-center gap-2.5">
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-[#1B4332] text-xs font-bold text-white">OW</div>
              <span className="text-base font-bold text-[#0F172A]">OrdWave</span>
            </Link>
            <p className="mt-3 max-w-xs text-sm leading-relaxed text-[#64748B]">
              Cloud-based distribution management platform for FMCG distributors, wholesalers, and multi-branch operations across India.
            </p>
            <div className="mt-5 flex gap-3">
              <a href="https://linkedin.com" target="_blank" rel="noopener noreferrer" aria-label="LinkedIn"
                className="flex h-8 w-8 items-center justify-center rounded-lg border border-[#E2E8F0] bg-white text-[#64748B] transition-colors hover:text-[#1B4332]">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M16 8a6 6 0 016 6v7h-4v-7a2 2 0 00-2-2 2 2 0 00-2 2v7h-4v-7a6 6 0 016-6zM2 9h4v12H2z"/><circle cx="4" cy="4" r="2"/></svg>
              </a>
              <a href="https://twitter.com" target="_blank" rel="noopener noreferrer" aria-label="Twitter"
                className="flex h-8 w-8 items-center justify-center rounded-lg border border-[#E2E8F0] bg-white text-[#64748B] transition-colors hover:text-[#1B4332]">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M23 3a10.9 10.9 0 01-3.14 1.53 4.48 4.48 0 00-7.86 3v1A10.66 10.66 0 013 4s-4 9 5 13a11.64 11.64 0 01-7 2c9 5 20 0 20-11.5a4.5 4.5 0 00-.08-.83A7.72 7.72 0 0023 3z"/></svg>
              </a>
            </div>
            <p className="mt-5 text-[11px] font-semibold uppercase tracking-widest text-[#52B788]">GST-Ready · Made in India</p>
          </div>

          {/* Product */}
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#0F172A]">Product</h4>
            <ul className="mt-4 space-y-2.5 text-sm text-[#64748B]">
              <li><Link href="/features" className="transition-colors hover:text-[#1B4332]">Features</Link></li>
              <li><Link href="/pricing" className="transition-colors hover:text-[#1B4332]">Pricing</Link></li>
              <li><Link href="/request-demo" className="transition-colors hover:text-[#1B4332]">Book Demo</Link></li>
              <li><Link href="/request-demo" className="transition-colors hover:text-[#1B4332]">Free Trial</Link></li>
            </ul>
          </div>

          {/* Solutions */}
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#0F172A]">Solutions</h4>
            <ul className="mt-4 space-y-2.5 text-sm text-[#64748B]">
              <li><Link href="/industries" className="transition-colors hover:text-[#1B4332]">FMCG Distribution</Link></li>
              <li><Link href="/industries" className="transition-colors hover:text-[#1B4332]">Rice Distribution</Link></li>
              <li><Link href="/industries" className="transition-colors hover:text-[#1B4332]">Wholesale</Link></li>
              <li><Link href="/industries" className="transition-colors hover:text-[#1B4332]">Multi-Branch Ops</Link></li>
            </ul>
          </div>

          {/* Resources */}
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#0F172A]">Resources</h4>
            <ul className="mt-4 space-y-2.5 text-sm text-[#64748B]">
              <li><Link href="/customers" className="transition-colors hover:text-[#1B4332]">Customers</Link></li>
              <li><Link href="/use-cases" className="transition-colors hover:text-[#1B4332]">Use Cases</Link></li>
              <li><Link href="/contact" className="transition-colors hover:text-[#1B4332]">Support</Link></li>
            </ul>
          </div>

          {/* Company */}
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-[#0F172A]">Company</h4>
            <ul className="mt-4 space-y-2.5 text-sm text-[#64748B]">
              <li><Link href="/about" className="transition-colors hover:text-[#1B4332]">About</Link></li>
              <li><Link href="/contact" className="transition-colors hover:text-[#1B4332]">Contact</Link></li>
              <li><span className="cursor-default">Privacy Policy</span></li>
              <li><span className="cursor-default">Terms of Service</span></li>
            </ul>
          </div>

        </div>
      </div>

      {/* Bottom bar */}
      <div className="border-t border-[#E2E8F0]">
        <div className="section-shell flex flex-col items-center justify-between gap-3 py-5 sm:flex-row">
          <p className="text-xs text-[#94A3B8]">© {new Date().getFullYear()} OrdWave. All rights reserved.</p>
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
