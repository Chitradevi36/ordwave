"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { useRouter } from "next/navigation";
import {
  Bell, Search, User, LogOut, Building2, GitBranch, ChevronDown, Check,
  Plus, PackageSearch, CheckSquare, X, ShoppingCart,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { apiClient } from "@/lib/api/client";

//  Types 
interface DropdownOption { value: string; label: string; sub?: string; }

interface Notification {
  id: string;
  type: "order_approved" | "credit_blocked" | "low_stock";
  message: string;
  time: string;
  read: boolean;
}

// Quick-nav items for command palette
const QUICK_LINKS = [
  { label: "New Order",  href: "/orders/new",            icon: ShoppingCart },
  { label: "Customers",  href: "/customers",             icon: Building2 },
  { label: "Stock",      href: "/inventory/stock",       icon: PackageSearch },
  { label: "Approvals",  href: "/approvals/credit-limits", icon: CheckSquare },
];

// Demo notifications  replace with real API hook when available
const DEMO_NOTIFICATIONS: Notification[] = [
  { id: "1", type: "order_approved", message: "Order ORD-1092 has been approved", time: "2m ago", read: false },
  { id: "2", type: "credit_blocked", message: "Fresh Mart credit limit exceeded", time: "15m ago", read: false },
  { id: "3", type: "low_stock", message: "Product SKU-001 below minimum threshold", time: "1h ago", read: true },
];

//  SwitcherDropdown 
function SwitcherDropdown({
  icon: Icon, label, options, value, onChange, loading, allLabel,
}: {
  icon: React.ElementType; label: string; options: DropdownOption[];
  value: string; onChange: (v: string) => void; loading?: boolean; allLabel?: string;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const h = (e: MouseEvent) => { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); };
    document.addEventListener("mousedown", h);
    return () => document.removeEventListener("mousedown", h);
  }, []);
  const selected = allLabel && value === "" ? allLabel : (options.find(o => o.value === value)?.label ?? label);
  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen(p => !p)}
        className="flex items-center gap-1.5 h-8 px-2.5 rounded-lg border border-border bg-background hover:bg-background-subtle transition-colors text-sm text-text-primary max-w-[200px]"
      >
        <Icon className="h-3.5 w-3.5 text-text-secondary shrink-0" />
        <span className="truncate font-medium">{loading ? "" : selected}</span>
        <ChevronDown className="h-3 w-3 text-text-secondary shrink-0 ml-auto" />
      </button>
      {open && (
        <div className="absolute left-0 top-full mt-1.5 min-w-[200px] max-w-[260px] rounded-lg border border-border bg-background shadow-lg z-50 py-1">
          {allLabel !== undefined && (
            <button onClick={() => { onChange(""); setOpen(false); }} className="flex w-full items-center justify-between px-3 py-2 text-sm hover:bg-background-subtle transition-colors text-text-secondary">
              <span>{allLabel}</span>
              {value === "" && <Check className="h-3.5 w-3.5 text-accent" />}
            </button>
          )}
          {allLabel !== undefined && options.length > 0 && <div className="h-px bg-border mx-2 my-1" />}
          {options.map(opt => (
            <button key={opt.value} onClick={() => { onChange(opt.value); setOpen(false); }} className="flex w-full items-center justify-between gap-2 px-3 py-2 text-sm hover:bg-background-subtle transition-colors">
              <div className="min-w-0">
                <p className="truncate text-text-primary font-medium">{opt.label}</p>
                {opt.sub && <p className="truncate text-xs text-text-secondary">{opt.sub}</p>}
              </div>
              {value === opt.value && <Check className="h-3.5 w-3.5 text-accent shrink-0" />}
            </button>
          ))}
          {options.length === 0 && !loading && <p className="px-3 py-2 text-xs text-text-secondary">No items found</p>}
        </div>
      )}
    </div>
  );
}

//  TopBar 
export interface TopBarProps {
  title?: string;
  mobileMenuButton?: React.ReactNode;
}

