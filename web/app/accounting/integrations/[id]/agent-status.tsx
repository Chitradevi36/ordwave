"use client";

import { useState, useEffect, useCallback } from "react";
import { Activity, Download, RefreshCw, CheckCircle2, AlertCircle, Clock, Loader2 } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  fetchAgents,
  registerAgent,
  type AccountingAgent,
  type AgentRegistrationResponse,
} from "@/lib/api/accounting";
import { useOrgBranch } from "@/lib/org-branch-context";

interface AgentStatusProps {
  integrationId: number;
}

export function AgentStatus({ integrationId }: AgentStatusProps) {
  const { token, orgId } = useOrgBranch();
  const [agents, setAgents] = useState<AccountingAgent[]>([]);
  const [loading, setLoading] = useState(true);
  const [registering, setRegistering] = useState(false);
  const [registrationResult, setRegistrationResult] = useState<AgentRegistrationResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  const loadAgents = useCallback(async () => {
    if (!token || !orgId) return;
    setLoading(true);
    setError(null);
    try {
      const data = await fetchAgents(integrationId, token, orgId);
      setAgents(data);
    } catch (err: unknown) {
      setError("Failed to load agent status.");
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [integrationId, token, orgId]);

  useEffect(() => {
    loadAgents();
    // Poll every 30 seconds for agent status
    const interval = setInterval(loadAgents, 30000);
    return () => clearInterval(interval);
  }, [loadAgents]);

  const handleRegisterAgent = async () => {
    if (!token || !orgId) return;
    setRegistering(true);
    setError(null);
    setRegistrationResult(null);
    try {
      const result = await registerAgent(
        integrationId,
        {
          agent_version: "1.0.0",
          os_info: "Manual Registration",
          tally_version: "Unknown",
        },
        token,
        orgId
      );
      setRegistrationResult(result);
      await loadAgents();
    } catch (err: unknown) {
      const message = (err as { response?: { data?: { error?: string } } })?.response?.data?.error ?? "Failed to register agent.";
      setError(message);
    } finally {
      setRegistering(false);
    }
  };

  const handleDownloadAgent = () => {
    // TODO: Replace with actual download URL when agent installer is built
    alert("Agent installer download will be available in the next release.\n\nFor now, use the registration flow to generate API keys.");
  };

  const formatRelativeTime = (timestamp: string | null): string => {
    if (!timestamp) return "Never";
    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffSec = Math.floor(diffMs / 1000);
    const diffMin = Math.floor(diffSec / 60);
    const diffHr = Math.floor(diffMin / 60);

    if (diffSec < 60) return `${diffSec}s ago`;
    if (diffMin < 60) return `${diffMin}m ago`;
    if (diffHr < 24) return `${diffHr}h ago`;
    return date.toLocaleDateString();
  };

  const isAgentOnline = (agent: AccountingAgent): boolean => {
    if (!agent.last_heartbeat_at) return false;
    const heartbeat = new Date(agent.last_heartbeat_at);
    const now = new Date();
    const diffMs = now.getTime() - heartbeat.getTime();
    return diffMs < 2 * 60 * 1000 && agent.status === "online"; // 2 minutes
  };

  if (loading && agents.length === 0) {
    return (
      <Card>
        <CardHeader className="pb-3">
          <CardTitle className="text-base flex items-center gap-2">
            <Activity className="h-4 w-4" />
            Agent Status
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

  const activeAgent = agents.find((a) => isAgentOnline(a));
  const hasAgents = agents.length > 0;

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <CardTitle className="text-base flex items-center gap-2">
            <Activity className="h-4 w-4" />
            Agent Status
          </CardTitle>
          <Button
            size="sm"
            variant="ghost"
            onClick={loadAgents}
            disabled={loading}
            className="h-7 w-7 p-0"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${loading ? "animate-spin" : ""}`} />
          </Button>
        </div>
      </CardHeader>
      <CardContent className="pt-0 space-y-4">
        {/* Error message */}
        {error && (
          <div className="flex items-start gap-2 bg-red-50 border border-red-200 rounded-lg px-3 py-2 text-sm text-red-700">
            <AlertCircle className="h-4 w-4 shrink-0 mt-px" />
            <span>{error}</span>
          </div>
        )}

        {/* Registration success message */}
        {registrationResult && (
          <div className="bg-green-50 border border-green-200 rounded-lg p-3 space-y-2">
            <div className="flex items-start gap-2 text-sm text-green-700">
              <CheckCircle2 className="h-4 w-4 shrink-0 mt-px" />
              <span className="font-medium">Agent Registered Successfully</span>
            </div>
            <div className="pl-6 space-y-1 text-xs text-green-800">
              <div>
                <span className="font-medium">Agent ID:</span>{" "}
                <code className="bg-green-100 px-1.5 py-0.5 rounded">{registrationResult.agent_id}</code>
              </div>
              <div>
                <span className="font-medium">API Key:</span>{" "}
                <code className="bg-green-100 px-1.5 py-0.5 rounded break-all">{registrationResult.api_key}</code>
              </div>
              <p className="text-green-700 mt-2 italic">
                ⚠️ Save this API key securely. It will not be shown again.
              </p>
            </div>
          </div>
        )}

        {/* Connection status */}
        <div className="space-y-2">
          <div className="flex items-center gap-2">
            <div
              className={`h-2.5 w-2.5 rounded-full ${
                activeAgent ? "bg-green-500 animate-pulse" : "bg-red-500"
              }`}
            />
            <span className="text-sm font-medium text-text-primary">
              {activeAgent ? "Connected" : "Disconnected"}
            </span>
          </div>

          {activeAgent && (
            <div className="ml-4.5 space-y-1.5 text-xs text-text-secondary">
              <div className="flex items-center gap-1.5">
                <Clock className="h-3 w-3" />
                <span>Last heartbeat: {formatRelativeTime(activeAgent.last_heartbeat_at)}</span>
              </div>
              {activeAgent.agent_version && (
                <div>
                  <span className="font-medium">Version:</span> {activeAgent.agent_version}
                </div>
              )}
              {activeAgent.os_info && (
                <div>
                  <span className="font-medium">OS:</span> {activeAgent.os_info}
                </div>
              )}
              {activeAgent.tally_version && (
                <div>
                  <span className="font-medium">Tally:</span> {activeAgent.tally_version}
                </div>
              )}
              <div>
                <span className="font-medium">Registered:</span>{" "}
                {new Date(activeAgent.registered_at).toLocaleDateString()}
              </div>
            </div>
          )}

          {!activeAgent && hasAgents && (
            <p className="ml-4.5 text-xs text-text-secondary">
              Agent is offline. Last seen: {formatRelativeTime(agents[0]?.last_heartbeat_at)}
            </p>
          )}
        </div>

        {/* All agents list (if multiple) */}
        {agents.length > 1 && (
          <div className="pt-3 border-t border-border">
            <p className="text-xs font-medium text-text-secondary mb-2">All Agents ({agents.length})</p>
            <div className="space-y-1.5">
              {agents.map((agent) => (
                <div key={agent.id} className="flex items-center justify-between text-xs">
                  <span className="text-text-secondary font-mono">{agent.agent_id.slice(0, 20)}...</span>
                  <Badge
                    variant={isAgentOnline(agent) ? "default" : "secondary"}
                    className="text-[10px] px-1.5 py-0"
                  >
                    {agent.status}
                  </Badge>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Action buttons */}
        <div className="flex flex-col gap-2 pt-2">
          {!hasAgents && (
            <Button
              size="sm"
              onClick={handleRegisterAgent}
              disabled={registering}
              className="w-full"
            >
              {registering ? (
                <Loader2 className="mr-2 h-3.5 w-3.5 animate-spin" />
              ) : (
                <CheckCircle2 className="mr-2 h-3.5 w-3.5" />
              )}
              Register Agent
            </Button>
          )}
          <Button
            size="sm"
            variant="outline"
            onClick={handleDownloadAgent}
            className="w-full"
          >
            <Download className="mr-2 h-3.5 w-3.5" />
            Download Agent Installer
          </Button>
        </div>

        {/* Instructions */}
        <div className="pt-3 border-t border-border">
          <p className="text-xs text-text-secondary leading-relaxed">
            The OrderLane Tally Agent runs on your local machine and syncs data with Tally in real-time.
            Download the installer and use the API key shown above during setup.
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
