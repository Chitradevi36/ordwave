"use client";

// ─── RiskiestRetailersPanel ──────────────────────────────────────────────────
// Dashboard panel showing top-N highest-risk customers.
// Only shown to owner / admin / manager roles.
// Fetches: GET /api/v1/credit/risk/riskiest?limit=5

import Link from "next/link";
import { ShieldAlert, ChevronRight, RefreshCw } from "lucide-react";
import { useEffect } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { RiskBadge } from "@/components/customers/risk-badge";
import { useRiskiestRetailers } from "@/lib/api/hooks/useRetailerRisk";
import { trackBusinessEvent, ANALYTICS_EVENTS } from "@/lib/analytics";

export function RiskiestRetailersPanel() {
  const { data, loading, error } = useRiskiestRetailers(5);

  // Track panel visibility once data loads
  useEffect(() => {
    if (data.length > 0) {
      trackBusinessEvent(ANALYTICS_EVENTS.RISKIEST_RETAILERS_PANEL_VIEWED, {
        module: "dashboard",
      });
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data.length > 0]);

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-sm font-semibold flex items-center gap-1.5">
          <ShieldAlert className="h-4 w-4 text-danger" />
          Riskiest Retailers
        </CardTitle>
        <Link href="/customers" className="flex items-center text-xs text-accent hover:underline">
          View all <ChevronRight className="h-3 w-3" />
        </Link>
      </CardHeader>
      <CardContent className="p-0">
        {loading && (
          <div className="divide-y divide-border">
            {[1, 2, 3, 4, 5].map((i) => (
              <div key={i} className="flex items-center gap-3 px-4 py-3 animate-pulse">
                <div className="flex-1 space-y-1">
                  <div className="h-3.5 w-32 rounded bg-gray-100" />
                  <div className="h-3 w-48 rounded bg-gray-100" />
                </div>
                <div className="h-5 w-20 rounded-full bg-gray-100" />
              </div>
            ))}
          </div>
        )}

        {error && !loading && (
          <div className="flex items-center gap-2 px-4 py-6 text-sm text-text-secondary">
            <RefreshCw className="h-4 w-4" />
            <span>Could not load risk data.</span>
          </div>
        )}

        {!loading && !error && data.length === 0 && (
          <div className="px-4 py-8 text-center text-sm text-text-secondary">
            No high-risk retailers at this time.
          </div>
        )}

        {!loading && !error && data.length > 0 && (
          <ol className="divide-y divide-border">
            {data.map((r, i) => (
              <li key={r.id}>
                <Link
                  href={`/customers/${r.id}`}
                  className="flex items-center gap-3 px-4 py-3 hover:bg-background-subtle transition-colors"
                >
                  <span className="w-5 shrink-0 text-center text-xs font-bold text-text-secondary">
                    {i + 1}
                  </span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-text-primary truncate">{r.name}</p>
                    <p className="text-xs text-text-secondary truncate">{r.recommendation}</p>
                  </div>
                  <RiskBadge score={r.risk_score} tier={r.risk_tier} compact />
                </Link>
              </li>
            ))}
          </ol>
        )}
      </CardContent>
    </Card>
  );
}
