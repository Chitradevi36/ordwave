"use client";

import {
  PieChart, Pie, Cell, Tooltip, Legend,
  ResponsiveContainer,
} from "recharts";

// ── Types ──────────────────────────────────────────────────────────────────────
export interface OrderStatusEntry {
  status: string;
  count: number;
}

// ── Config ────────────────────────────────────────────────────────────────────
const STATUS_CONFIG: Record<string, { label: string; color: string }> = {
  pending:           { label: "Pending",    color: "#D97706" },
  approved:          { label: "Approved",   color: "#1B4332" },
  dispatched:        { label: "Dispatched", color: "#2563EB" },
  delivered:         { label: "Delivered",  color: "#52B788" },
  cancelled:         { label: "Cancelled",  color: "#DC2626" },
  partially_delivered: { label: "Partial", color: "#7C3AED" },
};

function getConfig(status: string) {
  return STATUS_CONFIG[status] ?? { label: status, color: "#94A3B8" };
}

// ── Custom tooltip ─────────────────────────────────────────────────────────────
function CustomTooltip({ active, payload }: { active?: boolean; payload?: Array<{ name?: string; value?: number }> }) {
  if (!active || !payload?.length) return null;
  const item = payload[0];
  return (
    <div className="rounded-lg border border-border bg-background px-3 py-2 shadow-md text-sm">
      <p className="font-semibold text-text-primary">{getConfig(item.name ?? "").label}</p>
      <p className="text-text-secondary">{item.value} orders</p>
    </div>
  );
}

// ── Custom legend ─────────────────────────────────────────────────────────────
function CustomLegend({ payload }: { payload?: Array<{ value: string; color: string }> }) {
  if (!payload) return null;
  return (
    <ul className="flex flex-wrap justify-center gap-x-4 gap-y-1.5 mt-2">
      {payload.map(entry => (
        <li key={entry.value} className="flex items-center gap-1.5 text-xs text-text-secondary">
          <span className="inline-block h-2.5 w-2.5 rounded-full shrink-0" style={{ backgroundColor: entry.color }} />
          {getConfig(entry.value).label}
        </li>
      ))}
    </ul>
  );
}

// ── Skeleton ───────────────────────────────────────────────────────────────────
function OrderStatusSkeleton() {
  return (
    <div className="flex flex-col items-center gap-4">
      <div className="h-48 w-48 rounded-full animate-pulse bg-gray-100" aria-label="Loading chart" />
      <div className="flex gap-3">
        {[1, 2, 3].map(i => <div key={i} className="h-3 w-16 rounded animate-pulse bg-gray-100" />)}
      </div>
    </div>
  );
}

// ── OrderStatusChart ──────────────────────────────────────────────────────────
interface OrderStatusChartProps {
  data?: OrderStatusEntry[];
  loading?: boolean;
  error?: boolean;
}

export function OrderStatusChart({ data, loading, error }: OrderStatusChartProps) {
  if (loading) return <OrderStatusSkeleton />;

  if (error) {
    return (
      <div className="flex h-64 items-center justify-center">
        <p className="text-sm text-danger">Failed to load chart data</p>
      </div>
    );
  }

  if (!Array.isArray(data) || data.length === 0) {
    return (
      <div className="flex h-64 items-center justify-center">
        <p className="text-sm text-text-secondary">No order data available</p>
      </div>
    );
  }

  const chartData = data.map(d => ({ name: d.status, value: d.count }));
  const total = data.reduce((sum, d) => sum + d.count, 0);

  return (
    <div className="h-64 w-full" role="img" aria-label="Order status distribution donut chart">
      <ResponsiveContainer width="100%" height="100%">
        <PieChart>
          <Pie
            data={chartData}
            dataKey="value"
            nameKey="name"
            cx="50%"
            cy="45%"
            innerRadius={55}
            outerRadius={85}
            paddingAngle={2}
          >
            {chartData.map(entry => (
              <Cell key={entry.name} fill={getConfig(entry.name).color} strokeWidth={0} />
            ))}
          </Pie>
          {/* Centre label */}
          <text x="50%" y="42%" textAnchor="middle" dominantBaseline="middle" className="fill-text-primary">
            <tspan x="50%" dy="0" fontSize={22} fontWeight={700}>{total}</tspan>
            <tspan x="50%" dy={18} fontSize={11} fill="#64748B">orders</tspan>
          </text>
          <Tooltip content={<CustomTooltip />} />
          <Legend content={<CustomLegend />} />
        </PieChart>
      </ResponsiveContainer>
    </div>
  );
}
