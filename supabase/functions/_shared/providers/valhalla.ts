// Valhalla routing: request building + response parsing (pure functions).
//
// This module is the Valhalla-specific half of the RoutingProvider abstraction
// (see routingProvider.ts). It never talks to the network itself and holds no
// secrets — feature code keeps going through `getRoutingProvider()`, so a
// future provider swap still requires zero changes to business logic.
//
// Version tolerance: Valhalla deployments differ in how they return the route
// shape. Newer servers honour `shape_format: "geojson"` (leg.shape is a GeoJSON
// LineString object); some deployments (e.g. the public FOSSGIS demo) always
// return `shape` as an encoded polyline string. Every parser here handles both
// so one adapter works against self-hosted and demo instances alike.
//
// Honesty rules (match the rest of Route2Go): nothing here fabricates a route,
// a turn, a street name or a cost. Distances/times/instructions come verbatim
// from Valhalla. "fastest"/"shortest"/"cheapest" labels are derived from the
// actual metrics of the returned routes; "no_toll" comes from a real
// `use_tolls: false` profile request, never from relabeling another route.

import type {
  RouteAlternative,
  RoutePoint,
  RouteSegment,
  RouteStep,
} from "./routingProvider.ts";

// ---------------------------------------------------------------- requests

export interface ValhallaLocation {
  lat: number;
  lon: number;
  type: "break" | "through";
}

export interface ValhallaRequest {
  locations: ValhallaLocation[];
  costing: "auto";
  costing_options: { auto: { use_tolls: boolean } };
  directions_options: { units: "kilometers"; language: string; format: "text" };
  alternates: number;
  shape_format: "geojson";
}

export interface BuildValhallaRequestParams {
  origin: RoutePoint;
  destination: RoutePoint;
  waypoints?: RoutePoint[];
  roundTrip: boolean;
  useTolls: boolean;
  alternates: number;
}

/** Builds a Valhalla `/route` request body for a point-to-point journey.
 * A round trip is modelled honestly as an out-and-back via a final break at the
 * origin — Valhalla then routes the real return leg instead of us multiplying
 * distances by two. */
export function buildValhallaRequest(
  params: BuildValhallaRequestParams,
): ValhallaRequest {
  const locations: ValhallaLocation[] = [];
  const add = (p: RoutePoint) =>
    locations.push({ lat: p.lat, lon: p.lng, type: "break" });

  add(params.origin);
  for (const wp of params.waypoints ?? []) add(wp);
  add(params.destination);
  if (params.roundTrip) add(params.origin);

  return {
    locations,
    costing: "auto",
    costing_options: { auto: { use_tolls: params.useTolls } },
    directions_options: { units: "kilometers", language: "en-US", format: "text" },
    alternates: params.alternates,
    shape_format: "geojson",
  };
}

// --------------------------------------------------------------- responses

export interface ValhallaManeuver {
  type?: number;
  instruction?: string;
  street_names?: string[];
  length?: number;
  time?: number;
  begin_shape_index?: number;
  end_shape_index?: number;
  begin_lat?: number;
  begin_lon?: number;
}

export interface ValhallaLeg {
  shape?: { type?: string; coordinates?: number[][] } | string;
  summary?: { length?: number; time?: number };
  maneuvers?: ValhallaManeuver[];
}

export interface ValhallaTrip {
  status?: number;
  summary?: { length?: number; time?: number };
  legs?: ValhallaLeg[];
}

export interface RawValhallaRoute {
  trip?: ValhallaTrip;
  alternates?: Array<{ trip?: ValhallaTrip }>;
}

/** Error codes Valhalla returns when no drivable route exists (vs. a server or
 * config problem). These should surface as "no route found" (404), never as a
 * 502 provider outage. */
const NO_ROUTE_ERROR_CODES = new Set<number | string>([
  106, 150, 156, 158, 160, 161, 171, 172, 173, 174, 175, 176, 177, 180, 181,
  182, 183, "NoSegment", "NoPathFound", "NoConnectivity", "RouteNotPossible",
  "NoSuitableEdges", "No suitable edges near location",
]);

/** True when a Valhalla error body means "no route", not "provider broke". */
export function isNoRouteError(body: unknown): boolean {
  if (!body || typeof body !== "object") return false;
  const code = (body as Record<string, unknown>).error_code;
  if (code === undefined || code === null) return false;
  return NO_ROUTE_ERROR_CODES.has(code as number | string);
}

/** Decodes a Google-style encoded polyline (Valhalla polyline6 default).
 * Returns [lng, lat] pairs, the order our geometry contract expects. */
