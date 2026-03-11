"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Building2, Plus, ChevronRight, CheckCircle2, MapPin,
  Mail, Phone, ArrowRightLeft,
} from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { AddOrganizationModal } from "@/components/add-organization-modal";

// Extend the base Org type with fields returned by serialize_org
interface OrgDetail {
  id: number;
  name: string;
  slug: string;
  active: boolean;
  gst_number: string | null;
  city: string | null;
  state: string | null;
  contact_email: string | null;
  contact_phone: string | null;
  created_at: string;
}

function fmtDate(iso: string) {
  try {
    return new Date(iso).toLocaleDateString("en-IN", {
      day: "2-digit", month: "short", year: "numeric",
    });
  } catch { return iso; }
}

function OrgCardSkeleton() {
  return (
    <Card>
      <CardContent className="p-4 space-y-3 animate-pulse">
        <div className="flex items-start justify-between gap-3">
          <div className="space-y-1.5 flex-1">
            <div className="h-4 w-40 rounded bg-border" />
            <div className="h-3 w-28 rounded bg-border/60" />
          </div>
          <div className="h-8 w-24 rounded-md bg-border/60" />
        </div>
        <div className="flex gap-4">
          <div className="h-3 w-32 rounded bg-border/60" />
          <div className="h-3 w-24 rounded bg-border/60" />
        </div>
      </CardContent>
    </Card>
  );
}

export default function OrganizationsPage() {
  const router = useRouter();
  const {
    organizations, orgsLoading, orgId,
    switchOrg, refetchOrganizations,
  } = useOrgBranch();

  const [showAdd, setShowAdd] = useState(false);

  // Cast to extended type — the context stores the full API payload
  const orgs = organizations as unknown as OrgDetail[];
  const currentOrgId = orgId;

  return (
    <AppShell title="Organizations" hideBreadcrumb>
      <PageHeader
        title="Organizations"
        description="View and manage all organizations linked to your account"
        actions={[
          {
            label: "New Organization",
            onClick: () => setShowAdd(true),
            icon: Plus,
          },
        ]}
      />

      {/* List */}
      <div className="space-y-3">
        {orgsLoading ? (
          <>
            <OrgCardSkeleton />
            <OrgCardSkeleton />
          </>
        ) : orgs.length === 0 ? (
          <Card>
            <CardContent className="py-16 flex flex-col items-center text-center gap-3">
              <div className="h-12 w-12 rounded-full bg-background-subtle flex items-center justify-center">
                <Building2 className="h-6 w-6 text-text-secondary" />
              </div>
              <div>
                <p className="font-semibold text-text-primary">No organizations yet</p>
                <p className="text-sm text-text-secondary mt-0.5">
                  Create your first organization to get started.
                </p>
              </div>
              <Button onClick={() => setShowAdd(true)}>
                <Plus className="mr-1.5 h-4 w-4" /> New Organization
              </Button>
            </CardContent>
          </Card>
        ) : (
          orgs.map((org) => {
            const isActive = String(org.id) === currentOrgId;
            return (
              <Card
                key={org.id}
                className={`transition-colors ${isActive ? "border-primary/40 bg-primary/[0.02]" : ""}`}
              >
                <CardContent className="p-4">
                  <div className="flex items-start justify-between gap-4 flex-wrap">
                    {/* Left: name + meta */}
                    <div className="flex items-start gap-3 min-w-0">
                      <div className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-accent/10 text-accent">
                        <Building2 className="h-4.5 w-4.5" />
                      </div>
                      <div className="min-w-0">
                        <div className="flex items-center gap-2 flex-wrap">
                          <p className="text-sm font-semibold text-text-primary leading-snug">
                            {org.name}
                          </p>
                          {isActive && (
                            <Badge variant="default" className="gap-1 text-xs">
                              <CheckCircle2 className="h-3 w-3" /> Active
                            </Badge>
                          )}
                          {!org.active && (
                            <Badge variant="danger" className="text-xs">Inactive</Badge>
                          )}
                        </div>
                        {org.slug && (
                          <p className="text-xs text-text-secondary mt-0.5 font-mono">
                            {org.slug}
                          </p>
                        )}
                        {/* Location / contact row */}
                        <div className="mt-1.5 flex flex-wrap gap-x-4 gap-y-1 text-xs text-text-secondary">
                          {(org.city || org.state) && (
                            <span className="flex items-center gap-1">
                              <MapPin className="h-3 w-3 shrink-0" />
                              {[org.city, org.state].filter(Boolean).join(", ")}
                            </span>
                          )}
                          {org.contact_email && (
                            <span className="flex items-center gap-1">
                              <Mail className="h-3 w-3 shrink-0" />
                              {org.contact_email}
                            </span>
                          )}
                          {org.contact_phone && (
                            <span className="flex items-center gap-1">
                              <Phone className="h-3 w-3 shrink-0" />
                              {org.contact_phone}
                            </span>
                          )}
                          {org.gst_number && (
                            <span className="font-mono">{org.gst_number}</span>
                          )}
                        </div>
                        {org.created_at && (
                          <p className="text-[11px] text-text-secondary mt-1">
                            Created {fmtDate(org.created_at)}
                          </p>
                        )}
                      </div>
                    </div>

                    {/* Right: actions */}
                    <div className="flex items-center gap-2 shrink-0">
                      {!isActive && (
                        <Button
                          size="sm"
                          variant="outline"
                          className="gap-1.5"
                          onClick={() => {
                            switchOrg(String(org.id));
                            router.push("/dashboard");
                          }}
                        >
                          <ArrowRightLeft className="h-3.5 w-3.5" />
                          Switch
                        </Button>
                      )}
                      <Button
                        size="sm"
                        variant={isActive ? "default" : "outline"}
                        className="gap-1.5"
                        onClick={() => {
                          if (!isActive) switchOrg(String(org.id));
                          router.push("/settings/organization");
                        }}
                      >
                        Settings
                        <ChevronRight className="h-3.5 w-3.5" />
                      </Button>
                    </div>
                  </div>
                </CardContent>
              </Card>
            );
          })
        )}
      </div>

      {/* Add org bottom CTA */}
      {/* {!orgsLoading && orgs.length > 0 && (
        <div className="mt-4 flex justify-center">
          <Button variant="outline" onClick={() => setShowAdd(true)}>
            <Plus className="mr-1.5 h-4 w-4" /> Add Another Organization
          </Button>
        </div>
      )} */}

      <AddOrganizationModal
        open={showAdd}
        onClose={() => setShowAdd(false)}
        onCreated={(newOrgId) => {
          refetchOrganizations();
          if (newOrgId) switchOrg(newOrgId);
          setShowAdd(false);
        }}
      />
    </AppShell>
  );
}
