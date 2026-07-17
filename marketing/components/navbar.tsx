import Link from "next/link";
import Image from "next/image";
import { TrackedLink } from "@/components/tracked-link";

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
            <TrackedLink
              key={item.href}
              href={item.href}
              label={item.label}
              section="navbar"
              className="rounded-lg px-3.5 py-2 text-sm font-medium text-[#475569] transition-colors hover:bg-[#F8FAF8] hover:text-[#0F172A]"
            >
              {item.label}
            </TrackedLink>
          ))}
        </nav>

        {/* CTAs */}
        <div className="flex shrink-0 items-center gap-2">
          <TrackedLink
            href="https://app.ordwave.com/login"
            label="Sign In"
            section="navbar"
            className="hidden rounded-lg px-4 py-2 text-sm font-semibold text-[#475569] transition-colors hover:text-[#0F172A] sm:inline-flex"
          >
            Sign In
          </TrackedLink>
          <TrackedLink
            href="/request-demo"
            label="Book Demo"
            section="navbar"
            className="rounded-xl border border-[#E2E8F0] bg-white px-4 py-2 text-sm font-semibold text-[#0F172A] shadow-sm transition-all hover:bg-[#F8FAF8] hidden sm:inline-flex"
          >
            Book Demo
          </TrackedLink>
          <TrackedLink
            href="/request-demo"
            label="Start Free Trial"
            section="navbar"
            className="btn-primary rounded-xl px-4 py-2 text-sm"
          >
            Start Free Trial
          </TrackedLink>
        </div>
      </div>
    </header>
  );
}