export function decodeEncodedPolyline(
  encoded: string,
  precision = 1_000_000,
): number[][] {
  const coords: number[][] = [];
  let index = 0;
  let lat = 0;
  let lng = 0;

  while (index < encoded.length) {
    let result = 0;
    let shift = 0;
    let b: number;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dLat = (result & 1) ? ~(result >> 1) : (result >> 1);
    lat += dLat;

    result = 0;
    shift = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dLng = (result & 1) ? ~(result >> 1) : (result >> 1);
    lng += dLng;

    coords.push([lng / precision, lat / precision]);
  }
  return coords;
}

/** Extracts 2D [lng, lat] coordinates from one Valhalla leg, handling both the
 * GeoJSON object form (with optional elevation) and the encoded-polyline form. */
export function legShapeCoordinates(leg: ValhallaLeg): number[][] {
  const shape = leg.shape;
  if (shape && typeof shape === "object") {
    const coords = shape.coordinates;
    if (Array.isArray(coords)) {
      const points: number[][] = [];
      for (const c of coords) {
        if (Array.isArray(c) && c.length >= 2) {
          points.push([Number(c[0]), Number(c[1])]);
        }
      }
      return points;
    }
  }
  if (typeof shape === "string" && shape.length > 0) {
    return decodeEncodedPolyline(shape);
  }
  return [];
}

/** Merges per-leg shapes into one polyline, dropping the shared boundary point
 * between consecutive legs so the geometry has no duplicate vertex. */
export function concatenateShapes(legShapes: number[][][]): number[][] {
  const out: number[][] = [];
  for (const s of legShapes) {
    if (s.length === 0) continue;
    const last = out[out.length - 1];
    const start =
      last && s[0][0] === last[0] && s[0][1] === last[1] ? 1 : 0;
    for (let i = start; i < s.length; i++) out.push(s[i]);
  }
  return out;
}

/** Full-route GeoJSON LineString ({type, coordinates}), or null when no leg
 * carried usable geometry (callers then render the honest "no route map"
 * state — never a fabricated polyline). */
export function buildRouteGeometry(
  legs: ValhallaLeg[],
): { type: "LineString"; coordinates: number[][] } | null {
  const coords = concatenateShapes(legs.map(legShapeCoordinates));
  return coords.length >= 2
    ? { type: "LineString", coordinates: coords }
    : null;
}

/** The maneuver's maneuver point. Valhalla gives `begin_shape_index` into the
 * leg shape; newer versions also expose begin_lat/begin_lon. */
function maneuverPoint(
  m: ValhallaManeuver,
  shape: number[][],
): { lat: number; lng: number } {
  const idx = m.begin_shape_index;
  const pt = typeof idx === "number" ? shape[idx] : undefined;
  if (pt) return { lat: pt[1], lng: pt[0] };
  if (typeof m.begin_lat === "number" && typeof m.begin_lon === "number") {
    return { lat: m.begin_lat, lng: m.begin_lon };
  }
  return { lat: 0, lng: 0 };
}

function firstStreetName(names?: string[]): string | null {
  const n = names?.find((x) => x && x.trim().length > 0);
  return n ? n : null;
}

// Maneuver-type enums differ between Valhalla versions (older releases shift the
// numbers), so we derive the maneuver kind from the provider's own instruction
// text first and only fall back to the numeric table. The instruction text is
// authoritative provider data — never rewritten or fabricated here.
export function maneuverKind(instruction: string, type: number): string {
  const text = instruction.toLowerCase();
  if (text.length === 0) return "continue"; // no guidance -> UI shows progress, not fake text
  if (text.includes("you have arrived") || text.includes("destination is") ||
      text.includes("destination will be") || text.includes("arrive at")) {
    return "arrive";
  }
  if (text.startsWith("head ") || text.startsWith("drive ") ||
      text.startsWith("start") || text.startsWith("depart")) {
    return "depart";
  }
  if (text.includes("roundabout") || text.includes("rotary") ||
      text.includes("traffic circle")) {
    return "roundabout";
  }
  if (text.includes("u-turn") || text.includes("uturn")) return "uturn";
  if (text.includes("merge")) return "merge";
  if (text.includes("ramp") || text.includes("slip road")) return "on ramp";
  if (text.includes("exit") || text.includes("take the exit")) {
    return "off ramp";
  }
  if (text.includes("fork")) return "fork";
  if (text.includes("keep") && (text.includes("left") || text.includes("right"))) {
    return "turn";
  }
  if (text.includes("bear") && (text.includes("left") || text.includes("right"))) {
    return "turn";
  }
  if (text.includes("turn")) return "turn";
  if (text.includes("continue")) return "continue";
  if (text.startsWith("the road") || text.includes("becomes")) return "new name";
  // Best-effort numeric fallback (Valhalla 3.x numbering).
  switch (type) {
    case 14:
    case 29:
    case 30:
    case 31:
    case 32:
      return "depart";
    case 15:
      return "arrive";
    case 4:
    case 8:
    case 33:
      return "uturn";
    case 27:
    case 28:
    case 34:
    case 35:
    case 36:
    case 37:
    case 38:
      return "roundabout";
    case 18:
    case 19:
    case 39:
    case 40:
      return "merge";
    case 10:
    case 11:
    case 20:
    case 21:
    case 24:
    case 42:
    case 53:
    case 54:
      return "on ramp";
    case 12:
    case 13:
    case 22:
    case 23:
    case 25:
    case 41:
    case 51:
    case 52:
    case 70:
    case 71:
      return "off ramp";
    case 46:
    case 47:
    case 48:
    case 49:
    case 50:
      return "fork";
    case 16:
      return "new name";
    case 1:
    case 2:
    case 3:
    case 5:
    case 6:
    case 7:
    case 45:
      return "turn";
    default:
      return "continue";
  }
}

