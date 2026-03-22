"use client";

import { useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Building2, GitBranch, Users, ChevronRight, Plus, UserCircle, Receipt, Upload, CreditCard, Truck, Bell, FileDown, FileText, Shield, Workflow } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { AddBranchModal } from "@/components/add-branch-modal";
import { AddOrganizationModal } from "@/components/add-organization-modal";
import { API_URL } from "@/lib/api/client";

function SkeletonRow() {
  return (
    <div className="flex items-center justify-between px-4 py-2.5">
      <div className="space-y-1.5">
        <div className="h-3.5 w-40 rounded bg-border animate-pulse" />
        <div className="h-2.5 w-56 rounded bg-border/60 animate-pulse" />
      </div>
      <div className="h-4 w-4 rounded bg-border animate-pulse" />
    </div>
  );
}

export default function SettingsPage() {
  const router = useRouter();
  const { branches, branchesLoading, orgsLoading, refetchBranches, refetchOrganizations, switchOrg, token, orgId } = useOrgBranch();

  const [showAddBranch,   setShowAddBranch]   = useState(false);
  const [showAddOrg,      setShowAddOrg]       = useState(false);
  const [importingBranch, setImportingBranch]  = useState(false);
  const [branchImportMsg, setBranchImportMsg]  = useState<{ type: "success" | "error"; text: string } | null>(null);

  const handleBulkImportBranches = useCallback(async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !token || !orgId) return;
    setImportingBranch(true);
    setBranchImportMsg(null);
    try {
      const form = new FormData();
      form.append("file", file);
      const res = await fetch(`${API_URL}/api/v1/branches/bulk_import`, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
        body: form,
      });
      const json = await res.json();
      if (res.status === 401) {
        setBranchImportMsg({ type: "error", text: "Session expired. Please log in again." });
        return;
      }
      if (res.ok) {
        const d = json.data;
        const skippedNote = d.skipped_rows?.length ? ` ${d.skipped_rows.length} skipped.` : "";
        const failedNote  = d.failed_rows?.length  ? ` ${d.failed_rows.length} failed.`  : "";
        setBranchImportMsg({ type: "success", text: `${d.success_count} branches imported.${skippedNote}${failedNote}` });
        refetchBranches();
      } else {
        setBranchImportMsg({ type: "error", text: json.errors?.join(", ") ?? "Import failed" });
      }
    } catch {
      setBranchImportMsg({ type: "error", text: "Network error during import" });
    } finally {
      setImportingBranch(false);
      e.target.value = "";
    }
  }, [token, orgId, refetchBranches]);

  const isLoading = orgsLoading || branchesLoading;

  return (
    <AppShell title="Settings">
      <PageHeader
        title="Settings"
        description="Manage your organization, branches, and team"
        actions={[]}
      />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {/* Invoices */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <FileText className="h-4 w-4 text-accent" />
              Invoices
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 p-0 pb-3">
            <button
              onClick={() => router.push("/settings/invoices")}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
            >
              <div>
                <p className="text-sm font-medium text-text-primary">Invoice Settings</p>
                <p className="text-xs text-text-secondary">Prefix, numbering format, payment terms, auto-generate</p>
              </div>
              <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
            </button>
          </CardContent>
        </Card>
        
        {/* Exports */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <FileDown className="h-4 w-4 text-accent" />
              Exports
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 p-0 pb-3">
            <button
              onClick={() => router.push("/settings/exports")}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
            >
              <div>
                <p className="text-sm font-medium text-text-primary">Export History</p>
                <p className="text-xs text-text-secondary">Download CSV exports of orders, payments, customers and more</p>
              </div>
              <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
            </button>
          </CardContent>
        </Card>

        {/* Tax & Compliance */}
        {/* <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <Receipt className="h-4 w-4 text-accent" />
              Tax &amp; Compliance
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 p-0 pb-3">
            <button
              onClick={() => router.push("/settings/hsn-codes")}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
            >
              <div>
                <p className="text-sm font-medium text-text-primary">HSN / SAC Codes</p>
                <p className="text-xs text-text-secondary">Manage GST rate master &amp; HSN/SAC catalogue</p>
              </div>
              <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
            </button>
          </CardContent>
        </Card> */}

        {/* Fleet */}
        {/* <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <Truck className="h-4 w-4 text-accent" />
              Fleet
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 p-0 pb-3">
            <button
              onClick={() => router.push("/settings/fleet")}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
            >
              <div>
                <p className="text-sm font-medium text-text-primary">Vehicles</p>
                <p className="text-xs text-text-secondary">Add and manage delivery vehicles</p>
              </div>
              <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
            </button>
            <button
              onClick={() => router.push("/users")}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
            >
              <div>
                <p className="text-sm font-medium text-text-primary">Drivers</p>
                <p className="text-xs text-text-secondary">Drivers are org members — manage via Team</p>
              </div>
              <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
            </button>
          </CardContent>
        </Card> */}

        {/* Credit Engine */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <CreditCard className="h-4 w-4 text-accent" />
              Credit Engine
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 p-0 pb-3">
            <button
              onClick={() => router.push("/settings/credit-policy")}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
            >
              <div>
                <p className="text-sm font-medium text-text-primary">Credit Policy</p>
                <p className="text-xs text-text-secondary">Hard block, soft hold, SLA and invoice rules</p>
              </div>
              <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
            </button>
            <button
              onClick={() => router.push("/settings/prepayment-skus")}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
            >
              <div>
                <p className="text-sm font-medium text-text-primary">Prepayment SKUs</p>
                <p className="text-xs text-text-secondary">Products that require advance payment</p>
              </div>
              <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
            </button>
          </CardContent>
        </Card>

        {/* Audit Log */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <Shield className="h-4 w-4 text-accent" />
              Audit &amp; Security
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 p-0 pb-3">
            <button
              onClick={() => router.push("/settings/audit")}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
            >
              <div>
                <p className="text-sm font-medium text-text-primary">Audit Log</p>
                <p className="text-xs text-text-secondary">Track all actions by actors across orders, payments, credit, and more</p>
              </div>
              <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
            </button>
          </CardContent>
        </Card>

        {/* Billing */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <Receipt className="h-4 w-4 text-accent" />
              Billing &amp; Subscription
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 p-0 pb-3">
            <button
              onClick={() => router.push("/settings/billing")}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
            >
              <div>
                <p className="text-sm font-medium text-text-primary">Subscription &amp; Plans</p>
                <p className="text-xs text-text-secondary">Manage your plan, view usage limits, and access payment history</p>
              </div>
              <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
            </button>
          </CardContent>
        </Card>
      </div>

      {/* <AddBranchModal
        open={showAddBranch}
        onClose={() => setShowAddBranch(false)}
        onCreated={() => { refetchBranches(); setShowAddBranch(false); }}
      /> */}

      <AddOrganizationModal
        open={showAddOrg}
        onClose={() => setShowAddOrg(false)}
        onCreated={(newOrgId) => {
          refetchOrganizations();
          if (newOrgId) switchOrg(newOrgId);
        }}
      />
    </AppShell>
  );
}