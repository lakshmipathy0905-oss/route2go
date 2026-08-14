// Unit tests for the Valhalla routing adapter (pure functions in
// _shared/providers/valhalla.ts): request building, response parsing, polyline
// decoding, maneuver mapping, labeling, error classification and worldwide
// coverage. Run: deno test --allow-import valhalla_test.ts

import { assertEquals, assert, assertAlmostEquals } from "https://deno.land/std@0.221.0/assert/mod.ts";
import {
  buildValhallaRequest,
  decodeEncodedPolyline,
  legShapeCoordinates,
  concatenateShapes,
  buildRouteGeometry,
  maneuversToSteps,
  maneuversToSegments,
  parseValhallaTrip,
  collectValhallaRoutes,
  labelValhallaRoutes,
  isNoRouteError,
  type ValhallaLeg,
  type ValhallaManeuver,
} from "./valhalla.ts";

const ORIGIN = { label: "Bengaluru", lat: 12.9716, lng: 77.5946 };
const DEST = { label: "Mysuru", lat: 12.3052, lng: 76.6552 };
const WAYPOINT = { label: "Ramanagara", lat: 12.723, lng: 77.282 };

// ----------------------------------------------------------- request build

Deno.test("buildValhallaRequest produces a one-way auto request", () => {
  const req = buildValhallaRequest({
    origin: ORIGIN,
    destination: DEST,
    roundTrip: false,
    useTolls: true,
    alternates: 3,
  });
  assertEquals(req.costing, "auto");
  assertEquals(req.shape_format, "geojson");
  assertEquals(req.alternates, 3);
  assertEquals(req.costing_options.auto.use_tolls, true);
  assertEquals(req.directions_options.units, "kilometers");
  assertEquals(req.directions_options.format, "text");
  assertEquals(req.locations, [
    { lat: 12.9716, lon: 77.5946, type: "break" },
    { lat: 12.3052, lon: 76.6552, type: "break" },
  ]);
});

Deno.test("buildValhallaRequest routes through waypoints in order", () => {
  const req = buildValhallaRequest({
    origin: ORIGIN,
    destination: DEST,
    waypoints: [WAYPOINT],
    roundTrip: false,
    useTolls: true,
    alternates: 0,
  });
  assertEquals(req.locations.map((l) => [l.lat, l.lon]), [
    [12.9716, 77.5946],
    [12.723, 77.282],
    [12.3052, 76.6552],
  ]);
});

Deno.test("buildValhallaRequest models a round trip as an out-and-back", () => {
  const req = buildValhallaRequest({
    origin: ORIGIN,
    destination: DEST,
    roundTrip: true,
    useTolls: false,
    alternates: 1,
  });
  assertEquals(req.costing_options.auto.use_tolls, false);
  assertEquals(req.locations.length, 3);
  const last = req.locations[req.locations.length - 1];
  assertEquals([last.lat, last.lon], [12.9716, 77.5946]);
});

// ------------------------------------------------------------ polyline

// Pre-computed polyline6 (precision 1e6) for [12.9716,77.5946] and
// [12.3052,76.6552], produced with the standard Google encode algorithm.
const TWO_POINT_POLYLINE6 =
  "_dvvWo}~~rC~ptg@nwix@";

Deno.test("decodeEncodedPolyline round-trips a known polyline6", () => {
  const pts = decodeEncodedPolyline(TWO_POINT_POLYLINE6);
  assertEquals(pts.length, 2);
  assertAlmostEquals(pts[0][1], 12.9716, 1e-5);
  assertAlmostEquals(pts[0][0], 77.5946, 1e-5);
  assertAlmostEquals(pts[1][1], 12.3052, 1e-5);
  assertAlmostEquals(pts[1][0], 76.6552, 1e-5);
});

Deno.test("decodeEncodedPolyline handles an empty input", () => {
  assertEquals(decodeEncodedPolyline(""), []);
});

