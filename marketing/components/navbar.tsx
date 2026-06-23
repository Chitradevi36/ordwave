import Link from "next/link";

const navItems = [
  { label: "Features", href: "/features" },
  { label: "Pricing", href: "/pricing" },
  { label: "Use Cases", href: "/use-cases" },
  { label: "About", href: "/about" },
  { label: "Contact", href: "/contact" },
];

export function MarketingNavbar() {
  return (
    <header className="sticky top-0 z-50 border-b border-white/60 bg-white/80 backdrop-blur-xl">
      <div className="section-shell flex h-[74px] items-center justify-between">
        <Link href="/" className="group flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary text-sm font-bold text-white shadow-[0_10px_20px_rgba(27,67,50,0.26)] transition-transform group-hover:scale-105">
            OW
          </div>
          <div>
            <p className="text-base font-bold leading-tight text-text-primary">OrdWave</p>
            <p className="text-[11px] font-medium uppercase tracking-wide text-text-secondary">Distributor OMS</p>
          </div>
        </Link>

        <nav className="hidden items-center gap-7 md:flex">
          {navItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="text-sm font-semibold text-text-secondary transition-colors hover:text-text-primary"
            >
              {item.label}
            </Link>
          ))}
        </nav>

        <div className="flex items-center gap-2 sm:gap-3">
          <Link
            href="https://app.ordwave.com/login"
            className="rounded-lg border border-border bg-white px-4 py-2.5 text-sm font-semibold text-text-primary transition-colors hover:bg-background-subtle"
          >
            Login
          </Link>
          <Link
            href="/request-demo"
            className="rounded-lg bg-primary px-4 py-2.5 text-sm font-semibold text-white shadow-[0_10px_20px_rgba(27,67,50,0.25)] transition-all hover:-translate-y-[1px] hover:bg-primary-700"
          >
            Book Demo
          </Link>
        </div>
      </div>
    </header>
  );
}
