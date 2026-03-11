"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import {
  Building2, GitBranch, ChevronDown, Check, Search, Plus, User, LogOut,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { apiClient } from "@/lib/api/client";
import { CommandPalette } from "@/components/global/CommandPalette";
import { NotificationsPanel } from "@/components/global/NotificationsPanel";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { filterCreateActionsForRole } from "@/components/layout/nav.config";
import { ANALYTICS_EVENTS, trackClick } from "@/lib/analytics";

// ── Types ─────────────────────────────────────────────────────────────────────
interface DropdownOption { value: string; label: string; sub?: string; }

// ── SwitcherDropdown ──────────────────────────────────────────────────────────
function SwitcherDropdown({
  icon: Icon, label, options, value, onChange, loading, allLabel,
}: {
  icon: React.ElementType;
  label: string;
  options: DropdownOption[];
  value: string;
  onChange: (v: string) => void;
  loading?: boolean;
  allLabel?: string;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const h = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", h);
    return () => document.removeEventListener("mousedown", h);
  }, []);

  const selected =
    allLabel && value === "" ? allLabel : (options.find((o) => o.value === value)?.label ?? label);

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen((p) => !p)}
        className="flex items-center gap-1.5 h-8 px-2.5 rounded-lg border border-border bg-background hover:bg-background-subtle transition-colors text-sm text-text-primary max-w-[200px]"
      >
        <Icon className="h-3.5 w-3.5 text-text-secondary shrink-0" />
        <span className="truncate font-medium">{loading ? "…" : selected}</span>
        <ChevronDown className="h-3 w-3 text-text-secondary shrink-0 ml-auto" />
      </button>
      {open && (
        <div className="absolute left-0 top-full mt-1.5 min-w-[200px] max-w-[260px] rounded-lg border border-border bg-background shadow-lg z-50 py-1">
          {allLabel !== undefined && (
            <button
              onClick={() => { onChange(""); setOpen(false); }}
              className="flex w-full items-center justify-between px-3 py-2 text-sm hover:bg-background-subtle transition-colors text-text-secondary"
            >
              <span>{allLabel}</span>
              {value === "" && <Check className="h-3.5 w-3.5 text-accent" />}
            </button>
          )}
          {allLabel !== undefined && options.length > 0 && <div className="h-px bg-border mx-2 my-1" />}
          {options.map((opt) => (
            <button
              key={opt.value}
              onClick={() => { onChange(opt.value); setOpen(false); }}
              className="flex w-full items-center justify-between gap-2 px-3 py-2 text-sm hover:bg-background-subtle transition-colors"
            >
              <div className="min-w-0">
                <p className="truncate text-text-primary font-medium">{opt.label}</p>
                {opt.sub && <p className="truncate text-xs text-text-secondary">{opt.sub}</p>}
              </div>
              {value === opt.value && <Check className="h-3.5 w-3.5 text-accent shrink-0" />}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

// ── CreateDropdown ────────────────────────────────────────────────────────────
function CreateDropdown() {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const role = useCurrentRole();
  const actions = filterCreateActionsForRole(role);

  useEffect(() => {
    const h = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", h);
    return () => document.removeEventListener("mousedown", h);
  }, []);

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen((p) => !p)}
        aria-expanded={open}
        aria-label="Create new"
        className="flex items-center gap-1.5 h-8 px-3 rounded-lg bg-accent text-white text-sm font-medium hover:bg-accent/90 transition-colors"
      >
        <Plus className="h-3.5 w-3.5" />
        <span className="hidden sm:inline">Create</span>
      </button>
      {open && (
        <div className="absolute right-0 top-full mt-1.5 min-w-[200px] rounded-lg border border-border bg-background shadow-lg z-50 py-1">
          <p className="px-3 py-1.5 text-[11px] font-semibold text-text-secondary uppercase tracking-wider">
            New
          </p>
          {actions.map((action) => (
            <Link
              key={action.href}
              href={action.href}
              onClick={() => {
                trackClick(ANALYTICS_EVENTS.HEADER_CREATE_CLICKED, {
                  element_label: action.label,
                  page:          action.href,
                });
                setOpen(false);
              }}
              className="flex items-center gap-2.5 px-3 py-2 text-sm text-text-primary hover:bg-background-subtle transition-colors"
            >
              <Plus className="h-3.5 w-3.5 text-text-secondary shrink-0" />
              {action.label}
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}

// ── UserMenu ──────────────────────────────────────────────────────────────────
function UserMenu({ onLogout }: { onLogout: () => void }) {
  const [open, setOpen] = useState(false);
  const [user, setUser] = useState<{ first_name?: string; last_name?: string; email?: string } | null>(null);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    try { const d = localStorage.getItem("user"); if (d) setUser(JSON.parse(d)); } catch {}
  }, []);

  useEffect(() => {
    const h = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", h);
    return () => document.removeEventListener("mousedown", h);
  }, []);

  const initials =
    user ? `${user.first_name?.[0] ?? ""}${user.last_name?.[0] ?? ""}`.toUpperCase() || "U" : "U";
  const displayName = user ? `${user.first_name ?? ""} ${user.last_name ?? ""}`.trim() : "User";

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen((p) => !p)}
        aria-expanded={open}
        aria-label="User menu"
        className="flex items-center gap-2 h-8 px-2 rounded-lg hover:bg-background-subtle transition-colors"
      >
        <div className="w-7 h-7 rounded-full bg-primary flex items-center justify-center text-xs font-semibold text-white shrink-0">
          {initials}
        </div>
        <span className="hidden lg:block text-sm font-medium text-text-primary leading-none max-w-[100px] truncate">
          {displayName}
        </span>
        <ChevronDown className="h-3 w-3 text-text-secondary hidden lg:block" />
      </button>
      {open && (
        <div className="absolute right-0 top-full mt-1.5 w-[220px] rounded-lg border border-border bg-background shadow-lg z-50 py-1">
          <div className="px-3 py-2.5 border-b border-border mb-1">
            <p className="text-sm font-semibold text-text-primary truncate">{displayName}</p>
            {user?.email && <p className="text-xs text-text-secondary truncate">{user.email}</p>}
          </div>
          <Link
            href="/settings/profile"
            onClick={() => setOpen(false)}
            className="flex items-center gap-2 px-3 py-2 text-sm text-text-primary hover:bg-background-subtle transition-colors"
          >
            <User className="h-4 w-4 text-text-secondary" />
            Profile settings
          </Link>
          <div className="h-px bg-border mx-2 my-1" />
          <button
            onClick={() => { setOpen(false); onLogout(); }}
            className="flex items-center gap-2 w-full px-3 py-2 text-sm text-red-600 hover:bg-red-50 transition-colors"
          >
            <LogOut className="h-4 w-4" />
            Sign out
          </button>
        </div>
      )}
    </div>
  );
}

// ── TopBar ────────────────────────────────────────────────────────────────────
export interface TopBarProps {
  title?: string;
  mobileMenuButton?: React.ReactNode;
}

export function TopBar({ title, mobileMenuButton }: TopBarProps) {
  const [showCommandPalette, setShowCommandPalette] = useState(false);
  const router = useRouter();
  const role = useCurrentRole();

  const {
    orgId, branchId, organizations, branches, orgsLoading, branchesLoading,
    switchOrg, switchBranch,
  } = useOrgBranch();

  // Cmd+K / Ctrl+K shortcut
  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        setShowCommandPalette((p) => !p);
      }
    };
    document.addEventListener("keydown", h);
    return () => document.removeEventListener("keydown", h);
  }, []);

  const handleLogout = useCallback(async () => {
    try {
      const token = localStorage.getItem("auth_token");
      if (token) await apiClient.delete("/api/v1/auth/logout");
    } catch {/* ignore */} finally {
      localStorage.removeItem("auth_token");
      localStorage.removeItem("user");
      localStorage.removeItem("organization_id");
      // Clear auth presence cookie used by middleware
      document.cookie = 'auth_present=; path=/; max-age=0; SameSite=Lax';
      router.push("/login");
    }
  }, [router]);

  const orgOptions: DropdownOption[] = organizations.map((o) => ({
    value: String(o.id), label: o.name, sub: o.slug,
  }));
  const branchOptions: DropdownOption[] = branches.map((b) => ({
    value: String(b.id), label: b.name, sub: [b.code, b.city].filter(Boolean).join("  "),
  }));

  return (
    <>
      <header className="flex h-16 shrink-0 items-center gap-3 border-b border-border bg-background px-4 md:px-6 z-30">
        {/* Mobile hamburger */}
        {mobileMenuButton}

        {/* Page title (mobile) */}
        {title && (
          <h1 className="text-base font-semibold text-text-primary shrink-0 mr-1 sm:hidden truncate max-w-[140px]">
            {title}
          </h1>
        )}

        {/* Org / Branch switchers */}
        <div className="hidden sm:flex items-center gap-2">
          <SwitcherDropdown
            icon={Building2}
            label="Organization"
            options={orgOptions}
            value={orgId}
            onChange={switchOrg}
            loading={orgsLoading}
          />
          <span className="text-border select-none text-sm">/</span>
          <SwitcherDropdown
            icon={GitBranch}
            label="All Branches"
            options={branchOptions}
            value={branchId}
            onChange={switchBranch}
            loading={branchesLoading}
            allLabel="All Branches"
          />
        </div>

        {/* Right actions */}
        <div className="ml-auto flex items-center gap-2">
          {/* Search / command palette trigger */}
          <button
            onClick={() => {
              trackClick(ANALYTICS_EVENTS.GLOBAL_SEARCH_USED, { element_label: 'command_palette' });
              setShowCommandPalette(true);
            }}
            aria-label="Open command palette (Ctrl+K)"
            className="flex items-center gap-2 h-9 px-3 rounded-lg border border-border hover:bg-background-subtle transition-colors text-sm text-text-secondary"
          >
            <Search className="h-4 w-4" />
            <span className="hidden md:inline text-xs font-mono opacity-60">⌘K</span>
          </button>

          {/* + Create */}
          <CreateDropdown />

          {/* Notifications */}
          <NotificationsPanel />

          {/* User menu */}
          <UserMenu onLogout={handleLogout} />
        </div>
      </header>

      {/* Command palette */}
      <CommandPalette open={showCommandPalette} onClose={() => setShowCommandPalette(false)} />
    </>
  );
}
