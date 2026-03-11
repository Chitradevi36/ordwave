"use client";

import { usePathname } from "next/navigation";
import Link from "next/link";
import { AppShell } from "@/components/layout";
import { cn } from "@/lib/utils";

const SUB_NAV = [
  { label: "Integrations",   href: "/accounting/integrations" },
  { label: "Sync Dashboard", href: "/accounting/sync-records" },
  { label: "Export Center",  href: "/accounting/export-files" },
];

export default function AccountingLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();

  return (
    <AppShell title="Accounting" hideBreadcrumb>
      {/* ── Section header ── */}
      <div className="mb-6">
        <div className="flex flex-col gap-1 mb-4">
          <h1 className="text-2xl font-bold text-text-primary">Accounting</h1>
          <p className="text-sm text-text-secondary">
            Configure integrations, monitor syncs, and manage batch exports.
          </p>
        </div>

        {/* ── Sub nav tabs ── */}
        <div className="border-b border-border">
          <nav className="flex gap-0 -mb-px">
            {SUB_NAV.map((item) => {
              const active =
                pathname === item.href || pathname.startsWith(item.href + "/");
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={cn(
                    "px-4 py-2.5 text-sm font-medium border-b-2 transition-colors whitespace-nowrap",
                    active
                      ? "border-primary text-primary"
                      : "border-transparent text-text-secondary hover:text-text-primary hover:border-border"
                  )}
                >
                  {item.label}
                </Link>
              );
            })}
          </nav>
        </div>
      </div>

      {children}
    </AppShell>
  );
}
