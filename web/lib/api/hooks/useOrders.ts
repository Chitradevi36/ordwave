import { useQuery } from "@tanstack/react-query";
import { apiClient } from "../client";

// ── Types ────────────────────────────────────────────────────────────────────
export interface Order {
  id: number;
  order_number: string;
  status: string;
  total_amount: number | string;
  created_at: string;
  customer?: { id: number; name: string };
  branch?: { id: number; name: string };
  lines_count?: number;
}

export interface OrdersParams {
  page?: number;
  per_page?: number;
  sort?: string;
  status?: string;
}

export interface PaginationMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
}

export interface OrdersResponse {
  data: Order[];
  meta: PaginationMeta;
}

// ── Hook ────────────────────────────────────────────────────────────────────
export function useOrders(params: OrdersParams = {}) {
  const { page = 1, per_page = 5, sort = "created_at_desc", status } = params;

  return useQuery<OrdersResponse>({
    queryKey: ["orders", { page, per_page, sort, status }],
    queryFn: async () => {
      const queryParams: Record<string, string | number> = { page, per_page, sort };
      if (status) queryParams.status = status;

      const { data } = await apiClient.get<OrdersResponse>("/api/v1/sales_orders", {
        params: queryParams,
      });
      return data;
    },
    staleTime: 30_000,
    placeholderData: (prev) => prev,
  });
}
