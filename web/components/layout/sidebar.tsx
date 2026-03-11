"use client";

import { useState, useEffect } from "react";
import { usePathname } from "next/navigation";
import { ChevronLeft, ChevronRight, X, LogOut } from "lucide-react";
import * as Tooltip from "@radix-ui/react-tooltip";
import Link from "next/link";

import {
  GROUPED_NAV,
  filterGroupedNavForRole,
  isActiveGroup,
  isActiveChild,
  type NavGroup,
  type NavChild,
} from "./nav.config";
import { useCurrentRole } from "@/lib/hooks/use-current-role";
import { useApprovals } from "@/lib/api/hooks/useApprovals";
import { ANALYTICS_EVENTS, trackClick } from "@/lib/analytics";

// ── NavChild item ─────────────────────────────────────────────────────────────
function ChildItem({
  child,
  onClick,
  badgeCount,
}: {
  child: NavChild;
  onClick?: () => void;
  badgeCount?: number;
}) {
  const pathname = usePathname();
  const active = isActiveChild(pathname, child);

  if (child.comingSoon) {
    return (
      <li>
        <span
          className="flex items-center gap-2 rounded-md px-3 py-2 text-sm cursor-not-allowed opacity-50 select-none"
          aria-disabled="true"
        >
          <span className="w-1 h-1 rounded-full shrink-0 bg-primary-500" aria-hidden="true" />
          <span className="flex-1 truncate leading-none text-primary-400">{child.label}</span>
          <span className="ml-auto rounded px-1.5 py-0.5 text-[9px] font-semibold uppercase tracking-wide bg-primary-700 text-primary-300">
            Soon
          </span>
        </span>
      </li>
    );
  }

  return (
    <li>
      <Link
        href={child.href}
        onClick={() => {
          trackClick(ANALYTICS_EVENTS.SIDEBAR_NAV_CLICKED, {
            element_label: child.label,
            nav_item:      child.key,
            page:          child.href,
          });
          onClick?.();
        }}
        aria-current={active ? "page" : undefined}
        className={[
          "flex items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent",
          active
            ? "bg-accent/15 text-accent font-medium"
            : "text-primary-300 hover:bg-white/8 hover:text-white",
        ].join(" ")}
      >
        <span
          className={[
            "w-1 h-1 rounded-full shrink-0",
            active ? "bg-accent" : "bg-primary-500",
          ].join(" ")}
          aria-hidden="true"
        />
        <span className="flex-1 truncate leading-none">{child.label}</span>
        {badgeCount != null && badgeCount > 0 && (
          <span className="flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-bold text-white">
            {badgeCount > 99 ? "99+" : badgeCount}
          </span>
        )}
      </Link>
    </li>
  );
}