// Antimeridian-crossing polyline6 (precision 1e6) for [lng, lat] points
// [178.4501,-18.1248] -> [179.3510,-17.8540] -> [-179.6010,-17.4020] ->
// [-175.2020,-21.1420] (Suva -> Tonga), produced with the standard algorithm.
const ANTIMERIDIAN_POLYLINE6 =
  "~~fqa@gjvjsI_|oOgq~u@_yqZ~buskT~tgcFoxnkG";

Deno.test("decodeEncodedPolyline preserves an antimeridian crossing exactly", () => {
  const pts = decodeEncodedPolyline(ANTIMERIDIAN_POLYLINE6);
  assertEquals(pts.length, 4);
  // The jump +179 -> -179 must be preserved verbatim, never wrapped/normalised:
  // the client is responsible for any antimeridian rendering strategy, but the
  // parser must not corrupt the provider's raw coordinates.
  assertAlmostEquals(pts[1][0], 179.3510, 1e-5);
  assertAlmostEquals(pts[2][0], -179.6010, 1e-5);
  assertAlmostEquals(pts[3][1], -21.1420, 1e-5);
  assert(pts[1][0] > 0 && pts[2][0] < 0, "crossing retains both signs");
});

// ------------------------------------------------------------ geometry integrity

function geoJsonLeg(coords: number[][]): ValhallaLeg {
  return {
    shape: { type: "LineString", coordinates: coords },
    summary: { length: 146.2, time: 13419 },
    maneuvers: [
      { type: 14, instruction: "Head out.", length: 0.1, time: 6, begin_shape_index: 0 },
      { type: 15, instruction: "You have arrived at your destination.", length: 0, time: 0, begin_shape_index: coords.length - 1 },
    ],
  };
}

Deno.test("geometry integrity: BLR->Mysuru keeps [lng,lat] order, ends match endpoints", () => {
  // Realistic Valhalla GeoJSON shape: coordinates are [lng, lat].
  const shape: number[][] = [
    [77.5946, 12.9716],
    [77.60, 12.97],
    [77.61, 12.95],
    [77.3, 12.5],
    [76.95, 12.4],
    [76.6552, 12.3052],
  ];
  const parsed = parseValhallaTrip(
    { status: 0, summary: { length: 146.2, time: 13419 }, legs: [geoJsonLeg(shape)] },
    { isTollFree: false, isPrimary: true },
  );
  assert(parsed !== null);
  const coords = parsed.geometry?.coordinates;
  assert(coords !== null && coords !== undefined, "geometry present");
  assert(coords.length >= 2);
  // First = origin, last = destination, each in [lng, lat] order. If these were
  // inverted, 12.97 would appear in the lng slot (wrong hemisphere/lat range).
  assertAlmostEquals(coords[0][0], 77.5946, 1e-9);
  assertAlmostEquals(coords[0][1], 12.9716, 1e-9);
  assertAlmostEquals(coords[coords.length - 1][0], 76.6552, 1e-9);
  assertAlmostEquals(coords[coords.length - 1][1], 12.3052, 1e-9);
  // No coordinate may be silently swapped: lng in [-180,180], lat in [-90,90].
  for (const [lng, lat] of coords) {
    assert(lng >= -180 && lng <= 180, "lng in range");
    assert(lat >= -90 && lat <= 90, "lat in range");
    assert(lng !== lat, "lng and lat slots not coincident");
  }
});

