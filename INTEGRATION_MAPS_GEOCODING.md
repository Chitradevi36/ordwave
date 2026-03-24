# Google Maps Integration Guide

## Overview

The Maps & Geocoding integration enables OrdWave to:

- **Route Optimization**: Automatically reorder delivery stops for optimal distance/time
- **Address Management**: Geocode addresses to coordinates and validate customer locations
- **Distance Calculations**: Calculate distances and ETAs between multiple points
- **Real-time Tracking**: Display live driver location with polylines and markers
- **Turn-by-turn Directions**: Get detailed routing instructions for drivers

## Architecture

### Backend Components

**Service Layer** (`backend/app/services/maps_service.rb`)
- Core wrapper around Google Maps Web Services API
- Implements route optimization using waypoint reordering
- Handles geocoding, reverse geocoding, and address validation
- Calculates distances, directions, and traffic-aware ETAs

**API Controller** (`backend/app/controllers/api/v1/trip_optimization_controller.rb`)
- RESTful endpoints for Maps operations
- Trip-scoped authorization
- Error handling and validation

**Database Models**
- `DeliveryTrip` - Represents a driver's delivery route
- `TripStop` - Individual delivery stops within a trip

### Frontend Components

**React Hook** (`web/lib/hooks/useDeliveryMap.ts`)
- Manages map state and API interactions
- Handles async operations with proper error handling
- Provides methods for all Maps operations

**Map Component** (`web/components/delivery/DeliveryMapDisplay.tsx`)
- Renders Google Map with route visualization
- Displays markers for origin, stops, and current location
- Shows polyline connecting all stops
- Real-time ETA calculation

## Setup Instructions

### 1. Google Maps API Configuration

#### Prerequisites
- Google Cloud Console account
- Billing enabled

#### Steps

```bash
# 1. Create a new Google Cloud Project or use existing

# 2. Enable these APIs:
#    - Maps JavaScript API (for frontend rendering)
#    - Maps Geocoding API (for address ↔ coordinates)
#    - Distance Matrix API (for multi-point distances)
#    - Directions API (for turn-by-turn routing)
#    - Places API (for address autocomplete)

# 3. Create an API Key for backend services:
#    - Go to: https://console.cloud.google.com/apis/credentials
#    - Create API Key (Server type)
#    - Restrict to Google Maps services
#    - Set HTTP referrers if needed

# 4. Create API Key for frontend services:
#    - Go to: https://console.cloud.google.com/apis/credentials
#    - Create API Key (Browser type)
#    - Restrict to HTTP referrers: yourdomain.com
#    - Restrict to Maps JavaScript API

# 5. Enable billing with realistic quota:
#    - Budget: ~$50-100/month per 10,000 deliveries
#    - Set up usage alerts
```

#### Document Reference

| Operation | Cost |
|-----------|------|
| Geocoding | $0.005 per request |
| Reverse Geocoding | $0.005 per request |
| Distance Matrix | $0.005 per element |
| Directions | $0.005 per request |
| Maps Display | $0.007 per session (28-day month) |

### 2. Backend Setup

#### Add to Gemfile

```ruby
gem "google-maps-service", "~> 0.4.2"
```

Then run:
```bash
bundle install
```

#### Environment Variables

Add to `backend/.env`:

```bash
# Google Maps Configuration
GOOGLE_MAPS_API_KEY=AIzaSyDxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
MAPS_TIMEOUT_SECONDS=30
MAPS_ENABLE_CACHING=true
MAPS_CACHE_TTL_HOURS=24
```

### 3. Frontend Setup

#### Install Google Maps JavaScript Library

Add to `web/app/layout.tsx`:

```tsx
<script
  async
  defer
  src={`https://maps.googleapis.com/maps/api/js?key=${process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY}&libraries=places,geometry`}
></script>
```

Add to `web/.env.local`:

```bash
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=AIzaSyDxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 4. Database Migrations

The system uses existing models:
- `DeliveryTrip` - Trip entities
- `TripStop` - Individual delivery stops

No new tables required (maps data stored in memory or returned via API).

## API Reference

### Endpoint: Optimize Delivery Route

```
POST /api/v1/delivery_trips/:trip_id/optimize_trip

Body:
{
  "origin": {
    "lat": 12.9716,
    "lng": 77.5946
  },
  "stops": [
    {
      "id": 1,
      "lat": 12.9352,
      "lng": 77.6245,
      "address": "123 Main Street, Bangalore"
    },
    {
      "id": 2,
      "lat": 12.9111,
      "lng": 77.6412,
      "address": "456 Park Avenue, Bangalore"
    }
  ]
}

Response (200):
{
  "optimized_stops": [
    {
      "id": 2,
      "lat": 12.9111,
      "lng": 77.6412,
      "address": "456 Park Avenue, Bangalore",
      "sequence": 1
    },
    {
      "id": 1,
      "lat": 12.9352,
      "lng": 77.6245,
      "address": "123 Main Street, Bangalore",
      "sequence": 2
    }
  ],
  "total_distance_km": 12.5,
  "total_duration_minutes": 25
}
```

