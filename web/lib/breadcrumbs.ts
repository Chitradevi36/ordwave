import type { BreadcrumbItem } from "@/components/ui/breadcrumb";

// ── Route config ──────────────────────────────────────────────────────────────
// Each entry maps a known path to its label and optional parent path.
// Dynamic children are handled generically in buildBreadcrumbs().
const ROUTE_CONFIG: Record<string, { label: string; parent?: string }> = {
  // ── Workspace roots (no parent)
  "/dashboard":                   { label: "Dashboard" },
  "/sales":                       { label: "Sales" },
  "/orders":                      { label: "Orders" },
  "/catalog":                     { label: "Catalog" },
  "/operations":                  { label: "Operations" },
  "/finance":                     { label: "Finance" },
  "/inventory":                   { label: "Inventory" },
  "/insights":                    { label: "Insights" },
  "/settings":                    { label: "Settings" },
  "/customers":                   { label: "Customers" },

  // ── Sales workspace
  // "/orders":                      { label: "Orders",             parent: "/sales" },
  "/orders/new":                  { label: "New Order",          parent: "/orders" },
  // "/approvals":                   { label: "Approvals",          parent: "/sales" },
  "/approvals/credit-limits":     { label: "Credit Limits",      parent: "/approvals" },
  "/schemes":                     { label: "Schemes",            parent: "/sales" },

  // ── Customers workspace (sub-pages)
  // "/routes":                      { label: "Routes",             parent: "/customers" },
  // "/beats":                       { label: "Beats",              parent: "/customers" },
  "/customers/new":               { label: "New Customer",       parent: "/customers" },

  // ── Catalog workspace
  // "/products":                    { label: "Products",           parent: "/catalog" },
  "/products/new":                { label: "New Product",        parent: "/products" },
  "/products/categories":         { label: "Categories",         parent: "/products" },
  "/products/uom":                { label: "Units of Measure",   parent: "/products" },
  // "/products/price-lists":        { label: "Price Lists",        parent: "/products" },
  "/pricing":                     { label: "Pricing",            parent: "/catalog" },
  "/pricing/schemes":             { label: "Promotions",         parent: "/catalog" },

  // ── Operations workspace
  // "/delivery":                    { label: "Delivery Trips",     parent: "/operations" },
  "/delivery/new":                { label: "New Trip",           parent: "/delivery" },
  "/delivery/exceptions":         { label: "Exceptions",         parent: "/delivery" },
  "/delivery/rejections":         { label: "Rejections",         parent: "/delivery" },
  "/returns":                     { label: "Returns",            parent: "/operations" },
  "/returns/new":                 { label: "New Return",         parent: "/returns" },

  // ── Inventory workspace
  // "/inventory/stock":             { label: "Stock",              parent: "/inventory" },
  "/inventory/stock/new":         { label: "New Stock",          parent: "/inventory/stock" },
  "/inventory/adjustments":       { label: "Adjustments",        parent: "/inventory" },
  "/inventory/adjustments/new":   { label: "New Adjustment",     parent: "/inventory/adjustments" },
  // "/inventory/transfers":         { label: "Transfers",          parent: "/inventory" },
  "/inventory/transfers/new":     { label: "New Transfer",       parent: "/inventory/transfers" },
  // "/purchases":                   { label: "Purchases",          parent: "/inventory" },
  "/purchases/invoices":          { label: "Purchases",          parent: "/inventory" },
  "/purchases/invoices/new":      { label: "New Purchase",       parent: "/purchases/invoices" },
  // "/suppliers":                   { label: "Suppliers",          parent: "/inventory" },

  // ── Finance workspace
  // "/collections":                 { label: "Collections",        parent: "/finance" },
  "/collections/new":             { label: "New Collection",     parent: "/collections" },
  // "/sales-invoices":              { label: "Sales Invoices",     parent: "/finance" },
  // "/credit-notes":                { label: "Credit Notes",       parent: "/finance" },
  "/credit-notes/new":            { label: "New Credit Note",    parent: "/credit-notes" },
  "/advance-payments":            { label: "Advances",           parent: "/finance" },

  // ── Insights workspace
  "/insights/sales":              { label: "Sales Analytics",    parent: "/insights" },
  "/insights/collections":        { label: "Collections",        parent: "/insights" },
  "/insights/inventory":          { label: "Inventory",          parent: "/insights" },
  "/insights/beat-performance":   { label: "Beat Performance",   parent: "/insights" },

  // ── Settings
  "/settings/profile":            { label: "Profile",            parent: "/settings" },
  "/settings/account":            { label: "Account",            parent: "/settings" },
  "/settings/credit-policy":      { label: "Credit Policy",      parent: "/settings" },
  // "/settings/fleet":              { label: "Fleet",              parent: "/settings" },
  "/settings/prepayment-skus":    { label: "Prepayment SKUs",    parent: "/settings" },
  // "/users":                       { label: "Users",              parent: "/settings" },
  "/invite":                      { label: "Invite Team",        parent: "/settings" },
};

// Build the ancestor chain for a known route path
function resolveChain(path: string): BreadcrumbItem[] {
  const config = ROUTE_CONFIG[path];
  if (!config) return [];
  const chain: BreadcrumbItem[] = [];
  if (config.parent) chain.push(...resolveChain(config.parent));
  chain.push({ label: config.label, href: path });
  return chain;
}

// Format an unknown URL segment (dynamic IDs, etc.) into a readable label
function formatDynamicSegment(seg: string): string {
  if (seg === "new") return "New";
  if (seg === "edit") return "Edit";
  // Numeric ID — show as short hash
  if (/^\d+$/.test(seg)) return `#${seg}`;
  // UUID — truncate
  if (/^[0-9a-f-]{36}$/i.test(seg)) return `#${seg.slice(0, 8)}`;
  // Slug — title-case
  return seg
    .split("-")
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
}

/**
 * Build a breadcrumb item array from the current pathname.
 * Returns an empty array for the root or unrecognised paths.
 *
 * Pages can override this by passing a custom `breadcrumbs` prop to AppShell.
 */
export function buildBreadcrumbs(pathname: string): BreadcrumbItem[] {
  const clean = pathname.replace(/\/$/, "") || "/dashboard";

  // Exact known route → resolve full ancestor chain
  if (ROUTE_CONFIG[clean]) {
    const chain = resolveChain(clean);
    // Last item is current page — remove its href
    if (chain.length > 0) chain[chain.length - 1] = { label: chain[chain.length - 1].label };
    return chain;
  }

  // Find the longest known prefix
  const segments = clean.split("/").filter(Boolean);
  let knownPrefix = "";
  let knownItems: BreadcrumbItem[] = [];

  for (let i = segments.length; i >= 1; i--) {
    const candidate = "/" + segments.slice(0, i).join("/");
    if (ROUTE_CONFIG[candidate]) {
      knownItems = resolveChain(candidate);
      knownPrefix = candidate;
      break;
    }
  }

  // Append remaining (dynamic) segments after the known prefix
  const knownDepth = knownPrefix.split("/").filter(Boolean).length;
  const extra = segments.slice(knownDepth);

  for (let i = 0; i < extra.length; i++) {
    const segPath = "/" + segments.slice(0, knownDepth + i + 1).join("/");
    const isLast = i === extra.length - 1;
    knownItems.push({
      label: formatDynamicSegment(extra[i]),
      href: isLast ? undefined : segPath,
    });
  }

  // Ensure last item has no href (current page)
  if (knownItems.length > 0) {
    knownItems[knownItems.length - 1] = { label: knownItems[knownItems.length - 1].label };
  }

  return knownItems;
}

export type { BreadcrumbItem };
