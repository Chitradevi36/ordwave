import {
  LayoutDashboard,
  ShoppingCart,
  Users,
  BookOpen,
  Truck,
  Layers,
  DollarSign,
  BarChart2,
  BookMarked,
  type LucideIcon,
} from "lucide-react";

// ── Role type ─────────────────────────────────────────────────────────────────
export type UserRole =
  | "owner"
  | "admin"
  | "manager"
  | "sales_rep"
  | "warehouse_staff"
  | "accountant"
  | "driver"
  | string;

// ── Workspace nav item ────────────────────────────────────────────────────────
export interface WorkspaceNavItem {
  key: string;
  label: string;
  href: string;
  icon: LucideIcon;
  matchers: string[];
  rolesAllowed?: UserRole[];
}

// ── Primary workspace nav ────────────────────────────────────────────────────
export const WORKSPACE_NAV: WorkspaceNavItem[] = [
  {
    key: "dashboard",
    label: "Dashboard",
    href: "/dashboard",
    icon: LayoutDashboard,
    matchers: ["/dashboard"],
  },
  {
    key: "sales",
    label: "Sales",
    href: "/sales",
    icon: ShoppingCart,
    matchers: ["/sales", "/orders", "/approvals", "/schemes", "/pricing/schemes"],
    rolesAllowed: ["owner", "admin", "manager", "sales_rep"],
  },
  {
    key: "customers",
    label: "Customers",
    href: "/customers",
    icon: Users,
    matchers: ["/customers", "/routes", "/beats", "/visits"],
    rolesAllowed: ["owner", "admin", "manager", "sales_rep", "driver"],
  },
  {
    key: "catalog",
    label: "Catalog",
    href: "/catalog",
    icon: BookOpen,
    matchers: ["/catalog", "/products", "/pricing", "/promotions"],
    rolesAllowed: ["owner", "admin", "manager", "sales_rep", "warehouse_staff"],
  },
  {
    key: "operations",
    label: "Operations",
    href: "/operations",
    icon: Truck,
    matchers: ["/operations", "/delivery", "/returns", "/inventory/transfers"],
    rolesAllowed: ["owner", "admin", "manager", "sales_rep", "driver", "warehouse_staff"],
  },
  {
    key: "inventory",
    label: "Inventory",
    href: "/inventory",
    icon: Layers,
    matchers: ["/inventory", "/suppliers", "/purchases"],
    rolesAllowed: ["owner", "admin", "manager", "warehouse_staff"],
  },
  {
    key: "finance",
    label: "Finance",
    href: "/finance",
    icon: DollarSign,
    matchers: ["/finance", "/collections", "/sales-invoices", "/credit-notes", "/advance-payments", "/payments", "/compliance", "/supplier-debit-notes"],
    rolesAllowed: ["owner", "admin", "manager", "accountant"],
  },
  {
    key: "insights",
    label: "Insights",
    href: "/insights",
    icon: BarChart2,
    matchers: ["/insights", "/reports"],
    rolesAllowed: ["owner", "admin", "manager", "accountant"],
  },
  {
    key: "accounting",
    label: "Accounting",
    href: "/accounting",
    icon: BookMarked,
    matchers: ["/accounting"],
    rolesAllowed: ["owner", "admin", "accountant"],
  },
];

// ── Helpers ───────────────────────────────────────────────────────────────────
export function isActiveWorkspace(pathname: string, item: WorkspaceNavItem): boolean {
  return item.matchers.some((m) => pathname === m || pathname.startsWith(m + "/"));
}

export function canAccessWorkspace(role: UserRole | undefined, key: string): boolean {
  const item = WORKSPACE_NAV.find((w) => w.key === key);
  if (!item) return false;
  if (!item.rolesAllowed || item.rolesAllowed.length === 0) return true;
  if (!role) return true;
  return item.rolesAllowed.includes(role);
}

export function filterWorkspacesForRole(role: UserRole | undefined): WorkspaceNavItem[] {
  if (!role || role === "owner" || role === "admin") return WORKSPACE_NAV;
  return WORKSPACE_NAV.filter(
    (item) => !item.rolesAllowed || item.rolesAllowed.length === 0 || item.rolesAllowed.includes(role)
  );
}

// ── Create actions ────────────────────────────────────────────────────────────
export interface CreateAction {
  label: string;
  href: string;
  rolesAllowed?: UserRole[];
}

export const CREATE_ACTIONS: CreateAction[] = [
  { label: "New Order",               href: "/orders/new",               rolesAllowed: ["owner","admin","manager","sales_rep"] },
  { label: "New Customer",            href: "/customers/new",            rolesAllowed: ["owner","admin","manager","sales_rep"] },
  { label: "Record Collection",       href: "/collections/new",          rolesAllowed: ["owner","admin","manager","sales_rep","accountant"] },
  { label: "Create Credit Note",      href: "/credit-notes/new",         rolesAllowed: ["owner","admin","manager","accountant"] },
  { label: "Allocate Payment",        href: "/collections/allocate",     rolesAllowed: ["owner","admin","accountant"] },
  { label: "Purchase Invoice",        href: "/purchases/invoices/new",   rolesAllowed: ["owner","admin","manager","warehouse_staff"] },
  { label: "Receive Purchase",        href: "/purchases/receive",        rolesAllowed: ["owner","admin","manager","warehouse_staff"] },
  { label: "Stock Transfer",          href: "/inventory/transfers/new",  rolesAllowed: ["owner","admin","manager","warehouse_staff"] },
  { label: "Stock Adjustment",        href: "/inventory/adjustments/new",rolesAllowed: ["owner","admin","manager","warehouse_staff"] },
  { label: "New Return",              href: "/returns/new",              rolesAllowed: ["owner","admin","manager","sales_rep","driver"] },
  { label: "Start Trip",              href: "/delivery/new",             rolesAllowed: ["owner","admin","manager","driver"] },
];

export function filterCreateActionsForRole(role: UserRole | undefined): CreateAction[] {
  if (!role || role === "owner" || role === "admin") return CREATE_ACTIONS;
  return CREATE_ACTIONS.filter((a) => !a.rolesAllowed || a.rolesAllowed.includes(role));
}

// Legacy aliases (keeps existing imports working)
export type { WorkspaceNavItem as PrimaryNavItem };
export const PRIMARY_NAV = WORKSPACE_NAV;
export const isActiveRoute = isActiveWorkspace;
export const filterNavForRole = filterWorkspacesForRole;