### Endpoint: Calculate Distances

```
POST /api/v1/delivery_trips/:trip_id/distances

Body:
{
  "origins": [
    { "lat": 12.9716, "lng": 77.5946 },
    { "lat": 12.9352, "lng": 77.6245 }
  ],
  "destinations": [
    { "lat": 12.9111, "lng": 77.6412 },
    { "lat": 12.8761, "lng": 77.5955 }
  ],
  "mode": "driving"
}

Response (200):
{
  "distances": [
    [
      { "distance": 12500, "duration": 1500 },
      { "distance": 18200, "duration": 2100 }
    ],
    [
      { "distance": 8900, "duration": 1100 },
      { "distance": 14300, "duration": 1800 }
    ]
  ]
}
```

### Endpoint: Get Directions

```
GET /api/v1/delivery_trips/:trip_id/directions?origin_lat=12.97&origin_lng=77.59&dest_lat=12.93&dest_lng=77.62

Response (200):
{
  "polyline": "yvqhEw_...very_long_encoded_polyline...",
  "distance_m": 12500,
  "duration_s": 1500,
  "steps": [
    {
      "instruction": "Head south on Main Street",
      "distance": 2100,
      "duration": 180
    },
    {
      "instruction": "Turn right onto Park Avenue",
      "distance": 3200,
      "duration": 240
    }
  ]
}
```

### Endpoint: Calculate ETA

```
POST /api/v1/delivery_trips/:trip_id/eta

Body:
{
  "current_location": { "lat": 12.9716, "lng": 77.5946 },
  "destination": { "lat": 12.9352, "lng": 77.6245 }
}

Response (200):
{
  "duration_minutes": 15,
  "distance_meters": 12500,
  "formatted_duration": "15 mins"
}
```

### Endpoint: Geocode Address

```
POST /api/v1/delivery_trips/:trip_id/geocode

Body:
{
  "address": "123 Main Street, Bangalore, Karnataka 560001"
}

Response (200):
{
  "lat": 12.9716,
  "lng": 77.5946,
  "formatted_address": "123 Main Street, Bangalore, Karnataka 560001, India",
  "address_components": {
    "street": "123 Main Street",
    "city": "Bangalore",
    "state": "Karnataka",
    "zip": "560001",
    "country": "India"
  }
}
```

### Endpoint: Reverse Geocode

```
GET /api/v1/delivery_trips/:trip_id/reverse_geocode?lat=12.97&lng=77.59

Response (200):
{
  "address": "123 Main Street, Bangalore, Karnataka 560001",
  "city": "Bangalore",
  "state": "Karnataka",
  "zip": "560001"
}
```

### Endpoint: Validate Address

```
POST /api/v1/delivery_trips/:trip_id/validate_address

Body:
{
  "address": "123 Main St, Bangalore, KA"
}

Response (200):
{
  "valid": true,
  "formatted_address": "123 Main Street, Bangalore, Karnataka 560001"
}
```

## Frontend Usage

### Basic Usage

```tsx
import { DeliveryMapDisplay } from '@/components/delivery/DeliveryMapDisplay';

export function DeliveryPage() {
  const tripId = 'trip-123';
  const origin = { lat: 12.9716, lng: 77.5946 };
  const stops = [
    { id: 1, lat: 12.9352, lng: 77.6245, address: 'Customer 1' },
    { id: 2, lat: 12.9111, lng: 77.6412, address: 'Customer 2' },
  ];

  return (
    <DeliveryMapDisplay
      tripId={tripId}
      origin={origin}
      stops={stops}
      autoOptimize={true}
      showETA={true}
      height="600px"
      onStopsOptimized={(optimized) => {
        console.log('Route optimized:', optimized);
      }}
    />
  );
}
```

### Using the Hook Directly

```tsx
import { useDeliveryMap } from '@/lib/hooks/useDeliveryMap';

export function CustomMapComponent() {
  const {
    isLoading,
    error,
    optimizeRoute,
    calculateETA,
    geocodeAddress,
  } = useDeliveryMap('trip-123');

  // Optimize route
  const handleOptimize = async () => {
    const origin = { lat: 12.9716, lng: 77.5946 };
    const stops = [/* ... */];
    
    const optimized = await optimizeRoute(origin, stops);
    console.log('Optimized:', optimized);
  };

  // Calculate ETA
  const handleETA = async () => {
    const eta = await calculateETA(
      { lat: 12.9716, lng: 77.5946 },
      { lat: 12.9352, lng: 77.6245 }
    );
    console.log('ETA:', eta.duration_minutes, 'minutes');
  };

  return (
    <div>
      {error && <div className="text-red-600">{error}</div>}
      <button onClick={handleOptimize} disabled={isLoading}>
        Optimize Route
      </button>
      <button onClick={handleETA} disabled={isLoading}>
        Get ETA
      </button>
    </div>
  );
}
```

## Integration Points

### 1. Delivery Assignment Page

When assigning stops to a driver:

