"use client";

import { useState, useEffect, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Tabs } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Modal } from "@/components/ui/modal";
import { Input } from "@/components/ui/input";
import { DataTable, Column } from "@/components/ui/data-table";
import { Pencil, Ban, CheckCircle2, Plus, Trash2, ExternalLink } from "lucide-react";
import { useOrgBranch } from "@/lib/org-branch-context";
import { API_URL } from "@/lib/api/client";

// ─── Types ────────────────────────────────────────────────────────────────────
interface SupplierProduct {
  id: number;
  product_id: number;
  product_name: string | null;
  product_sku: string | null;
  purchase_price: number | null;
  supplier_sku: string | null;
  lead_time_days: number | null;
}

interface SupplierDetail {
  id: number;
  name: string;
  code: string;
  status: string;
  phone: string | null;
  email: string | null;
  contact_person: string | null;
  gstin: string | null;
  pan: string | null;
  address: string | null;
  city: string | null;
  state: string | null;
  pincode: string | null;
  bank_name: string | null;
  bank_account: string | null;
  bank_ifsc: string | null;
  payment_terms_days: number;
  credit_limit: number | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
  supplier_products: SupplierProduct[];
}

interface Product {
  id: number;
  name: string;
  sku: string;
}

const STATUS_VARIANT: Record<string, "success" | "secondary" | "danger"> = {
  active:      "success",
  inactive:    "secondary",
  blacklisted: "danger",
};