Deno.test("geometry integrity: London->Manchester keeps negative lng signs", () => {
  const shape: number[][] = [
    [-0.1278, 51.5074],
    [-0.5, 52.0],
    [-1.2, 52.5],
    [-1.9, 53.0],
    [-2.2426, 53.4808],
  ];
  const parsed = parseValhallaTrip(
    { status: 0, summary: { length: 336.2, time: 14564 }, legs: [geoJsonLeg(shape)] },
    { isTollFree: false, isPrimary: true },
  );
  assert(parsed !== null);
  const coords = parsed.geometry?.coordinates;
  assert(coords !== null && coords !== undefined);
  assertAlmostEquals(coords[0][0], -0.1278, 1e-9); // west of Greenwich, must stay negative
  assertAlmostEquals(coords[0][1], 51.5074, 1e-9);
  assertAlmostEquals(coords[coords.length - 1][0], -2.2426, 1e-9);
  assertAlmostEquals(coords[coords.length - 1][1], 53.4808, 1e-9);
  for (const [lng, lat] of coords) {
    assert(lng < 0, "lng stays negative (no eastward sign flip)");
    assert(lat > 0, "lat stays positive (no inversion into lng slot)");
  }
});

Deno.test("geometry integrity: A -> stop1 -> stop2 -> B preserves waypoint order", () => {
  // Three legs, each a [lng, lat] shape; shared boundary points are dropped once.
  const leg1 = geoJsonLeg([[77.5946, 12.9716], [77.4, 12.9], [77.282, 12.723]]);  // BLR -> stop1
  const leg2 = geoJsonLeg([[77.282, 12.723], [76.9, 12.5], [76.8, 12.4]]);         // stop1 -> stop2
  const leg3 = geoJsonLeg([[76.8, 12.4], [76.7, 12.35], [76.6552, 12.3052]]);     // stop2 -> BLR dest
  const parsed = parseValhallaTrip(
    { status: 0, summary: { length: 145.6, time: 13800 }, legs: [leg1, leg2, leg3] },
    { isTollFree: false, isPrimary: true },
  );
  assert(parsed !== null);
  const coords = parsed.geometry?.coordinates;
  assert(coords !== null && coords !== undefined);
  // Full path must be contiguous and monotonic toward the destination.
  assertAlmostEquals(coords[0][0], 77.5946, 1e-9);
  assertAlmostEquals(coords[coords.length - 1][0], 76.6552, 1e-9);
  // The waypoint (stop1 at 77.282,12.723) must appear on the path in order.
  const stop1 = coords.find(([lng, lat]) => lng === 77.282 && lat === 12.723);
  assert(stop1 !== undefined, "stop1 present on geometry");
  const stop2 = coords.find(([lng, lat]) => lng === 76.8 && lat === 12.4);
  assert(stop2 !== undefined, "stop2 present on geometry");
  assert(coords.indexOf(stop1!) < coords.indexOf(stop2!), "waypoints appear in order");
  // One shared boundary point per seam is dropped (no duplicate vertices).
  assertEquals(coords.length, 3 + 3 + 3 - 2);
});

// ------------------------------------------------------------ shape forms

function legWithGeoJsonShape(coords: number[][]): ValhallaLeg {
  return { shape: { type: "LineString", coordinates: coords }, summary: {}, maneuvers: [] };
}

Deno.test("legShapeCoordinates accepts GeoJSON shape and strips elevation", () => {
  const leg = legWithGeoJsonShape([
    [77.5946, 12.9716, 920],
    [77.595, 12.972, 921],
  ]);
  assertEquals(legShapeCoordinates(leg), [
    [77.5946, 12.9716],
    [77.595, 12.972],
  ]);
});

Deno.test("legShapeCoordinates decodes the encoded-polyline form", () => {
  const leg: ValhallaLeg = { shape: TWO_POINT_POLYLINE6 };
  const pts = legShapeCoordinates(leg);
  assertEquals(pts.length, 2);
  assertAlmostEquals(pts[0][1], 12.9716, 1e-5);
  assertAlmostEquals(pts[1][0], 76.6552, 1e-5);
});

Deno.test("legShapeCoordinates returns [] for malformed shapes", () => {
  assertEquals(legShapeCoordinates({}), []);
  assertEquals(legShapeCoordinates({ shape: 42 as unknown as string }), []);
  assertEquals(legShapeCoordinates({ shape: { coordinates: "nope" as unknown as number[][] } }), []);
});

