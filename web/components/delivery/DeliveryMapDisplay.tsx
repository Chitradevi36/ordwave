// ── Delivery Map Display Component ──────────────────────────────────────────
// Renders Google Map with route polylines, stop markers, and ETA information

'use client';

import React, { useEffect, useRef, useState } from 'react';
import { useDeliveryMap, TripStop, MapLocation, OptimizedStop } from '@/lib/hooks/useDeliveryMap';
import { Card } from '@/components/ui/card';
import { Alert } from '@/components/ui/alert';
import { Loader2, AlertTriangle, Navigation, Clock, MapPin } from 'lucide-react';

// Google Maps type declarations
declare global {
  interface Window {
    google: any;
  }
}

export interface DeliveryMapDisplayProps {
  tripId: string;
  origin: MapLocation;
  stops: TripStop[];
  onStopsOptimized?: (stops: OptimizedStop[]) => void;
  onDirectionsLoaded?: (route: any) => void;
  autoOptimize?: boolean;
  height?: string;
  showETA?: boolean;
}

// Map marker colors
const MARKER_COLORS = {
  origin: '#22c55e',    // Green
  stop: '#3b82f6',      // Blue
  current: '#f59e0b',   // Amber
  selected: '#ec4899',  // Pink
};

/**
 * DeliveryMapDisplay Component
 *
 * Displays an interactive Google Map with:
 * - Route polyline visualization
 * - Stop markers with sequence numbers
 * - Origin and destination markers
 * - ETA information
 * - Real-time driver location (if available)
 *
 * Features:
 * - Auto-optimization of delivery stops
 * - Click markers to show stop details
 * - Distance and duration information
 * - ETA countdown to next stop
 */
