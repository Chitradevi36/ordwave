"use client";

import { useRef, useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import {
  Bell,
  ShoppingCart,
  AlertCircle,
  DollarSign,
  Package,
  Truck,
  CheckCircle,
  X,
  Loader2,
} from "lucide-react";
import {
  useNotifications,
  useMarkNotificationRead,
  useMarkAllNotificationsRead,
  useDismissNotification,
  type AppNotification,
} from "@/lib/api/hooks/useNotifications";

// â”€â”€ Icon map by notification_type â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
};

const ICON_MAP: Record<IconKey, { icon: React.ElementType; cls: string }> = {
  order:     { icon: ShoppingCart, cls: "bg-blue-50 text-blue-600" },
  approval:  { icon: AlertCircle,  cls: "bg-amber-50 text-amber-600" },
  payment:   { icon: DollarSign,   cls: "bg-green-50 text-green-600" },
  inventory: { icon: Package,      cls: "bg-purple-50 text-purple-600" },
  delivery:  { icon: Truck,        cls: "bg-orange-50 text-orange-600" },
  system:    { icon: CheckCircle,  cls: "bg-primary-100 text-primary" },
};

function timeAgo(iso: string) {
  const diff = (Date.now() - new Date(iso).getTime()) / 1000;
  if (diff < 60)    return "just now";
  if (diff < 3600)  return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

// â”€â”€ NotificationsPanel (wired to real API) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export function NotificationsPanel() {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const router = useRouter();

  const { data, isLoading } = useNotifications();
  const markRead    = useMarkNotificationRead();
  const markAllRead = useMarkAllNotificationsRead();
  const dismiss     = useDismissNotification();

  const notifications = data?.data ?? [];
  const unreadCount   = data?.meta.total_unread ?? 0;

  // Close on outside click
  useEffect(() => {
    if (!open) return;
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [open]);

  function handleClick(notif: AppNotification) {
    if (!notif.read) markRead.mutate(notif.id);
    if (notif.deep_link_url) {
      router.push(notif.deep_link_url);
      setOpen(false);
    }
  }

  return (
    <div ref={ref} className="relative">
      {/* Bell button */}
      <button
        onClick={() => setOpen((v) => !v)}
        aria-label="Notifications"
        aria-expanded={open}
        className={[
          "relative w-9 h-9 flex items-center justify-center rounded-lg transition-colors",
          open ? "bg-primary-100 text-primary" : "text-text-secondary hover:bg-background-subtle hover:text-text-primary",
        ].join(" ")}
      >
        <Bell size={18} />
        {unreadCount > 0 && (
          <span className="absolute top-1 right-1 w-4 h-4 bg-red-500 rounded-full text-[9px] font-bold text-white flex items-center justify-center leading-none">
            {unreadCount > 9 ? "9+" : unreadCount}
          </span>
        )}
      </button>

      {/* Dropdown */}
      {open && (
        <div className="absolute right-0 top-11 w-[360px] sm:w-[400px] bg-background border border-border rounded-xl shadow-xl z-50 overflow-hidden">
          {/* Header */}
          <div className="flex items-center justify-between px-4 py-3 border-b border-border">
            <div>
              <p className="text-sm font-semibold text-text-primary">Notifications</p>
              {unreadCount > 0 && (
                <p className="text-xs text-text-secondary">{unreadCount} unread</p>
              )}
            </div>
            {unreadCount > 0 && (
              <button
                onClick={() => markAllRead.mutate()}
                disabled={markAllRead.isPending}
                className="text-xs text-accent font-medium hover:underline disabled:opacity-50"
              >
                {markAllRead.isPending ? "Markingâ€¦" : "Mark all read"}
              </button>
            )}
          </div>

          {/* List */}
          <div className="overflow-y-auto max-h-[420px] divide-y divide-border">
            {isLoading ? (
              <div className="flex items-center justify-center py-10">
                <Loader2 size={20} className="animate-spin text-text-secondary" />
              </div>
            ) : notifications.length === 0 ? (
              <p className="text-sm text-text-secondary text-center py-12">
                All caught up! No new notifications.
              </p>
            ) : (
              notifications.map((notif) => {
                const key = TYPE_TO_KEY[notif.notification_type] ?? "system";
                const { icon: Icon, cls } = ICON_MAP[key];
                return (
                  <div
                    key={notif.id}
                    className={[
                      "flex items-start gap-3 px-4 py-3 hover:bg-background-subtle transition-colors cursor-pointer",
                      !notif.read ? "bg-primary-50/40" : "",
                    ].join(" ")}
                    onClick={() => handleClick(notif)}
                  >
                    <div className={`w-9 h-9 rounded-full flex items-center justify-center shrink-0 mt-0.5 ${cls}`}>
                      <Icon size={15} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-1">
                        <p className="text-sm font-medium text-text-primary leading-tight">
                          {!notif.read && (
                            <span className="inline-block w-1.5 h-1.5 bg-accent rounded-full mr-1.5 mb-0.5" />
                          )}
                          {notif.title}
                        </p>
                        <button
                          onClick={(e) => { e.stopPropagation(); dismiss.mutate(notif.id); }}
                          className="text-text-secondary hover:text-text-primary shrink-0 mt-0.5"
                          aria-label="Dismiss"
                        >
                          <X size={13} />
                        </button>
                      </div>
                      {notif.body && (
                        <p className="text-xs text-text-secondary mt-0.5 line-clamp-2">{notif.body}</p>
                      )}
                      <p className="text-[11px] text-text-secondary mt-1">{timeAgo(notif.created_at)}</p>
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {/* Footer */}
          {notifications.length > 0 && (
            <div className="border-t border-border px-4 py-2.5 text-center">
              <button
                className="text-xs text-accent font-medium hover:underline"
                onClick={() => { router.push("/notifications"); setOpen(false); }}
              >
                View all notifications
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

