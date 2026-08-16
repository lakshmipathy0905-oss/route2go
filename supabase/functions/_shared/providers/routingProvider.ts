// Routing provider abstraction. Feature code (trip-calculate, route-nav) only
// ever talks to this interface — never to a specific vendor SDK — so swapping
// providers (Valhalla, GraphHopper, Google Directions, Mapbox) never requires a
// rewrite of business logic.
//
// Production adapter: Valhalla (`ValhallaRoutingProvider`). Activated by
// setting VALHALLA_BASE_URL (preferred) or the legacy ROUTING_PROVIDER_BASE_URL.
// A deterministic mock is used when neither is configured (local dev/tests) and
// is clearly labelled `mock-dev-fixture` so it is never mistaken for real data.

import {
  buildValhallaRequest,
  collectValhallaRoutes,
  isNoRouteError,
  labelValhallaRoutes,
  type RawValhallaRoute,
} from "./valhalla.ts";

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

/** One turn-by-turn instruction extracted from the provider's response.
 * `instruction` is taken verbatim from the provider (Valhalla returns a
 * ready-to-display sentence such as "Drive east."); it is never hard-coded or
 * fabricated per-route. `distanceKm` is the distance remaining to the maneuver
 * point (from the previous maneuver). */
export interface RouteStep {
  instruction: string;
  maneuverType: string; // depart | turn | new name | continue | arrive | roundabout | ...
  modifier: string | null; // left | right | straight | slight left | uturn | ...
  name: string | null; // road name, when the provider supplies one
  distanceKm: number;
  durationMin: number;
  lat: number;
  lng: number;
}

export interface RouteAlternative {
  routeType: "fastest" | "cheapest" | "shortest" | "no_toll" | "recommended";
  distanceKm: number;
  durationMin: number;
  geometry: unknown; // GeoJSON / encoded polyline, provider-specific but opaque to callers
  segments: RouteSegment[];
  steps: RouteStep[]; // turn-by-turn instructions; empty when the provider gives none
  provider: string;
}

export interface RoutingProvider {
  getRouteAlternatives(params: {
    origin: RoutePoint;
    destination: RoutePoint;
    waypoints?: RoutePoint[];
    roundTrip: boolean;
  }): Promise<RouteAlternative[]>;

  /** Returns exactly ONE route (the provider's primary/recommended). Used by
   * /route-nav so live reroutes never pay for alternatives or a toll-free
   * profile they discard. Returns null when no drivable route exists. */
  getSingleRoute(params: {
    origin: RoutePoint;
    destination: RoutePoint;
    waypoints?: RoutePoint[];
    roundTrip: boolean;
  }): Promise<RouteAlternative | null>;
}

/**
 * Deterministic mock/fake adapter. Used automatically when no
 * ROUTING_PROVIDER_BASE_URL is configured, and always used in tests, so the
 * app never silently fabricates route data as if it came from a live provider —
 * the "provider" field on every result makes the source explicit.
 */
