import { LucideIcon, TrendingUp, TrendingDown, Minus } from "lucide-react";

// ── Sparkline ──────────────────────────────────────────────────────────────────
function Sparkline({ data, color = "#52B788" }: { data: number[]; color?: string }) {
  if (!data || data.length < 2) return null;
  const W = 80, H = 32, pad = 2;
  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;
  const xs = data.map((_, i) => pad + (i / (data.length - 1)) * (W - pad * 2));
  const ys = data.map(v => H - pad - ((v - min) / range) * (H - pad * 2));
  const points = xs.map((x, i) => `${x},${ys[i]}`).join(" ");
  const fillPts = `${xs[0]},${H} ${points} ${xs[xs.length - 1]},${H}`;

  return (
    <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} aria-hidden="true">
      <polygon points={fillPts} fill={color} fillOpacity={0.15} />
      <polyline points={points} fill="none" stroke={color} strokeWidth={1.5} strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}

// ── Skeleton ───────────────────────────────────────────────────────────────────
export function KpiCardSkeleton() {
  return (
    <div className="rounded-xl border border-border bg-background p-5 animate-pulse">
      <div className="flex items-start justify-between">
        <div className="h-4 w-24 rounded bg-gray-100" />
        <div className="h-9 w-9 rounded-lg bg-gray-100" />
      </div>
      <div className="mt-4 h-7 w-32 rounded bg-gray-100" />
      <div className="mt-2 h-3 w-16 rounded bg-gray-100" />
    </div>
  );
}

// ── KpiCard ───────────────────────────────────────────────────────────────────
export interface KpiCardProps {
  label: string;
  value: string | number;
  /** Percentage change e.g. 12.5 means +12.5%, -3.1 means -3.1% */
  change?: number;
  icon: LucideIcon;
  /** Tailwind color variant: "green" | "amber" | "red" | "blue" */
  color?: "green" | "amber" | "red" | "blue";
  sparklineData?: number[];
  loading?: boolean;
  error?: boolean;
}

const COLORS = {
  green: { bg: "bg-accent/10",  icon: "text-accent",   spark: "#52B788" },
  amber: { bg: "bg-amber-50",   icon: "text-amber-600", spark: "#D97706" },
  red:   { bg: "bg-red-50",     icon: "text-danger",    spark: "#DC2626" },
  blue:  { bg: "bg-blue-50",    icon: "text-blue-600",  spark: "#2563EB" },
};

export function KpiCard({
  label, value, change, icon: Icon, color = "green", sparklineData, loading, error,
}: KpiCardProps) {
  if (loading) return <KpiCardSkeleton />;

  const c = COLORS[color];
  const trendPositive = change !== undefined && change > 0;
  const trendNegative = change !== undefined && change < 0;
  const TrendIcon = trendPositive ? TrendingUp : trendNegative ? TrendingDown : Minus;
  const trendColor = trendPositive ? "text-green-600" : trendNegative ? "text-danger" : "text-text-secondary";

  return (
    <div
      className="rounded-xl border border-border bg-background p-5 hover:shadow-sm transition-shadow"
      role="region"
      aria-label={label}
    >
      <div className="flex items-start justify-between">
        <p className="text-sm font-medium text-text-secondary">{label}</p>
        <span className={`flex h-9 w-9 items-center justify-center rounded-lg ${c.bg}`} aria-hidden="true">
          <Icon className={`h-5 w-5 ${c.icon}`} />
        </span>
      </div>

      {error ? (
        <p className="mt-4 text-sm text-danger">Failed to load</p>
      ) : (
        <>
          <p className="mt-4 text-2xl font-bold text-text-primary tracking-tight">{value}</p>
          <div className="mt-2 flex items-center justify-between">
            {change !== undefined ? (
              <span className={`flex items-center gap-1 text-xs font-medium ${trendColor}`}>
                <TrendIcon className="h-3 w-3" aria-hidden="true" />
                {Math.abs(change).toFixed(1)}% vs last month
              </span>
            ) : (
              <span />
            )}
            {sparklineData && <Sparkline data={sparklineData} color={c.spark} />}
          </div>
        </>
      )}
    </div>
  );
}
