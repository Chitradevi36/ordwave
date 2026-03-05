import {
  LayoutDashboard,
  ShoppingCart,
  Users,
  Package,
  Wallet,
  Layers,
  BarChart2,
  Settings,
  Truck,
  type LucideIcon,
} from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────
export type UserRole =
  | "owner"
  | "admin"
  | "manager"
  | "sales_rep"
  | "accounts"
  | string;

export interface PrimaryNavItem {
  key: string;
  label: string;
  /** Where clicking the nav item navigates to */
  href: string;
  icon: LucideIcon;
  /**
   * All path prefixes that should highlight this nav item as active.
   * E.g. Orders highlights for /orders, /approvals, /schemes
   */
  matchPaths: string[];
  /**
   * If defined, item is only shown to these roles.
   * If undefined (or empty), item is visible to everyone.
   */
  rolesAllowed?: UserRole[];
}

// ── Primary nav (max 8 items, no scroll on 768px+) ───────────────────────────
//
// Secondary nav lives inside each module page as header tabs:
//
//  Orders         → tabs: Sales Orders | Approvals | Schemes
//  Inventory      → tabs: Stock | Purchases | Suppliers | Transfers | Returns
//  Collections    → tabs: Payments | Sales Invoices | Credit Notes | Advances
//  Field Ops      → tabs: Delivery | Routes | Beats       (under Settings or Delivery page)
//
export const PRIMARY_NAV: PrimaryNavItem[] = [
  {
    key: "dashboard",
    label: "Dashboard",
    href: "/dashboard",
    icon: LayoutDashboard,
    matchPaths: ["/dashboard"],
  },
  {
    key: "orders",
    label: "Orders",
    href: "/orders",
    icon: ShoppingCart,
    matchPaths: ["/orders", "/approvals", "/schemes"],
    rolesAllowed: ["owner", "admin", "manager", "sales_rep"],
  },
  {
    key: "customers",
    label: "Customers",
    href: "/customers",
    icon: Users,
    matchPaths: ["/customers"],
    rolesAllowed: ["owner", "admin", "manager", "sales_rep"],
  },
  {
    key: "products",
    label: "Products",
    href: "/products",
    icon: Package,
    matchPaths: ["/products"],
    rolesAllowed: ["owner", "admin", "manager", "sales_rep"],
  },
  {
    key: "collections",
    label: "Collections",
    href: "/collections",
    icon: Wallet,
    matchPaths: ["/collections", "/sales-invoices", "/credit-notes", "/payments", "/invoices"],
    rolesAllowed: ["owner", "admin", "manager", "accounts"],
  },
  {
    key: "inventory",
    label: "Inventory",
    href: "/inventory/stock",
    icon: Layers,
    matchPaths: ["/inventory", "/suppliers", "/purchases", "/returns"],
    rolesAllowed: ["owner", "admin", "manager", "sales_rep"],
  },
  {
    key: "delivery",
    label: "Delivery",
    href: "/delivery",
    icon: Truck,
    matchPaths: ["/delivery", "/beats", "/routes"],
    rolesAllowed: ["owner", "admin", "manager"],
  },
  {
    key: "reports",
    label: "Reports",
    href: "/insights",
    icon: BarChart2,
    matchPaths: ["/insights", "/reports"],
  },
  {
    key: "settings",
    label: "Settings",
    href: "/settings",
    icon: Settings,
    matchPaths: ["/settings"],
  },
];

// ── Route matching helper ─────────────────────────────────────────────────────
export function isActiveRoute(
  pathname: string,
  item: PrimaryNavItem
): boolean {
  return item.matchPaths.some(
    (p) => pathname === p || pathname.startsWith(p + "/")
  );
}

// ── Role-based filter ─────────────────────────────────────────────────────────
export function filterNavForRole(role: UserRole | undefined): PrimaryNavItem[] {
  if (!role || role === "owner" || role === "admin") return PRIMARY_NAV;
  return PRIMARY_NAV.filter(
    (item) =>
      !item.rolesAllowed ||
      item.rolesAllowed.length === 0 ||
      item.rolesAllowed.includes(role)
  );
}
