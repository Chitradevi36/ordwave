"use client";

import { useState, useMemo, useCallback, useEffect } from "react";
import { useQuery } from "@tanstack/react-query";
import { apiClient } from "@/lib/api/client";
import { useOrgBranch } from "@/lib/org-branch-context";

// ── Types ────────────────────────────────────────────────────────────────────

export interface PaginationMeta {
  current_page: number;
  total_pages: number;
  total_count: number;
  per_page: number;
}

export interface ListPageResponse<T> {
  data: T[];
  meta: PaginationMeta;
}

export interface UseListPageOptions<TFilter extends Record<string, unknown> = Record<string, never>> {
  /** API endpoint, e.g. "/api/v1/products" */
  endpoint: string;
  /** React Query cache key prefix, e.g. "products" */
  queryKey: string;
  /** Items per page (default 20) */
  perPage?: number;
  /** Search debounce in ms (default 300) */
  debounceMs?: number;
  /** Initial filter values */
  defaultFilters?: TFilter;
  /** Whether the query is enabled (defaults to true when orgId is present) */
  enabled?: boolean;
}

export interface UseListPageReturn<T, TFilter extends Record<string, unknown>> {
  /** Paginated data items for the current page */
  data: T[];
  /** Whether data is loading for the first time */
  isLoading: boolean;
  /** Whether a background refetch is happening */
  isFetching: boolean;
  /** Error if the query failed */
  error: Error | null;
  /** Current search string (raw, not debounced) */
  search: string;
  /** Set the search string — automatically resets to page 1 */
  setSearch: (q: string) => void;
  /** Current page (1-indexed) */
  page: number;
  /** Navigate to a specific page */
  setPage: (p: number) => void;
  /** Total pages from server */
  totalPages: number;
  /** Total item count from server */
  totalCount: number;
  /** Current filter state */
  filters: TFilter;
  /** Update one or more filter values — resets to page 1 */
  setFilters: (patch: Partial<TFilter>) => void;
  /** Reset all filters + search to defaults */
  clearFilters: () => void;
  /** Whether any filter or search is active */
  hasActiveFilters: boolean;
  /** Manually refetch (e.g. after a mutation) */
  refetch: () => void;
}

// ── Hook ─────────────────────────────────────────────────────────────────────

export function useListPage<
  T,
  TFilter extends Record<string, unknown> = Record<string, never>,
>(opts: UseListPageOptions<TFilter>): UseListPageReturn<T, TFilter> {
  const {
    endpoint,
    queryKey: keyPrefix,
    perPage = 20,
    debounceMs = 300,
    defaultFilters = {} as TFilter,
    enabled: enabledProp,
  } = opts;

  const { orgId } = useOrgBranch();

  // ── Local state ───────────────────────────────────────────────────────────
  const [page, setPageRaw] = useState(1);
  const [search, setSearchRaw] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [filters, setFiltersRaw] = useState<TFilter>(defaultFilters);

  // Debounce search
  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(search), debounceMs);
    return () => clearTimeout(t);
  }, [search, debounceMs]);

  // Setters that auto-reset page
  const setSearch = useCallback((q: string) => {
    setSearchRaw(q);
    setPageRaw(1);
  }, []);

  const setFilters = useCallback((patch: Partial<TFilter>) => {
    setFiltersRaw((prev) => ({ ...prev, ...patch }));
    setPageRaw(1);
  }, []);

  const setPage = useCallback((p: number) => setPageRaw(p), []);

  const clearFilters = useCallback(() => {
    setSearchRaw("");
    setDebouncedSearch("");
    setFiltersRaw(defaultFilters);
    setPageRaw(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Build query params
  const params = useMemo(() => {
    const qp: Record<string, string> = {
      page: String(page),
      per_page: String(perPage),
    };
    if (debouncedSearch) qp.q = debouncedSearch;
    Object.entries(filters).forEach(([k, v]) => {
      if (v !== undefined && v !== null && v !== "") qp[k] = String(v);
    });
    return qp;
  }, [page, perPage, debouncedSearch, filters]);

  const isEnabled = enabledProp ?? !!orgId;

  const { data: response, isLoading, isFetching, error, refetch } = useQuery<ListPageResponse<T>>({
    queryKey: [keyPrefix, params, orgId],
    queryFn: async () => {
      const { data } = await apiClient.get<ListPageResponse<T>>(endpoint, { params });
      return data;
    },
    staleTime: 30_000,
    placeholderData: (prev) => prev,
    enabled: isEnabled,
  });

  const data = response?.data ?? [];
  const totalPages = response?.meta?.total_pages ?? 1;
  const totalCount = response?.meta?.total_count ?? 0;

  const hasActiveFilters = useMemo(() => {
    if (search) return true;
    return Object.values(filters).some((v) => v !== undefined && v !== null && v !== "");
  }, [search, filters]);

  return {
    data,
    isLoading,
    isFetching,
    error: error as Error | null,
    search,
    setSearch,
    page,
    setPage,
    totalPages,
    totalCount,
    filters,
    setFilters,
    clearFilters,
    hasActiveFilters,
    refetch,
  };
}