/** A nullable modifier (left / right / straight / uturn / …) derived from the
 * provider's instruction text, used only to enrich the step model. */
export function maneuverModifier(
  instruction: string,
  type: number,
): string | null {
  const text = instruction.toLowerCase();
  if (text.includes("u-turn") || text.includes("uturn")) return "uturn";
  if (text.includes("slight") && text.includes("left")) return "slight left";
  if (text.includes("slight") && text.includes("right")) return "slight right";
  if (text.includes("sharp") && text.includes("left")) return "sharp left";
  if (text.includes("sharp") && text.includes("right")) return "sharp right";
  if (text.includes("turn left") || text.includes("keep left")) return "left";
  if (text.includes("turn right") || text.includes("keep right")) return "right";
  if (text.includes("bear left")) return "slight left";
  if (text.includes("bear right")) return "slight right";
  if (text.includes("straight") || text.includes("go straight")) return "straight";
  switch (type) {
    case 1:
    case 27:
    case 35:
    case 30:
      return "slight right";
    case 2:
    case 18:
    case 20:
      return "right";
    case 3:
      return "sharp right";
    case 4:
    case 8:
    case 33:
      return "uturn";
    case 5:
      return "sharp left";
    case 6:
    case 19:
    case 21:
    case 31:
      return "left";
    case 7:
    case 28:
    case 36:
      return "slight left";
    case 9:
    case 24:
    case 25:
    case 32:
    case 37:
    case 39:
      return "straight";
    default:
      return null;
  }
}

/** Maps every Valhalla maneuver to our RouteStep shape. `distanceKm` is the
 * maneuver's own length (Valhalla reports it in km because we asked for
 * kilometers), so the ManeuverEngine's cumulative math stays correct. */
export function maneuversToSteps(legs: ValhallaLeg[]): RouteStep[] {
  const steps: RouteStep[] = [];
  for (const leg of legs ?? []) {
    const shape = legShapeCoordinates(leg);
    for (const m of leg.maneuvers ?? []) {
      const instruction = (m.instruction ?? "").trim();
      const { lat, lng } = maneuverPoint(m, shape);
      steps.push({
        instruction: instruction.length > 0 ? instruction : "",
        maneuverType: maneuverKind(instruction, m.type ?? 0),
        modifier: maneuverModifier(instruction, m.type ?? 0),
        name: firstStreetName(m.street_names),
        distanceKm: round1(m.length ?? 0),
        durationMin: Math.round((m.time ?? 0) / 60),
        lat,
        lng,
      });
    }
  }
  return steps;
}

/** Per-maneuver route segments, used by the toll provider to scan for plazas
 * near each road stretch. */
export function maneuversToSegments(legs: ValhallaLeg[]): RouteSegment[] {
  const segments: RouteSegment[] = [];
  for (const leg of legs ?? []) {
    const shape = legShapeCoordinates(leg);
    const ms = leg.maneuvers ?? [];
    for (const m of ms) {
      const start = maneuverPoint(m, shape);
      const endIdx = m.end_shape_index;
      const endPt = typeof endIdx === "number" ? shape[endIdx] : undefined;
      segments.push({
        startLat: start.lat,
        startLng: start.lng,
        endLat: endPt ? endPt[1] : start.lat,
        endLng: endPt ? endPt[0] : start.lng,
        distanceKm: round1(m.length ?? 0),
      });
    }
  }
  return segments;
}

// ------------------------------------------------------------- aggregation

/** A parsed Valhalla route, pre-label. Kept internal to this module so callers
 * only ever see the typed RouteAlternative. */
export interface ParsedValhallaRoute {
  distanceKm: number;
  durationMin: number;
  geometry: { type: "LineString"; coordinates: number[][] } | null;
  segments: RouteSegment[];
  steps: RouteStep[];
  isTollFree: boolean;
  isPrimary: boolean;
}

