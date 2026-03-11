"use client";

// ─── RiskWidget ─────────────────────────────────────────────────────────────
// Expanded risk card for the customer detail page Credit tab.
// Shows: score dial, tier badge, recommendation, factor chips, recompute btn.

import { useState } from "react";
import { RefreshCw, ChevronDown, ChevronUp, AlertTriangle, Clock } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { RiskBadge, type RiskTier } from "@/components/customers/risk-badge";
import { useRetailerRisk, type RiskFactor } from "@/lib/api/hooks/useRetailerRisk";
import { trackBusinessEvent, ANALYTICS_EVENTS } from "@/lib/analytics";

// Score dial arc gauge (SVG-based, no external chart lib needed)
function ScoreDial({ score }: { score: number }) {
  const pct      = Math.min(100, Math.max(0, score)) / 100;
  const radius   = 36;
  const cx       = 50;
  const cy       = 52;
  const circumf  = Math.PI * radius;          // half-circle circumference
  const strokeBg = circumf;
  const strokeFg = circumf * pct;

  const tierColor =
    score < 25  ? "#16a34a"
    : score < 50 ? "#d97706"
    : score < 75 ? "#ea580c"
    : "#dc2626";

  // Pre-computed arc values to avoid template-literal ambiguity in JSX
  const arcPath  = `M ${cx - radius} ${cy} a ${radius} ${radius} 0 0 1 ${radius * 2} 0`;
  const dashArr  = `${strokeFg} ${strokeBg}`;
  const ariaLbl  = `Risk score ${score}`;
  const textY1   = cy - 2;
  const textY2   = cy + 10;

  return (
    <svg viewBox="0 0 100 56" className="w-24 h-14" aria-label={ariaLbl}>
      {/* Background arc */}
      <path
        d={arcPath}
        fill="none"
        stroke="#e5e7eb"
        strokeWidth={10}
        strokeLinecap="round"
      />
      {/* Foreground arc */}
      <path
        d={arcPath}
        fill="none"
        stroke={tierColor}
        strokeWidth={10}
        strokeLinecap="round"
        strokeDasharray={dashArr}
        style={{ transition: "stroke-dasharray 0.6s ease" }}
      />
      <text
        x={cx}
        y={textY1}
        textAnchor="middle"
        fontSize={18}
        fontWeight={700}
        fill={tierColor}
      >
        {score}
      </text>
      <text x={cx} y={textY2} textAnchor="middle" fontSize={8} fill="#6b7280">
        {"/ 100"}
      </text>
    </svg>
  );
}

// Factor chip row
function FactorChip({ factor }: { factor: RiskFactor }) {
  const [open, setOpen] = useState(false);
  const positive = factor.points > 0;
  const neutral  = factor.points === 0;

  return (
    <div
      className={`rounded-md border px-3 py-2 text-xs cursor-pointer transition-colors
        ${positive ? "bg-red-50 border-red-200 text-red-700" : neutral ? "bg-gray-50 border-gray-200 text-text-secondary" : "bg-green-50 border-green-200 text-green-700"}`}
      onClick={() => setOpen((o) => !o)}
    >
      <div className="flex items-center justify-between gap-2">
        <span className="font-medium">{factor.label}</span>
        <div className="flex items-center gap-1.5">
          <span className={`font-bold tabular-nums ${positive ? "text-red-700" : "text-green-700"}`}>
            {positive ? `+${factor.points}` : factor.points === 0 ? "0" : factor.points}
          </span>
          {open ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />}
        </div>
      </div>
      {open && (
        <p className="mt-1.5 text-[11px] text-text-secondary leading-snug">{factor.detail}</p>
      )}
    </div>
  );
}

function fmtTime(iso: string) {
  try {
    return new Date(iso).toLocaleString("en-IN", {
      day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit",
    });
  } catch { return iso; }
}

// ── Main Export ────────────────────────────────────────────────────────────