Deno.test("concatenateShapes drops the shared boundary point", () => {
  const merged = concatenateShapes([
    [[77.0, 12.0], [77.1, 12.1], [77.2, 12.2]],
    [[77.2, 12.2], [77.3, 12.3], [77.4, 12.4]],
  ]);
  assertEquals(merged, [
    [77.0, 12.0],
    [77.1, 12.1],
    [77.2, 12.2],
    [77.3, 12.3],
    [77.4, 12.4],
  ]);
});

Deno.test("buildRouteGeometry returns null when no usable geometry", () => {
  assertEquals(buildRouteGeometry([]), null);
  assertEquals(buildRouteGeometry([{ shape: "" }]), null);
  assertEquals(buildRouteGeometry([legWithGeoJsonShape([[77.0, 12.0]])]), null);
});

Deno.test("buildRouteGeometry merges legs into one LineString", () => {
  const g = buildRouteGeometry([
    legWithGeoJsonShape([[77.0, 12.0], [77.1, 12.1]]),
    legWithGeoJsonShape([[77.1, 12.1], [77.2, 12.2]]),
  ]);
  assertEquals(g, {
    type: "LineString",
    coordinates: [
      [77.0, 12.0],
      [77.1, 12.1],
      [77.2, 12.2],
    ],
  });
});

// -------------------------------------------------------------- maneuvers

function maneuver(overrides: Partial<ValhallaManeuver> = {}): ValhallaManeuver {
  return {
    type: 17,
    instruction: "Continue.",
    length: 1.4,
    time: 90,
    begin_shape_index: 0,
    end_shape_index: 4,
    ...overrides,
  };
}

Deno.test("maneuversToSteps keeps the provider's own instruction verbatim", () => {
  const shape = [[77.5946, 12.9716], [77.60, 12.96], [77.61, 12.95]];
  const legs = [{
    shape: { type: "LineString", coordinates: shape },
    maneuvers: [
      maneuver({ type: 14, instruction: "Drive east on MG Road.", street_names: ["MG Road"], length: 0.032, time: 9.6, begin_shape_index: 0 }),
      maneuver({ type: 6, instruction: "Turn left onto Ring Road.", street_names: ["Ring Road"], length: 3.2, time: 300, begin_shape_index: 1 }),
      maneuver({ type: 15, instruction: "You have arrived at your destination.", length: 0, time: 0, begin_shape_index: 2 }),
    ],
  }];
  const steps = maneuversToSteps(legs);

  assertEquals(steps.length, 3);
  assertEquals(steps[0].instruction, "Drive east on MG Road.");
  assertEquals(steps[0].maneuverType, "depart");
  assertEquals(steps[0].name, "MG Road");
  assertAlmostEquals(steps[0].distanceKm, 0.0, 0.01);
  assertEquals(steps[0].durationMin, 0);

  assertEquals(steps[1].instruction, "Turn left onto Ring Road.");
  assertEquals(steps[1].maneuverType, "turn");
  assertEquals(steps[1].modifier, "left");
  assertEquals(steps[1].name, "Ring Road");
  assertAlmostEquals(steps[1].distanceKm, 3.2, 0.01);
  assertEquals(steps[1].durationMin, 5);
  // Maneuver point comes from the shape at begin_shape_index.
  assertAlmostEquals(steps[1].lat, 12.96, 1e-9);
  assertAlmostEquals(steps[1].lng, 77.60, 1e-9);

  assertEquals(steps[2].maneuverType, "arrive");
});

