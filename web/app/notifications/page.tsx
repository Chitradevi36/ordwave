"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import {
  Bell,
  ShoppingCart,
  AlertCircle,
  DollarSign,
  Package,
  Truck,
  CheckCircle2,
  X,
  Loader2,
  CheckCheck,
} from "lucide-react";
import { AppShell, PageHeader } from "@/components/layout";
import { Badge } from "@/components/ui/badge";
import {
  useNotifications,
  useMarkNotificationRead,
  useMarkAllNotificationsRead,
  useDismissNotification,
  type AppNotification,
} from "@/lib/api/hooks/useNotifications";

// ── Icon map ──────────────────────────────────────────────────────────────────

type IconKey = "order" | "approval" | "payment" | "inventory" | "delivery" | "system";

const TYPE_TO_KEY: Record<string, IconKey> = {
  order_submitted:        "order",
  order_approved:         "order",
  order_rejected:         "approval",
  order_held:             "approval",
  credit_blocked:         "approval",
  payment_confirmed:      "payment",
  payment_reversed:       "payment",
  delivery_completed:     "delivery",
  delivery_failed:        "delivery",
  stock_low:              "inventory",
  transfer_dispatched:    "inventory",
  transfer_received:      "inventory",
  limit_change_requested: "approval",
  limit_change_decided:   "approval",
  return_submitted:       "order",
  credit_note_issued:     "payment",
  beat_assigned:          "system",
  invoice_generated:      "payment",
  trip_assigned:          "delivery",
};

const ICON_MAP: Record<IconKey, { icon: React.ElementType; cls: string }> = {
  order:     { icon: ShoppingCart,  cls: "bg-blue-50   text-blue-600" },
  approval:  { icon: AlertCircle,   cls: "bg-amber-50  text-amber-600" },
  payment:   { icon: DollarSign,    cls: "bg-green-50  text-green-600" },
  inventory: { icon: Package,       cls: "bg-purple-50 text-purple-600" },
  delivery:  { icon: Truck,         cls: "bg-orange-50 text-orange-600" },
  system:    { icon: CheckCircle2,  cls: "bg-primary-100 text-primary" },
};

const SEVERITY_VARIANT: Record<string, "danger" | "warning" | "secondary"> = {
  high:   "danger",
  medium: "warning",
  low:    "secondary",
};