```tsx
// Show map with auto-optimized stops
<DeliveryMapDisplay
  tripId={tripId}
  origin={depotLocation}
  stops={selectedStops}
  autoOptimize={true}
  onStopsOptimized={(optimized) => {
    // Save optimized sequence to trip
    updateTripStops(optimized);
  }}
/>
```

### 2. Delivery Tracking Page

Real-time tracking of driver and deliveries:

```tsx
// Update current location every 10 seconds
useEffect(() => {
  const interval = setInterval(async () => {
    const location = await getDriverCurrentLocation(driverId);
    updateMapLocation(location);
  }, 10000);
  return () => clearInterval(interval);
}, [driverId]);
```

### 3. Customer Address Management

Validate addresses during order creation:

```tsx
// Validate customer address when typed in form
const handleAddressChange = async (address: string) => {
  const validated = await validateAddress(address);
  if (validated.valid) {
    setFormAddress(validated.formatted_address);
  } else {
    showError('Invalid address');
  }
};
```

### 4. ETA Display in Customer Notifications

Show ETAs when sending delivery notifications:

```tsx
// In SMS/Push notification payload
const eta = await calculateETA(currentLocation, customerLocation);
sendNotification({
  message: `Driver arriving in ${eta.duration_minutes} minutes`,
  deliveryTime: eta
});
```

## Performance Optimization

### Caching

The `MapsService` caches:
- Geocoded addresses (24 hours)
- Distance matrices for same origin/destinations (1 hour)
- Directions for frequent routes (6 hours)

Configure cache via environment:

```bash
MAPS_ENABLE_CACHING=true
MAPS_CACHE_TTL_HOURS=24
```

### Request Batching

Groups multiple geocoding/distance requests:

```rb
# Instead of individual requests
locations = addresses.map { |a| maps.geocode_address(a) }

# Consider batch operations where API supports
```

### API Usage Limits

Monitor quota and costs:

```bash
# Daily estimates
# 100 deliveries/day × 3 stops avg × 2 API calls = 600 calls
# Cost: 600 × $0.005 = $3/day = ~$90/month
```

## Testing

### Unit Tests

```ruby
# spec/services/maps_service_spec.rb
describe MapsService do
  let(:maps) { described_class.new }

  describe '#geocode_address' do
    it 'converts address to coordinates' do
      result = maps.geocode_address('123 Main Street, Bangalore')
      expect(result).to have_key(:lat)
      expect(result).to have_key(:lng)
    end
  end

  describe '#optimize_route' do
    it 'reorders stops for efficiency' do
      origin = { lat: 12.9716, lng: 77.5946 }
      stops = [/* ... */]
      result = maps.optimize_route(origin, stops)
      expect(result.length).to eq(stops.length)
    end
  end
end
```

### Integration Tests

```typescript
// __tests__/hooks/useDeliveryMap.test.ts
import { renderHook, act, waitFor } from '@testing-library/react';
import { useDeliveryMap } from '@/lib/hooks/useDeliveryMap';

describe('useDeliveryMap', () => {
  it('optimizes delivery route', async () => {
    const { result } = renderHook(() => useDeliveryMap('trip-123'));

    await act(async () => {
      const optimized = await result.current.optimizeRoute(
        { lat: 12.9716, lng: 77.5946 },
        [/* stops */]
      );
      expect(optimized).toBeDefined();
    });
  });
});
```

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Maps API not initialized" | Script not loaded | Add script tag in layout.tsx |
| "Invalid API key" | Credentials misconfigured | Verify GOOGLE_MAPS_API_KEY in .env |
| "Address not found" | Invalid address format | Validate with validateAddress endpoint |
| "Service unavailable" | API quota exceeded | Check billing, increase quotas |

### Debugging

Enable verbose logging in development:

```bash
# backend/.env
MAPS_DEBUG=true
```

Check API quotas:
- https://console.cloud.google.com/apis/api/maps-backend/quotas

Monitor dashboard requests:
- https://console.cloud.google.com/apis/api/maps-backend/metrics

## Deployment

### Production Checklist

- [ ] API keys restricted to production domains
- [ ] Billing alerts configured
- [ ] Rate limiting implemented
- [ ] Error handling for API degradation
- [ ] Monitoring for unusual API usage
- [ ] Caching configured appropriately
- [ ] Load testing with projected traffic
- [ ] Documentation reviewed with team

### Scaling Considerations

For high-volume deployments (1000+ deliveries/day):

1. **Cache Heavily**: Pre-compute common routes
2. **Batch Requests**: Group geocoding operations
3. **Regional Caching**: Use CDN for JavaScript
4. **API Versioning**: Use V3 endpoint with web services
5. **Fallback Strategy**: Plan for API outages

## Support & Documentation

- [Google Maps Platform Documentation](https://developers.google.com/maps)
- [Distance Matrix API](https://developers.google.com/maps/documentation/distance-matrix)
- [Geocoding API](https://developers.google.com/maps/documentation/geocoding)
- [Directions API](https://developers.google.com/maps/documentation/directions)
- [Maps JavaScript API](https://developers.google.com/maps/documentation/javascript)

---

**Last Updated**: March 2026
**Integration Version**: 1.0
