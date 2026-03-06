"use client";

import { useRef, useState, useEffect } from "react";
import {
  Bell,
  ShoppingCart,
  AlertCircle,
  DollarSign,
  Package,
  Truck,
  CheckCircle,
  X,
} from "lucide-react";
import type { UserRole } from "@/components/layout/nav.config";

// ── Types ─────────────────────────────────────────────────────────────────────
type NotifKind = "order" | "approval" | "payment" | "inventory" | "delivery" | "system";

interface Notification {
  id: number;
  kind: NotifKind;
  title: string;
  message: string;
  time: string;
  unread: boolean;
  roles: UserRole[];
}

const ICON_MAP: Record<NotifKind, { icon: React.ElementType; cls: string }> = {
  order:     { icon: ShoppingCart, cls: "bg-blue-50 text-blue-600" },
  approval:  { icon: AlertCircle,  cls: "bg-amber-50 text-amber-600" },
  payment:   { icon: DollarSign,   cls: "bg-green-50 text-green-600" },
  inventory: { icon: Package,      cls: "bg-purple-50 text-purple-600" },
  delivery:  { icon: Truck,        cls: "bg-orange-50 text-orange-600" },
  system:    { icon: CheckCircle,  cls: "bg-primary-100 text-primary" },
};

const ALL_ROLES: UserRole[] = ["owner", "admin", "manager", "sales_rep", "driver", "accounts", "warehouse"];

const SAMPLE: Notification[] = [
  { id: 1, kind: "approval",  title: "Order pending approval", message: "Order #ORD-1042 from Fresh Mart requires your approval", time: "2 min ago",  unread: true,  roles: ["owner","admin","manager"] },
  { id: 2, kind: "order",     title: "New order received",     message: "Order #ORD-1043 placed by Green Grocers",               time: "5 min ago",  unread: true,  roles: ["owner","admin","manager","sales_rep"] },
  { id: 3, kind: "payment",   title: "Payment collected",      message: "₹12,500 collected from City Supermarket",               time: "18 min ago", unread: true,  roles: ["owner","admin","manager","accounts"] },
  { id: 4, kind: "delivery",  title: "Trip started",           message: "Trip #T-210 started — 14 stops, 2.3 km",               time: "32 min ago", unread: false, roles: ["driver","owner","admin","manager"] },
  { id: 5, kind: "inventory", title: "Low stock alert",        message: "Amul Butter 500g — only 12 units left",                 time: "1 hr ago",   unread: false, roles: ["warehouse","owner","admin","manager"] },
  { id: 6, kind: "system",    title: "Credits updated",        message: "Credit limit for Metro Stores increased to ₹50,000",   time: "3 hr ago",   unread: false, roles: ALL_ROLES },
];

// ── NotificationsPanel ────────────────────────────────────────────────────────
interface NotificationsPanelProps {
  role?: UserRole;
}

export function NotificationsPanel({ role }: NotificationsPanelProps) {
  const [open, setOpen] = useState(false);
  const [notifs, setNotifs] = useState(SAMPLE);
  const ref = useRef<HTMLDivElement>(null);

  const filtered = role
    ? notifs.filter((n) => n.roles.includes(role))
    : notifs;

  const unreadCount = filtered.filter((n) => n.unread).length;

  // Close on outside click
  useEffect(() => {
    if (!open) return;
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [open]);

  const markAllRead = () => {
    setNotifs((prev) => prev.map((n) => ({ ...n, unread: false })));
  };

  const dismiss = (id: number) => {
    setNotifs((prev) => prev.filter((n) => n.id !== id));
  };

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
                onClick={markAllRead}
                className="text-xs text-accent font-medium hover:underline"
              >
                Mark all read
              </button>
            )}
          </div>

          {/* List */}
          <div className="overflow-y-auto max-h-[420px] divide-y divide-border">
            {filtered.length === 0 ? (
              <p className="text-sm text-text-secondary text-center py-12">No notifications</p>
            ) : (
              filtered.map((notif) => {
                const { icon: Icon, cls } = ICON_MAP[notif.kind];
                return (
                  <div
                    key={notif.id}
                    className={[
                      "flex items-start gap-3 px-4 py-3 hover:bg-background-subtle transition-colors",
                      notif.unread ? "bg-primary-50/40" : "",
                    ].join(" ")}
                  >
                    <div className={`w-9 h-9 rounded-full flex items-center justify-center shrink-0 mt-0.5 ${cls}`}>
                      <Icon size={15} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-start justify-between gap-1">
                        <p className="text-sm font-medium text-text-primary leading-tight">
                          {notif.unread && (
                            <span className="inline-block w-1.5 h-1.5 bg-accent rounded-full mr-1.5 mb-0.5" />
                          )}
                          {notif.title}
                        </p>
                        <button
                          onClick={() => dismiss(notif.id)}
                          className="text-text-secondary hover:text-text-primary shrink-0 mt-0.5"
                          aria-label="Dismiss"
                        >
                          <X size={13} />
                        </button>
                      </div>
                      <p className="text-xs text-text-secondary mt-0.5 line-clamp-2">{notif.message}</p>
                      <p className="text-[11px] text-text-secondary mt-1">{notif.time}</p>
                    </div>
                  </div>
                );
              })
            )}
          </div>

          {/* Footer */}
          {filtered.length > 0 && (
            <div className="border-t border-border px-4 py-2.5 text-center">
              <button className="text-xs text-accent font-medium hover:underline">
                View all notifications
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
