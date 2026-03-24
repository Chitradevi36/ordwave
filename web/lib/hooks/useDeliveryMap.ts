// ── Delivery Map & Route Optimization Hook ──────────────────────────────────
// Manages map state, route optimization, and real-time driver tracking

import { useCallback, useRef, useState } from 'react';
import { apiClient } from '@/lib/api/client';

export interface MapLocation {
  lat: number;
  lng: number;
}

export interface TripStop {
  id: string | number;
  lat: number;
  lng: number;
  address: string;
  sequence?: number;
}

export interface OptimizedStop extends TripStop {
  sequence: number;
}

export interface RouteData {
  polyline: string;
  distance_m: number;
  duration_s: number;
  steps?: RouteStep[];
}

export interface RouteStep {
  instruction: string;
  distance: number;
  duration: number;
}

export interface ETAData {
  duration_minutes: number;
  distance_meters: number;
  formatted_duration?: string;
}

export interface DistanceMatrix {
  [key: string]: {
    [key: string]: {
      distance: number;
      duration: number;
    };
  };
}

export interface UseDeliveryMapReturn {
  // Map initialization
  isLoading: boolean;
  error: string | null;

  // Route optimization
  optimizedStops: OptimizedStop[];
  optimizeRoute: (origin: MapLocation, stops: TripStop[]) => Promise<OptimizedStop[]>;

  // Route data
  currentRoute: RouteData | null;
  getDirections: (origin: MapLocation, destination: MapLocation) => Promise<RouteData>;

  // Distance calculations
  distances: DistanceMatrix | null;
  calculateDistances: (
    origins: MapLocation[],
    destinations: MapLocation[],
    mode?: 'driving' | 'walking'
  ) => Promise<DistanceMatrix>;

  // ETA calculations
  calculateETA: (current: MapLocation, destination: MapLocation) => Promise<ETAData>;

  // Address operations
  geocodeAddress: (address: string) => Promise<MapLocation & { formatted_address: string }>;
  reverseGeocode: (lat: number, lng: number) => Promise<string>;
  validateAddress: (address: string) => Promise<{ valid: boolean; formatted_address: string }>;

  // Trip management
  tripId: string | null;
  setTripId: (id: string | null) => void;
  clearErrors: () => void;
}