function timeAgo(iso: string) {
  const diff = (Date.now() - new Date(iso).getTime()) / 1000;
  if (diff < 60)    return "just now";
  if (diff < 3600)  return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

// ── Filter tabs ───────────────────────────────────────────────────────────────

type FilterKey = "all" | "unread" | "high";

const FILTERS: { key: FilterKey; label: string }[] = [
  { key: "all",    label: "All" },
  { key: "unread", label: "Unread" },
  { key: "high",   label: "High Priority" },
];

// ── Notification row ──────────────────────────────────────────────────────────

function NotifRow({
  notif,
  onRead,
  onDismiss,
  onNavigate,
}: {
  notif: AppNotification;
  onRead:     (id: number) => void;
  onDismiss:  (id: number) => void;
  onNavigate: (notif: AppNotification) => void;
}) {
  const iconKey            = TYPE_TO_KEY[notif.notification_type] ?? "system";
  const { icon: Icon, cls } = ICON_MAP[iconKey];

  return (
    <div
      className={[
        "group flex items-start gap-3 px-4 py-4 border-b border-border transition-colors",
        notif.read
          ? "bg-white"
          : "bg-primary-50/40 hover:bg-primary-50/60",
        notif.deep_link_url ? "cursor-pointer hover:bg-background-subtle" : "",
      ].join(" ")}
      onClick={() => onNavigate(notif)}
    >
      {/* Unread dot */}
      <div className="mt-1 shrink-0 w-2">
        {!notif.read && (
          <span className="block w-2 h-2 rounded-full bg-primary mt-0.5" />
        )}
      </div>

      {/* Icon */}
      <div className={`shrink-0 w-9 h-9 rounded-lg flex items-center justify-center ${cls}`}>
        <Icon size={16} />
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <div className="flex items-start justify-between gap-2">
          <p className={`text-sm leading-tight ${notif.read ? "text-text-secondary" : "font-semibold text-text-primary"}`}>
            {notif.title}
          </p>
          <div className="flex items-center gap-1.5 shrink-0">
            {notif.severity !== "low" && (
              <Badge variant={SEVERITY_VARIANT[notif.severity]} className="text-[10px] px-1.5 py-0">
                {notif.severity}
              </Badge>
            )}
            <span className="text-[11px] text-text-tertiary whitespace-nowrap">
              {timeAgo(notif.created_at)}
            </span>
          </div>
        </div>

        {notif.body && (
          <p className="text-xs text-text-secondary mt-0.5 line-clamp-2">{notif.body}</p>
        )}

        {notif.actor && (
          <p className="text-[11px] text-text-tertiary mt-1">by {notif.actor.name}</p>
        )}
      </div>

      {/* Actions (shown on hover) */}
      <div
        className="shrink-0 flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity"
        onClick={(e) => e.stopPropagation()}
      >
        {!notif.read && (
          <button
            title="Mark as read"
            onClick={() => onRead(notif.id)}
            className="w-7 h-7 flex items-center justify-center rounded-md text-text-secondary hover:text-primary hover:bg-primary-50 transition-colors"
          >
            <CheckCheck size={14} />
          </button>
        )}
        <button
          title="Dismiss"
          onClick={() => onDismiss(notif.id)}
          className="w-7 h-7 flex items-center justify-center rounded-md text-text-secondary hover:text-danger hover:bg-danger/10 transition-colors"
        >
          <X size={14} />
        </button>
      </div>
    </div>
  );
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function NotificationsPage() {
  const router         = useRouter();
  const [filter, setFilter] = useState<FilterKey>("all");

  const queryFilters = {
    unread:   filter === "unread" ? true  : undefined,
    severity: filter === "high"   ? "high": undefined,
  };

  const { data, isLoading, isError } = useNotifications(queryFilters);
  const markRead    = useMarkNotificationRead();
  const markAllRead = useMarkAllNotificationsRead();
  const dismiss     = useDismissNotification();

  const notifications = data?.data ?? [];
  const unreadCount   = data?.meta.total_unread ?? 0;

  function handleNavigate(notif: AppNotification) {
    if (!notif.read) markRead.mutate(notif.id);
    if (notif.deep_link_url) router.push(notif.deep_link_url);
  }

  return (
    <AppShell>
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-6">
        <PageHeader
          title="Notifications"
          subtitle={
            unreadCount > 0
              ? `${unreadCount} unread notification${unreadCount === 1 ? "" : "s"}`
              : "You're all caught up"
          }
          actions={
            unreadCount > 0
              ? [
                  {
                    label:    markAllRead.isPending ? "Marking…" : "Mark all read",
                    onClick:  () => markAllRead.mutate(),
                    disabled: markAllRead.isPending,
                    variant:  "outline" as const,
                    icon:     CheckCheck,
                  },
                ]
              : undefined
          }
        />

        {/* Filter tabs */}
        <div className="flex gap-1 mt-4 mb-2 border-b border-border">
          {FILTERS.map((f) => (
            <button
              key={f.key}
              onClick={() => setFilter(f.key)}
              className={[
                "px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors",
                filter === f.key
                  ? "border-primary text-primary"
                  : "border-transparent text-text-secondary hover:text-text-primary",
              ].join(" ")}
            >
              {f.label}
            </button>
          ))}
        </div>

        {/* Content */}
        <div className="rounded-xl border border-border overflow-hidden bg-white mt-4">
          {isLoading ? (
            <div className="flex items-center justify-center py-20">
              <Loader2 size={24} className="animate-spin text-text-secondary" />
            </div>
          ) : isError ? (
            <div className="flex flex-col items-center justify-center py-20 gap-2 text-danger">
              <AlertCircle size={32} />
              <p className="text-sm">Failed to load notifications.</p>
            </div>
          ) : notifications.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-3 text-text-secondary">
              <Bell size={36} strokeWidth={1.5} />
              <p className="text-sm font-medium">No notifications here</p>
              <p className="text-xs">
                {filter === "unread"
                  ? "You have no unread notifications."
                  : filter === "high"
                  ? "No high-priority notifications."
                  : "All caught up! Nothing to show."}
              </p>
            </div>
          ) : (
            notifications.map((notif) => (
              <NotifRow
                key={notif.id}
                notif={notif}
                onRead={(id) => markRead.mutate(id)}
                onDismiss={(id) => dismiss.mutate(id)}
                onNavigate={handleNavigate}
              />
            ))
          )}
        </div>
      </div>
    </AppShell>
  );
}
