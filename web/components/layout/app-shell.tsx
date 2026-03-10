"use client";

import { useState, useEffect } from "react";
import { usePathname } from "next/navigation";
import { Menu } from "lucide-react";
import { Sidebar } from "./sidebar";
import { TopBar } from "./top-bar";
import { Breadcrumb } from "@/components/ui/breadcrumb";
import { buildBreadcrumbs } from "@/lib/breadcrumbs";
import type { BreadcrumbItem } from "@/components/ui/breadcrumb";
import { useKeyboardShortcuts } from "@/lib/hooks/useKeyboardShortcuts";

export interface AppShellProps {
  children: React.ReactNode;
  title?: string;
  /** Custom breadcrumbs. When provided, overrides the auto-generated ones (use
   *  for pages with dynamic entity names like customer/order detail views). */
  breadcrumbs?: BreadcrumbItem[];
  /** Set true on workspace root pages or any page managing its own breadcrumbs
   *  inside children to suppress the shell-level breadcrumb. */
  hideBreadcrumb?: boolean;
  /** Remove the default p-4 md:p-6 padding from main — workspace pages use
   *  this to render a full-bleed header then apply their own inner padding. */
  noPad?: boolean;
}

export type { BreadcrumbItem };

export function AppShell({ children, title, breadcrumbs, hideBreadcrumb, noPad }: AppShellProps) {
  const [mobileOpen, setMobileOpen] = useState(false);
  const pathname = usePathname();

  // Register global keyboard shortcuts (Ctrl+K, Ctrl+N, Escape)
  useKeyboardShortcuts();

  // Auto-generate breadcrumbs from route (unless custom or suppressed)
  const autoCrumbs = buildBreadcrumbs(pathname);
  const crumbs = breadcrumbs ?? autoCrumbs;
  // Only show when 2+ items (single-item = workspace root, not useful)
  const showBreadcrumb = !hideBreadcrumb && crumbs.length >= 2;

  // Close drawer on route change
  useEffect(() => {
    setMobileOpen(false);
  }, [pathname]);

  // Close drawer on Escape
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") setMobileOpen(false);
    };
    document.addEventListener("keydown", handleKeyDown);
    return () => document.removeEventListener("keydown", handleKeyDown);
  }, []);

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar
        mobileOpen={mobileOpen}
        onMobileClose={() => setMobileOpen(false)}
      />
      <div className="flex flex-1 flex-col overflow-hidden min-w-0">
        <TopBar
          title={title}
          mobileMenuButton={
            <button
              onClick={() => setMobileOpen(true)}
              aria-label="Open navigation menu"
              className="flex h-9 w-9 items-center justify-center rounded-lg border border-border hover:bg-background-subtle transition-colors lg:hidden"
            >
              <Menu className="h-4 w-4 text-text-secondary" />
            </button>
          }
        />
        <main className={`flex-1 overflow-y-auto bg-background-subtle${noPad ? "" : " p-4 md:p-6"}`}>
          {showBreadcrumb && (
            <Breadcrumb items={crumbs} className="mb-4" />
          )}
          {children}
        </main>
      </div>
    </div>
  );
}
