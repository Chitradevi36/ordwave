import { useState, useEffect } from "react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";
import { ShoppingCart, DollarSign, Package, Truck, Layers } from "lucide-react";

//  Types 
export interface OverviewStats {
  sales: {
    count: number;
    value: number;
    outstanding: number;
    avg: number;
  };
  collections: {
    payments_today: number;
    payments_mtd: number;
    payments_period: number;
    unpaid_invoices_count: number;
    unpaid_invoices_value: number;
    collection_rate: number;
  };
  credit_risk: {
    total_accounts: number;
    risky_count: number;
  };
  inventory: {
    low_stock_count: number;
    dead_stock_count: number;
    total_skus: number;
    zero_stock_count: number;
  };
}

export interface OperationsStats {
  active_trips: number;
  completed_today: number;
  pending_stops: number;
  returns_open: number;
}

export interface CatalogStats {
  active_products: number;
  price_lists: number;
  active_schemes: number;
  inactive_products: number;
}

function headers(token: string, orgId: string | number) {
  return {
    Authorization: `Bearer ${token}`,
    "X-Organization-Id": String(orgId),
    "Content-Type": "application/json",
  };
}

type WorkspaceKey = "sales" | "finance" | "catalog" | "operations" | "inventory";

interface WorkspaceActivityItem {
  id: string | number;
  icon?: typeof ShoppingCart;
  iconColor?: string;
  message: string;
  sub?: string;
  time: string;
  unread?: boolean;
}

function fmtTimeAgo(value: string | null | undefined): string {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  const diff = Date.now() - date.getTime();
  const minutes = Math.floor(diff / 60000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

export function useWorkspaceActivity(workspace: WorkspaceKey) {
  const { token, orgId } = useOrgBranch();
  const [items, setItems] = useState<WorkspaceActivityItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!token || !orgId) return;
    setLoading(true);

    const h = headers(token, orgId);

    const fetcher = async () => {
      try {
        if (workspace === "sales") {
          const res = await fetch(`${API_URL}/api/v1/sales_orders?per_page=4`, { headers: h });
          const json = await res.json();
          const mapped = (json?.data ?? []).map((o: Record<string, unknown>) => ({
            id: o.id as number,
            icon: ShoppingCart,
            iconColor: "bg-blue-50 text-blue-600",
            message: `Order ${String(o.order_number ?? `#${o.id}`)} ${String(o.status ?? "")}`.trim(),
            sub: o.customer && typeof o.customer === "object" ? String((o.customer as Record<string, unknown>).name ?? "") : "",
            time: fmtTimeAgo(String(o.created_at ?? o.updated_at ?? "")),
            unread: false,
          }));
          setItems(mapped);
          return;
        }

        if (workspace === "finance") {
          const res = await fetch(`${API_URL}/api/v1/payments?per_page=4`, { headers: h });
          const json = await res.json();
          const mapped = (json?.data ?? []).map((p: Record<string, unknown>) => ({
            id: p.id as number,
            icon: DollarSign,
            iconColor: "bg-green-50 text-green-600",
            message: `Payment ${String(p.payment_number ?? `#${p.id}`)}`,
            sub: p.amount ? fmtINR(Number(p.amount)) : "",
            time: fmtTimeAgo(String(p.created_at ?? p.updated_at ?? "")),
            unread: false,
          }));
          setItems(mapped);
          return;
        }

        if (workspace === "catalog") {
          const res = await fetch(`${API_URL}/api/v1/products?per_page=4`, { headers: h });
          const json = await res.json();
          const mapped = (json?.data ?? []).map((p: Record<string, unknown>) => ({
            id: p.id as number,
            icon: Package,
            iconColor: "bg-purple-50 text-purple-600",
            message: `Product ${String(p.name ?? `#${p.id}`)}`,
            sub: String(p.sku ?? ""),
            time: fmtTimeAgo(String(p.updated_at ?? p.created_at ?? "")),
            unread: false,
          }));
          setItems(mapped);
          return;
        }

        if (workspace === "operations") {
          const res = await fetch(`${API_URL}/api/v1/delivery_trips?per_page=4`, { headers: h });
          const json = await res.json();
          const mapped = (json?.data ?? []).map((t: Record<string, unknown>) => ({
            id: t.id as number,
            icon: Truck,
            iconColor: "bg-orange-50 text-orange-600",
            message: `Trip ${String(t.trip_number ?? `#${t.id}`)} ${String(t.status ?? "")}`.trim(),
            sub: t.branch && typeof t.branch === "object" ? String((t.branch as Record<string, unknown>).name ?? "") : "",
            time: fmtTimeAgo(String(t.created_at ?? t.updated_at ?? "")),
            unread: false,
          }));
          setItems(mapped);
          return;
        }

        const res = await fetch(`${API_URL}/api/v1/stock_transfers?per_page=4`, { headers: h });
        const json = await res.json();
        const mapped = (json?.data ?? []).map((t: Record<string, unknown>) => ({
          id: t.id as number,
          icon: Layers,
          iconColor: "bg-amber-50 text-amber-600",
          message: `Transfer ${String(t.transfer_number ?? `#${t.id}`)} ${String(t.status ?? "")}`.trim(),
          sub:
            t.source_branch && t.destination_branch && typeof t.source_branch === "object" && typeof t.destination_branch === "object"
              ? `${String((t.source_branch as Record<string, unknown>).name ?? "")} → ${String((t.destination_branch as Record<string, unknown>).name ?? "")}`
              : "",
          time: fmtTimeAgo(String(t.created_at ?? t.updated_at ?? "")),
          unread: false,
        }));
        setItems(mapped);
      } catch {
        setItems([]);
      } finally {
        setLoading(false);
      }
    };

    void fetcher();
  }, [workspace, token, orgId]);

  return { items, loading };
}

