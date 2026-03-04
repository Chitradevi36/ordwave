"use client";

import { useState, useEffect } from "react";
import { useRouter, useParams } from "next/navigation";
import { AppShell, PageHeader } from "@/components/layout";
import { Breadcrumb } from "@/components/ui/breadcrumb";
import { useOrgBranch } from "@/lib/org-branch-context";
import { ProductForm, ProductCategory, UnitsOfMeasure, type ProductFormData } from "../../_components/ProductForm";

interface ProductDetail {
  id:            number;
  sku:           string;
  name:          string;
  gst_rate:      number;
  min_order_qty:  number;
  purchase_price: number | null;
  barcode:       string | null;
  weight_kg:     number | null;
  description:   string | null;
  image_url:     string | null;
  status:        string;
  hsn:           { id: number; code: string; code_type: string; description: string; gst_rate: number } | null;
  category:      { id: number; name: string } | null;
  uom:           { id: number; name: string; symbol: string } | null;
}

export default function EditProductPage() {
  const router    = useRouter();
  const params    = useParams<{ id: string }>();
  const { token, orgId } = useOrgBranch();

  const [product,    setProduct]    = useState<ProductDetail | null>(null);
  const [categories, setCategories] = useState<ProductCategory[]>([]);
  const [uoms,       setUoms]       = useState<UnitsOfMeasure[]>([]);
  const [loading,    setLoading]    = useState(false);
  const [fetching,   setFetching]   = useState(true);
  const [errors,     setErrors]     = useState<string[]>([]);

  useEffect(() => {
    if (!token || !orgId || !params.id) return;
    const headers = { Authorization: `Bearer ${token}`, "X-Organization-Id": orgId };
    setFetching(true);
    Promise.all([
      fetch(`http://localhost:3001/api/v1/products/${params.id}`,           { headers }).then((r) => r.json()),
      fetch(`http://localhost:3001/api/v1/product_categories?per_page=100`, { headers }).then((r) => r.json()),
      fetch(`http://localhost:3001/api/v1/units_of_measure?per_page=100`,   { headers }).then((r) => r.json()),
    ]).then(([prod, cats, uomList]) => {
      if (prod.data)    setProduct(prod.data);
      if (cats.data)    setCategories(cats.data);
      if (uomList.data) setUoms(uomList.data);
    }).finally(() => setFetching(false));
  }, [token, orgId, params.id]);

  const handleSubmit = async (data: ProductFormData) => {
    if (!token || !orgId) return;
    setLoading(true);
    setErrors([]);
    try {
      const res  = await fetch(`http://localhost:3001/api/v1/products/${params.id}`, {
        method: "PATCH",
        headers: {
          "Content-Type":     "application/json",
          Authorization:      `Bearer ${token}`,
          "X-Organization-Id": orgId,
        },
        body: JSON.stringify({ product: data }),
      });
      const json = await res.json();
      if (res.ok) {
        router.push("/products");
      } else {
        setErrors(json.errors ?? ["Something went wrong"]);
      }
    } finally {
      setLoading(false);
    }
  };

  if (fetching) {
    return (
      <AppShell title="Products">
        <div className="flex items-center justify-center py-24">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
        </div>
      </AppShell>
    );
  }

  if (!product) {
    return (
      <AppShell title="Products">
        <p className="text-sm text-danger">Product not found.</p>
      </AppShell>
    );
  }

  const initialData: Partial<ProductFormData> = {
    sku:                 product.sku,
    name:                product.name,
    product_category_id: product.category  ? String(product.category.id)  : "",
    units_of_measure_id: product.uom       ? String(product.uom.id)       : "",
    hsn_sac_code_id:     product.hsn       ? String(product.hsn.id)       : "",
    gst_rate:            String(product.gst_rate),
    min_order_qty:       String(product.min_order_qty),
    purchase_price:      product.purchase_price != null ? String(product.purchase_price) : "",
    barcode:             product.barcode     ?? "",
    weight_kg:           product.weight_kg   != null ? String(product.weight_kg) : "",
    description:         product.description ?? "",
    image_url:           product.image_url   ?? "",
    status:              product.status,
  };

  return (
    <AppShell title="Products">
      <Breadcrumb items={[
        { label: "Products", href: "/products" },
        { label: product.name },
      ]} />
      <PageHeader title={`Edit: ${product.name}`} description={`SKU: ${product.sku}`} />

      <div className="max-w-2xl">
        <ProductForm
          initialData={initialData}
          initialHsn={product.hsn ?? null}
          categories={categories}
          uoms={uoms}
          loading={loading}
          errors={errors}
          token={token}
          orgId={orgId}
          onSubmit={handleSubmit}
          onCancel={() => router.push("/products")}
          submitLabel="Save Changes"
        />
      </div>
    </AppShell>
  );
}
