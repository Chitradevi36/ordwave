"use client";

import { useState, useEffect, useCallback } from "react";
import { BarChart3, RefreshCw, Loader2, TrendingUp } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { fetchAgentQueueStats, type AgentQueueStats } from "@/lib/api/accounting";
import { useOrgBranch } from "@/lib/org-branch-context";

interface AgentSyncQueueStatsProps {
  integrationId: number;
}

export function AgentSyncQueueStats({ integrationId }: AgentSyncQueueStatsProps) {
  const { token, orgId } = useOrgBranch();
  const [stats, setStats] = useState<AgentQueueStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadStats = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const data = await fetchAgentQueueStats(integrationId, token, orgId);
      setStats(data);
    } catch (err: unknown) {
      setError("Failed to load queue statistics.");
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [integrationId, token, orgId]);

  useEffect(() => {
    loadStats();
    // Poll every 15 seconds for queue stats
    const interval = setInterval(loadStats, 15000);
    return () => clearInterval(interval);
  }, [loadStats]);

  if (loading && !stats) {
    return (
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-base flex items-center gap-2">
            <BarChart3 className="h-4 w-4" />
            Sync Queue
          </CardTitle>
        </CardHeader>
        <CardContent className="pt-0">
          <div className="flex items-center justify-center py-8">
            <Loader2 className="h-5 w-5 animate-spin text-text-secondary" />
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <CardTitle className="text-base flex items-center gap-2">
            <BarChart3 className="h-4 w-4" />
            Sync Queue
          </CardTitle>
          <Button
            size="sm"
            variant="ghost"
            onClick={loadStats}
            disabled={loading}
            className="h-7 w-7 p-0"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${loading ? "animate-spin" : ""}`} />
          </Button>
        </div>
      </CardHeader>
      <CardContent className="pt-0">
        {error && (
          <div className="text-sm text-red-600 mb-3">{error}</div>
        )}

        {stats && (
          <div className="space-y-4">
            {/* Active queue items */}
            <div className="space-y-2">
              <StatRow
                label="Pending"
                count={stats.pending}
                color="text-blue-600"
                bgColor="bg-blue-50"
              />
              <StatRow
                label="Processing"
                count={stats.processing}
                color="text-yellow-600"
                bgColor="bg-yellow-50"
                pulse={stats.processing > 0}
              />
              <StatRow
                label="Retrying"
                count={stats.retrying}
                color="text-orange-600"
                bgColor="bg-orange-50"
              />
            </div>

            <div className="border-t border-border pt-3 space-y-2">
              <StatRow
                label="Failed"
                count={stats.failed}
                color="text-red-600"
                bgColor="bg-red-50"
              />
              <StatRow
                label="Success (Total)"
                count={stats.success}
                color="text-green-600"
                bgColor="bg-green-50"
                icon={<TrendingUp className="h-3.5 w-3.5" />}
              />
            </div>

            {/* Agent info */}
            <div className="border-t border-border pt-3">
              <div className="flex items-center justify-between text-xs">
                <span className="text-text-secondary">Agents Online</span>
                <span className="font-medium text-text-primary">
                  {stats.agents_online} / {stats.agents_total}
                </span>
              </div>
            </div>

            {/* Quick link to sync records */}
            <div className="pt-2">
              <a
                href={`/accounting/sync-records?integration_id=${integrationId}`}
                className="text-xs text-primary hover:underline flex items-center gap-1"
              >
                View detailed sync records →
              </a>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

interface StatRowProps {
  label: string;
  count: number;
  color: string;
  bgColor: string;
  pulse?: boolean;
  icon?: React.ReactNode;
}

function StatRow({ label, count, color, bgColor, pulse = false, icon }: StatRowProps) {
  return (
    <div className="flex items-center justify-between py-1.5 px-2 rounded-lg hover:bg-surface transition-colors">
      <div className="flex items-center gap-1.5">
        {icon}
        <span className="text-sm text-text-secondary">{label}</span>
      </div>
      <div className={`flex items-center gap-1.5 ${pulse ? "animate-pulse" : ""}`}>
        <div className={`h-5 min-w-[2rem] flex items-center justify-center rounded px-2 ${bgColor}`}>
          <span className={`text-xs font-semibold ${color}`}>
            {count.toLocaleString()}
          </span>
        </div>
      </div>
    </div>
  );
}
