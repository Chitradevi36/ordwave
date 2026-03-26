import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "../client";
import { useOrgBranch } from "@/lib/org-branch-context";

// ── Types ────────────────────────────────────────────────────────────────────

export interface Product {
  id: number;
  name: string;
  sku: string;
  hsn_code: string | null;
  status: string;
  unit_price: number | string;
  gst_rate: number | string;
  category?: { id: number; name: string } | null;
  uom?: { id: number; name: string; abbreviation: string } | null;
  stock_qty?: number;
  created_at: string;
}

export interface ProductsParams {
  page?: number;
  per_page?: number;
  q?: string;
  category_id?: number;
  status?: string;
  sort?: string;
}

export interface PaginationMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
}

export interface ProductsResponse {
  data: Product[];
  meta: PaginationMeta;
}

// ── List hook ────────────────────────────────────────────────────────────────

export function useProducts(params: ProductsParams = {}) {
  const { orgId, branchId } = useOrgBranch();
  const { page = 1, per_page = 20, q, category_id, status, sort } = params;

  return useQuery<ProductsResponse>({
    queryKey: ["products", { page, per_page, q, category_id, status, sort, orgId, branchId }],
    queryFn: async () => {
      const qp: Record<string, string | number> = { page, per_page };
      if (q) qp.q = q;
      if (category_id) qp.category_id = category_id;
      if (status) qp.status = status;
      if (sort) qp.sort = sort;
      if (branchId) qp.branch_id = branchId;

      const { data } = await apiClient.get<ProductsResponse>("/api/v1/products", { params: qp });
      return data;
    },
    staleTime: 30_000,
    placeholderData: (prev) => prev,
    enabled: !!orgId,
  });
}

// ── Detail hook ──────────────────────────────────────────────────────────────

export function useProduct(id: number | string | null) {
  const { orgId } = useOrgBranch();

  return useQuery<Product>({
    queryKey: ["product", id, orgId],
    queryFn: async () => {
      const { data } = await apiClient.get<{ data: Product }>(`/api/v1/products/${id}`);
      return data.data;
    },
    enabled: !!orgId && !!id,
  });
}

// ── Mutations ────────────────────────────────────────────────────────────────

export function useCreateProduct() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (product: Record<string, unknown>) =>
      apiClient.post("/api/v1/products", { product }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["products"] });
    },
  });
}

export function useUpdateProduct() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, product }: { id: number; product: Record<string, unknown> }) =>
      apiClient.patch(`/api/v1/products/${id}`, { product }),
    onSuccess: (_data, { id }) => {
      qc.invalidateQueries({ queryKey: ["products"] });
      qc.invalidateQueries({ queryKey: ["product", id] });
    },
  });
}

export function useDiscontinueProduct() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) =>
      apiClient.post(`/api/v1/products/${id}/discontinue`),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["products"] });
    },
  });
}