Deno.test("maneuversToSteps handles roundabout and uturn semantics", () => {
  const steps = maneuversToSteps([{
    shape: { type: "LineString", coordinates: [[77.0, 12.0], [77.1, 12.1]] },
    maneuvers: [
      maneuver({ type: 34, instruction: "At the roundabout, take the second exit onto NH-275." }),
      maneuver({ type: 4, instruction: "Make a U-turn." }),
    ],
  }]);
  assertEquals(steps[0].maneuverType, "roundabout");
  assertEquals(steps[1].maneuverType, "uturn");
  assertEquals(steps[1].modifier, "uturn");
});

Deno.test("maneuversToSegments emits one segment per maneuver", () => {
  const segments = maneuversToSegments([{
    shape: { type: "LineString", coordinates: [[77.0, 12.0], [77.1, 12.1], [77.2, 12.2]] },
    maneuvers: [
      maneuver({ length: 1.0, begin_shape_index: 0, end_shape_index: 1 }),
      maneuver({ length: 2.0, begin_shape_index: 1, end_shape_index: 2 }),
    ],
  }]);
  assertEquals(segments.length, 2);
  assertAlmostEquals(segments[0].startLng, 77.0, 1e-9);
  assertAlmostEquals(segments[0].endLng, 77.1, 1e-9);
  assertAlmostEquals(segments[0].distanceKm, 1.0, 0.01);
  assertAlmostEquals(segments[1].distanceKm, 2.0, 0.01);
});

// ------------------------------------------------------- trip aggregation

function tripFor(distanceKm: number, durationSec: number, opts: { isTollFree: boolean; isPrimary: boolean; alt?: number } = { isTollFree: false, isPrimary: true }) {
  return {
    trip: {
      status: 0,
      summary: { length: distanceKm, time: durationSec },
      legs: [{
        shape: { type: "LineString", coordinates: [[77.0, 12.0], [77.5, 12.5], [78.0, 13.0]] },
        maneuvers: [
          maneuver({ type: 14, instruction: "Head out.", length: 0.1, time: 6, begin_shape_index: 0 }),
          maneuver({ type: 2, instruction: "Turn right.", length: distanceKm - 0.1, time: durationSec - 6, begin_shape_index: 1 }),
        ],
      }],
    },
  };
}

Deno.test("parseValhallaTrip maps summary distance/time and builds steps", () => {
  const parsed = parseValhallaTrip(tripFor(146.2, 13419).trip, { isTollFree: false, isPrimary: true });
  assert(parsed !== null);
  assertAlmostEquals(parsed.distanceKm, 146.2, 0.01);
  assertEquals(parsed.durationMin, 224);
  assertEquals(parsed.geometry?.type, "LineString");
  assertEquals(parsed.segments.length, 2);
  assertEquals(parsed.steps.length, 2);
  assertEquals(parsed.isPrimary, true);
  assertEquals(parsed.isTollFree, false);
});

Deno.test("parseValhallaTrip returns null for empty or zero-length trips", () => {
  assertEquals(parseValhallaTrip(undefined, { isTollFree: false, isPrimary: true }), null);
  assertEquals(
    parseValhallaTrip({ status: 0, summary: { length: 0, time: 0 }, legs: [] }, { isTollFree: false, isPrimary: true }),
    null,
  );
});

Deno.test("collectValhallaRoutes gathers primary, alternates and toll-free", () => {
  const main = {
    trip: tripFor(146.2, 13419, { isTollFree: false, isPrimary: true }).trip,
    alternates: [{ trip: tripFor(162.3, 18169, { isTollFree: false, isPrimary: false }).trip }],
  };
  const noToll = {
    trip: tripFor(141.3, 13748, { isTollFree: true, isPrimary: false }).trip,
  };
  const routes = collectValhallaRoutes(main, noToll);
  assertEquals(routes.length, 3);
  assertEquals(routes[0].isPrimary, true);
  assertEquals(routes[2].isTollFree, true);
});

