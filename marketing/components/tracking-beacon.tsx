"use client";

import { useEffect } from "react";
import { trackEvent } from "@/lib/analytics";

type TrackingBeaconProps = {
  eventName: string;
  params?: Record<string, unknown>;
};

export function TrackingBeacon({ eventName, params }: TrackingBeaconProps) {
  useEffect(() => {
    trackEvent(eventName, params);
  }, [eventName, params]);

  return null;
}
