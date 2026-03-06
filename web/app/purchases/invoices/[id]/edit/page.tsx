"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { PurchaseInvoiceForm, PurchaseInvoiceFormData, LineItem } from "@/app/purchases/invoices/_components/purchase-invoice-form";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

export default function EditPurchaseInvoicePage() {
  const params = useParams<{ id: string }>();
  const { token, orgId } = useOrgBranch();

  const [initial,  setInitial]  = useState<(Partial<PurchaseInvoiceFormData> & { lines?: LineItem[] }) | null>(null);
  const [loading,  setLoading]  = useState(true);
  const [notFound, setNotFound] = useState(false);
  const [invoiceNumber, setInvoiceNumber] = useState("");

  const load = useCallback(async () => {
    if (!token || !orgId || !params.id) return;
    const res  = await fetch(`${API_URL}/api/v1/purchase_invoices/${params.id}`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    });
    if (!res.ok) { setNotFound(true); setLoading(false); return; }
    const json = await res.json();
    const inv  = json.data;

    if (inv.status !== "draft") { setNotFound(true); setLoading(false); return; }

    setInvoiceNumber(inv.invoice_number);
    setInitial({
      supplier_id:    String(inv.supplier?.id ?? ""),
      branch_id:      String(inv.branch?.id  ?? ""),
      invoice_number: inv.invoice_number,
      invoice_date:   inv.invoice_date?.split("T")[0] ?? "",
      due_date:       inv.due_date?.split("T")[0] ?? "",
      currency:       inv.currency,
      notes:          inv.notes ?? "",
      lines: (inv.lines ?? []).map((l: Record<string, unknown>) => ({
        id:              l.id as number,
        product_id:      String(l.product_id),
        hsn_sac_code_id: l.hsn_sac_code_id ? String(l.hsn_sac_code_id) : "",
        qty:             String(l.qty),
        unit_price:      String(l.unit_price),
        discount_pct:    String(l.discount_pct),
        tax_rate:        String(l.tax_rate),
        notes:           (l.notes as string) ?? "",
      })),
    });
    setLoading(false);
  }, [token, orgId, params.id]);

  useEffect(() => { load(); }, [load]);

  if (loading) {
    return (
      <AppShell title="Edit Invoice">
        <div className="flex items-center justify-center h-48">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      </AppShell>
    );
  }

  if (notFound || !initial) {
    return (
      <AppShell title="Not Found">
        <div className="flex items-center justify-center h-48 text-text-secondary text-sm">
          Invoice not found or is not editable (only draft invoices can be edited).
        </div>
      </AppShell>
    );
  }

  return (
    <AppShell breadcrumbs={[
        { label: "Purchases", href: "/purchases/invoices" },
        { label: invoiceNumber, href: `/purchases/invoices/${params.id}` },
        { label: "Edit" },
      ]}>
      <PageHeader
        title={`Edit Invoice ${invoiceNumber}`}
        description="Edit this draft purchase invoice"
      />
      <div className="mt-6">
        <PurchaseInvoiceForm
          initial={initial}
          invoiceId={Number(params.id)}
          token={token}
          orgId={orgId}
        />
      </div>
    </AppShell>
  );
}
