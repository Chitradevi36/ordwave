"use client";

import { AppShell } from "@/components/layout/app-shell";

/**
 * Dashboard route group layout.
 *
 * Wraps all authenticated pages with AppShell (sidebar + top bar + breadcrumbs).
 * Pages placed under `app/(dashboard)/` will automatically get the shell
 * without needing to import and wrap <AppShell> themselves.
 *
 * ── Migration guide ──────────────────────────────────────────────────────────
 * To move a page into this layout group:
 * 1. Move `app/<name>/page.tsx` → `app/(dashboard)/<name>/page.tsx`
 * 2. Remove the <AppShell> wrapper from the page component
 * 3. The URL remains `/<name>` (route groups don't affect the URL)
 *
 * Pages that need custom AppShell props (hideBreadcrumb, noPad, etc.) can
 * pass them via route segment config or continue wrapping AppShell directly.
 */
export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <AppShell>{children}</AppShell>;
}
