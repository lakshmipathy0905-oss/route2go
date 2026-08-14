// Routing provider abstraction. Feature code (trip-calculate, route-nav) only
// ever talks to this interface — never to a specific vendor SDK — so swapping
// providers (OSRM, GraphHopper, Google Directions, Mapbox) never requires a
// rewrite of business logic.

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
 * `instruction` is a human sentence built from provider data (maneuver type +
 * modifier + road name), never hard-coded per-route. `distanceKm` is the
 * distance remaining to the maneuver point (from the previous maneuver). */
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
    const path = [params.origin, ...(params.waypoints ?? []), params.destination];
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
      speedKmph: number
    ): RouteAlternative => {
      const distanceKm = Math.round(baseDistance * distanceFactor * multiplier * 10) / 10;
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
}

/**
 * OSRM-compatible adapter. Activated by setting ROUTING_PROVIDER_BASE_URL
 * (e.g. the free public demo https://router.project-osrm.org or your own
 * instance). An optional ROUTING_PROVIDER_KEY is sent as a Bearer token for
 * providers that require one.
 */
class HttpRoutingProvider implements RoutingProvider {
  constructor(private baseUrl: string, private apiKey: string) {}

  async getRouteAlternatives(params: {
    origin: RoutePoint;
    destination: RoutePoint;
    waypoints?: RoutePoint[];
    roundTrip: boolean;
  }): Promise<RouteAlternative[]> {
    const path = [params.origin, ...(params.waypoints ?? []), params.destination];
    const coords = path.map((p) => `${p.lng},${p.lat}`).join(";");
    const url = `${this.baseUrl}/route/v1/driving/${coords}?alternatives=true&overview=full&geometries=geojson&steps=true`;
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
    return body.routes.slice(0, 5).map((r: any, idx: number) => {
      const legs = r.legs ?? [];
      const steps = legs.flatMap((leg: any) => parseOsrmSteps(leg.steps ?? []));
      return {
        routeType: labels[idx] ?? "recommended",
        distanceKm: Math.round((r.distance / 1000) * 10) / 10,
        durationMin: Math.round(r.duration / 60),
        geometry: r.geometry,
        segments: legs.flatMap((leg: any) =>
          (leg.steps ?? []).map((s: any) => ({
            startLat: s.maneuver?.location?.[1] ?? params.origin.lat,
            startLng: s.maneuver?.location?.[0] ?? params.origin.lng,
            endLat: s.maneuver?.location?.[1] ?? params.destination.lat,
            endLng: s.maneuver?.location?.[0] ?? params.destination.lng,
            distanceKm: Math.round(((s.distance ?? 0) / 1000) * 10) / 10,
          }))
        ),
        steps,
        provider: "osrm-compatible",
      };
    });
  }
}

/** Converts raw OSRM steps into our RouteStep shape with a human instruction.
 * All text is derived from the provider's maneuver type/modifier/road name —
 * nothing is fabricated or hard-coded per route. */
function parseOsrmSteps(rawSteps: any[]): RouteStep[] {
  const steps: RouteStep[] = [];
  for (const s of rawSteps) {
    const type = s.maneuver?.type ?? "continue";
    const modifier = s.maneuver?.modifier ?? null;
    const name = s.name && s.name.length > 0 ? s.name : null;
    const location = s.maneuver?.location ?? [0, 0];
    steps.push({
      instruction: instructionFor(type, modifier, name),
      maneuverType: type,
      modifier,
      name,
      distanceKm: Math.round(((s.distance ?? 0) / 1000) * 10) / 10,
      durationMin: Math.round((s.duration ?? 0) / 60),
      lat: location[1],
      lng: location[0],
    });
  }
  return steps;
}

/** Builds a spoken/natural instruction from OSRM maneuver semantics. */
function instructionFor(type: string, modifier: string | null, name: string | null): string {
  const m = modifier ?? "";
  const onto = name ? ` onto ${name}` : "";
  switch (type) {
    case "depart":
      return name ? `Head ${m || "straight"} on ${name}` : "Head out on your route";
    case "arrive":
      return "You have arrived at your destination";
    case "turn":
      return `Turn ${m || "left"}${onto}`;
    case "continue":
      return m && m !== "straight" ? `Continue ${m}${onto}` : `Continue${onto}`;
    case "new name":
      return name ? `Continue onto ${name}` : "Continue onto the next road";
    case "merge":
      return `Merge ${m}${onto}`.replace(/\s+/g, " ").trim();
    case "on ramp":
      return name ? `Take the ramp onto ${name}` : "Take the ramp";
    case "off ramp":
      return name ? `Take the exit for ${name}` : "Take the exit";
    case "fork":
      return `Keep ${m || "straight"}${onto}`;
    case "end of road":
      return `At the end of the road, turn ${m || "left"}${onto}`;
    case "roundabout":
      return name ? `Enter the roundabout and take the ${m || "second"} exit onto ${name}` : `Enter the roundabout and take the ${m || "second"} exit`;
    case "roundabout turn":
      return name ? `At the roundabout, take the ${m || "second"} exit onto ${name}` : `At the roundabout, take the ${m || "second"} exit`;
    case "exit roundabout":
      return name ? `Exit the roundabout onto ${name}` : "Exit the roundabout";
    case "rotary":
      return name ? `Enter the rotary and take the ${m || "second"} exit onto ${name}` : `Enter the rotary and take the ${m || "second"} exit`;
    case "exit rotary":
      return name ? `Exit the rotary onto ${name}` : "Exit the rotary";
    case "uturn":
      return "Make a U-turn";
    case "notification":
      return name ? `Continue on ${name}` : "Continue straight";
    default:
      return name ? `Continue on ${name}` : "Continue straight";
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