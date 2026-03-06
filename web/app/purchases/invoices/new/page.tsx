"use client";

import { AppShell, PageHeader } from "@/components/layout";

import { PurchaseInvoiceForm } from "@/app/purchases/invoices/_components/purchase-invoice-form";
import { useOrgBranch } from "@/lib/org-branch-context";

export default function NewPurchaseInvoicePage() {
  const { token, orgId } = useOrgBranch();

  return (
    <AppShell title="New Purchase Invoice" breadcrumbs={[
      { label: "Purchases", href: "/purchases/invoices" },
      { label: "New Invoice" },
    ]}>
      <PageHeader
        title="New Purchase Invoice"
        description="Record a new supplier invoice"
      />
      <div className="mt-6">
        <PurchaseInvoiceForm token={token} orgId={orgId} />
      </div>
    </AppShell>
  );
}
