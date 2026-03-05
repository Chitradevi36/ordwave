"use client";

import { AppShell, PageHeader } from "@/components/layout";
import { Breadcrumb } from "@/components/ui/breadcrumb";
import { SupplierForm } from "@/app/suppliers/_components/supplier-form";
import { useOrgBranch } from "@/lib/org-branch-context";

export default function NewSupplierPage() {
  const { token, orgId } = useOrgBranch();

  return (
    <AppShell title="New Supplier">
      <Breadcrumb items={[
        { label: "Suppliers", href: "/suppliers" },
        { label: "New Supplier" },
      ]} />
      <PageHeader
        title="New Supplier"
        description="Add a new supplier to your organization"
      />
      <div className="mt-6">
        <SupplierForm token={token} orgId={orgId} />
      </div>
    </AppShell>
  );
}
