"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import { Bell, Search, User, LogOut, Building2, GitBranch, ChevronDown, Check } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";

export interface TopBarProps {
  title?: string;
}

// ─── Tiny dropdown primitive ──────────────────────────────────────────────────
interface DropdownOption { value: string; label: string; sub?: string; }

function SwitcherDropdown({
  icon: Icon,
  label,
  options,
  value,
  onChange,
  loading,
  allLabel,
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
    function handleClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const selected =
    allLabel && value === ""
      ? allLabel
      : (options.find((o) => o.value === value)?.label ?? label);

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

          {allLabel !== undefined && options.length > 0 && (
            <div className="h-px bg-border mx-2 my-1" />
          )}

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

          {options.length === 0 && !loading && (
            <p className="px-3 py-2 text-xs text-text-secondary">No items found</p>
          )}
        </div>
      )}
    </div>
  );
}

// ─── TopBar ──────────────────────────────────────────────────────────────────
export function TopBar({ title }: TopBarProps) {
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [user, setUser] = useState<any>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const router  = useRouter();

  const {
    orgId,
    branchId,
    organizations,
    branches,
    orgsLoading,
    branchesLoading,
    switchOrg,
    switchBranch,
  } = useOrgBranch();

  useEffect(() => {
    const userData = localStorage.getItem("user");
    if (userData) setUser(JSON.parse(userData));

    function handleClickOutside(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setShowUserMenu(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleLogout = async () => {
    try {
      const token = localStorage.getItem("auth_token");
      if (token) {
        await fetch("http://localhost:3001/api/v1/auth/logout", {
          method: "DELETE",
          headers: {
            Authorization:  `Bearer ${token}`,
            "Content-Type": "application/json",
          },
        });
      }
    } catch (error) {
      console.error("Logout error:", error);
    } finally {
      localStorage.removeItem("auth_token");
      localStorage.removeItem("user");
      localStorage.removeItem("organization_id");
      router.push("/login");
    }
  };

  const orgOptions: DropdownOption[] = organizations.map((o) => ({
    value: String(o.id),
    label: o.name,
    sub:   o.slug,
  }));

  const branchOptions: DropdownOption[] = branches.map((b) => ({
    value: String(b.id),
    label: b.name,
    sub:   [b.code, b.city].filter(Boolean).join(" · "),
  }));

  return (
    <header className="flex h-16 items-center gap-3 border-b border-border bg-background px-6">
      {/* Page title */}
      {title && (
        <h1 className="text-lg font-semibold text-text-primary shrink-0 mr-1">{title}</h1>
      )}

      {/* ── Org / Branch switchers ─────────────────────────────────────── */}
      <div className="flex items-center gap-2">
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

      {/* ── Right actions ─────────────────────────────────────────────── */}
      <div className="ml-auto flex items-center gap-3">
        <button className="flex h-9 w-9 items-center justify-center rounded-lg border border-border hover:bg-background-subtle transition-colors">
          <Search className="h-4 w-4 text-text-secondary" />
        </button>
        <button className="relative flex h-9 w-9 items-center justify-center rounded-lg border border-border hover:bg-background-subtle transition-colors">
          <Bell className="h-4 w-4 text-text-secondary" />
          <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-danger" />
        </button>

        {/* User Menu */}
        <div className="relative" ref={menuRef}>
          <button
            onClick={() => setShowUserMenu(!showUserMenu)}
            className="flex h-9 w-9 items-center justify-center rounded-full bg-primary text-white hover:bg-primary-700 transition-colors"
          >
            <User className="h-4 w-4" />
          </button>

          {showUserMenu && (
            <div className="absolute right-0 mt-2 w-64 rounded-lg border border-border bg-background shadow-lg z-50">
              <div className="px-4 py-3 border-b border-border">
                <p className="text-sm font-medium text-text-primary">
                  {user?.first_name} {user?.last_name}
                </p>
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
  );
}