export function TopBar({ title, mobileMenuButton }: TopBarProps) {
  const [showUserMenu, setShowUserMenu]         = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showCommandPalette, setShowCommandPalette] = useState(false);
  const [searchQuery, setSearchQuery]           = useState("");
  const [user, setUser]                         = useState<{ first_name?: string; last_name?: string; email?: string } | null>(null);
  const [notifications, setNotifications]       = useState<Notification[]>(DEMO_NOTIFICATIONS);

  const menuRef   = useRef<HTMLDivElement>(null);
  const notifRef  = useRef<HTMLDivElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const router    = useRouter();

  const { orgId, branchId, organizations, branches, orgsLoading, branchesLoading, switchOrg, switchBranch } = useOrgBranch();

  const unreadCount = notifications.filter(n => !n.read).length;

  // Load user from localStorage
  useEffect(() => {
    try { const d = localStorage.getItem("user"); if (d) setUser(JSON.parse(d)); } catch {}
  }, []);

  // Close dropdowns on outside click
  useEffect(() => {
    const h = (e: MouseEvent) => {
      if (menuRef.current  && !menuRef.current.contains(e.target  as Node)) setShowUserMenu(false);
      if (notifRef.current && !notifRef.current.contains(e.target as Node)) setShowNotifications(false);
    };
    document.addEventListener("mousedown", h);
    return () => document.removeEventListener("mousedown", h);
  }, []);

  // Cmd+K / Ctrl+K shortcut
  useEffect(() => {
    const h = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        setShowCommandPalette(p => !p);
      }
      if (e.key === "Escape") {
        setShowCommandPalette(false);
      }
    };
    document.addEventListener("keydown", h);
    return () => document.removeEventListener("keydown", h);
  }, []);

  // Focus search when palette opens
  useEffect(() => {
    if (showCommandPalette) { setTimeout(() => searchRef.current?.focus(), 50); }
    else { setSearchQuery(""); }
  }, [showCommandPalette]);

  const handleLogout = useCallback(async () => {
    try {
      const token = localStorage.getItem("auth_token");
      if (token) {
        await apiClient.delete("/api/v1/auth/logout");
      }
    } catch {/* ignore */} finally {
      localStorage.removeItem("auth_token");
      localStorage.removeItem("user");
      localStorage.removeItem("organization_id");
      router.push("/login");
    }
  }, [router]);

  const markAllRead = () => setNotifications(n => n.map(item => ({ ...item, read: true })));

  const filteredLinks = QUICK_LINKS.filter(l =>
    searchQuery === "" || l.label.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const orgOptions: DropdownOption[] = organizations.map(o => ({ value: String(o.id), label: o.name, sub: o.slug }));
  const branchOptions: DropdownOption[] = branches.map(b => ({ value: String(b.id), label: b.name, sub: [b.code, b.city].filter(Boolean).join("  ") }));

  return (
    <>
      <header className="flex h-16 shrink-0 items-center gap-3 border-b border-border bg-background px-4 md:px-6">
        {/* Mobile hamburger */}
        {mobileMenuButton}

        {/* Page title */}
        {title && <h1 className="text-lg font-semibold text-text-primary shrink-0 mr-1 hidden sm:block">{title}</h1>}

        {/* Org / Branch switchers */}
        <div className="hidden sm:flex items-center gap-2">
          <SwitcherDropdown icon={Building2} label="Organization" options={orgOptions} value={orgId} onChange={switchOrg} loading={orgsLoading} />
          <span className="text-border select-none text-sm">/</span>
          <SwitcherDropdown icon={GitBranch} label="All Branches" options={branchOptions} value={branchId} onChange={switchBranch} loading={branchesLoading} allLabel="All Branches" />
        </div>

        {/* Right actions */}
        <div className="ml-auto flex items-center gap-2">
          {/* Command palette trigger */}
          <button
            onClick={() => setShowCommandPalette(true)}
            aria-label="Open command palette (Ctrl+K)"
            className="flex items-center gap-2 h-9 px-3 rounded-lg border border-border hover:bg-background-subtle transition-colors text-sm text-text-secondary"
          >
            <Search className="h-4 w-4" />
            <span className="hidden md:inline text-xs">K</span>
          </button>

          {/* Notifications */}
          <div className="relative" ref={notifRef}>
            <button
              onClick={() => setShowNotifications(p => !p)}
              aria-label={`Notifications${unreadCount > 0 ? `, ${unreadCount} unread` : ""}`}
              className="relative flex h-9 w-9 items-center justify-center rounded-lg border border-border hover:bg-background-subtle transition-colors"
            >
              <Bell className="h-4 w-4 text-text-secondary" />
              {unreadCount > 0 && (
                <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-danger" />
              )}
            </button>
            {showNotifications && (
              <div className="absolute right-0 top-full mt-1.5 w-80 rounded-lg border border-border bg-background shadow-lg z-50">
                <div className="flex items-center justify-between px-4 py-3 border-b border-border">
                  <p className="text-sm font-semibold text-text-primary">Notifications</p>
                  {unreadCount > 0 && (
                    <button onClick={markAllRead} className="text-xs text-accent hover:underline">Mark all read</button>
                  )}
                </div>
                <div className="max-h-72 overflow-y-auto divide-y divide-border">
                  {notifications.map(n => (
                    <div key={n.id} className={`flex items-start gap-3 px-4 py-3 ${n.read ? "" : "bg-accent/5"}`}>
                      <div className={`mt-1 h-2 w-2 shrink-0 rounded-full ${n.read ? "bg-border" : "bg-accent"}`} />
                      <div className="min-w-0 flex-1">
                        <p className="text-sm text-text-primary">{n.message}</p>
                        <p className="text-xs text-text-secondary mt-0.5">{n.time}</p>
                      </div>
                    </div>
                  ))}
                  {notifications.length === 0 && (
                    <p className="px-4 py-8 text-sm text-text-secondary text-center">No notifications</p>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* User menu */}
          <div className="relative" ref={menuRef}>
            <button
              onClick={() => setShowUserMenu(!showUserMenu)}
              aria-label="User menu"
              className="flex h-9 w-9 items-center justify-center rounded-full bg-primary text-white hover:bg-primary-700 transition-colors"
            >
              <User className="h-4 w-4" />
            </button>
            {showUserMenu && (
              <div className="absolute right-0 mt-2 w-64 rounded-lg border border-border bg-background shadow-lg z-50">
                <div className="px-4 py-3 border-b border-border">
                  <p className="text-sm font-medium text-text-primary">{user?.first_name} {user?.last_name}</p>
                  <p className="text-xs text-text-secondary mt-0.5">{user?.email}</p>
                </div>
                <div className="py-1">
                  <button
                    onClick={handleLogout}
                    className="w-full flex items-center gap-3 px-4 py-2 text-sm text-danger hover:bg-background-subtle transition-colors"
                  >
                    <LogOut className="h-4 w-4" />
                    Logout
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </header>

      {/* Command Palette modal */}
      {showCommandPalette && (
        <div className="fixed inset-0 z-[100] flex items-start justify-center pt-20 px-4" role="dialog" aria-modal="true" aria-label="Command palette">
          {/* Backdrop */}
          <div className="absolute inset-0 bg-black/40" onClick={() => setShowCommandPalette(false)} />
          {/* Panel */}
          <div className="relative w-full max-w-lg rounded-xl border border-border bg-background shadow-2xl overflow-hidden">
            {/* Search input */}
            <div className="flex items-center gap-3 px-4 py-3 border-b border-border">
              <Search className="h-4 w-4 text-text-secondary shrink-0" />
              <input
                ref={searchRef}
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                placeholder="Search or jump to"
                className="flex-1 bg-transparent text-sm text-text-primary placeholder:text-text-secondary outline-none"
              />
              <button onClick={() => setShowCommandPalette(false)} className="text-text-secondary hover:text-text-primary">
                <X className="h-4 w-4" />
              </button>
            </div>
            {/* Quick links */}
            <div className="py-2">
              <p className="px-4 py-1 text-[10px] font-semibold uppercase tracking-wider text-text-secondary">Quick Navigation</p>
              {filteredLinks.map(link => {
                const Icon = link.icon;
                return (
                  <button
                    key={link.href}
                    onClick={() => { router.push(link.href); setShowCommandPalette(false); }}
                    className="flex w-full items-center gap-3 px-4 py-2.5 text-sm hover:bg-background-subtle transition-colors"
                  >
                    <span className="flex h-7 w-7 items-center justify-center rounded-md bg-background-subtle">
                      <Icon className="h-4 w-4 text-text-secondary" />
                    </span>
                    <span className="text-text-primary font-medium">{link.label}</span>
                  </button>
                );
              })}
              {filteredLinks.length === 0 && (
                <p className="px-4 py-4 text-sm text-text-secondary text-center">No results</p>
              )}
            </div>
            <div className="border-t border-border px-4 py-2 flex items-center gap-3 text-xs text-text-secondary">
              <span><kbd className="font-mono"></kbd> navigate</span>
              <span><kbd className="font-mono"></kbd> select</span>
              <span><kbd className="font-mono">Esc</kbd> close</span>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
