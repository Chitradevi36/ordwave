"use client";

import { useState, useEffect } from "react";
import { usePathname } from "next/navigation";
import { ChevronLeft, X, LogOut } from "lucide-react";
import * as Tooltip from "@radix-ui/react-tooltip";
import Link from "next/link";

import {
  PRIMARY_NAV,
  filterNavForRole,
  isActiveRoute,
  type PrimaryNavItem,
} from "./nav.config";
import { useCurrentRole } from "@/lib/hooks/use-current-role";

// ── NavItem ───────────────────────────────────────────────────────────────────
function NavItem({
  item,
  collapsed,
  onClick,
}: {
  item: PrimaryNavItem;
  collapsed: boolean;
  onClick?: () => void;
}) {
  const pathname = usePathname();
  const active = isActiveRoute(pathname, item);
  const Icon = item.icon;

  const linkClass = [
    "group relative flex items-center rounded-lg text-sm font-medium transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent",
    collapsed ? "h-10 w-10 justify-center mx-auto" : "gap-3 px-3 py-2.5",
    active
      ? "bg-accent/15 text-accent"
      : "text-primary-200 hover:bg-white/8 hover:text-white",
  ].join(" ");

  const inner = (
    <Link
      href={item.href}
      onClick={onClick}
      className={linkClass}
      aria-current={active ? "page" : undefined}
    >
      {/* Active indicator bar */}
      {active && (
        <span
          className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-6 rounded-r bg-accent"
          aria-hidden="true"
        />
      )}
      <Icon
        className={[
          "shrink-0 transition-colors",
          collapsed ? "h-5 w-5" : "h-[18px] w-[18px]",
          active ? "text-accent" : "text-primary-300 group-hover:text-white",
        ].join(" ")}
        aria-hidden="true"
      />
      {!collapsed && (
        <span className="truncate leading-none">{item.label}</span>
      )}
    </Link>
  );

  if (!collapsed) return inner;

  return (
    <Tooltip.Root delayDuration={150}>
      <Tooltip.Trigger asChild>{inner}</Tooltip.Trigger>
      <Tooltip.Portal>
        <Tooltip.Content
          side="right"
          sideOffset={10}
          className="z-[60] rounded-md bg-gray-900 px-2.5 py-1.5 text-xs font-medium text-white shadow-lg"
        >
          {item.label}
          <Tooltip.Arrow className="fill-gray-900" />
        </Tooltip.Content>
      </Tooltip.Portal>
    </Tooltip.Root>
  );
}

