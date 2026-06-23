import Link from "next/link";
import Image from "next/image";

const navLinks = [
  { label: "Product",    href: "/features" },
  { label: "Industries", href: "/industries" },
  { label: "Pricing",    href: "/pricing" },
  { label: "Customers",  href: "/customers" },
  { label: "About",      href: "/about" },
  { label: "Contact",    href: "/contact" },
];

export function MarketingNavbar() {
  return (
    <header className="sticky top-0 z-50 border-b border-[#E2E8F0] bg-white/90 backdrop-blur-xl">
      <div className="section-shell flex h-[72px] items-center justify-between gap-6">

        {/* Logo */}
        <Link href="/" className="group flex shrink-0 items-center gap-2.5">
          <Image
            src="/logo.svg"
            alt="OrdWave"
            width={36}
            height={36}
            className="transition-transform group-hover:scale-105"
          />
          <span className="text-[17px] font-bold tracking-tight text-[#0F172A]">OrdWave</span>
        </Link>

        {/* Nav */}
        <nav className="hidden items-center gap-1 lg:flex">
          {navLinks.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="rounded-lg px-3.5 py-2 text-sm font-medium text-[#475569] transition-colors hover:bg-[#F8FAF8] hover:text-[#0F172A]"
            >
              {item.label}
            </Link>
          ))}
        </nav>

        {/* CTAs */}
        <div className="flex shrink-0 items-center gap-2">
          <Link
            href="https://app.ordwave.com/login"
            className="hidden rounded-lg px-4 py-2 text-sm font-semibold text-[#475569] transition-colors hover:text-[#0F172A] sm:inline-flex"
          >
            Sign In
          </Link>
          <Link
            href="/request-demo"
            className="rounded-xl border border-[#E2E8F0] bg-white px-4 py-2 text-sm font-semibold text-[#0F172A] shadow-sm transition-all hover:bg-[#F8FAF8] hidden sm:inline-flex"
          >
            Book Demo
          </Link>
          <Link
            href="/request-demo"
            className="btn-primary rounded-xl px-4 py-2 text-sm"
          >
            Start Free Trial
          </Link>
        </div>
      </div>
    </header>
  );
}
