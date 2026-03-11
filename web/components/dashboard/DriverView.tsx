"use client";

import Link from "next/link";
import { Truck, Smartphone, ShoppingCart, Clock, MapPin } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import type { DashboardData } from "@/lib/api/hooks/useDashboard";

interface Props {
  data: DashboardData | undefined;
  isLoading: boolean;
  isError: boolean;
}

export function DriverView({ data, isLoading, isError }: Props) {
  return (
    <div className="space-y-5">
      {/* ── Stats strip ──────────────────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-3">
        <Card>
          <CardContent className="pt-5 text-center">
            <ShoppingCart className="mx-auto mb-2 h-7 w-7 text-blue-500" />
            <p className="text-2xl font-bold text-text-primary">
              {isLoading ? <span className="inline-block h-7 w-10 rounded bg-gray-100 animate-pulse" /> : (data?.orders.today ?? 0)}
            </p>
            <p className="text-xs text-text-secondary mt-0.5">Orders Today</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="pt-5 text-center">
            <Clock className="mx-auto mb-2 h-7 w-7 text-amber-500" />
            <p className="text-2xl font-bold text-text-primary">
              {isLoading ? <span className="inline-block h-7 w-10 rounded bg-gray-100 animate-pulse" /> : (data?.orders.pending ?? 0)}
            </p>
            <p className="text-xs text-text-secondary mt-0.5">Pending Orders</p>
          </CardContent>
        </Card>
      </div>

      {/* ── Mobile app nudge ─────────────────────────────────────────────── */}
      <Card className="border-blue-200 bg-blue-50">
        <CardHeader className="pb-2">
          <CardTitle className="flex items-center gap-2 text-sm font-semibold text-blue-800">
            <Smartphone className="h-4 w-4" />
            Use the OrdWave Mobile App
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-blue-700">
            Your trips, stops, delivery confirmations, and customer check-ins are all managed from the
            <strong> OrdWave mobile app</strong>. Open it on your phone to start today&apos;s deliveries.
          </p>
        </CardContent>
      </Card>

      {/* ── Web quick links ───────────────────────────────────────────────── */}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Link
          href="/delivery"
          className="flex items-center gap-3 rounded-xl border border-border bg-background px-5 py-4 hover:bg-background-subtle transition-colors group"
        >
          <span className="flex h-10 w-10 items-center justify-center rounded-full bg-accent/10 text-accent">
            <Truck className="h-5 w-5" />
          </span>
          <div>
            <p className="font-semibold text-text-primary text-sm">Delivery Trips</p>
            <p className="text-xs text-text-secondary">View assigned trip routes</p>
          </div>
        </Link>
        <Link
          href="/operations"
          className="flex items-center gap-3 rounded-xl border border-border bg-background px-5 py-4 hover:bg-background-subtle transition-colors group"
        >
          <span className="flex h-10 w-10 items-center justify-center rounded-full bg-blue-100 text-blue-600">
            <MapPin className="h-5 w-5" />
          </span>
          <div>
            <p className="font-semibold text-text-primary text-sm">Operations</p>
            <p className="text-xs text-text-secondary">Returns, transfers &amp; more</p>
          </div>
        </Link>
      </div>
    </div>
  );
}