export const useDeliveryMap = (tripId?: string): UseDeliveryMapReturn => {
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentTripId, setCurrentTripId] = useState<string | null>(tripId || null);
  const [optimizedStops, setOptimizedStops] = useState<OptimizedStop[]>([]);
  const [currentRoute, setCurrentRoute] = useState<RouteData | null>(null);
  const [distances, setDistances] = useState<DistanceMatrix | null>(null);

  const abortControllerRef = useRef<AbortController | null>(null);

  const clearErrors = useCallback(() => {
    setError(null);
  }, []);

  const handleError = useCallback(
    (err: any, message: string) => {
      console.error(`[Maps] ${message}:`, err);
      setError(message);
      setIsLoading(false);
    },
    []
  );

  // ── Optimize Delivery Route ────────────────────────────────────────────────
  const optimizeRoute = useCallback(
    async (origin: MapLocation, stops: TripStop[]): Promise<OptimizedStop[]> => {
      if (!currentTripId) {
        handleError(new Error('No trip ID'), 'Trip ID is required for optimization');
        return [];
      }

      setIsLoading(true);
      clearErrors();

      try {
        abortControllerRef.current = new AbortController();

        const response = await apiClient.post(
          `/api/v1/delivery_trips/${currentTripId}/optimize_trip`,
          {
            origin,
            stops: stops.map((stop) => ({
              id: stop.id,
              lat: stop.lat,
              lng: stop.lng,
              address: stop.address,
            })),
          },
          {
            signal: abortControllerRef.current.signal,
          }
        );

        const optimized = response.data.optimized_stops || [];
        setOptimizedStops(optimized);
        return optimized;
      } catch (err: any) {
        if (err.name !== 'AbortError') {
          handleError(err, 'Failed to optimize route');
        }
        return [];
      } finally {
        setIsLoading(false);
      }
    },
    [currentTripId, clearErrors, handleError]
  );

  // ── Get Directions Between Two Points ────────────────────────────────────
  const getDirections = useCallback(
    async (origin: MapLocation, destination: MapLocation): Promise<RouteData> => {
      if (!currentTripId) {
        handleError(new Error('No trip ID'), 'Trip ID is required for directions');
        return { polyline: '', distance_m: 0, duration_s: 0 };
      }

      setIsLoading(true);
      clearErrors();

      try {
        abortControllerRef.current = new AbortController();

        const response = await apiClient.get(
          `/api/v1/delivery_trips/${currentTripId}/directions`,
          {
            params: {
              origin_lat: origin.lat,
              origin_lng: origin.lng,
              dest_lat: destination.lat,
              dest_lng: destination.lng,
            },
            signal: abortControllerRef.current.signal,
          }
        );

        const route = response.data || {};
        setCurrentRoute(route);
        return route;
      } catch (err: any) {
        if (err.name !== 'AbortError') {
          handleError(err, 'Failed to fetch directions');
        }
        return { polyline: '', distance_m: 0, duration_s: 0 };
      } finally {
        setIsLoading(false);
      }
    },
    [currentTripId, clearErrors, handleError]
  );

  // ── Calculate Distance Matrix ──────────────────────────────────────────────
  const calculateDistances = useCallback(
    async (
      origins: MapLocation[],
      destinations: MapLocation[],
      mode: 'driving' | 'walking' = 'driving'
    ): Promise<DistanceMatrix> => {
      if (!currentTripId) {
        handleError(new Error('No trip ID'), 'Trip ID is required for distance calculation');
        return {};
      }

      setIsLoading(true);
      clearErrors();

      try {
        abortControllerRef.current = new AbortController();

        const response = await apiClient.post(
          `/api/v1/delivery_trips/${currentTripId}/distances`,
          {
            origins,
            destinations,
            mode,
          },
          {
            signal: abortControllerRef.current.signal,
          }
        );

        const matrix = response.data.distances || {};
        setDistances(matrix);
        return matrix;
      } catch (err: any) {
        if (err.name !== 'AbortError') {
          handleError(err, 'Failed to calculate distances');
        }
        return {};
      } finally {
        setIsLoading(false);
      }
    },
    [currentTripId, clearErrors, handleError]
  );

  // ── Calculate ETA ──────────────────────────────────────────────────────────
  const calculateETA = useCallback(
    async (current: MapLocation, destination: MapLocation): Promise<ETAData> => {
      if (!currentTripId) {
        handleError(new Error('No trip ID'), 'Trip ID is required for ETA calculation');
        return { duration_minutes: 0, distance_meters: 0 };
      }

      setIsLoading(true);
      clearErrors();

      try {
        abortControllerRef.current = new AbortController();

        const response = await apiClient.post(
          `/api/v1/delivery_trips/${currentTripId}/eta`,
          {
            current_location: current,
            destination,
          },
          {
            signal: abortControllerRef.current.signal,
          }
        );

        return response.data || { duration_minutes: 0, distance_meters: 0 };
      } catch (err: any) {
        if (err.name !== 'AbortError') {
          handleError(err, 'Failed to calculate ETA');
        }
        return { duration_minutes: 0, distance_meters: 0 };
      } finally {
        setIsLoading(false);
      }
    },
    [currentTripId, clearErrors, handleError]
  );

  // ── Geocode Address to Coordinates ─────────────────────────────────────────
  const geocodeAddress = useCallback(
    async (address: string): Promise<MapLocation & { formatted_address: string }> => {
      if (!currentTripId) {
        handleError(new Error('No trip ID'), 'Trip ID is required for geocoding');
        return { lat: 0, lng: 0, formatted_address: '' };
      }

      setIsLoading(true);
      clearErrors();

      try {
        abortControllerRef.current = new AbortController();

        const response = await apiClient.post(
          `/api/v1/delivery_trips/${currentTripId}/geocode`,
          { address },
          {
            signal: abortControllerRef.current.signal,
          }
        );

        return response.data || { lat: 0, lng: 0, formatted_address: '' };
      } catch (err: any) {
        if (err.name !== 'AbortError') {
          handleError(err, `Failed to geocode address: "${address}"`);
        }
        return { lat: 0, lng: 0, formatted_address: '' };
      } finally {
        setIsLoading(false);
      }
    },
    [currentTripId, clearErrors, handleError]
  );

  // ── Reverse Geocode (Coordinates to Address) ──────────────────────────────
  const reverseGeocode = useCallback(
    async (lat: number, lng: number): Promise<string> => {
      if (!currentTripId) {
        handleError(new Error('No trip ID'), 'Trip ID is required for reverse geocoding');
        return '';
      }

      setIsLoading(true);
      clearErrors();

      try {
        abortControllerRef.current = new AbortController();

        const response = await apiClient.get(
          `/api/v1/delivery_trips/${currentTripId}/reverse_geocode`,
          {
            params: { lat, lng },
            signal: abortControllerRef.current.signal,
          }
        );

        return response.data?.address || '';
      } catch (err: any) {
        if (err.name !== 'AbortError') {
          handleError(err, 'Failed to reverse geocode location');
        }
        return '';
      } finally {
        setIsLoading(false);
      }
    },
    [currentTripId, clearErrors, handleError]
  );

  // ── Validate Address ───────────────────────────────────────────────────────
  const validateAddress = useCallback(
    async (address: string): Promise<{ valid: boolean; formatted_address: string }> => {
      if (!currentTripId) {
        handleError(
          new Error('No trip ID'),
          'Trip ID is required for address validation'
        );
        return { valid: false, formatted_address: '' };
      }

      setIsLoading(true);
      clearErrors();

      try {
        abortControllerRef.current = new AbortController();

        const response = await apiClient.post(
          `/api/v1/delivery_trips/${currentTripId}/validate_address`,
          { address },
          {
            signal: abortControllerRef.current.signal,
          }
        );

        return response.data || { valid: false, formatted_address: '' };
      } catch (err: any) {
        if (err.name !== 'AbortError') {
          handleError(err, 'Failed to validate address');
        }
        return { valid: false, formatted_address: '' };
      } finally {
        setIsLoading(false);
      }
    },
    [currentTripId, clearErrors, handleError]
  );

  return {
    // State
    isLoading,
    error,
    tripId: currentTripId,
    setTripId: setCurrentTripId,
    optimizedStops,
    currentRoute,
    distances,

    // Methods
    optimizeRoute,
    getDirections,
    calculateDistances,
    calculateETA,
    geocodeAddress,
    reverseGeocode,
    validateAddress,
    clearErrors,
  };
};
