"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useRouter } from "next/navigation";
import { CheckCircle, PackagePlus, Plus, Clock3, ArrowRight, List } from "lucide-react";
import { AppShell, PageHeader } from "@/components/layout";
import { Button } from "@/components/ui/button";
import { useOrgBranch } from "@/lib/org-branch-context";
import {
  ProductForm,
  type ProductCategory,
  type UnitsOfMeasure,
  type ProductFormData,
} from "../_components/ProductForm";
import { AssignPriceModal } from "../_components/AssignPriceModal";
import { API_URL } from "@/lib/api/client";

export default function NewProductPage() {
  const router = useRouter();
  const { token, orgId, branchId } = useOrgBranch();

  const [categories, setCategories] = useState<ProductCategory[]>([]);
  const [uoms,       setUoms]       = useState<UnitsOfMeasure[]>([]);
  const [loading,    setLoading]    = useState(false);
  const [errors,     setErrors]     = useState<string[]>([]);
  const [role,       setRole]       = useState<string>("member");

  // Post-create state
  const [createdProductId,   setCreatedProductId]   = useState<number | null>(null);
  const [createdProductName, setCreatedProductName] = useState("");
  const [showAssignModal,    setShowAssignModal]    = useState(false);
  const [formKey,            setFormKey]            = useState(0);
  const [countdown,          setCountdown]          = useState(5);
  const countdownRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Auto-redirect countdown once product is created
  useEffect(() => {
    if (!createdProductId) return;
    setCountdown(5);
    countdownRef.current = setInterval(() => {
      setCountdown((n) => {
        if (n <= 1) {
          clearInterval(countdownRef.current!);
          router.push(`/products/${createdProductId}/edit`);
          return 0;
        }
        return n - 1;
      });
    }, 1000);
    return () => { if (countdownRef.current) clearInterval(countdownRef.current); };
  }, [createdProductId, router]);

  const stopCountdown = () => {
    if (countdownRef.current) clearInterval(countdownRef.current);
  };

  // Load form reference data + resolve current user role for this org
  useEffect(() => {
    if (!token || !orgId) return;
    const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };
    Promise.all([
      fetch(`${API_URL}/api/v1/product_categories?per_page=100`, { headers }).then((r) => r.json()),
      fetch(`${API_URL}/api/v1/units_of_measure?per_page=100`,   { headers }).then((r) => r.json()),
      fetch(`${API_URL}/api/v1/profile`,                         { headers }).then((r) => r.json()),
    ]).then(([cats, uomList, profile]) => {
      if (cats.data)    setCategories(cats.data);
      if (uomList.data) setUoms(uomList.data);
      // profile.data.organizations[].role gives the role for each org
      if (profile.data?.organizations) {
        const entry = profile.data.organizations.find(
          (o: { id: number }) => String(o.id) === orgId,
        );
        if (entry?.role) setRole(entry.role);
      }
    });
  }, [token, orgId]);

  // Call backend SKU generator
  const handleGenerateSku = useCallback(async (): Promise<string> => {
    if (!token || !orgId) return "";
    const res  = await fetch(`${API_URL}/api/v1/products/generate_sku`, {
      headers: { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId },
    });
    const json = await res.json();
    return json.data?.sku ?? "";
  }, [token, orgId]);

  const handleSubmit = async (data: ProductFormData) => {
    if (!token || !orgId) return;
    setLoading(true);
    setErrors([]);
    try {
      const res  = await fetch(`${API_URL}/api/v1/products`, {
        method:  "POST",
        headers: {
          "Content-Type":      "application/json",
          Authorization:       `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({ product: data }),
      });
      const json = await res.json();
      if (res.ok) {
        setCreatedProductId(json.data.id);
        setCreatedProductName(json.data.name);
      } else {
        setErrors(json.errors ?? ["Something went wrong"]);
      }
    } finally {
      setLoading(false);
    }
  };

  const resetForAnother = () => {
    stopCountdown();
    setCreatedProductId(null);
    setCreatedProductName("");
    setFormKey((k) => k + 1);
  };

  // ── Post-create success panel ───────────────────────────────────────────────
  if (createdProductId) {
    return (
      <AppShell breadcrumbs={[
        { label: "Catalog", href: "/catalog" },
        { label: "Products", href: "/products" },
        { label: "Add Product" },
      ]}>
        <PageHeader title="Product Created" description="Next, assign a selling price to start selling." />

        <div className="max-w-2xl">
          <div className="rounded-lg border border-accent/30 bg-accent/5 p-5">
            <div className="flex items-start gap-3">
              <CheckCircle className="h-5 w-5 text-accent mt-0.5 shrink-0" />
              <div className="flex-1">
                <p className="font-medium text-text-primary">
                  <span className="text-accent">{createdProductName}</span> was created successfully.
                </p>
                <p className="mt-1 text-sm text-text-secondary">
                  Assign it to a price list so it can be included in orders.
                </p>
              </div>
              <span className="text-xs text-text-secondary whitespace-nowrap">
                Redirecting in {countdown}s…
              </span>
            </div>

            <div className="mt-4 flex flex-wrap gap-3">
              <Button
                onClick={() => { stopCountdown(); router.push(`/products/${createdProductId}/edit`); }}
              >
                <ArrowRight className="h-4 w-4 mr-2" />
                View Product
              </Button>
              <Button
                variant="outline"
                onClick={() => { stopCountdown(); setShowAssignModal(true); }}
              >
                <PackagePlus className="h-4 w-4 mr-2" />
                Assign to Price List
              </Button>
              <Button variant="outline" onClick={resetForAnother}>
                <Plus className="h-4 w-4 mr-2" />
                Create Another
              </Button>
              <Button
                variant="ghost"
                onClick={() => { stopCountdown(); router.push("/products"); }}
              >
                <List className="h-4 w-4 mr-2" />
                All Products
              </Button>
            </div>
          </div>
        </div>

        {showAssignModal && (
          <AssignPriceModal
            productId={createdProductId}
            productName={createdProductName}
            token={token!}
            orgId={orgId!}
            branchId={branchId}
            onClose={() => setShowAssignModal(false)}
            onAssigned={() => {
              setShowAssignModal(false);
              router.push("/products");
            }}
          />
        )}
      </AppShell>
    );
  }

  // ── Create form ────────────────────────────────────────────────────────────
  return (
    <AppShell breadcrumbs={[
        { label: "Catalog", href: "/catalog" },
        { label: "Products", href: "/products" },
        { label: "Add Product" },
      ]}>
      <PageHeader title="Add Product" description="Create a new product in your catalogue" />

      <div className="max-w-2xl">
        {/* Time-to-complete hint */}
        <p className="mb-4 flex items-center gap-1.5 text-xs text-text-secondary">
          <Clock3 className="h-3.5 w-3.5 shrink-0" />
          Typical time to complete: ~20 seconds — only the required fields below are needed to start.
        </p>

        <ProductForm
          key={formKey}
          categories={categories}
          uoms={uoms}
          loading={loading}
          errors={errors}
          token={token}
          orgId={orgId}
          purchasePriceVisible={role !== "sales_rep"}
          onGenerateSku={handleGenerateSku}
          onSubmit={handleSubmit}
          onCancel={() => router.push("/products")}
          submitLabel="Create Product"
          onCategoryCreated={(cat) => setCategories((prev) => [...prev, cat])}
          onUomCreated={(uom) => setUoms((prev) => [...prev, uom])}
        />
      </div>
    </AppShell>
  );
}
