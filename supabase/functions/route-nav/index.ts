// Route2Go — /route-nav Edge Function
//
// Lightweight navigation routing: returns ONE recommended route with full
// geometry + turn-by-turn steps for the active navigation session. Unlike
// /trip-calculate it does NOT compute fuel/toll/budget and does NOT persist
// anything — it exists so live navigation can reroute from the user's current
// GPS position (through any added stops) without hammering the planner or
// writing DB rows on every reroute.
//
// Guests are allowed (consistent with trip-calculate): live navigation is part
// of the guest planning flow, and no user data is persisted here.

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import {
  getRoutingProvider,
  type RoutePoint,
} from "../_shared/providers/routingProvider.ts";
import { rateLimitGuard } from "../_shared/rateLimit.ts";

interface RouteNavRequest {
  origin: RoutePoint;
  destination: RoutePoint;
  waypoints?: RoutePoint[];
}

Deno.serve(async (req: Request) => {
  const reqId = requestId();

  if (req.method !== "POST") {
    return jsonError(
      405,
      "METHOD_NOT_ALLOWED",
      "Only POST is supported.",
      reqId,
      false,
    );
  }

  // Live reroutes are user-initiated and sparse; a generous per-key cap still
  // protects Valhalla from a single abusive client.
  const tooMany = rateLimitGuard(req, 30, 60_000, reqId);
  if (tooMany) return tooMany;

  let body: RouteNavRequest;
  try {
    body = await req.json();
  } catch {
    return jsonError(
      422,
      "INVALID_JSON",
      "Request body must be valid JSON.",
      reqId,
      false,
    );
  }

  const validationError = validateRouteNavRequest(body);
  if (validationError) {
    return jsonError(422, "VALIDATION_ERROR", validationError, reqId, false);
  }

  const routingProvider = getRoutingProvider();
  let route: Awaited<ReturnType<typeof routingProvider.getSingleRoute>>;
  try {
    // Navigation needs exactly one route. getSingleRoute issues a single
    // Valhalla request (no alternatives, no toll-free profile) so live reroutes
    // are fast and never discard work — see routingProvider.getSingleRoute.
    route = await routingProvider.getSingleRoute({
      origin: body.origin,
      destination: body.destination,
      waypoints: body.waypoints ?? [],
      roundTrip: false,
    });
  } catch {
    return jsonError(
      502,
      "ROUTE_PROVIDER_UNAVAILABLE",
      "Route data is temporarily unavailable. Please try again.",
      reqId,
      true,
    );
  }

  if (!route) {
    return jsonError(
      404,
      "NO_ROUTE_FOUND",
      "No route available for this input. Check the locations or try a nearby major town.",
      reqId,
      false,
    );
  }

  return jsonOk(
    {
      route: {
        route_type: route.routeType,
        distance_km: route.distanceKm,
        duration_min: route.durationMin,
        geometry: route.geometry,
        steps: route.steps,
        provider: route.provider,
        fetched_at: new Date().toISOString(),
      },
    },
    reqId,
  );
});

function validateRouteNavRequest(body: RouteNavRequest): string | null {
  if (
    !body?.origin || typeof body.origin.lat !== "number" ||
    typeof body.origin.lng !== "number"
  ) {
    return "origin.lat and origin.lng are required numbers.";
  }
  if (
    !body?.destination || typeof body.destination.lat !== "number" ||
    typeof body.destination.lng !== "number"
  ) {
    return "destination.lat and destination.lng are required numbers.";
  }
  if (body.waypoints) {
    if (!Array.isArray(body.waypoints)) {
      return "waypoints must be an array.";
    }
    for (const wp of body.waypoints) {
      if (!wp || typeof wp.lat !== "number" || typeof wp.lng !== "number") {
        return "each waypoint needs lat and lng numbers.";
      }
    }
  }
  const coordInRange = (lat: number, lng: number) =>
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  if (
    !coordInRange(body.origin.lat, body.origin.lng) ||
    !coordInRange(body.destination.lat, body.destination.lng)
  ) {
    return "Coordinates are out of valid range.";
  }
  return null;
}
