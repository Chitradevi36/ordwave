import Link from "next/link";

export function MarketingFooter() {
  return (
    <footer className="border-t border-border bg-background-subtle/70">
      <div className="section-shell grid gap-10 py-12 lg:grid-cols-4">
        <div>
          <div className="mb-3 inline-flex items-center gap-2 rounded-lg bg-white px-3 py-2 shadow-sm">
            <div className="flex h-7 w-7 items-center justify-center rounded-md bg-primary text-xs font-bold text-white">OW</div>
            <h3 className="text-sm font-bold text-text-primary">OrdWave</h3>
          </div>
          <p className="mt-1 text-sm text-text-secondary">Cloud-based OMS for distributor operations.</p>
          <p className="mt-3 text-xs font-semibold uppercase tracking-wide text-primary">Built for Indian distributors</p>
        </div>

        <div>
          <h4 className="text-sm font-semibold text-text-primary">Product</h4>
          <ul className="mt-3 space-y-2 text-sm text-text-secondary">
            <li><Link href="/features" className="hover:text-text-primary">Features</Link></li>
            <li><Link href="/pricing" className="hover:text-text-primary">Pricing</Link></li>
            <li><Link href="/use-cases" className="hover:text-text-primary">Use Cases</Link></li>
          </ul>
        </div>

        <div>
          <h4 className="text-sm font-semibold text-text-primary">Company</h4>
          <ul className="mt-3 space-y-2 text-sm text-text-secondary">
            <li><Link href="/about" className="hover:text-text-primary">About</Link></li>
            <li><Link href="/contact" className="hover:text-text-primary">Contact</Link></li>
            <li>Privacy Policy (coming soon)</li>
            <li>Terms of Service (coming soon)</li>
          </ul>
        </div>

        <div>
          <h4 className="text-sm font-semibold text-text-primary">Why OrdWave</h4>
          <ul className="mt-3 space-y-2 text-sm text-text-secondary">
            <li>GST-ready invoicing</li>
            <li>Credit-first operations</li>
            <li>Offline-ready field workflows</li>
            <li>Multi-branch control center</li>
          </ul>
        </div>
      </div>
    </footer>
  );
}
