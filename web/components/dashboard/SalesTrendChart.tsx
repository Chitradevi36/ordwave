"use client";

import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid,
  Tooltip, Legend, ResponsiveContainer,
} from "recharts";

// ── Types ──────────────────────────────────────────────────────────────────────
export interface SalesTrendPoint {
  date: string;
  /** Backwards-compat single-series field */
  revenue?: number;
  /** New dual-series fields */
  orders_value?: number;
  collections?: number;
}

// ── Helpers ─────────────────────────────────────────────────────────────────────
function formatDate(dateStr: string) {
  try {
    return new Date(dateStr).toLocaleDateString("en-IN", { month: "short", day: "numeric" });
  } catch {
    return dateStr;
  }
}

function formatYAxis(value: number) {
  if (value >= 100_000) return `₹${(value / 100_000).toFixed(1)}L`;
  if (value >= 1_000)   return `₹${(value / 1_000).toFixed(0)}K`;
  return `₹${value}`;
}

function fmt(v?: number) {
  return `₹${(v ?? 0).toLocaleString("en-IN")}`;
}

// ── Custom tooltip ─────────────────────────────────────────────────────────────
function CustomTooltip({
  active, payload, label,
}: {
  active?: boolean;
  payload?: Array<{ name?: string; value?: number; color?: string }>;
  label?: string;
}) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-lg border border-border bg-background px-3 py-2 shadow-md text-sm min-w-[160px]">
      <p className="text-text-secondary mb-1 font-medium">{label}</p>
      {payload.map((p, i) => (
        <p key={i} className="text-text-primary" style={{ color: p.color }}>
          {p.name}: <span className="font-semibold">{fmt(p.value)}</span>
        </p>
      ))}
    </div>
  );
}

// ── Skeleton ───────────────────────────────────────────────────────────────────
function SalesTrendSkeleton() {
  return (
    <div className="h-64 w-full animate-pulse rounded-lg bg-gray-100" aria-label="Loading chart" />
  );
}

// ── SalesTrendChart ────────────────────────────────────────────────────────────
interface SalesTrendChartProps {
  data?: SalesTrendPoint[];
  loading?: boolean;
  error?: boolean;
}

export function SalesTrendChart({ data, loading, error }: SalesTrendChartProps) {
  if (loading) return <SalesTrendSkeleton />;

  if (error) {
    return (
      <div className="flex h-64 items-center justify-center rounded-lg border border-border bg-background">
        <p className="text-sm text-danger">Failed to load chart data</p>
      </div>
    );
  }

  if (!Array.isArray(data) || data.length === 0) {
    return (
      <div className="flex h-64 items-center justify-center rounded-lg border border-border bg-background">
        <p className="text-sm text-text-secondary">No data yet</p>
      </div>
    );
  }

  // Normalise: support both old `revenue` and new dual-series fields
  const chartData = data.map(d => ({
    date:         formatDate(d.date),
    orders_value: d.orders_value ?? d.revenue ?? 0,
    collections:  d.collections ?? 0,
  }));

  const hasDual = data.some(d => d.collections !== undefined || d.orders_value !== undefined);

  return (
    <div className="h-64 w-full" role="img" aria-label="Revenue trend chart">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={chartData} margin={{ top: 4, right: 4, left: 0, bottom: 0 }}>
          <defs>
            <linearGradient id="ordersGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%"  stopColor="#52B788" stopOpacity={0.25} />
              <stop offset="95%" stopColor="#52B788" stopOpacity={0.02} />
            </linearGradient>
            <linearGradient id="collectionsGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%"  stopColor="#2563EB" stopOpacity={0.2} />
              <stop offset="95%" stopColor="#2563EB" stopOpacity={0.02} />
            </linearGradient>
          </defs>

          <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" vertical={false} />
          <XAxis
            dataKey="date"
            tick={{ fontSize: 11, fill: "#64748B" }}
            axisLine={false}
            tickLine={false}
            interval="preserveStartEnd"
          />
          <YAxis
            tickFormatter={formatYAxis}
            tick={{ fontSize: 11, fill: "#64748B" }}
            axisLine={false}
            tickLine={false}
            width={56}
          />
          <Tooltip content={<CustomTooltip />} cursor={{ stroke: "#94A3B8", strokeWidth: 1, strokeDasharray: "4 4" }} />
          {hasDual && (
            <Legend
              wrapperStyle={{ fontSize: 12, paddingTop: 8 }}
              formatter={(value) => value === "orders_value" ? "Orders" : "Collections"}
            />
          )}

          <Area
            type="monotone"
            dataKey="orders_value"
            name="orders_value"
            stroke="#52B788"
            strokeWidth={2}
            fill="url(#ordersGradient)"
            dot={false}
            activeDot={{ r: 4, fill: "#52B788", strokeWidth: 0 }}
          />
          {hasDual && (
            <Area
              type="monotone"
              dataKey="collections"
              name="collections"
              stroke="#2563EB"
              strokeWidth={2}
              fill="url(#collectionsGradient)"
              dot={false}
              activeDot={{ r: 4, fill: "#2563EB", strokeWidth: 0 }}
            />
          )}
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

