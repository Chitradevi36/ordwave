"use client";

import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer,
} from "recharts";

// ── Types ──────────────────────────────────────────────────────────────────────
export interface SalesTrendPoint {
  date: string;   // "2024-01-15"
  revenue: number;
}

// ── Custom tooltip ─────────────────────────────────────────────────────────────
function CustomTooltip({ active, payload, label }: { active?: boolean; payload?: Array<{ value?: number }>; label?: string }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-lg border border-border bg-background px-3 py-2 shadow-md text-sm">
      <p className="text-text-secondary mb-1">{label}</p>
      <p className="font-semibold text-text-primary">
        ₹{payload[0].value?.toLocaleString("en-IN")}
      </p>
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
        <p className="text-sm text-text-secondary">No sales data available</p>
      </div>
    );
  }

  const chartData = data.map(d => ({ ...d, date: formatDate(d.date) }));

  return (
    <div className="h-64 w-full" role="img" aria-label="Sales trend area chart">
      <ResponsiveContainer width="100%" height="100%">
        <AreaChart data={chartData} margin={{ top: 4, right: 4, left: 0, bottom: 0 }}>
          <defs>
            <linearGradient id="salesGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%"  stopColor="#52B788" stopOpacity={0.3} />
              <stop offset="95%" stopColor="#52B788" stopOpacity={0.02} />
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
          <Tooltip content={<CustomTooltip />} cursor={{ stroke: "#52B788", strokeWidth: 1, strokeDasharray: "4 4" }} />
          <Area
            type="monotone"
            dataKey="revenue"
            stroke="#52B788"
            strokeWidth={2}
            fill="url(#salesGradient)"
            dot={false}
            activeDot={{ r: 4, fill: "#52B788", strokeWidth: 0 }}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
