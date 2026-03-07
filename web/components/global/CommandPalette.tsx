"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import {
  Search,
  LayoutDashboard,
  ShoppingCart,
  Users,
  Package,
  Truck,
  Archive,
  DollarSign,
  BarChart2,
  Settings,
  Plus,
  ArrowRight,
  X,
} from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────
interface CommandItem {
  id: string;
  group: string;
  label: string;
  description?: string;
  href: string;
  icon: React.ReactNode;
  keywords?: string[];
}

const ALL_COMMANDS: CommandItem[] = [
  // Workspaces
  { id: "dash",       group: "Workspaces", label: "Dashboard",        href: "/dashboard",         icon: <LayoutDashboard size={16} />, keywords: ["home", "overview"] },
  { id: "sales",      group: "Workspaces", label: "Sales",            href: "/sales",              icon: <ShoppingCart size={16} />,   keywords: ["orders", "approval"] },
  { id: "customers",  group: "Workspaces", label: "Customers",        href: "/customers",          icon: <Users size={16} />,          keywords: ["clients", "contacts"] },
  { id: "catalog",    group: "Workspaces", label: "Catalog",          href: "/catalog",            icon: <Package size={16} />,        keywords: ["products", "pricing"] },
  { id: "operations", group: "Workspaces", label: "Operations",       href: "/operations",         icon: <Truck size={16} />,          keywords: ["delivery", "returns"] },
  { id: "inventory",  group: "Workspaces", label: "Inventory",        href: "/inventory",          icon: <Archive size={16} />,        keywords: ["stock", "warehouse"] },
  { id: "finance",    group: "Workspaces", label: "Finance",          href: "/finance",            icon: <DollarSign size={16} />,     keywords: ["collections", "invoices"] },
  { id: "insights",   group: "Workspaces", label: "Insights",         href: "/insights",           icon: <BarChart2 size={16} />,      keywords: ["reports", "analytics"] },
  // Quick pages
  { id: "orders",     group: "Pages",      label: "Orders",           href: "/orders",             icon: <ShoppingCart size={16} /> },
  { id: "approvals",  group: "Pages",      label: "Approvals",        href: "/approvals",          icon: <ShoppingCart size={16} /> },
  { id: "products",   group: "Pages",      label: "Products",         href: "/products",           icon: <Package size={16} /> },
  { id: "delivery",   group: "Pages",      label: "Delivery trips",   href: "/delivery",           icon: <Truck size={16} /> },
  { id: "returns",    group: "Pages",      label: "Returns",          href: "/returns",            icon: <Truck size={16} /> },
  { id: "suppliers",  group: "Pages",      label: "Suppliers",        href: "/suppliers",          icon: <Archive size={16} /> },
  { id: "coll",       group: "Pages",      label: "Collections",      href: "/collections",        icon: <DollarSign size={16} /> },
  { id: "invoices",   group: "Pages",      label: "Sales invoices",   href: "/sales-invoices",     icon: <DollarSign size={16} /> },
  { id: "credits",    group: "Pages",      label: "Credit notes",     href: "/credit-notes",       icon: <DollarSign size={16} /> },
  { id: "settings",   group: "Pages",      label: "Settings",         href: "/settings",           icon: <Settings size={16} /> },
  // Create actions
  { id: "new-order",    group: "Create", label: "New order",          href: "/orders/new",         icon: <Plus size={16} /> },
  { id: "new-customer", group: "Create", label: "New customer",       href: "/customers/new",      icon: <Plus size={16} /> },
  { id: "new-product",  group: "Create", label: "New product",        href: "/products/new",       icon: <Plus size={16} /> },
];

function fuzzyMatch(item: CommandItem, query: string): boolean {
  if (!query) return true;
  const q = query.toLowerCase();
  return (
    item.label.toLowerCase().includes(q) ||
    (item.description?.toLowerCase().includes(q) ?? false) ||
    (item.keywords?.some((k) => k.includes(q)) ?? false)
  );
}

// ── CommandPalette ────────────────────────────────────────────────────────────
interface CommandPaletteProps {
  open: boolean;
  onClose: () => void;
}

