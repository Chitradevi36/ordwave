"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

function fmtDate(d: string | null | undefined) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}

function fmtDateTime(d: string | null | undefined) {
  if (!d) return "—";
  return new Date(d).toLocaleString("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function Row({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  return (
    <div className="flex items-start justify-between gap-3 py-2">
      <span className="text-sm text-text-secondary">{label}</span>
      <span className="text-sm text-text-primary font-medium">{value}</span>
    </div>
  );
}

export interface FulfillmentPanelProps {
  pickStatus?: "pending_pick" | "picked" | "pick_confirmed";
  pickedAt?: string | null;
  pickedByName?: string;
  pickConfirmedAt?: string | null;
  pickConfirmedByName?: string;
  tripId?: string | null;
  driverName?: string;
  vehicleNumber?: string;
  dispatchTime?: string | null;
  deliveredTime?: string | null;
  deliveryPodUrl?: string | null;
  onViewTrip?: (tripId: string) => void;
  onDownloadPod?: () => void;
}

const PICK_STATUS_CONFIG = {
  pending_pick: { label: "Awaiting Pick", variant: "secondary" as const },
  picked: { label: "Picked", variant: "warning" as const },
  pick_confirmed: { label: "Pick Confirmed", variant: "success" as const },
};

export function FulfillmentPanel({
  pickStatus = "pending_pick",
  pickedAt,
  pickedByName,
  pickConfirmedAt,
  pickConfirmedByName,
  tripId,
  driverName,
  vehicleNumber,
  dispatchTime,
  deliveredTime,
  deliveryPodUrl,
  onViewTrip,
  onDownloadPod,
}: FulfillmentPanelProps) {
  return (
    <div className="space-y-4">
      {/* Warehouse Picking */}
      <Card>
        <CardHeader>
          <CardTitle className="text-sm">Warehouse Picking</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-sm text-text-secondary">Status</span>
            <Badge variant={PICK_STATUS_CONFIG[pickStatus].variant}>
              {PICK_STATUS_CONFIG[pickStatus].label}
            </Badge>
          </div>
          {pickedAt && (
            <>
              <Row label="Picked At" value={fmtDateTime(pickedAt)} />
              {pickedByName && <Row label="Picked By" value={pickedByName} />}
            </>
          )}
          {pickConfirmedAt && (
            <>
              <Row label="Confirmed At" value={fmtDateTime(pickConfirmedAt)} />
              {pickConfirmedByName && (
                <Row label="Confirmed By" value={pickConfirmedByName} />
              )}
            </>
          )}
        </CardContent>
      </Card>

      {/* Dispatch & Delivery */}
      {tripId && (
        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Dispatch & Delivery</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            <Row label="Trip ID" value={tripId} />
            {driverName && <Row label="Driver" value={driverName} />}
            {vehicleNumber && <Row label="Vehicle" value={vehicleNumber} />}
            {dispatchTime && <Row label="Dispatch Time" value={fmtDateTime(dispatchTime)} />}
            {deliveredTime && (
              <Row label="Delivered Time" value={fmtDateTime(deliveredTime)} />
            )}

            <div className="pt-2 flex gap-2 border-t border-border">
              {onViewTrip && (
                <Button size="sm" variant="outline" onClick={() => onViewTrip(tripId)}>
                  View Trip
                </Button>
              )}
              {deliveryPodUrl && onDownloadPod && (
                <Button size="sm" variant="outline" onClick={onDownloadPod}>
                  Download POD
                </Button>
              )}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Shortages & Returns */}
      {/* Placeholder for future shortages/returns info */}
    </div>
  );
}