//  useOverviewStats 
export function useOverviewStats() {
  const { token, orgId } = useOrgBranch();
  const [stats, setStats] = useState<OverviewStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!token || !orgId) return;
    setLoading(true);
    fetch(`${API_URL}/api/v1/analytics/overview`, {
      headers: headers(token, orgId),
    })
      .then((r) => r.json())
      .then((j) => { if (j.success && j.data) setStats(j.data); })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [token, orgId]);

  return { stats, loading };
}

//  useOperationsStats 
export function useOperationsStats() {
  const { token, orgId } = useOrgBranch();
  const [data, setData] = useState<OperationsStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!token || !orgId) return;
    setLoading(true);
    const h = headers(token, orgId);
    Promise.all([
      fetch(`${API_URL}/api/v1/delivery_trips?status=dispatched&per_page=1`, { headers: h }).then((r) => r.json()),
      fetch(`${API_URL}/api/v1/delivery_trips?status=completed&per_page=1`,  { headers: h }).then((r) => r.json()),
      fetch(`${API_URL}/api/v1/delivery_trips?status=draft&per_page=1`,      { headers: h }).then((r) => r.json()),
      fetch(`${API_URL}/api/v1/return_requests?status=draft,submitted&per_page=1`, { headers: h }).then((r) => r.json()),
    ])
      .then(([dispatched, completed, draft, returns]) => {
        setData({
          active_trips:    dispatched?.meta?.total_count ?? 0,
          completed_today: completed?.meta?.total_count  ?? 0,
          pending_stops:   draft?.meta?.total_count      ?? 0,
          returns_open:    returns?.meta?.total_count    ?? 0,
        });
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [token, orgId]);

  return { data, loading };
}

//  useCatalogStats 
export function useCatalogStats() {
  const { token, orgId } = useOrgBranch();
  const [data, setData] = useState<CatalogStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!token || !orgId) return;
    setLoading(true);
    const h = headers(token, orgId);
    Promise.all([
      fetch(`${API_URL}/api/v1/products?status=active&per_page=1`,   { headers: h }).then((r) => r.json()),
      fetch(`${API_URL}/api/v1/price_lists?per_page=1`,               { headers: h }).then((r) => r.json()),
      fetch(`${API_URL}/api/v1/schemes/stats`,                        { headers: h }).then((r) => r.json()),
      fetch(`${API_URL}/api/v1/products?status=inactive&per_page=1`, { headers: h }).then((r) => r.json()),
    ])
      .then(([active, priceLists, schemes, inactive]) => {
        setData({
          active_products:  active?.meta?.total_count     ?? 0,
          price_lists:      priceLists?.meta?.total_count ?? 0,
          active_schemes:   schemes?.data?.active_count   ?? 0,
          inactive_products:inactive?.meta?.total_count   ?? 0,
        });
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [token, orgId]);

  return { data, loading };
}

//  useSalesStats 
export function useSalesStats() {
  const { token, orgId } = useOrgBranch();
  const [data, setData] = useState<{ open_orders: number; pending_approvals: number } | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!token || !orgId) return;
    setLoading(true);
    const h = headers(token, orgId);
    Promise.all([
      fetch(`${API_URL}/api/v1/sales_orders?status=submitted,approved,dispatched&per_page=1`, { headers: h }).then((r) => r.json()),
      fetch(`${API_URL}/api/v1/sales_orders?status=submitted&per_page=1`,                     { headers: h }).then((r) => r.json()),
    ])
      .then(([open, pending]) => {
        setData({
          open_orders:       open?.meta?.total_count    ?? 0,
          pending_approvals: pending?.meta?.total_count ?? 0,
        });
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [token, orgId]);

  return { data, loading };
}

//  Utility 
export function fmtINR(n: number): string {
  if (n >= 10000000) return `\u20B9${(n / 10000000).toFixed(1)}Cr`;
  if (n >= 100000)   return `\u20B9${(n / 100000).toFixed(1)}L`;
  if (n >= 1000)     return `\u20B9${(n / 1000).toFixed(0)}K`;
  return `\u20B9${n.toFixed(0)}`;
}