// ── UserFooter ────────────────────────────────────────────────────────────────
function UserFooter({
  collapsed,
  onLogout,
}: {
  collapsed: boolean;
  onLogout: () => void;
}) {
  const [user, setUser] = useState<{
    first_name?: string;
    last_name?: string;
    email?: string;
  } | null>(null);
  const [showMenu, setShowMenu] = useState(false);

  useEffect(() => {
    try {
      const raw = localStorage.getItem("user");
      if (raw) setUser(JSON.parse(raw));
    } catch {}
  }, []);

  const initials = user
    ? `${user.first_name?.[0] ?? ""}${user.last_name?.[0] ?? ""}`.toUpperCase()
    : "?";
  const fullName = user
    ? `${user.first_name ?? ""} ${user.last_name ?? ""}`.trim() || "User"
    : "User";

  const avatar = (
    <button
      onClick={() => setShowMenu((p) => !p)}
      aria-label="User menu"
      className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent/20 text-xs font-bold text-accent hover:bg-accent/30 transition-colors"
    >
      {initials}
    </button>
  );

  if (collapsed) {
    return (
      <div className="shrink-0 border-t border-primary-700 py-3 flex justify-center">
        <Tooltip.Root delayDuration={150}>
          <Tooltip.Trigger asChild>{avatar}</Tooltip.Trigger>
          <Tooltip.Portal>
            <Tooltip.Content
              side="right"
              sideOffset={10}
              className="z-[60] rounded-md bg-gray-900 px-2.5 py-1.5 text-xs text-white shadow-lg"
            >
              <p className="font-medium">{fullName}</p>
              <p className="opacity-70">{user?.email}</p>
              <Tooltip.Arrow className="fill-gray-900" />
            </Tooltip.Content>
          </Tooltip.Portal>
        </Tooltip.Root>
      </div>
    );
  }

  return (
    <div className="shrink-0 border-t border-primary-700 p-3">
      <div className="relative">
        <button
          onClick={() => setShowMenu((p) => !p)}
          className="flex w-full items-center gap-2.5 rounded-lg px-2 py-1.5 hover:bg-white/8 transition-colors"
        >
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent/20 text-xs font-bold text-accent">
            {initials}
          </div>
          <div className="min-w-0 flex-1 text-left">
            <p className="truncate text-xs font-semibold text-white leading-tight">
              {fullName}
            </p>
            <p className="truncate text-[11px] text-primary-300 opacity-70 leading-tight mt-0.5">
              {user?.email ?? ""}
            </p>
          </div>
        </button>

        {showMenu && (
          <div className="absolute bottom-full left-0 mb-1 w-full rounded-lg border border-primary-700 bg-primary-800 shadow-xl py-1">
            <button
              onClick={onLogout}
              className="flex w-full items-center gap-2 px-3 py-2 text-xs text-red-400 hover:bg-white/8 transition-colors"
            >
              <LogOut className="h-3.5 w-3.5" />
              Sign out
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

// ── SidebarBody ───────────────────────────────────────────────────────────────
function SidebarBody({
  collapsed,
  onToggleCollapse,
  onMobileClose,
  isMobile,
  onLogout,
}: {
  collapsed: boolean;
  onToggleCollapse?: () => void;
  onMobileClose?: () => void;
  isMobile?: boolean;
  onLogout: () => void;
}) {
  const role = useCurrentRole();
  const navItems = filterNavForRole(role);
  const isCollapsed = collapsed && !isMobile;

  return (
    <div
      className={[
        "flex h-screen flex-col bg-primary overflow-hidden transition-all duration-200",
        isCollapsed ? "w-16" : "w-64",
      ].join(" ")}
    >
      {/* ── Header: logo + collapse toggle ── */}
      <div
        className={[
          "flex h-14 shrink-0 items-center border-b border-primary-700",
          isCollapsed ? "justify-center px-0" : "justify-between px-4",
        ].join(" ")}
      >
        {!isCollapsed && (
          <Link href="/dashboard" className="text-base font-bold tracking-tight text-white hover:opacity-90 transition-opacity">
            OrderLane
          </Link>
        )}
        {isMobile ? (
          <button
            onClick={onMobileClose}
            aria-label="Close navigation"
            className="flex h-8 w-8 items-center justify-center rounded-lg text-primary-200 hover:bg-primary-700 transition-colors"
          >
            <X className="h-4 w-4" />
          </button>
        ) : (
          <button
            onClick={onToggleCollapse}
            aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
            className="flex h-8 w-8 items-center justify-center rounded-lg text-primary-200 hover:bg-primary-700 transition-colors"
          >
            <ChevronLeft
              className={[
                "h-4 w-4 transition-transform duration-200",
                collapsed ? "rotate-180" : "",
              ].join(" ")}
            />
          </button>
        )}
      </div>

      {/* ── Nav (never overflows with ≤9 items) ── */}
      <nav
        className={[
          "flex-1 overflow-hidden py-3",
          isCollapsed ? "px-3" : "px-2",
        ].join(" ")}
        aria-label="Main navigation"
      >
        <ul className="space-y-0.5 list-none m-0 p-0" role="list">
          {navItems.map((item) => (
            <li key={item.key}>
              <NavItem
                item={item}
                collapsed={isCollapsed}
                onClick={isMobile ? onMobileClose : undefined}
              />
            </li>
          ))}
        </ul>
      </nav>

      {/* ── Footer: user avatar + name ── */}
      <UserFooter collapsed={isCollapsed} onLogout={onLogout} />
    </div>
  );
}

// ── Sidebar (exported) ────────────────────────────────────────────────────────
export interface SidebarProps {
  mobileOpen?: boolean;
  onMobileClose?: () => void;
}

export function Sidebar({ mobileOpen = false, onMobileClose }: SidebarProps) {
  const [collapsed, setCollapsed] = useState(false);

  // Hydrate collapse state after mount to avoid SSR mismatch
  useEffect(() => {
    try {
      const stored = localStorage.getItem("sidebar_collapsed");
      if (stored !== null) setCollapsed(stored === "true");
    } catch {}
  }, []);

  const handleToggle = () => {
    const next = !collapsed;
    setCollapsed(next);
    try {
      localStorage.setItem("sidebar_collapsed", String(next));
    } catch {}
  };

  const handleLogout = () => {
    localStorage.removeItem("auth_token");
    localStorage.removeItem("user");
    localStorage.removeItem("organization_id");
    localStorage.removeItem("orderlane_profile_cache");
    window.location.href = "/login";
  };

  return (
    <Tooltip.Provider>
      {/* ── Desktop: always-visible fixed column ── */}
      <aside className="hidden lg:block h-screen shrink-0">
        <SidebarBody
          collapsed={collapsed}
          onToggleCollapse={handleToggle}
          onLogout={handleLogout}
        />
      </aside>

      {/* ── Mobile: slide-in drawer ── */}
      <div className="lg:hidden">
        {mobileOpen && (
          <div
            className="fixed inset-0 z-40 bg-black/50 backdrop-blur-sm"
            onClick={onMobileClose}
            aria-hidden="true"
          />
        )}
        <aside
          className={[
            "fixed inset-y-0 left-0 z-50 transition-transform duration-200",
            mobileOpen ? "translate-x-0" : "-translate-x-full",
          ].join(" ")}
          role="dialog"
          aria-modal="true"
          aria-label="Navigation"
          aria-hidden={!mobileOpen}
        >
          <SidebarBody
            isMobile
            collapsed={false}
            onMobileClose={onMobileClose}
            onLogout={handleLogout}
          />
        </aside>
      </div>
    </Tooltip.Provider>
  );
}
