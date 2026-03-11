"use client";

// ─── RiskBadge ──────────────────────────────────────────────────────────────
// Compact inline badge for a retailer's computed risk tier + score.
// Usage: <RiskBadge score={62} tier="high" />
// Usage (compact icon-only): <RiskBadge score={62} tier="high" compact />

import { AlertTriangle, ShieldCheck, ShieldAlert, ShieldOff } from "lucide-react";

export type RiskTier = "low" | "medium" | "high" | "critical";

const TIER_CONFIG: Record<
  RiskTier,
  { label: string; bg: string; text: string; border: string; Icon: React.ElementType }
> = {
  low:      { label: "Low Risk",      bg: "bg-green-50",  text: "text-green-700",  border: "border-green-200",  Icon: ShieldCheck  },
  medium:   { label: "Medium Risk",   bg: "bg-amber-50",  text: "text-amber-700",  border: "border-amber-200",  Icon: AlertTriangle },
  high:     { label: "High Risk",     bg: "bg-orange-50", text: "text-orange-700", border: "border-orange-200", Icon: ShieldAlert   },
  critical: { label: "Critical Risk", bg: "bg-red-50",    text: "text-red-700",    border: "border-red-200",    Icon: ShieldOff     },
};

interface RiskBadgeProps {
  score: number;
  tier: RiskTier;
  /** When true renders a minimal pill (score only, no label) */
  compact?: boolean;
  className?: string;
}

export function RiskBadge({ score, tier, compact = false, className = "" }: RiskBadgeProps) {
  const cfg = TIER_CONFIG[tier] ?? TIER_CONFIG.low;
  const { Icon } = cfg;

  if (compact) {
    return (
      <span
        className={`inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-xs font-semibold
          ${cfg.bg} ${cfg.text} ${cfg.border} ${className}`}
        title={`${cfg.label} — score ${score}`}
      >
        <Icon className="h-3 w-3 shrink-0" />
        {score}
      </span>
    );
  }

  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-medium
        ${cfg.bg} ${cfg.text} ${cfg.border} ${className}`}
    >
      <Icon className="h-3.5 w-3.5 shrink-0" />
      <span>{cfg.label}</span>
      <span className="font-bold tabular-nums ml-0.5">{score}</span>
    </span>
  );
}
