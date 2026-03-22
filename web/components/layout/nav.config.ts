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
  Settings,
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
    matchers: ["/finance", "/collections", "/bank-reconciliation", "/sales-invoices", "/credit-notes", "/advance-payments", "/payments", "/compliance", "/supplier-debit-notes"],
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

// ── Grouped sidebar nav ───────────────────────────────────────────────────────
export interface NavChild {
  key: string;
  label: string;
  href: string;
  matchers: string[];
  rolesAllowed?: UserRole[];
  comingSoon?: boolean;
  badgeKey?: string;
}

export interface NavGroup {
  key: string;
  label: string;
  icon: LucideIcon;
  /** Set href to make the group itself a direct link (no accordion). */
  href?: string;
  matchers: string[];
  rolesAllowed?: UserRole[];
  children?: NavChild[];
}

export const GROUPED_NAV: NavGroup[] = [
  {
    key: "home",
    label: "Home",
    href: "/dashboard",
    icon: LayoutDashboard,
    matchers: ["/dashboard"],
  },

  {
    key: "sales",
    label: "Sales",
    icon: ShoppingCart,
    matchers: ["/orders", "/products/price-lists", "/pricing/schemes"],
    rolesAllowed: ["owner", "admin", "manager", "sales_rep"],
    children: [
      {
        key: "orders",
        label: "Orders",
        href: "/orders",
        matchers: ["/orders"],
      },
      // {
      //   key: "approvals",
      //   label: "Approvals",
      //   href: "/approvals",
      //   matchers: ["/approvals"],
      //   rolesAllowed: ["owner", "admin", "manager"],
      //   badgeKey: "pendingApprovals",
      // },
      {
        key: "price-lists",
        label: "Price Lists",
        href: "/products/price-lists",
        matchers: ["/products/price-lists"],
        rolesAllowed: ["owner", "admin", "manager"],
      },
      {
        key: "schemes",
        label: "Schemes",
        href: "/pricing/schemes",
        matchers: ["/pricing/schemes"],
        rolesAllowed: ["owner", "admin", "manager"],
      },
    ],
  },

  {
    key: "retailers",
    label: "Retailers",
    icon: Users,
    matchers: ["/customers", "/routes", "/beats"],
    rolesAllowed: ["owner", "admin", "manager", "sales_rep", "driver"],
    children: [
      {
        key: "retailers-list",
        label: "Retailers",
        href: "/customers",
        matchers: ["/customers"],
      },
      {
        key: "routes",
        label: "Routes",
        href: "/routes",
        matchers: ["/routes"],
        rolesAllowed: ["owner", "admin", "manager"],
      },
      {
        key: "beat-plans",
        label: "Beat Plans",
        href: "/beats",
        matchers: ["/beats"],
        rolesAllowed: ["owner", "admin", "manager"],
      },
    ],
  },

  {
    key: "inventory",
    label: "Inventory",
    icon: Layers,
    matchers: ["/inventory", "/inventory/transfers", "/purchases", "/suppliers"],
    rolesAllowed: ["owner", "admin", "manager", "warehouse_staff"],
    children: [
      {
        key: "stock-position",
        label: "Stock Position",
        href: "/inventory/stock",
        matchers: ["/inventory/stock"],
      },
      {
        key: "stock-transfers",
        label: "Transfers",
        href: "/inventory/transfers",
        matchers: ["/inventory/transfers"],
      },
      {
        key: "purchases",
        label: "Purchases",
        href: "/purchases/invoices",
        matchers: ["/purchases"],
      },
      {
        key: "suppliers",
        label: "Suppliers",
        href: "/suppliers",
        matchers: ["/suppliers"],
        rolesAllowed: ["owner", "admin", "manager"],
      },
    ],
  },

  {
    key: "dispatch",
    label: "Dispatch",
    icon: Truck,
    matchers: ["/delivery", "/operations", "/returns", "/delivery/exceptions"],
    rolesAllowed: ["owner", "admin", "manager", "driver", "warehouse_staff"],
    children: [
      {
        key: "trips",
        label: "Trips",
        href: "/delivery",
        matchers: ["/delivery"],
        badgeKey: "activeTrips",
      },
      {
        key: "operations",
        label: "Operations",
        href: "/operations",
        matchers: ["/operations"],
        rolesAllowed: ["owner", "admin", "manager", "warehouse_staff"],
      },
      // {
      //   key: "exceptions",
      //   label: "Exceptions",
      //   href: "/delivery/exceptions",
      //   matchers: ["/delivery/exceptions"],
      //   badgeKey: "deliveryExceptions",
      // },
      {
        key: "returns",
        label: "Returns",
        href: "/returns",
        matchers: ["/returns"],
        badgeKey: "pendingReturns",
      },
    ],
  },

  {
    key: "finance",
    label: "Finance",
    icon: DollarSign,
    matchers: [
      "/collections",
      "/sales-invoices",
      "/credit-notes",
      "/advance-payments",
      "/approvals/credit-limits"
    ],
    rolesAllowed: ["owner", "admin", "manager", "accountant"],
    children: [
      {
        key: "collections",
        label: "Collections",
        href: "/collections",
        matchers: ["/collections"],
        badgeKey: "overdueCollections",
      },
      {
        key: "invoices",
        label: "Invoices",
        href: "/sales-invoices",
        matchers: ["/sales-invoices"],
      },
      {
        key: "credit-limits",
        label: "Credit Control",
        href: "/approvals/credit-limits",
        matchers: ["/approvals/credit-limits"],
        rolesAllowed: ["owner", "admin", "manager"],
        badgeKey: "creditLimitRequests",
      },
      {
        key: "credit-notes",
        label: "Credit Notes",
        href: "/credit-notes",
        matchers: ["/credit-notes"],
      },
      {
        key: "advance-payments",
        label: "Advances",
        href: "/advance-payments",
        matchers: ["/advance-payments"],
      }
    ],
  },

  {
    key: "accounting",
    label: "Accounting",
    icon: BookOpen,
    matchers: [
      "/compliance",
      "/accounting/integrations",
    ],
    rolesAllowed: ["owner", "admin", "accountant"],
    children: [
      {
        key: "integrations",
        label: "Integrations",
        href: "/accounting/integrations",
        matchers: ["/accounting/integrations"],
      },
      {
        key: "gst-compliance",
        label: "GST Filing",
        href: "/compliance",
        matchers: ["/compliance"],
      },
    ],
  },

  {
    key: "insights",
    label: "Insights",
    href: "/insights",
    icon: BarChart2,
    matchers: ["/insights", "/reports", "/accounting"],
    rolesAllowed: ["owner", "admin", "manager", "accountant"],
  },

  {
    key: "setup",
    label: "Setup",
    icon: Settings,
    matchers: [
      "/products",
      "/products/hsn-codes",
      "/settings",
      "/users",
      "/settings/branches",
      "/settings/organizations",
      "/settings/fleet",
      "/settings/organization",
    ],
    rolesAllowed: ["owner", "admin"],
    children: [
      {
        key: "products",
        label: "Products",
        href: "/products",
        matchers: ["/products"],
      },
      {
        key: "hsn-sac",
        label: "HSN / SAC",
        href: "/products/hsn-codes",
        matchers: ["/products/hsn-codes"],
      },
      {
        key: "users",
        label: "Users",
        href: "/users",
        matchers: ["/users"],
      },
      {
        key: "vehicles",
        label: "Vehicles",
        href: "/settings/fleet",
        matchers: ["/settings/fleet"],
      },
      {
        key: "organizations",
        label: "Organizations",
        href: "/settings/organizations",
        matchers: ["/settings/organizations"],      
      },
      {
        key: "preferences",
        label: "Preferences",
        href: "/settings",
        matchers: ["/settings"],
      },
    ],
  },
];

export function isActiveGroup(pathname: string, group: NavGroup): boolean {
  return group.matchers.some((m) => pathname === m || pathname.startsWith(m + "/"));
}

export function isActiveChild(pathname: string, child: NavChild): boolean {
  return child.matchers.some((m) => pathname === m || pathname.startsWith(m + "/"));
}

export function filterGroupedNavForRole(role: UserRole | undefined): NavGroup[] {
  const groups = !role || role === "owner" || role === "admin"
    ? GROUPED_NAV
    : GROUPED_NAV.filter((g) => !g.rolesAllowed || g.rolesAllowed.includes(role));

  return groups.map((g) => ({
    ...g,
    children: g.children?.filter(
      (c) => !c.rolesAllowed || !role || role === "owner" || role === "admin" || c.rolesAllowed.includes(role)
    ),
  }));
}