Deno.test("labelValhallaRoutes labels from real metrics, dedupes, caps at five", () => {
  const main = {
    trip: tripFor(146.2, 13419).trip,
    alternates: [
      { trip: tripFor(162.3, 18169).trip },
      { trip: tripFor(155.1, 16800).trip },
    ],
  };
  const noToll = { trip: tripFor(141.3, 13748).trip };
  const routes = collectValhallaRoutes(main, noToll);

  const labeled = labelValhallaRoutes(routes);
  assertEquals(labeled.length, 4);
  assertEquals(labeled[0].routeType, "recommended");
  assertAlmostEquals(labeled[0].distanceKm, 146.2, 0.01);
  assertEquals(labeled[1].routeType, "no_toll");
  assertAlmostEquals(labeled[1].distanceKm, 141.3, 0.01);
  // fastest = minimum duration among the unlabeled (155.1km/280min vs 162.3km/303min).
  assertEquals(labeled[2].routeType, "fastest");
  assertAlmostEquals(labeled[2].distanceKm, 155.1, 0.01);
  assertEquals(labeled[3].routeType, "shortest");
  assertAlmostEquals(labeled[3].distanceKm, 162.3, 0.01);
  for (const r of labeled) assertEquals(r.provider, "valhalla");
});

Deno.test("labelValhallaRoutes collapses identical routes", () => {
  const main = {
    trip: tripFor(146.2, 13419).trip,
    alternates: [
      { trip: tripFor(146.2, 13419).trip }, // duplicate of the primary
    ],
  };
  const routes = collectValhallaRoutes(main);
  assertEquals(routes.length, 2);
  const labeled = labelValhallaRoutes(routes);
  assertEquals(labeled.length, 1);
  assertEquals(labeled[0].routeType, "recommended");
});

Deno.test("labelValhallaRoutes tolerates a missing toll-free result", () => {
  const main = { trip: tripFor(146.2, 13419).trip };
  const labeled = labelValhallaRoutes(collectValhallaRoutes(main, null));
  assertEquals(labeled.length, 1);
  assertEquals(labeled[0].routeType, "recommended");
});

// -------------------------------------------------------------- error map

Deno.test("isNoRouteError classifies Valhalla no-route codes", () => {
  assertEquals(isNoRouteError({ error_code: 171, error: "No suitable edges near location" }), true);
  assertEquals(isNoRouteError({ error_code: 156 }), true);
  assertEquals(isNoRouteError({ error_code: 100 }), false);
  assertEquals(isNoRouteError({ error_code: "NoPathFound" }), true);
  assertEquals(isNoRouteError({}), false);
  assertEquals(isNoRouteError(null), false);
});

// --------------------------------------------------------- worldwide docs

const WORLDWIDE: Array<{ city: string; lat: number; lng: number }> = [
  { city: "Bengaluru", lat: 12.9716, lng: 77.5946 },
  { city: "Goa", lat: 15.2993, lng: 74.124 },
  { city: "London", lat: 51.5074, lng: -0.1278 },
  { city: "New York", lat: 40.7128, lng: -74.006 },
  { city: "Tokyo", lat: 35.6762, lng: 139.6503 },
  { city: "Sydney", lat: -33.8688, lng: 151.2093 },
  { city: "Dubai", lat: 25.2048, lng: 55.2708 },
];

Deno.test("worldwide coverage: request building keeps coordinates in range and order", () => {
  for (const c of WORLDWIDE) {
    const req = buildValhallaRequest({
      origin: { label: c.city, lat: c.lat, lng: c.lng },
      destination: { label: "Downtown", lat: c.lat + 0.05, lng: c.lng + 0.05 },
      roundTrip: false,
      useTolls: true,
      alternates: 3,
    });
    assertEquals(req.locations.length, 2);
    for (const l of req.locations) {
      assert(l.lat >= -90 && l.lat <= 90, `${c.city} lat out of range`);
      assert(l.lon >= -180 && l.lon <= 180, `${c.city} lon out of range`);
    }
    assertEquals(req.locations[0].lat, c.lat);
  }
});