// ── NavGroup item ─────────────────────────────────────────────────────────────
function GroupItem({
  group,
  collapsed,
  open,
  onToggle,
  onClick,
  badgeCount,
}: {
  group: NavGroup;
  collapsed: boolean;
  open: boolean;
  onToggle: () => void;
  onClick?: () => void;
  badgeCount?: number;
}) {
  const pathname = usePathname();
  const active = isActiveGroup(pathname, group);
  const hasChildren = !!(group.children && group.children.length > 0);

  const Icon = group.icon;

  // ── Collapsed (icon-only) mode ──
  if (collapsed) {
    const trigger = (
      <Link
        href={group.href ?? group.children?.[0]?.href ?? "#"}
        onClick={onClick}
        aria-current={active ? "page" : undefined}
        className={[
          "group relative flex h-10 w-10 items-center justify-center rounded-lg mx-auto transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent",
          active ? "bg-accent/15 text-accent" : "text-primary-200 hover:bg-white/8 hover:text-white",
        ].join(" ")}
      >
        {active && (
          <span className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-6 rounded-r bg-accent" aria-hidden="true" />
        )}
        <Icon className={["h-5 w-5 shrink-0 transition-colors", active ? "text-accent" : "text-primary-300 group-hover:text-white"].join(" ")} aria-hidden="true" />
        {badgeCount != null && badgeCount > 0 && (
          <span className="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[9px] font-bold text-white">
            {badgeCount > 99 ? "99+" : badgeCount}
          </span>
        )}
      </Link>
    );
    return (
      <li>
        <Tooltip.Root delayDuration={150}>
          <Tooltip.Trigger asChild>{trigger}</Tooltip.Trigger>
          <Tooltip.Portal>
            <Tooltip.Content side="right" sideOffset={10} className="z-[60] rounded-md bg-gray-900 px-2.5 py-1.5 text-xs font-medium text-white shadow-lg">
              {group.label}
              <Tooltip.Arrow className="fill-gray-900" />
            </Tooltip.Content>
          </Tooltip.Portal>
        </Tooltip.Root>
      </li>
    );
  }

  // ── Expanded mode — direct link (no children) ──
  if (!hasChildren) {
    return (
      <li>
        <Link
          href={group.href ?? "#"}
          onClick={onClick}
          aria-current={active ? "page" : undefined}
          className={[
            "group relative flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent",
            active ? "bg-accent/15 text-accent" : "text-primary-200 hover:bg-white/8 hover:text-white",
          ].join(" ")}
        >
          {active && <span className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-6 rounded-r bg-accent" aria-hidden="true" />}
          <Icon className={["h-[18px] w-[18px] shrink-0 transition-colors", active ? "text-accent" : "text-primary-300 group-hover:text-white"].join(" ")} aria-hidden="true" />
          <span className="flex-1 truncate leading-none">{group.label}</span>
          {badgeCount != null && badgeCount > 0 && (
            <span className="ml-auto flex h-5 min-w-5 items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-bold text-white">
              {badgeCount > 99 ? "99+" : badgeCount}
            </span>
          )}
        </Link>
      </li>
    );
  }

  // ── Expanded mode — accordion group ──
  return (
    <li>
      <button
        onClick={onToggle}
        aria-expanded={open}
        className={[
          "group relative flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent",
          active ? "text-white" : "text-primary-200 hover:bg-white/8 hover:text-white",
        ].join(" ")}
      >
        {active && <span className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-6 rounded-r bg-accent" aria-hidden="true" />}
        <Icon className={["h-[18px] w-[18px] shrink-0 transition-colors", active ? "text-white" : "text-primary-300 group-hover:text-white"].join(" ")} aria-hidden="true" />
        <span className="flex-1 truncate leading-none text-left">{group.label}</span>
        {badgeCount != null && badgeCount > 0 && !open && (
          <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-bold text-white">
            {badgeCount > 99 ? "99+" : badgeCount}
          </span>
        )}
        <ChevronRight
          className={["h-3.5 w-3.5 shrink-0 text-primary-400 transition-transform duration-200", open ? "rotate-90" : ""].join(" ")}
          aria-hidden="true"
        />
      </button>

      {open && (
        <ul className="mt-0.5 ml-3 pl-3 border-l border-primary-700 space-y-0.5 list-none" role="list">
          {group.children!.map((child) => (
            <ChildItem
              key={child.key}
              child={child}
              onClick={onClick}
              badgeCount={child.key === "approvals" ? badgeCount : undefined}
            />
          ))}
        </ul>
      )}
    </li>
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
            <Tooltip.Content side="right" sideOffset={10} className="z-[60] rounded-md bg-gray-900 px-2.5 py-1.5 text-xs text-white shadow-lg">
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
            <p className="truncate text-xs font-semibold text-white leading-tight">{fullName}</p>
            <p className="truncate text-[11px] text-primary-300 opacity-70 leading-tight mt-0.5">{user?.email ?? ""}</p>
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
  const pathname = usePathname();
  const role = useCurrentRole();
  const groups = filterGroupedNavForRole(role);
  const isCollapsed = collapsed && !isMobile;

  // Single accordion: track which group key is open
  const activeGroupKey = groups.find((g) => isActiveGroup(pathname, g))?.key ?? null;
  const [openKey, setOpenKey] = useState<string | null>(activeGroupKey);

  // When the route changes, ensure the active group is open
  useEffect(() => {
    if (activeGroupKey) setOpenKey(activeGroupKey);
  }, [activeGroupKey]);

  // Approvals badge — only for manager/owner/admin roles
  const isApprover = role != null && ["manager", "owner", "admin"].includes(role);
  const { data: approvalsData } = useApprovals({ enabled: isApprover });
  const approvalsBadge = isApprover ? (approvalsData?.total_count ?? 0) : 0;

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
            OrdWave
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

      {/* ── Nav ── */}
      <nav
        className={[
          "flex-1 overflow-y-auto overflow-x-hidden py-3 scrollbar-none",
          isCollapsed ? "px-3" : "px-2",
        ].join(" ")}
        aria-label="Main navigation"
      >
        <ul className="space-y-0.5 list-none m-0 p-0" role="list">
          {groups.map((group) => (
            <GroupItem
              key={group.key}
              group={group}
              collapsed={isCollapsed}
              open={openKey === group.key}
              onToggle={() => setOpenKey((k) => (k === group.key ? null : group.key))}
              onClick={isMobile ? onMobileClose : undefined}
              badgeCount={group.key === "sales" ? approvalsBadge : undefined}
            />
          ))}
        </ul>
      </nav>

      {/* ── Footer: user avatar + name ── */}
      {/* <UserFooter collapsed={isCollapsed} onLogout={onLogout} /> */}
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
    document.cookie = "auth_present=; path=/; max-age=0; SameSite=Lax";
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