interface RiskWidgetProps {
  customerId: string | number;
  /** If true (manager+), shows the Recompute button */
  canRecompute?: boolean;
}

export function RiskWidget({ customerId, canRecompute = false }: RiskWidgetProps) {
  const { data, loading, error, recompute, recomputing } = useRetailerRisk(customerId);
  const [showFactors, setShowFactors] = useState(false);

  const handleRecompute = async () => {
    await recompute();
    trackBusinessEvent(ANALYTICS_EVENTS.RISK_RECOMPUTED, {
      module: "credit_risk",
      customer_id: customerId,
    });
  };

  if (loading) {
    return (
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm">Risk Profile</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex gap-4 animate-pulse">
            <div className="h-14 w-24 rounded bg-gray-100" />
            <div className="flex-1 space-y-2">
              <div className="h-4 w-32 rounded bg-gray-100" />
              <div className="h-3 w-48 rounded bg-gray-100" />
              <div className="h-3 w-40 rounded bg-gray-100" />
            </div>
          </div>
        </CardContent>
      </Card>
    );
  }

  if (error) {
    return (
      <Card>
        <CardHeader className="pb-2">
          <CardTitle className="text-sm">Risk Profile</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="flex items-center gap-2 text-sm text-danger">
            <AlertTriangle className="h-4 w-4" />
            <span>Could not load risk profile.</span>
          </div>
        </CardContent>
      </Card>
    );
  }

  if (!data) return null;

  const activeFactors = data.factors.filter((f) => f.points !== 0);

  return (
    <Card>
      <CardHeader className="pb-2 flex flex-row items-center justify-between">
        <CardTitle className="text-sm font-semibold">Risk Profile</CardTitle>
        {canRecompute && (
          <Button
            size="sm"
            variant="outline"
            className="gap-1.5 h-7 text-xs"
            disabled={recomputing}
            onClick={handleRecompute}
          >
            <RefreshCw className={`h-3 w-3 ${recomputing ? "animate-spin" : ""}`} />
            {recomputing ? "Recomputing…" : "Recompute"}
          </Button>
        )}
      </CardHeader>
      <CardContent className="space-y-3">
        {/* Score dial + tier badge + recommendation */}
        <div className="flex items-start gap-4">
          <ScoreDial score={data.risk_score} />
          <div className="flex-1 min-w-0 pt-1">
            <RiskBadge score={data.risk_score} tier={data.risk_tier} />
            <p className="text-xs text-text-secondary mt-2 leading-snug">{data.recommendation}</p>
          </div>
        </div>

        {/* Stale / computed_at */}
        <div className="flex items-center gap-1.5 text-[11px] text-text-secondary">
          <Clock className="h-3 w-3" />
          <span>
            Computed {fmtTime(data.computed_at)}
            {data.stale && (
              <span className="ml-2 text-amber-600 font-medium">· Stale — recompute for latest score</span>
            )}
          </span>
        </div>

        {/* Factor chips toggle */}
        {activeFactors.length > 0 && (
          <>
            <button
              className="flex items-center gap-1 text-xs font-medium text-accent hover:underline"
              onClick={() => setShowFactors((o) => !o)}
            >
              {showFactors ? <ChevronUp className="h-3.5 w-3.5" /> : <ChevronDown className="h-3.5 w-3.5" />}
              {showFactors ? "Hide" : "Show"} {activeFactors.length} risk factor{activeFactors.length !== 1 ? "s" : ""}
            </button>
            {showFactors && (
              <div className="grid gap-1.5 sm:grid-cols-2">
                {activeFactors.map((f) => <FactorChip key={f.key} factor={f} />)}
              </div>
            )}
          </>
        )}
        {activeFactors.length === 0 && (
          <p className="text-xs text-success font-medium">No active risk signals — this retailer looks healthy.</p>
        )}
      </CardContent>
    </Card>
  );
}