export const DeliveryMapDisplay: React.FC<DeliveryMapDisplayProps> = ({
  tripId,
  origin,
  stops,
  onStopsOptimized,
  onDirectionsLoaded,
  autoOptimize = true,
  height = '600px',
  showETA = true,
}) => {
  const mapRef = useRef<HTMLDivElement>(null);
  const gMapRef = useRef<any>(null);
  const markersRef = useRef<any[]>([]);
  const polylineRef = useRef<any>(null);

  const { isLoading, error, optimizeRoute, getDirections, calculateETA, clearErrors } =
    useDeliveryMap(tripId);

  const [selectedStop, setSelectedStop] = useState<TripStop | null>(null);
  const [eta, setEta] = useState<{ duration_minutes: number; distance_meters: number } | null>(
    null
  );
  const [currentLocation, setCurrentLocation] = useState<MapLocation>(origin);
  const [optimizedStops, setOptimizedStops] = useState<OptimizedStop[]>([]);

  // ── Initialize Google Map ──────────────────────────────────────────────────
  useEffect(() => {
    if (!mapRef.current) return;
    if (!window.google) return;

    const google = window.google;
    const defaultCenter = {
      lat: origin.lat,
      lng: origin.lng,
    };

    gMapRef.current = new google.maps.Map(mapRef.current, {
      zoom: 13,
      center: defaultCenter,
      mapTypeControl: true,
      fullscreenControl: true,
      streetViewControl: false,
      styles: [
        {
          featureType: 'poi',
          stylers: [{ visibility: 'off' }],
        },
      ],
    });
  }, [origin.lat, origin.lng]);

  // ── Auto-optimize route on load ────────────────────────────────────────────
  useEffect(() => {
    if (!autoOptimize || stops.length === 0) return;

    const performOptimization = async () => {
      const result = await optimizeRoute(origin, stops);
      if (result.length > 0) {
        setOptimizedStops(result);
        onStopsOptimized?.(result);

        // Get directions for first leg
        if (result.length > 0) {
          const firstStop = result[0];
          const route = await getDirections(origin, {
            lat: firstStop.lat,
            lng: firstStop.lng,
          });

          if (route.polyline) {
            onDirectionsLoaded?.(route);
          }
        }
      }
    };

    performOptimization();
  }, [stops, autoOptimize]);

  // ── Render markers and polyline ────────────────────────────────────────────
  useEffect(() => {
    if (!gMapRef.current) return;
    if (!window.google) return;

    const google = window.google;

    // Clear existing markers
    markersRef.current.forEach((marker) => marker.setMap(null));
    markersRef.current = [];

    // Clear existing polyline
    if (polylineRef.current) {
      polylineRef.current.setMap(null);
    }

    const stopsToDisplay = optimizedStops.length > 0 ? optimizedStops : stops;

    // Origin marker
    const originMarker = new google.maps.Marker({
      position: { lat: origin.lat, lng: origin.lng },
      map: gMapRef.current,
      title: 'Trip Start',
      icon: {
        path: google.maps.SymbolPath.CIRCLE,
        scale: 8,
        fillColor: MARKER_COLORS.origin,
        fillOpacity: 1,
        strokeColor: '#ffffff',
        strokeWeight: 2,
      },
      zIndex: 100,
    });

    const originInfoWindow = new google.maps.InfoWindow({
      content: '<div style="padding: 8px"><strong>Trip Start</strong></div>',
    });

    originMarker.addListener('click', () => {
      originInfoWindow.open(gMapRef.current, originMarker);
    });

    markersRef.current.push(originMarker);

    // Stop markers
    stopsToDisplay.forEach((stop, index) => {
      const isLast = index === stopsToDisplay.length - 1;
      const marker = new google.maps.Marker({
        position: { lat: stop.lat, lng: stop.lng },
        map: gMapRef.current,
        label: {
          text: (index + 1).toString(),
          color: '#ffffff',
          fontWeight: 'bold',
          fontSize: '12px',
        },
        icon: {
          path: google.maps.SymbolPath.CIRCLE,
          scale: 10,
          fillColor: isLast ? MARKER_COLORS.selected : MARKER_COLORS.stop,
          fillOpacity: 1,
          strokeColor: '#ffffff',
          strokeWeight: 2,
        },
        title: stop.address,
        zIndex: 50 - index,
      });

      const infoWindow = new google.maps.InfoWindow({
        content: `
          <div style="padding: 8px; max-width: 200px">
            <strong>Stop ${index + 1}</strong>
            <p style="margin: 4px 0; font-size: 12px">${stop.address}</p>
            ${stop.id ? `<small>ID: ${stop.id}</small>` : ''}
          </div>
        `,
      });

      marker.addListener('click', () => {
        infoWindow.open(gMapRef.current, marker);
        setSelectedStop(stop);
      });

      markersRef.current.push(marker);
    });

    // Draw polyline connecting all stops
    if (stopsToDisplay.length > 0) {
      const polylinePath = [
        { lat: origin.lat, lng: origin.lng },
        ...stopsToDisplay.map((stop) => ({ lat: stop.lat, lng: stop.lng })),
      ];

      polylineRef.current = new google.maps.Polyline({
        path: polylinePath,
        geodesic: true,
        strokeColor: '#3b82f6',
        strokeOpacity: 0.7,
        strokeWeight: 2,
        map: gMapRef.current,
        zIndex: 10,
      });
    }

    // Fit bounds to all markers
    if (markersRef.current.length > 0) {
      const bounds = new google.maps.LatLngBounds();
      markersRef.current.forEach((marker) => {
        bounds.extend(marker.getPosition());
      });
      gMapRef.current?.fitBounds(bounds, 50);
    }
  }, [optimizedStops, stops, origin]);

  // ── Calculate ETA to next stop ─────────────────────────────────────────────
  useEffect(() => {
    if (!showETA || optimizedStops.length === 0) return;

    const nextStop = optimizedStops[0];
    calculateETA(currentLocation, {
      lat: nextStop.lat,
      lng: nextStop.lng,
    }).then((etaData) => {
      setEta(etaData);
    });

    // Recalculate every 30 seconds
    const interval = setInterval(() => {
      calculateETA(currentLocation, {
        lat: nextStop.lat,
        lng: nextStop.lng,
      }).then((etaData) => {
        setEta(etaData);
      });
    }, 30000);

    return () => clearInterval(interval);
  }, [currentLocation, optimizedStops, showETA, calculateETA]);

  return (
    <Card className="w-full overflow-hidden">
      <div className="p-4 border-b bg-white">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold flex items-center gap-2">
            <Navigation className="w-5 h-5" />
            Delivery Route
          </h3>
          {optimizedStops.length > 0 && (
            <div className="text-sm text-gray-600">
              {optimizedStops.length} stops • Optimized
            </div>
          )}
        </div>
      </div>

      {error && (
        <Alert variant="danger" className="m-4">
          <div className="flex items-center gap-2">
            <AlertTriangle className="h-4 w-4 flex-shrink-0" />
            <span>{error}</span>
          </div>
        </Alert>
      )}

      {isLoading && (
        <div className="absolute inset-0 flex items-center justify-center bg-white/50 z-50">
          <Loader2 className="w-8 h-8 animate-spin text-blue-600" />
        </div>
      )}

      {/* Map Container */}
      <div ref={mapRef} style={{ height }} className="w-full bg-gray-100 relative" />

      {/* Info Panel */}
      <div className="p-4 bg-gray-50 border-t grid grid-cols-2 gap-4">
        {selectedStop && (
          <div className="col-span-2 p-3 bg-white rounded border border-blue-200">
            <h4 className="font-semibold text-sm mb-2 flex items-center gap-2">
              <MapPin className="w-4 h-4" />
              Selected Stop
            </h4>
            <p className="text-sm text-gray-700">{selectedStop.address}</p>
          </div>
        )}

        {eta && showETA && (
          <div className="p-3 bg-blue-50 rounded border border-blue-200">
            <div className="text-xs font-semibold text-blue-900 mb-1 flex items-center gap-2">
              <Clock className="w-3 h-3" />
              ETA to Next Stop
            </div>
            <p className="text-sm font-bold text-blue-700">
              {eta.duration_minutes} min
            </p>
            <p className="text-xs text-blue-600">
              {(eta.distance_meters / 1000).toFixed(1)} km
            </p>
          </div>
        )}

        <div className="p-3 bg-gray-50 rounded">
          <div className="text-xs font-semibold text-gray-700 mb-1">
            Total Stops
          </div>
          <p className="text-lg font-bold text-gray-900">
            {optimizedStops.length > 0 ? optimizedStops.length : stops.length}
          </p>
        </div>
      </div>
    </Card>
  );
};
