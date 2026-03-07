"use client";

import { useState, useEffect } from "react";
import { useParams } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { SupplierForm, SupplierFormData } from "@/app/suppliers/_components/supplier-form";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

export default function EditSupplierPage() {
  const params = useParams<{ id: string }>();
  const { token, orgId } = useOrgBranch();

  const [initial,  setInitial]  = useState<Partial<SupplierFormData> | null>(null);
  const [loading,  setLoading]  = useState(true);
  const [notFound, setNotFound] = useState(false);

  useEffect(() => {
    if (!token || !orgId || !params.id) return;
    fetch(`${API_URL}/api/v1/suppliers/${params.id}`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => {
        if (!r.ok) { setNotFound(true); return null; }
        return r.json();
      })
      .then((json) => {
        if (!json) return;
        const d = json.data;
        setInitial({
          name:               d.name               ?? "",
          code:               d.code               ?? "",
          status:             d.status             ?? "active",
          phone:              d.phone              ?? "",
          email:              d.email              ?? "",
          contact_person:     d.contact_person     ?? "",
          gstin:              d.gstin              ?? "",
          pan:                d.pan                ?? "",
          address:            d.address            ?? "",
          city:               d.city               ?? "",
          state:              d.state              ?? "",
          pincode:            d.pincode            ?? "",
          bank_name:          d.bank_name          ?? "",
          bank_account:       d.bank_account       ?? "",
          bank_ifsc:          d.bank_ifsc          ?? "",
          payment_terms_days: String(d.payment_terms_days ?? 30),
          credit_limit:       d.credit_limit != null ? String(d.credit_limit) : "",
          notes:              d.notes              ?? "",
        });
      })
      .finally(() => setLoading(false));
  }, [token, orgId, params.id]);

  if (loading) {
    return (
      <AppShell title="Edit Supplier">
        <div className="flex items-center justify-center h-48">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      </AppShell>
    );
  }

  if (notFound || !initial) {
    return (
      <AppShell title="Supplier Not Found">
        <div className="flex items-center justify-center h-48 text-text-secondary text-sm">
          Supplier not found.
        </div>
      </AppShell>
    );
  }

  return (
    <AppShell breadcrumbs={[
        { label: "Suppliers", href: "/suppliers" },
        { label: initial.name ?? "Supplier", href: `/suppliers/${params.id}` },
        { label: "Edit" },
      ]}>
      <PageHeader title="Edit Supplier" description={`Editing: ${initial.name}`} />
      <div className="mt-6">
        <SupplierForm
          initial={initial}
          supplierId={Number(params.id)}
          token={token}
          orgId={orgId}
        />
      </div>
    </AppShell>
  );
}