export function CommandPalette({ open, onClose }: CommandPaletteProps) {
  const router = useRouter();
  const inputRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLDivElement>(null);
  const [query, setQuery] = useState("");
  const [activeIndex, setActiveIndex] = useState(0);

  const results = ALL_COMMANDS.filter((c) => fuzzyMatch(c, query));

  // Group results
  const grouped: Record<string, CommandItem[]> = {};
  for (const item of results) {
    if (!grouped[item.group]) grouped[item.group] = [];
    grouped[item.group].push(item);
  }

  // Flat list for keyboard nav
  const flat = results;
  const active = flat[activeIndex];

  const navigate = useCallback(
    (item: CommandItem) => {
      router.push(item.href);
      onClose();
      setQuery("");
      setActiveIndex(0);
    },
    [router, onClose]
  );

  useEffect(() => {
    if (open) {
      setTimeout(() => inputRef.current?.focus(), 30);
      setQuery("");
      setActiveIndex(0);
    }
  }, [open]);

  // key handler
  useEffect(() => {
    if (!open) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        onClose();
      } else if (e.key === "ArrowDown") {
        e.preventDefault();
        setActiveIndex((i) => Math.min(i + 1, flat.length - 1));
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        setActiveIndex((i) => Math.max(i - 1, 0));
      } else if (e.key === "Enter") {
        if (active) navigate(active);
      }
    };
    document.addEventListener("keydown", handler);
    return () => document.removeEventListener("keydown", handler);
  }, [open, flat, active, navigate, onClose]);

  // Scroll active item into view
  useEffect(() => {
    const el = listRef.current?.querySelector(`[data-index="${activeIndex}"]`) as HTMLElement | null;
    el?.scrollIntoView({ block: "nearest" });
  }, [activeIndex]);

  if (!open) return null;

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50"
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Panel */}
      <div
        role="dialog"
        aria-label="Command palette"
        className="fixed inset-x-0 top-0 sm:top-[15vh] z-50 flex sm:justify-center px-4 sm:px-0"
      >
        <div className="w-full sm:w-[600px] bg-background rounded-b-2xl sm:rounded-2xl shadow-2xl border border-border overflow-hidden flex flex-col max-h-[90vh] sm:max-h-[70vh]">
          {/* Input */}
          <div className="flex items-center gap-3 px-4 py-3.5 border-b border-border">
            <Search size={18} className="text-text-secondary shrink-0" />
            <input
              ref={inputRef}
              type="text"
              placeholder="Search pages, actions, people..."
              className="flex-1 bg-transparent text-sm text-text-primary placeholder:text-text-secondary outline-none"
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setActiveIndex(0);
              }}
            />
            {query && (
              <button
                onClick={() => { setQuery(""); inputRef.current?.focus(); }}
                className="text-text-secondary hover:text-text-primary"
                aria-label="Clear"
              >
                <X size={15} />
              </button>
            )}
            <kbd className="hidden sm:inline-flex items-center px-1.5 py-0.5 text-[10px] font-medium text-text-secondary bg-background-subtle border border-border rounded">
              ESC
            </kbd>
          </div>

          {/* Results */}
          <div ref={listRef} className="overflow-y-auto flex-1 py-2">
            {results.length === 0 ? (
              <p className="text-sm text-text-secondary text-center py-10">No results for "{query}"</p>
            ) : (
              Object.entries(grouped).map(([group, items]) => (
                <div key={group} className="mb-2">
                  <p className="text-[11px] font-semibold text-text-secondary uppercase tracking-wider px-4 py-1.5">
                    {group}
                  </p>
                  {items.map((item) => {
                    const idx = flat.indexOf(item);
                    const isActive = idx === activeIndex;
                    return (
                      <button
                        key={item.id}
                        data-index={idx}
                        onClick={() => navigate(item)}
                        onMouseEnter={() => setActiveIndex(idx)}
                        className={[
                          "w-full flex items-center gap-3 px-4 py-2.5 text-left transition-colors",
                          isActive ? "bg-primary-50" : "hover:bg-background-subtle",
                        ].join(" ")}
                      >
                        <span className={`shrink-0 ${isActive ? "text-accent" : "text-text-secondary"}`}>
                          {item.icon}
                        </span>
                        <span className="flex-1 min-w-0">
                          <span className="text-sm text-text-primary font-medium">{item.label}</span>
                          {item.description && (
                            <span className="text-xs text-text-secondary ml-2">{item.description}</span>
                          )}
                        </span>
                        {isActive && <ArrowRight size={14} className="text-accent shrink-0" />}
                      </button>
                    );
                  })}
                </div>
              ))
            )}
          </div>

          {/* Footer hint */}
          <div className="border-t border-border px-4 py-2 hidden sm:flex items-center gap-4 text-[11px] text-text-secondary">
            <span><kbd className="font-mono">↑↓</kbd> Navigate</span>
            <span><kbd className="font-mono">↵</kbd> Open</span>
            <span><kbd className="font-mono">Esc</kbd> Close</span>
          </div>
        </div>
      </div>
    </>
  );
}
