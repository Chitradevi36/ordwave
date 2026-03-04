"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Building2, GitBranch, Users, ChevronRight, Plus } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { AddBranchModal } from "@/components/add-branch-modal";
import { AddOrganizationModal } from "@/components/add-organization-modal";

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
  const { branches, branchesLoading, orgsLoading, refetchBranches, refetchOrganizations, switchOrg } = useOrgBranch();

  const [showAddBranch, setShowAddBranch] = useState(false);
  const [showAddOrg, setShowAddOrg]       = useState(false);

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

        {/* Branch Settings */}
        <Card className="sm:col-span-2 lg:col-span-3">
          <CardHeader className="flex flex-row items-center justify-between">
            <CardTitle className="flex items-center gap-2 text-sm font-semibold">
              <GitBranch className="h-4 w-4 text-accent" />
              Branch Settings
            </CardTitle>
            <Button size="sm" variant="outline" onClick={() => setShowAddBranch(true)}>
              <Plus className="mr-1.5 h-3.5 w-3.5" /> Add Branch
            </Button>
          </CardHeader>
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