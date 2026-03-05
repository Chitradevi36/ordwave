"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import {
  LayoutDashboard,
  Package,
  ShoppingCart,
  Users,
  Truck,
  MapPin,
  BarChart3,
  Settings,
  Building2,
  CheckSquare,
  Boxes,
  FileText,
  Warehouse,
  ArrowLeftRight,
  RotateCcw,
  ReceiptText,
  Receipt,
  Wallet,
  CalendarCheck,
  Tag,
} from "lucide-react";

const navItems = [
  { href: "/dashboard",               label: "Dashboard",        icon: LayoutDashboard },
  { href: "/orders",                  label: "Orders",           icon: ShoppingCart },
  { href: "/products",                label: "Products",         icon: Package },
  { href: "/customers",               label: "Customers",        icon: Building2 },
  { href: "/suppliers",               label: "Suppliers",        icon: Boxes },
  { href: "/purchases/invoices",      label: "Purchases",        icon: FileText },
  { href: "/inventory/stock",         label: "Stock",            icon: Warehouse },
  { href: "/inventory/transfers",     label: "Transfers",        icon: ArrowLeftRight },
  { href: "/returns",                 label: "Returns",          icon: RotateCcw },
  { href: "/credit-notes",           label: "Credit Notes",     icon: ReceiptText },
  { href: "/sales-invoices",          label: "Sales Invoices",   icon: Receipt },
  { href: "/collections",             label: "Collections",     icon: Wallet },
  { href: "/routes",                  label: "Routes",           icon: MapPin },
  { href: "/beats",                    label: "Beats",             icon: CalendarCheck },
  { href: "/delivery",                 label: "Delivery",    icon: Truck },
  { href: "/pricing/schemes",          label: "Schemes",     icon: Tag },
  { href: "/approvals/credit-limits", label: "Approvals",   icon: CheckSquare },
  { href: "/reports",                 label: "Reports",     icon: BarChart3 },
  { href: "/settings",                label: "Settings",    icon: Settings },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="flex h-full w-64 flex-col bg-primary text-white">
      {/* Logo */}
      <div className="flex items-center gap-3 px-6 py-5 border-b border-primary-700">
        <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-accent">
          <span className="text-sm font-bold text-primary">OD</span>
        </div>
        <div>
          <p className="text-sm font-bold leading-tight">OmniDist OMS</p>
          <p className="text-xs text-primary-300 opacity-75">Distribution Platform</p>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto px-3 py-4">
        <ul className="space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = pathname === item.href || pathname?.startsWith(item.href + "/");
            return (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className={cn(
                    "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium transition-colors",
                    isActive
                      ? "bg-accent/20 text-accent"
                      : "text-primary-200 hover:bg-primary-700 hover:text-white"
                  )}
                >
                  <Icon className="h-4 w-4 shrink-0" />
                  {item.label}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      {/* Footer */}
      <div className="px-4 py-4 border-t border-primary-700">
        <p className="text-xs text-primary-300 opacity-60">v1.0.0 · OmniDist OMS</p>
      </div>
    </aside>
  );
}
