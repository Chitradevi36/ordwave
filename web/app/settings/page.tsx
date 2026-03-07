"use client";

import { useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Building2, GitBranch, Users, ChevronRight, Plus, UserCircle, Receipt, Upload, CreditCard, Truck } from "lucide-react";
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
        actions={[
          {
            label: "New Organization",
            onClick: () => setShowAddOrg(true),
            icon: Plus,
            variant: "outline",
          },
        ]}
      />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {/* Account */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <UserCircle className="h-4 w-4 text-accent" />
              Account
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 p-0 pb-3">
            <button
              onClick={() => router.push("/settings/account")}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
            >
              <div>
                <p className="text-sm font-medium text-text-primary">Profile &amp; Password</p>
                <p className="text-xs text-text-secondary">Name, phone, and change password</p>
              </div>
              <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
            </button>
          </CardContent>
        </Card>

        {/* Organization */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <Building2 className="h-4 w-4 text-accent" />
              Organization
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 p-0 pb-3">
            <button
              onClick={() => router.push("/settings/organization")}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
            >
              <div>
                <p className="text-sm font-medium text-text-primary">Organization Profile &amp; Settings</p>
                <p className="text-xs text-text-secondary">Name, GSTIN, PAN, timezone, currency</p>
              </div>
              <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
            </button>
          </CardContent>
        </Card>

        {/* Team */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <Users className="h-4 w-4 text-accent" />
              Team
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-1 p-0 pb-3">
            <button
              onClick={() => router.push("/users")}
              className="flex w-full items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
            >
              <div>
                <p className="text-sm font-medium text-text-primary">Team Members</p>
                <p className="text-xs text-text-secondary">Manage users, roles, and invitations</p>
              </div>
              <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
            </button>
          </CardContent>
        </Card>

        {/* Tax & Compliance */}
        <Card>
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
        </Card>

        {/* Fleet */}
        <Card>
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
        </Card>

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

        {/* Branch Settings */}
        <Card className="sm:col-span-2 lg:col-span-3">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <GitBranch className="h-4 w-4 text-accent" />
              Branch Settings
            </CardTitle>
            <div className="flex items-center gap-2">
              <Button size="sm" variant="ghost" onClick={() => document.getElementById("branch-import-input")?.click()} disabled={importingBranch}>
                <Upload className="mr-1.5 h-3.5 w-3.5" /> {importingBranch ? "Importing…" : "Import CSV"}
              </Button>
              <Button size="sm" variant="outline" onClick={() => setShowAddBranch(true)}>
                <Plus className="mr-1.5 h-3.5 w-3.5" /> Add Branch
              </Button>
            </div>
          </CardHeader>

          {/* Hidden file input */}
          <input id="branch-import-input" type="file" accept=".csv" className="sr-only" onChange={handleBulkImportBranches} />

          <CardContent className="grid gap-1 p-0 pb-3 sm:grid-cols-2 lg:grid-cols-3">
            {isLoading ? (
              <>
                <SkeletonRow />
                <SkeletonRow />
              </>
            ) : branches.length === 0 ? (
              <div className="col-span-full px-4 py-6 text-center">
                <GitBranch className="mx-auto mb-2 h-8 w-8 text-text-secondary/40" />
                <p className="text-sm font-medium text-text-primary">No branches yet</p>
                <p className="mt-0.5 text-xs text-text-secondary">Add your first branch to get started.</p>
                <Button size="sm" variant="outline" className="mt-3" onClick={() => setShowAddBranch(true)}>
                  <Plus className="mr-1.5 h-3.5 w-3.5" /> Add Branch
                </Button>
              </div>
            ) : (
              branches.map((branch) => (
                <button
                  key={branch.id}
                  onClick={() => router.push(`/settings/branches/${branch.id}`)}
                  className="flex items-center justify-between px-4 py-2.5 text-left hover:bg-background-subtle transition-colors"
                >
                  <div>
                    <p className="text-sm font-medium text-text-primary">{branch.name}</p>
                    <p className="text-xs text-text-secondary">
                      {branch.code}{branch.city ? `  ${branch.city}` : ""}
                    </p>
                  </div>
                  <ChevronRight className="h-4 w-4 text-text-secondary shrink-0" />
                </button>
              ))
            )}
          </CardContent>
          {/* Import feedback + sample download */}
          <div className="flex items-center gap-3 px-4 pb-3">
            <a href="/samples/sample_branches.csv" download className="text-xs text-accent hover:underline">
              Download sample CSV
            </a>
            {branchImportMsg && (
              <span className={`text-xs font-medium ${
                branchImportMsg.type === "success" ? "text-success" : "text-danger"
              }`}>
                {branchImportMsg.text}
              </span>
            )}
          </div>
        </Card>
      </div>

      <AddBranchModal
        open={showAddBranch}
        onClose={() => setShowAddBranch(false)}
        onCreated={() => { refetchBranches(); setShowAddBranch(false); }}
      />

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