class MockRoutingProvider implements RoutingProvider {
  async getRouteAlternatives(params: {
    origin: RoutePoint;
    destination: RoutePoint;
    waypoints?: RoutePoint[];
    roundTrip: boolean;
  }): Promise<RouteAlternative[]> {
    const path = [
      params.origin,
      ...(params.waypoints ?? []),
      params.destination,
    ];
    let straightLineKm = 0;
    for (let i = 1; i < path.length; i++) {
      straightLineKm += haversineKm(path[i - 1], path[i]);
    }
    // Rough road-distance multiplier for a plausible dev/test fixture; NOT for production use.
    const baseDistance = Math.round(straightLineKm * 1.25 * 10) / 10;
    const multiplier = params.roundTrip ? 2 : 1;

    const makeAlt = (
      routeType: RouteAlternative["routeType"],
      distanceFactor: number,
      speedKmph: number,
    ): RouteAlternative => {
      const distanceKm =
        Math.round(baseDistance * distanceFactor * multiplier * 10) / 10;
      const durationMin = Math.round((distanceKm / speedKmph) * 60);
      return {
        routeType,
        distanceKm,
        durationMin,
        // Geometry follows the waypoint path so reroute previews show the stops.
        geometry: {
          type: "LineString",
          coordinates: path.map((p) => [p.lng, p.lat]),
        },
        segments: path.slice(1).map((p, i) => ({
          startLat: path[i].lat,
          startLng: path[i].lng,
          endLat: p.lat,
          endLng: p.lng,
          distanceKm: Math.round(haversineKm(path[i], p) * 1.25 * 10) / 10,
        })),
        // The mock has no real road/street data, so it returns NO instructions.
        // Callers must fall back to route-progress display (never fabricate).
        steps: [],
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

  async getSingleRoute(params: {
    origin: RoutePoint;
    destination: RoutePoint;
    waypoints?: RoutePoint[];
    roundTrip: boolean;
  }): Promise<RouteAlternative | null> {
    const alternatives = await this.getRouteAlternatives(params);
    // Keep dev consistent with production semantics: live navigation follows
    // the recommended (primary) route, so the mock returns that too.
    return alternatives.find((a) => a.routeType === "recommended") ??
      alternatives[0] ??
      null;
  }
}

/**
 * Valhalla adapter. Activated by setting VALHALLA_BASE_URL (or the legacy
 * ROUTING_PROVIDER_BASE_URL). The request/response translation lives in
 * ./valhalla.ts; this class owns the HTTP call and the error mapping.
 *
 * The public demo endpoint (https://valhalla1.openstreetmap.de) is for dev/test
 * only — production must point at a self-hosted instance (see infra/valhalla).
 * An optional ROUTING_PROVIDER_KEY is sent as a Bearer token for instances that
 * require one.
 */
class ValhallaRoutingProvider implements RoutingProvider {
  constructor(private baseUrl: string, private apiKey: string) {}

  /** One POST to `/route` with a bounded timeout and at most one retry on
   * transient failures (network errors and 5xx only — never on 4xx input
   * errors). Returns `{ trip: undefined }` for a legitimate no-route answer. */
  private async postRoute(
    params: {
      origin: RoutePoint;
      destination: RoutePoint;
      waypoints?: RoutePoint[];
      roundTrip: boolean;
    },
    useTolls: boolean,
    alternates: number,
  ): Promise<RawValhallaRoute> {
    const base = this.baseUrl.replace(/\/+$/, "");
    const attempts = useTolls ? 2 : 1; // main retries once; toll-free stays fast
    const body = JSON.stringify(
      buildValhallaRequest({ ...params, useTolls, alternates }),
    );

    let res: Response | null = null;
    let lastError: unknown = null;
    for (let attempt = 0; attempt < attempts; attempt++) {
      if (attempt > 0) await new Promise((r) => setTimeout(r, 500));
      try {
        res = await fetch(`${base}/route`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...(this.apiKey ? { Authorization: `Bearer ${this.apiKey}` } : {}),
          },
          body,
          signal: AbortSignal.timeout(10_000),
        });
      } catch (err) {
        // Timeout (AbortError) or a network failure — retryable.
        lastError = err;
        continue;
      }
      // 5xx is transient; 4xx (including Valhalla no-route codes) must not
      // be retried — re-issuing a bad request only wastes the server.
      if (res.status >= 500 && res.status < 600 && attempt < attempts - 1) {
        lastError = new Error(`Valhalla returned ${res.status}`);
        continue;
      }
      break;
    }
    if (!res) {
      throw lastError instanceof Error
        ? lastError
        : new Error("Valhalla routing request failed");
    }
    if (!res.ok) {
      const bodyJson = await res.json().catch(() => null);
      if (isNoRouteError(bodyJson)) {
        // Legitimately no drivable route -> caller maps to 404 NO_ROUTE_FOUND.
        return { trip: undefined };
      }
      throw new Error(`Valhalla routing provider responded with ${res.status}`);
    }
    const json = (await res.json()) as RawValhallaRoute;
    if (!json || typeof json !== "object" || !json.trip) {
      throw new Error("Valhalla returned an unexpected response shape.");
    }
    return json;
  }

  async getRouteAlternatives(params: {
    origin: RoutePoint;
    destination: RoutePoint;
    waypoints?: RoutePoint[];
    roundTrip: boolean;
  }): Promise<RouteAlternative[]> {
    // Tolls-allowed profile: primary + up to 3 alternatives. A failure here is
    // fatal (the caller turns it into 502 ROUTE_PROVIDER_UNAVAILABLE).
    const main = await this.postRoute(params, true, 3);

    // Toll-avoiding profile for a genuine "no_toll" option. A failure here must
    // never kill the whole trip calculation — we just omit that option.
    let noToll: RawValhallaRoute | null = null;
    try {
      noToll = await this.postRoute(params, false, 1);
    } catch (err) {
      console.error(
        "valhalla no-toll request failed; skipping no_toll option",
        err,
      );
    }

    return labelValhallaRoutes(collectValhallaRoutes(main, noToll));
  }

  async getSingleRoute(params: {
    origin: RoutePoint;
    destination: RoutePoint;
    waypoints?: RoutePoint[];
    roundTrip: boolean;
  }): Promise<RouteAlternative | null> {
    // Navigation needs exactly one route: a single tolls-allowed request with
    // no alternatives. This keeps live reroutes fast and halves Valhalla load
    // versus the full alternatives request used by trip-calculate.
    const main = await this.postRoute(params, true, 0);
    const primary = collectValhallaRoutes(main).find((r) => r.isPrimary);
    if (!primary) return null;
    const labeled = labelValhallaRoutes([primary]);
    return labeled[0] ?? null;
  }
}

export function getRoutingProvider(): RoutingProvider {
  const baseUrl = Deno.env.get("VALHALLA_BASE_URL") ??
    Deno.env.get("ROUTING_PROVIDER_BASE_URL");
  if (!baseUrl) {
    return new MockRoutingProvider();
  }
  const apiKey = Deno.env.get("ROUTING_PROVIDER_KEY") ?? "";
  return new ValhallaRoutingProvider(baseUrl, apiKey);
}

function haversineKm(a: RoutePoint, b: RoutePoint): number {
  const R = 6371;
  const dLat = deg2rad(b.lat - a.lat);
  const dLng = deg2rad(b.lng - a.lng);
  const s = Math.sin(dLat / 2) ** 2 +
    Math.cos(deg2rad(a.lat)) * Math.cos(deg2rad(b.lat)) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(s), Math.sqrt(1 - s));
}

function deg2rad(deg: number): number {
  return (deg * Math.PI) / 180;
}