// ─── AddProductModal ──────────────────────────────────────────────────────────
function AddProductModal({
  supplierId, token, orgId, existing, onClose, onAdded,
}: {
  supplierId: number;
  token:      string | null;
  orgId:      string | null;
  existing:   number[];          // product_ids already linked
  onClose:    () => void;
  onAdded:    () => void;
}) {
  const [products, setProducts] = useState<Product[]>([]);
  const [productId, setProductId] = useState("");
  const [price,     setPrice]     = useState("");
  const [sku,       setSku]       = useState("");
  const [leadDays,  setLeadDays]  = useState("");
  const [saving,    setSaving]    = useState(false);
  const [errors,    setErrors]    = useState<string[]>([]);

  useEffect(() => {
    if (!token || !orgId) return;
    fetch(`${API_URL}/api/v1/products?per_page=200`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => setProducts((j.data ?? []).filter((p: Product) => !existing.includes(p.id))));
  }, [token, orgId, existing]);

  const handleSave = async () => {
    if (!token || !orgId || !productId) return;
    setSaving(true); setErrors([]);
    const res = await fetch(`${API_URL}/api/v1/suppliers/${supplierId}/supplier_products`, {
      method:  "POST",
      headers: {
        "Content-Type":      "application/json",
        Authorization:       `Bearer ${token}`,
        "X-Organization-Id": orgId,
      },
      body: JSON.stringify({
        supplier_product: {
          product_id:     Number(productId),
          purchase_price: price     ? Number(price)    : undefined,
          supplier_sku:   sku       || undefined,
          lead_time_days: leadDays  ? Number(leadDays) : undefined,
        },
      }),
    });
    const json = await res.json();
    if (res.ok) { onAdded(); onClose(); }
    else setErrors(json.errors ?? ["Failed to add product"]);
    setSaving(false);
  };

  return (
    <Modal open onClose={onClose} title="Add Product to Supplier">
      <div className="space-y-4">
        {errors.length > 0 && (
          <div className="rounded-md bg-danger/8 border border-danger/20 px-4 py-2 text-sm text-danger">
            {errors.join(", ")}
          </div>
        )}
        <div className="space-y-1.5">
          <label className="text-sm font-medium text-text-primary">Product <span className="text-danger">*</span></label>
          <select
            className="h-9 w-full rounded-md border border-border bg-background px-3 text-sm text-text-primary focus:outline-none focus:ring-2 focus:ring-accent"
            value={productId}
            onChange={(e) => setProductId(e.target.value)}
          >
            <option value="">Select product…</option>
            {products.map((p) => (
              <option key={p.id} value={String(p.id)}>{p.name} ({p.sku})</option>
            ))}
          </select>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Purchase Price (₹)</label>
            <Input type="number" min="0" step="0.01" value={price} onChange={(e) => setPrice(e.target.value)} placeholder="0.00" />
          </div>
          <div className="space-y-1.5">
            <label className="text-sm font-medium text-text-primary">Lead Time (days)</label>
            <Input type="number" min="0" value={leadDays} onChange={(e) => setLeadDays(e.target.value)} placeholder="0" />
          </div>
        </div>
        <div className="space-y-1.5">
          <label className="text-sm font-medium text-text-primary">Supplier SKU</label>
          <Input value={sku} onChange={(e) => setSku(e.target.value)} placeholder="Supplier's internal SKU" />
        </div>
        <div className="flex justify-end gap-2 border-t border-border pt-3">
          <Button variant="outline" onClick={onClose} disabled={saving}>Cancel</Button>
          <Button onClick={handleSave} disabled={saving || !productId}>
            {saving ? "Adding…" : "Add Product"}
          </Button>
        </div>
      </div>
    </Modal>
  );
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────
function OverviewTab({ supplier }: { supplier: SupplierDetail }) {
  const field = (label: string, value: string | number | null | undefined) => (
    <div key={label}>
      <dt className="text-xs font-medium text-text-secondary uppercase tracking-wide">{label}</dt>
      <dd className="mt-0.5 text-sm text-text-primary">{value ?? <span className="text-text-secondary">—</span>}</dd>
    </div>
  );

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 rounded-lg border border-border bg-background p-5">
        <div>
          <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">General</p>
          <dl className="space-y-3">
            {field("Contact Person", supplier.contact_person)}
            {field("Phone",          supplier.phone)}
            {field("Email",          supplier.email)}
            {field("Status",         supplier.status.charAt(0).toUpperCase() + supplier.status.slice(1))}
          </dl>
        </div>
        <div>
          <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">Tax & Legal</p>
          <dl className="space-y-3">
            {field("GSTIN", supplier.gstin)}
            {field("PAN",   supplier.pan)}
          </dl>
        </div>
        <div>
          <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">Address</p>
          <dl className="space-y-3">
            {field("Street",  supplier.address)}
            {field("City",    supplier.city)}
            {field("State",   supplier.state)}
            {field("Pincode", supplier.pincode)}
          </dl>
        </div>
        <div>
          <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">Banking</p>
          <dl className="space-y-3">
            {field("Bank Name", supplier.bank_name)}
            {field("Account",   supplier.bank_account ? `****${String(supplier.bank_account).slice(-4)}` : null)}
            {field("IFSC",      supplier.bank_ifsc)}
          </dl>
        </div>
        <div>
          <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">Commercial</p>
          <dl className="space-y-3">
            {field("Payment Terms",
              supplier.payment_terms_days === 0
                ? "Immediate"
                : `Net ${supplier.payment_terms_days} days`)}
            {field("Credit Limit",
              supplier.credit_limit != null
                ? `₹${supplier.credit_limit.toLocaleString("en-IN")}`
                : "Unlimited")}
          </dl>
        </div>
        {supplier.notes && (
          <div className="sm:col-span-2 lg:col-span-3">
            <p className="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-2">Notes</p>
            <p className="text-sm text-text-primary whitespace-pre-line">{supplier.notes}</p>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── Products Tab ─────────────────────────────────────────────────────────────
function ProductsTab({
  supplier, token, orgId, onRefresh,
}: {
  supplier:  SupplierDetail;
  token:     string | null;
  orgId:     string | null;
  onRefresh: () => void;
}) {
  const [showAdd,      setShowAdd]      = useState(false);
  const [removing,     setRemoving]     = useState<number | null>(null);

  const handleRemove = async (spId: number) => {
    if (!token || !orgId) return;
    if (!confirm("Remove this product from supplier?")) return;
    setRemoving(spId);
    await fetch(`${API_URL}/api/v1/suppliers/${supplier.id}/supplier_products/${spId}`, {
      method:  "DELETE",
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    });
    setRemoving(null);
    onRefresh();
  };

  const columns: Column<SupplierProduct>[] = [
    {
      key:    "product_name",
      header: "Product",
      render: (_: unknown, row: SupplierProduct) => (
        <div>
          <p className="text-sm font-medium text-text-primary">{row.product_name ?? "—"}</p>
          <p className="text-xs text-text-secondary font-mono">{row.product_sku ?? ""}</p>
        </div>
      ),
    },
    {
      key:    "supplier_sku",
      header: "Supplier SKU",
      render: (v) => <span className="text-sm font-mono text-text-secondary">{(v as string) ?? "—"}</span>,
    },
    {
      key:    "purchase_price",
      header: "Purchase Price",
      render: (v) => (
        <span className="text-sm text-text-primary">
          {v != null ? `₹${Number(v).toLocaleString("en-IN", { minimumFractionDigits: 2 })}` : "—"}
        </span>
      ),
    },
    {
      key:    "lead_time_days",
      header: "Lead Time",
      render: (v) => (
        <span className="text-sm text-text-secondary">
          {v != null ? `${v} day${Number(v) !== 1 ? "s" : ""}` : "—"}
        </span>
      ),
    },
    {
      key:    "remove_col",
      header: "",
      render: (_: unknown, row: SupplierProduct) => (
        <button
          onClick={(e) => { e.stopPropagation(); handleRemove(row.id); }}
          disabled={removing === row.id}
          className="p-1 rounded hover:bg-muted text-text-secondary hover:text-danger transition-colors disabled:opacity-40"
          title="Remove"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-4">
      <div className="flex justify-end">
        <Button size="sm" onClick={() => setShowAdd(true)}>
          <Plus className="h-4 w-4 mr-1" /> Add Product
        </Button>
      </div>

      <DataTable
        columns={columns}
        data={supplier.supplier_products}
        emptyMessage="No products linked to this supplier yet."
      />

      {showAdd && (
        <AddProductModal
          supplierId={supplier.id}
          token={token}
          orgId={orgId}
          existing={supplier.supplier_products.map((sp) => sp.product_id)}
          onClose={() => setShowAdd(false)}
          onAdded={onRefresh}
        />
      )}
    </div>
  );
}

// ─── Invoices Tab ─────────────────────────────────────────────────────────────
interface SupplierInvoice {
  id: number;
  invoice_number: string;
  invoice_date:   string;
  status:         string;
  grand_total:    number;
  due_date:       string | null;
}

const INV_STATUS_VARIANT: Record<string, "success" | "secondary" | "danger"> = {
  draft: "secondary", posted: "success", cancelled: "danger",
};

function fmt(n: number) {
  return `₹${Number(n).toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}
function fdate(d: string) {
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

function InvoicesTab({
  supplierId, token, orgId,
}: {
  supplierId: number;
  token:      string | null;
  orgId:      string | null;
}) {
  const router = useRouter();
  const [invoices, setInvoices] = useState<SupplierInvoice[]>([]);
  const [loading,  setLoading]  = useState(false);

  useEffect(() => {
    if (!token || !orgId) return;
    setLoading(true);
    fetch(`${API_URL}/api/v1/purchase_invoices?supplier_id=${supplierId}&per_page=50`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    })
      .then((r) => r.json())
      .then((j) => setInvoices(j.data ?? []))
      .finally(() => setLoading(false));
  }, [token, orgId, supplierId]);

  const columns: Column<SupplierInvoice>[] = [
    {
      key: "invoice_number",
      header: "Invoice #",
      render: (_: unknown, row: SupplierInvoice) => (
        <span className="font-medium font-mono text-text-primary">{row.invoice_number}</span>
      ),
    },
    {
      key: "invoice_date",
      header: "Date",
      render: (v) => <span className="text-sm text-text-secondary">{fdate(v as string)}</span>,
    },
    {
      key: "status",
      header: "Status",
      render: (_: unknown, row: SupplierInvoice) => (
        <Badge variant={INV_STATUS_VARIANT[row.status] ?? "secondary"}>
          {row.status.charAt(0).toUpperCase() + row.status.slice(1)}
        </Badge>
      ),
    },
    {
      key: "grand_total",
      header: "Grand Total",
      render: (v) => <span className="text-sm font-medium text-text-primary">{fmt(Number(v))}</span>,
    },
    {
      key: "due_date",
      header: "Due Date",
      render: (v) => <span className="text-sm text-text-secondary">{v ? fdate(v as string) : "—"}</span>,
    },
    {
      key: "view",
      header: "",
      render: (_: unknown, row: SupplierInvoice) => (
        <button
          onClick={(e) => { e.stopPropagation(); router.push(`/purchases/invoices/${row.id}`); }}
          className="p-1 rounded hover:bg-muted text-text-secondary hover:text-accent transition-colors"
          title="View invoice"
        >
          <ExternalLink className="h-3.5 w-3.5" />
        </button>
      ),
    },
  ];

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="h-5 w-5 animate-spin rounded-full border-2 border-accent border-t-transparent" />
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="flex justify-end">
        <Button size="sm" onClick={() => router.push(`/purchases/invoices/new?supplier_id=${supplierId}`)}>
          <Plus className="h-4 w-4 mr-1" /> New Invoice
        </Button>
      </div>
      <DataTable
        columns={columns}
        data={invoices}
        onRowClick={(row) => router.push(`/purchases/invoices/${row.id}`)}
        emptyMessage="No purchase invoices for this supplier."
      />
    </div>
  );
}

// ─── Activity Tab ─────────────────────────────────────────────────────────────
function ActivityTab() {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-text-secondary">
      <p className="text-sm">Activity log will be available once the audit trail API is wired.</p>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────
export default function SupplierDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const { token, orgId } = useOrgBranch();

  const [supplier,     setSupplier]     = useState<SupplierDetail | null>(null);
  const [loading,      setLoading]      = useState(true);
  const [notFound,     setNotFound]     = useState(false);
  const [actionLoading, setActionLoading] = useState(false);

  const fetchSupplier = useCallback(async () => {
    if (!token || !orgId || !params.id) return;
    setLoading(true);
    const res  = await fetch(`${API_URL}/api/v1/suppliers/${params.id}`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    });
    if (!res.ok) { setNotFound(true); setLoading(false); return; }
    const json = await res.json();
    setSupplier(json.data);
    setLoading(false);
  }, [token, orgId, params.id]);

  useEffect(() => { fetchSupplier(); }, [fetchSupplier]);

  const handleStatusAction = async (action: "blacklist" | "activate") => {
    if (!token || !orgId || !supplier) return;
    setActionLoading(true);
    const res = await fetch(`${API_URL}/api/v1/suppliers/${supplier.id}/${action}`, {
      method:  "POST",
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    });
    if (res.ok) fetchSupplier();
    setActionLoading(false);
  };

  const handleDelete = async () => {
    if (!token || !orgId || !supplier) return;
    const reason = prompt("Reason for deleting this supplier (optional):");
    if (reason === null) return; // user cancelled
    setActionLoading(true);
    const res = await fetch(`${API_URL}/api/v1/suppliers/${supplier.id}`, {
      method:  "DELETE",
      headers: {
        "Content-Type":      "application/json",
        Authorization:       `Bearer ${token}`,
        "X-Organization-Id": orgId,
      },
      body: JSON.stringify({ reason }),
    });
    if (res.ok) router.push("/suppliers");
    setActionLoading(false);
  };

  if (loading) {
    return (
      <AppShell title="Supplier">
        <div className="flex items-center justify-center h-48">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-accent border-t-transparent" />
        </div>
      </AppShell>
    );
  }

  if (notFound || !supplier) {
    return (
      <AppShell title="Supplier Not Found">
        <div className="flex items-center justify-center h-48 text-text-secondary text-sm">
          Supplier not found.
        </div>
      </AppShell>
    );
  }

  const actions = [
    {
      label:   "Edit",
      onClick: () => router.push(`/suppliers/${supplier.id}/edit`),
      icon:    Pencil,
      variant: "outline" as const,
    },
    ...(supplier.status !== "blacklisted"
      ? [{
          label:    "Blacklist",
          onClick:  () => handleStatusAction("blacklist"),
          icon:     Ban,
          variant:  "outline" as const,
          disabled: actionLoading,
        }]
      : [{
          label:    "Activate",
          onClick:  () => handleStatusAction("activate"),
          icon:     CheckCircle2,
          variant:  "outline" as const,
          disabled: actionLoading,
        }]
    ),
    {
      label:    "Delete",
      onClick:  handleDelete,
      icon:     Trash2,
      variant:  "danger" as const,
      disabled: actionLoading,
    },
  ];

  const tabs = [
    {
      value:   "overview",
      label:   "Overview",
      content: <OverviewTab supplier={supplier} />,
    },
    {
      value:   "products",
      label:   `Products (${supplier.supplier_products.length})`,
      content: (
        <ProductsTab
          supplier={supplier}
          token={token}
          orgId={orgId}
          onRefresh={fetchSupplier}
        />
      ),
    },
    {
      value:   "activity",
      label:   "Activity",
      content: <ActivityTab />,
    },
    {
      value:   "invoices",
      label:   "Purchase Invoices",
      content: (
        <InvoicesTab
          supplierId={supplier.id}
          token={token}
          orgId={orgId}
        />
      ),
    },
  ];

  return (
    <AppShell breadcrumbs={[
        { label: "Suppliers", href: "/suppliers" },
        { label: supplier.name },
      ]}>
      <PageHeader
        title={supplier.name}
        description={
          <span className="flex items-center gap-2">
            <span className="text-text-secondary font-mono text-sm">{supplier.code}</span>
            <Badge variant={STATUS_VARIANT[supplier.status] ?? "secondary"}>
              {supplier.status.charAt(0).toUpperCase() + supplier.status.slice(1)}
            </Badge>
          </span>
        }
        actions={actions}
      />

      <div className="mt-6">
        <Tabs items={tabs} />
      </div>
    </AppShell>
  );
}
