"use client";

import Link from "next/link";
import type { LucideIcon } from "lucide-react";
import { TrendingUp, TrendingDown, Minus } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────
export interface KpiItem {
  label: string;
  value: string | number;
  subValue?: string;
  trend?: "up" | "down" | "flat";
  trendValue?: string;
  icon?: LucideIcon;
  color?: "green" | "blue" | "amber" | "red" | "purple";
}

export interface QuickAction {
  label: string;
  description?: string;
  icon: LucideIcon;
  href?: string;
  onClick?: () => void;
}

export interface ActivityItem {
  id: string | number;
  icon?: LucideIcon;
  iconColor?: string;
  message: string;
  sub?: string;
  time: string;
  unread?: boolean;
}

// ── Color maps ────────────────────────────────────────────────────────────────
const colorMap: Record<NonNullable<KpiItem["color"]>, string> = {
  green:  "bg-green-50  text-green-600",
  blue:   "bg-blue-50   text-blue-600",
  amber:  "bg-amber-50  text-amber-600",
  red:    "bg-red-50    text-red-600",
  purple: "bg-purple-50 text-purple-600",
};

// ── WorkspaceKpis ─────────────────────────────────────────────────────────────
interface WorkspaceKpisProps {
  items: KpiItem[];
  loading?: boolean;
  className?: string;
}

export function WorkspaceKpis({ items, loading = false, className = "" }: WorkspaceKpisProps) {
  if (loading) {
    return (
      <div className={`grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 ${className}`}>
        {Array.from({ length: 4 }).map((_, i) => (
          <div key={i} className="bg-background rounded-xl border border-border p-5 animate-pulse">
            <div className="h-3 w-24 bg-border rounded mb-3" />
            <div className="h-7 w-32 bg-border rounded mb-2" />
            <div className="h-3 w-16 bg-border rounded" />
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className={`grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 ${className}`}>
      {items.map((item, i) => (
        <KpiCard key={i} item={item} />
      ))}
    </div>
  );
}

function KpiCard({ item }: { item: KpiItem }) {
  const Icon = item.icon;
  const iconCls = colorMap[item.color ?? "green"];
  const TrendIcon = item.trend === "up" ? TrendingUp : item.trend === "down" ? TrendingDown : Minus;
  const trendCls =
    item.trend === "up"
      ? "text-green-600"
      : item.trend === "down"
      ? "text-red-500"
      : "text-text-secondary";

  return (
    <div className="bg-background rounded-xl border border-border p-5 hover:shadow-sm transition-shadow">
      <div className="flex items-start justify-between gap-2">
        <p className="text-sm text-text-secondary font-medium">{item.label}</p>
        {Icon && (
          <div className={`w-8 h-8 rounded-lg flex items-center justify-center shrink-0 ${iconCls}`}>
            <Icon size={16} />
          </div>
        )}
      </div>
      <p className="text-2xl font-bold text-text-primary mt-2">{item.value}</p>
      <div className="flex items-center gap-1.5 mt-1">
        {item.trend && (
          <TrendIcon size={13} className={trendCls} />
        )}
        {item.trendValue && (
          <span className={`text-xs font-medium ${trendCls}`}>{item.trendValue}</span>
        )}
        {item.subValue && (
          <span className="text-xs text-text-secondary">{item.subValue}</span>
        )}
      </div>
    </div>
  );
}

// ── WorkspaceActions ──────────────────────────────────────────────────────────
interface WorkspaceActionsProps {
  actions: QuickAction[];
  title?: string;
  className?: string;
}

export function WorkspaceActions({ actions, title = "Quick actions", className = "" }: WorkspaceActionsProps) {
  if (actions.length === 0) return null;

  return (
    <div className={className}>
      <h2 className="text-sm font-semibold text-text-secondary uppercase tracking-wide mb-3">{title}</h2>
      <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 xl:grid-cols-6 gap-3">
        {actions.map((action, i) => {
          const Icon = action.icon;
          const inner = (
            <>
              <div className="w-10 h-10 rounded-xl bg-primary-100 flex items-center justify-center mx-auto mb-2">
                <Icon size={20} className="text-primary" />
              </div>
              <p className="text-xs font-medium text-text-primary text-center leading-tight">{action.label}</p>
              {action.description && (
                <p className="text-[11px] text-text-secondary text-center mt-0.5 leading-tight">{action.description}</p>
              )}
            </>
          );

          const cls =
            "bg-background border border-border rounded-xl p-4 flex flex-col items-center hover:bg-primary-50 hover:border-accent/40 transition-colors cursor-pointer";

          if (action.href) {
            return (
              <Link key={i} href={action.href} className={cls}>
                {inner}
              </Link>
            );
          }
          return (
            <button key={i} onClick={action.onClick} className={cls}>
              {inner}
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ── WorkspaceActivity ─────────────────────────────────────────────────────────
interface WorkspaceActivityProps {
  items: ActivityItem[];
  title?: string;
  loading?: boolean;
  emptyMessage?: string;
  className?: string;
}

export function WorkspaceActivity({
  items,
  title = "Recent activity",
  loading = false,
  emptyMessage = "No recent activity",
  className = "",
}: WorkspaceActivityProps) {
  return (
    <div className={className}>
      <h2 className="text-sm font-semibold text-text-secondary uppercase tracking-wide mb-3">{title}</h2>
      <div className="bg-background border border-border rounded-xl overflow-hidden">
        {loading ? (
          <div className="divide-y divide-border">
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="flex items-center gap-3 px-4 py-3 animate-pulse">
                <div className="w-8 h-8 rounded-full bg-border shrink-0" />
                <div className="flex-1">
                  <div className="h-3 w-48 bg-border rounded mb-1.5" />
                  <div className="h-2.5 w-24 bg-border rounded" />
                </div>
                <div className="h-2.5 w-12 bg-border rounded" />
              </div>
            ))}
          </div>
        ) : items.length === 0 ? (
          <p className="text-sm text-text-secondary px-4 py-8 text-center">{emptyMessage}</p>
        ) : (
          <div className="divide-y divide-border">
            {items.map((item) => {
              const Icon = item.icon;
              return (
                <div key={item.id} className="flex items-center gap-3 px-4 py-3 hover:bg-background-subtle">
                  {Icon ? (
                    <div
                      className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${item.iconColor ?? "bg-primary-100 text-primary"}`}
                    >
                      <Icon size={14} />
                    </div>
                  ) : (
                    <div className="w-8 h-8 rounded-full bg-border shrink-0" />
                  )}
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-text-primary truncate">
                      {item.unread && <span className="inline-block w-1.5 h-1.5 bg-accent rounded-full mr-1.5 mb-0.5" />}
                      {item.message}
                    </p>
                    {item.sub && <p className="text-xs text-text-secondary truncate">{item.sub}</p>}
                  </div>
                  <p className="text-xs text-text-secondary shrink-0">{item.time}</p>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
