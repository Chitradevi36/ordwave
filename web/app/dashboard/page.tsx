"use client";

import { useOnboardingGuard } from "@/lib/hooks/useOnboardingGuard";
import { AppShell } from "@/components/layout/app-shell";
import { PageHeader } from "@/components/layout/page-header";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { DataTable, Column } from "@/components/ui/data-table";
import { Plus, TrendingUp, Package, ShoppingCart, Users } from "lucide-react";

const stats = [
  { label: "Total Orders", value: "1,247", change: "+12%", icon: ShoppingCart, color: "text-primary" },
  { label: "Active Outlets", value: "384", change: "+3%", icon: Users, color: "text-secondary" },
  { label: "Products", value: "892", change: "+8%", icon: Package, color: "text-accent" },
  { label: "Revenue (MTD)", value: "₹24.6L", change: "+18%", icon: TrendingUp, color: "text-primary" },
];

interface Order {
  id: string;
  outlet: string;
  products: number;
  amount: string;
  status: "pending" | "confirmed" | "dispatched" | "delivered";
  date: string;
}

const recentOrders: Order[] = [
  { id: "ORD-001", outlet: "Fresh Mart", products: 5, amount: "₹4,500", status: "confirmed", date: "2026-03-03" },
  { id: "ORD-002", outlet: "Daily Needs Store", products: 3, amount: "₹2,100", status: "dispatched", date: "2026-03-03" },
  { id: "ORD-003", outlet: "Super Bazaar", products: 8, amount: "₹7,800", status: "pending", date: "2026-03-02" },
  { id: "ORD-004", outlet: "Corner Shop", products: 2, amount: "₹950", status: "delivered", date: "2026-03-02" },
];

const statusVariant = {
  pending: "warning" as const,
  confirmed: "secondary" as const,
  dispatched: "default" as const,
  delivered: "success" as const,
};

const orderColumns: Column<Order>[] = [
  { key: "id", header: "Order ID" },
  { key: "outlet", header: "Outlet" },
  { key: "products", header: "Items", render: (v) => `${v} items` },
  { key: "amount", header: "Amount" },
  {
    key: "status",
    header: "Status",
    render: (v) => (
      <Badge variant={statusVariant[v as Order["status"]]}>
        {String(v).charAt(0).toUpperCase() + String(v).slice(1)}
      </Badge>
    ),
  },
  { key: "date", header: "Date" },
];

export default function DashboardPage() {
  const isReady = useOnboardingGuard();

  // Prevent any render while checking - return null to avoid flick
  if (!isReady) {
    return null;
  }

  return (
    <AppShell title="Dashboard">
      <PageHeader
        title="Dashboard"
        description="Welcome back. Here's what's happening today."
        actions={[
          { label: "New Order", onClick: () => {}, icon: Plus },
        ]}
      />

      {/* Stats */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4 mb-6">
        {stats.map((stat) => {
          const Icon = stat.icon;
          return (
            <Card key={stat.label}>
              <CardHeader className="pb-2">
                <div className="flex items-center justify-between">
                  <CardTitle className="text-sm font-medium text-text-secondary">
                    {stat.label}
                  </CardTitle>
                  <Icon className={`h-4 w-4 ${stat.color}`} />
                </div>
              </CardHeader>
              <CardContent>
                <p className="text-2xl font-bold text-text-primary">{stat.value}</p>
                <p className="text-xs text-accent mt-1">{stat.change} from last month</p>
              </CardContent>
            </Card>
          );
        })}
      </div>

      {/* Recent Orders */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Orders</CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          <DataTable columns={orderColumns} data={recentOrders} />
        </CardContent>
      </Card>
    </AppShell>
  );
}