export function parseValhallaTrip(
  trip: ValhallaTrip | undefined,
  opts: { isTollFree: boolean; isPrimary: boolean },
): ParsedValhallaRoute | null {
  if (!trip) return null;
  const legs = trip.legs ?? [];
  if (legs.length === 0) return null;
  const distanceKm = round1(trip.summary?.length ?? 0);
  if (!(distanceKm > 0)) return null;
  return {
    distanceKm,
    durationMin: Math.round((trip.summary?.time ?? 0) / 60),
    geometry: buildRouteGeometry(legs),
    segments: maneuversToSegments(legs),
    steps: maneuversToSteps(legs),
    isTollFree: opts.isTollFree,
    isPrimary: opts.isPrimary,
  };
}

/** Collects every route Valhalla returned: the primary, its alternatives, the
 * toll-free profile's primary and its alternatives. Empty when the provider
 * had no usable route at all. */
export function collectValhallaRoutes(
  main: RawValhallaRoute,
  noToll?: RawValhallaRoute | null,
): ParsedValhallaRoute[] {
  const out: ParsedValhallaRoute[] = [];
  const pushTrip = (
    trip: ValhallaTrip | undefined,
    isTollFree: boolean,
    isPrimary: boolean,
  ) => {
    const r = parseValhallaTrip(trip, { isTollFree, isPrimary });
    if (r) out.push(r);
  };

  pushTrip(main.trip, false, true);
  for (const a of main.alternates ?? []) pushTrip(a.trip, false, false);

  if (noToll) {
    pushTrip(noToll.trip, true, false);
    for (const a of noToll.alternates ?? []) pushTrip(a.trip, true, false);
  }
  return out;
}

function routeSignature(r: ParsedValhallaRoute): string {
  const coords = r.geometry?.coordinates ?? [];
  const first = coords[0];
  const last = coords[coords.length - 1];
  return [
    Math.round(r.distanceKm * 10),
    Math.round(r.durationMin / 5) * 5,
    first ? `${first[0].toFixed(3)},${first[1].toFixed(3)}` : "?",
    last ? `${last[0].toFixed(3)},${last[1].toFixed(3)}` : "?",
  ].join("|");
}

/** Collapses identical routes (Valhalla can return the same path as both a
 * primary and an alternate). Keeps the first occurrence. */
export function dedupeValhallaRoutes(
  routes: ParsedValhallaRoute[],
): ParsedValhallaRoute[] {
  const seen = new Set<string>();
  const out: ParsedValhallaRoute[] = [];
  for (const r of routes) {
    const sig = routeSignature(r);
    if (seen.has(sig)) continue;
    seen.add(sig);
    out.push(r);
  }
  return out;
}

/** Assigns honest labels from the actual returned metrics:
 *  - recommended = Valhalla's primary
 *  - no_toll      = the real toll-avoiding profile result (never a relabel)
 *  - fastest      = minimum duration among the remaining routes
 *  - shortest     = minimum distance among the remaining routes
 *  - cheapest     = minimum distance among what's left (fuel cost scales with
 *                   distance; the toll engine prices the route independently)
 * Fewer than five distinct routes is fine — the UI renders whatever arrives. */
export function labelValhallaRoutes(
  routes: ParsedValhallaRoute[],
): RouteAlternative[] {
  const deduped = dedupeValhallaRoutes(routes);
  const out: RouteAlternative[] = [];
  const used = new Set<ParsedValhallaRoute>();
  const label = (
    r: ParsedValhallaRoute,
    routeType: RouteAlternative["routeType"],
  ) => {
    used.add(r);
    out.push(toAlternative(r, routeType));
  };
  const unlabeled = () => deduped.filter((r) => !used.has(r));

  const primary = deduped.find((r) => r.isPrimary);
  if (primary) label(primary, "recommended");

  const tollFree = deduped.find((r) => r.isTollFree && !used.has(r));
  if (tollFree) label(tollFree, "no_toll");

  const fastest = unlabeled().reduce(
    (a, b) => (b.durationMin < a.durationMin ? b : a),
    unlabeled()[0],
  );
  if (fastest) label(fastest, "fastest");

  const shortest = unlabeled().reduce(
    (a, b) => (b.distanceKm < a.distanceKm ? b : a),
    unlabeled()[0],
  );
  if (shortest) label(shortest, "shortest");

  const cheapest = unlabeled().reduce(
    (a, b) => (b.distanceKm < a.distanceKm ? b : a),
    unlabeled()[0],
  );
  if (cheapest) label(cheapest, "cheapest");

  return out.slice(0, 5);
}

function toAlternative(
  r: ParsedValhallaRoute,
  routeType: RouteAlternative["routeType"],
): RouteAlternative {
  return {
    routeType,
    distanceKm: r.distanceKm,
    durationMin: r.durationMin,
    geometry: r.geometry,
    segments: r.segments,
    steps: r.steps,
    provider: "valhalla",
  };
}

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}