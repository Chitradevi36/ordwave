import type { LucideIcon } from "lucide-react";
import {
  ShoppingCart, BookOpen, Truck, Layers, DollarSign,
  Users, BarChart2,
} from "lucide-react";
import type { UserRole } from "@/components/layout/nav.config";

// ── Tab definition ────────────────────────────────────────────────────────────
export interface WorkspaceTab {
  key: string;
  label: string;
  href: string;
  rolesAllowed?: UserRole[];
}

export interface WorkspaceConfig {
  key: string;
  title: string;
  description: string;
  tabs: WorkspaceTab[];
  /** Lucide icon component for the workspace header badge */
  icon: LucideIcon;
  /** Icon container background class */
  iconBg: string;
  /** Icon foreground color class */
  iconColor: string;
}

// ── Per-workspace config ──────────────────────────────────────────────────────
export const WORKSPACE_CONFIGS: Record<string, WorkspaceConfig> = {
  sales: {
    key: "sales",
    title: "Sales",
    description: "Orders, approvals and schemes",
    icon: ShoppingCart,
    iconBg: "bg-blue-50",
    iconColor: "text-blue-600",
    tabs: [
      { key: "orders",    label: "Orders",    href: "/orders" },
      { key: "approvals", label: "Approvals", href: "/approvals",        rolesAllowed: ["owner","admin","manager"] },
      { key: "schemes",   label: "Schemes",   href: "/pricing/schemes",  rolesAllowed: ["owner","admin","manager"] },
    ],
  },

  customers: {
    key: "customers",
    title: "Customers",
    description: "Manage customers, routes and beats",
    icon: Users,
    iconBg: "bg-violet-50",
    iconColor: "text-violet-600",
    tabs: [
      // { key: "customers", label: "Customers", href: "/customers" },
      // { key: "routes",    label: "Routes",    href: "/routes",   rolesAllowed: ["owner","admin","manager"] },
      // { key: "beats",     label: "Beats",     href: "/beats",    rolesAllowed: ["owner","admin","manager"] },
    ],
  },

  catalog: {
    key: "catalog",
    title: "Catalog",
    description: "Products, pricing and promotions",
    icon: BookOpen,
    iconBg: "bg-purple-50",
    iconColor: "text-purple-600",
    tabs: [
      // { key: "products",   label: "Products",   href: "/products" },
      // { key: "pricing",    label: "Pricing",    href: "/pricing",          rolesAllowed: ["owner","admin","manager"] },
      // { key: "promotions", label: "Promotions", href: "/pricing/schemes",  rolesAllowed: ["owner","admin","manager"] },
    ],
  },

  operations: {
    key: "operations",
    title: "Operations",
    description: "Deliveries, returns and transfers",
    icon: Truck,
    iconBg: "bg-orange-50",
    iconColor: "text-orange-600",
    tabs: [
      // { key: "delivery",   label: "Delivery Trips", href: "/delivery" },
      // { key: "returns",    label: "Returns",        href: "/returns" },
      // { key: "transfers",  label: "Transfers",      href: "/inventory/transfers", rolesAllowed: ["owner","admin","manager","warehouse"] },
    ],
  },

  inventory: {
    key: "inventory",
    title: "Inventory",
    description: "Stock, purchases and suppliers",
    icon: Layers,
    iconBg: "bg-amber-50",
    iconColor: "text-amber-600",
    tabs: [
      // { key: "stock",       label: "Stock",       href: "/inventory/stock" },
      // { key: "purchases",   label: "Purchases",   href: "/purchases/invoices" },
      // { key: "suppliers",   label: "Suppliers",   href: "/suppliers" },
      // { key: "adjustments", label: "Adjustments", href: "/inventory/adjustments", rolesAllowed: ["owner","admin","manager","warehouse"] },
    ],
  },

  finance: {
    key: "finance",
    title: "Finance",
    description: "Collections, invoices and credit",
    icon: DollarSign,
    iconBg: "bg-primary-100",
    iconColor: "text-primary",
    tabs: [
      // { key: "collections",      label: "Collections",      href: "/collections" },
      // { key: "sales-invoices",   label: "Sales Invoices",   href: "/sales-invoices" },
      // { key: "credit-notes",     label: "Credit Notes",     href: "/credit-notes" },
      // { key: "advance-payments", label: "Advances",         href: "/advance-payments" },
    ],
  },

  insights: {
    key: "insights",
    title: "Insights",
    description: "Reports and performance analytics",
    icon: BarChart2,
    iconBg: "bg-primary-100",
    iconColor: "text-primary",
    tabs: [
      // { key: "sales",       label: "Sales",       href: "/insights/sales" },
      // { key: "collections", label: "Collections", href: "/insights/collections" },
      // { key: "inventory",   label: "Inventory",   href: "/insights/inventory" },
    ],
  },
};

export function getWorkspaceConfig(key: string): WorkspaceConfig | undefined {
  return WORKSPACE_CONFIGS[key];
}

export function getTabsForRole(
  config: WorkspaceConfig,
  role: UserRole | undefined
): WorkspaceTab[] {
  if (!role || role === "owner" || role === "admin") return config.tabs;
  return config.tabs.filter(
    (tab) => !tab.rolesAllowed || tab.rolesAllowed.includes(role)
  );
}
