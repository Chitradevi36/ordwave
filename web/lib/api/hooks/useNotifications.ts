import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiClient } from "../client";

// ── Types ─────────────────────────────────────────────────────────────────────

export interface AppNotification {
  id: number;
  notification_type: string;
  title: string;
  body: string | null;
  deep_link_url: string | null;
  severity: "low" | "medium" | "high";
  read: boolean;
  read_at: string | null;
  actor: { id: number; name: string } | null;
  created_at: string;
}

interface NotificationsResponse {
  data: AppNotification[];
  meta: { total_unread: number };
}

// ── Query Keys ────────────────────────────────────────────────────────────────

export const notificationsKeys = {
  all:    () => ["notifications"] as const,
  list:   (filters?: Record<string, string>) => ["notifications", "list", filters] as const,
};

// ── Hooks ─────────────────────────────────────────────────────────────────────

export function useNotifications(filters?: { unread?: boolean; type?: string; severity?: string }) {
  const params = new URLSearchParams();
  if (filters?.unread)   params.set("unread",   "true");
  if (filters?.type)     params.set("type",     filters.type);
  if (filters?.severity) params.set("severity", filters.severity);

  return useQuery<NotificationsResponse>({
    queryKey: notificationsKeys.list(Object.fromEntries(params)),
    queryFn: async () => {
      const { data } = await apiClient.get<NotificationsResponse>(
        `/api/v1/notifications?${params.toString()}`
      );
      return data;
    },
    refetchInterval: 30_000,   // poll every 30 s
    staleTime:       15_000,
  });
}

export function useUnreadCount() {
  const { data } = useNotifications({ unread: true });
  return data?.meta.total_unread ?? 0;
}

export function useMarkNotificationRead() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => apiClient.patch(`/api/v1/notifications/${id}/read`),
    onSuccess: () => qc.invalidateQueries({ queryKey: notificationsKeys.all() }),
  });
}

export function useMarkAllNotificationsRead() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: () => apiClient.post("/api/v1/notifications/read_all"),
    onSuccess: () => qc.invalidateQueries({ queryKey: notificationsKeys.all() }),
  });
}

export function useDismissNotification() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => apiClient.delete(`/api/v1/notifications/${id}`),
    onSuccess: () => qc.invalidateQueries({ queryKey: notificationsKeys.all() }),
  });
}
