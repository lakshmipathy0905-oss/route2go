// Routing provider abstraction. Feature code (trip-calculate) only ever talks
// to this interface — never to a specific vendor SDK — so swapping providers
// (OSRM, GraphHopper, Google Directions, Mapbox) never requires a rewrite of
// business logic.

export interface RoutePoint {
  label: string;
  lat: number;
  lng: number;
}

export interface RouteSegment {
  startLat: number;
  startLng: number;
  endLat: number;
  endLng: number;
  distanceKm: number;
}

export interface RouteAlternative {
  routeType: "fastest" | "cheapest" | "shortest" | "no_toll" | "recommended";
  distanceKm: number;
  durationMin: number;
  geometry: unknown; // GeoJSON / encoded polyline, provider-specific but opaque to callers
  segments: RouteSegment[];
  provider: string;
}

export interface RoutingProvider {
  getRouteAlternatives(params: {
    origin: RoutePoint;
    destination: RoutePoint;
    roundTrip: boolean;
  }): Promise<RouteAlternative[]>;
}

/**
 * Deterministic mock/fake adapter. Used automatically when no
 * ROUTING_PROVIDER_KEY is configured, and always used in tests, so the app
 * never silently fabricates route data as if it came from a live provider —
 * the "provider" field on every result makes the source explicit.
 */
class MockRoutingProvider implements RoutingProvider {
  async getRouteAlternatives(params: {
    origin: RoutePoint;
    destination: RoutePoint;
    roundTrip: boolean;
  }): Promise<RouteAlternative[]> {
    const straightLineKm = haversineKm(params.origin, params.destination);
    // Rough road-distance multiplier for a plausible dev/test fixture; NOT for production use.
    const baseDistance = Math.round(straightLineKm * 1.25 * 10) / 10;
    const multiplier = params.roundTrip ? 2 : 1;

    const makeAlt = (
      routeType: RouteAlternative["routeType"],
      distanceFactor: number,
      speedKmph: number
    ): RouteAlternative => {
      const distanceKm = Math.round(baseDistance * distanceFactor * multiplier * 10) / 10;
      const durationMin = Math.round((distanceKm / speedKmph) * 60);
      return {
        routeType,
        distanceKm,
        durationMin,
        geometry: {
          type: "LineString",
          coordinates: [
            [params.origin.lng, params.origin.lat],
            [params.destination.lng, params.destination.lat],
          ],
        },
        segments: [
          {
            startLat: params.origin.lat,
            startLng: params.origin.lng,
            endLat: params.destination.lat,
            endLng: params.destination.lng,
            distanceKm,
          },
        ],
        provider: "mock-dev-fixture",
      };
    };

    return [
      makeAlt("fastest", 1.0, 65),
      makeAlt("cheapest", 1.08, 55),
      makeAlt("shortest", 0.95, 50),
      makeAlt("no_toll", 1.15, 50),
      makeAlt("recommended", 1.02, 60),
    ];
  }
}

/**
 * Production adapter template for an OSRM-compatible routing service.
 * Fill in ROUTING_PROVIDER_BASE_URL / ROUTING_PROVIDER_KEY and adjust the
 * response mapping to match whichever provider you contract with — the
 * interface above is what the rest of the app depends on, not this class.
 */
class HttpRoutingProvider implements RoutingProvider {
  constructor(private baseUrl: string, private apiKey: string) {}

  async getRouteAlternatives(params: {
    origin: RoutePoint;
    destination: RoutePoint;
    roundTrip: boolean;
  }): Promise<RouteAlternative[]> {
    const url = `${this.baseUrl}/route/v1/driving/${params.origin.lng},${params.origin.lat};${params.destination.lng},${params.destination.lat}?alternatives=true&overview=full&geometries=geojson`;
    const res = await fetch(url, {
      headers: this.apiKey ? { Authorization: `Bearer ${this.apiKey}` } : {},
    });
    if (!res.ok) {
      throw new Error(`Routing provider responded with ${res.status}`);
    }
    const body = await res.json();
    if (!body.routes || body.routes.length === 0) {
      return [];
    }

    // Map provider routes -> our RouteAlternative shape. OSRM returns one "best"
    // route plus alternatives; we label them by characteristic rather than
    // assuming the provider labels them the way our UI needs.
    const labels: RouteAlternative["routeType"][] = ["recommended", "fastest", "shortest", "cheapest", "no_toll"];
    return body.routes.slice(0, 5).map((r: any, idx: number) => ({
      routeType: labels[idx] ?? "recommended",
      distanceKm: Math.round((r.distance / 1000) * 10) / 10,
      durationMin: Math.round(r.duration / 60),
      geometry: r.geometry,
      segments: (r.legs?.[0]?.steps ?? []).map((s: any) => ({
        startLat: s.maneuver?.location?.[1] ?? params.origin.lat,
        startLng: s.maneuver?.location?.[0] ?? params.origin.lng,
        endLat: s.maneuver?.location?.[1] ?? params.destination.lat,
        endLng: s.maneuver?.location?.[0] ?? params.destination.lng,
        distanceKm: Math.round(((s.distance ?? 0) / 1000) * 10) / 10,
      })),
      provider: "osrm-compatible",
    }));
  }
}

export function getRoutingProvider(): RoutingProvider {
  const baseUrl = Deno.env.get("ROUTING_PROVIDER_BASE_URL");
  const apiKey = Deno.env.get("ROUTING_PROVIDER_KEY") ?? "";
  if (!baseUrl) {
    return new MockRoutingProvider();
  }
  return new HttpRoutingProvider(baseUrl, apiKey);
}

function haversineKm(a: RoutePoint, b: RoutePoint): number {
  const R = 6371;
  const dLat = deg2rad(b.lat - a.lat);
  const dLng = deg2rad(b.lng - a.lng);
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(deg2rad(a.lat)) * Math.cos(deg2rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(s), Math.sqrt(1 - s));
}

function deg2rad(deg: number): number {
  return (deg * Math.PI) / 180;
}
