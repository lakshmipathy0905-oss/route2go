// Route2Go — /trip/calculate Edge Function
//
// Responsibilities:
//  1. Verify the Firebase ID token sent as `Authorization: Bearer <token>`
//  2. Resolve the verified firebase_uid -> internal users.id (never trust client-supplied ids)
//  3. Call the routing provider (behind an interface so it's swappable)
//  4. Compute fuel/toll/total cost per route option
//  5. Persist route options against the trip
//  6. Return typed, freshness-labelled results — never a fabricated route/cost
//
// Deploy: supabase functions deploy trip-calculate
// Required secrets (set via `supabase secrets set`):
//   FIREBASE_PROJECT_ID
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//   ROUTING_PROVIDER_KEY   (optional in dev; mock adapter used if absent)
//   ROUTING_PROVIDER_BASE_URL

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  AuthError,
  authRequest,
  requireUser,
  resolveServiceRoleKey,
} from "../_shared/auth.ts";
import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { getRoutingProvider } from "../_shared/providers/routingProvider.ts";
import { getFuelPriceProvider } from "../_shared/providers/fuelPriceProvider.ts";
import { getTollProvider } from "../_shared/providers/tollProvider.ts";
import {
  computeFuelCost,
  round2,
  SAFETY_BUFFER_PCT,
} from "../_shared/fuelCostEngine.ts";
import { rateLimitGuard } from "../_shared/rateLimit.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = resolveServiceRoleKey();

// readPhaseFlags and the fuel engine live in _shared modules; the fuel engine
// (spec Section 12.1) is unit-tested in _shared/fuelCostEngine_test.ts.

interface CalculateRequest {
  origin: { label: string; lat: number; lng: number };
  destination: { label: string; lat: number; lng: number };
  trip_type: "one_way" | "round_trip";
  vehicle: {
    fuel_type: "petrol" | "diesel" | "ev" | "cng";
    mileage_kmpl?: number;
    ev_efficiency_kwh_per_km?: number;
    cng_mileage_km_per_kg?: number;
  };
  fuel_price_per_litre?: number;
  ev_price_per_kwh?: number;
  budget_total?: number;
  trip_id?: string; // optional: attach results to an existing draft trip
}

// Reads the gating flags for cost paths. Falls back to the same statics the// /feature-flags endpoint publishes so behaviour is consistent even if the
// table is unreachable (never fabricate a cost because a flag read failed).
async function readPhaseFlags(supabase: any): Promise<Record<string, boolean>> {
  const defaults: Record<string, boolean> = {
    phase2_ev: false,
    phase2_cng: false,
  };
  const { data, error } = await supabase.from("feature_flags").select(
    "key, enabled",
  );
  if (error || !data) return defaults;
  for (const row of data) {
    if (typeof row.enabled === "boolean") defaults[row.key] = row.enabled;
  }
  return defaults;
}

// Fuel price resolution: manual override always wins over provider data.
// For EV/CNG the cost engine is gated behind phase2_ev / phase2_cng flags.
// Never rejects: a provider failure degrades to "unavailable", never a crash.
async function resolveFuelPrice(
  body: CalculateRequest,
): Promise<
  { perUnit: number | null; source: string; freshness: string | null }
> {
  const fuelPriceProvider = getFuelPriceProvider();
  let fuelPricePerUnit: number | null = body.vehicle.fuel_type === "ev"
    ? (body.ev_price_per_kwh ?? null)
    : (body.fuel_price_per_litre ?? null);
  let fuelPriceSource: string = fuelPricePerUnit ? "manual" : "unavailable";
  let fuelPriceFreshness: string | null = null;

  if (!fuelPricePerUnit && body.vehicle.fuel_type !== "ev") {
    try {
      const priceInfo = await fuelPriceProvider.getPrice({
        region: "IN", // region derivation from lat/lng is a follow-up refinement
        fuelType: body.vehicle.fuel_type === "cng"
          ? "cng"
          : body.vehicle.fuel_type,
      });
      fuelPricePerUnit = priceInfo.price;
      fuelPriceSource = "provider";
      fuelPriceFreshness = priceInfo.lastUpdated;
    } catch {
      fuelPriceSource = "unavailable";
    }
  }
  return {
    perUnit: fuelPricePerUnit,
    source: fuelPriceSource,
    freshness: fuelPriceFreshness,
  };
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

  // Trip calculation is the highest-cost operation (Valhalla + DB writes).
  // A generous per-key cap still protects shared upstreams from a single
  // abusive client.
  const tooMany = rateLimitGuard(req, 60, 60_000, reqId);
  if (tooMany) return tooMany;

  // 1. Verify Firebase token (never trust client-provided uid/email).
  //    Guest mode is allowed here (spec Section 5.2): route calculation works
  //    signed out, but nothing is persisted to a user-owned trip. Authenticated
  //    callers get lazily provisioned via authRequest (see _shared/auth.ts).
  let ctx;
  try {
    ctx = await authRequest(req, { allowGuest: true });
  } catch (err) {
    if (err instanceof AuthError) {
      return jsonError(err.status, err.code, err.message, reqId, err.retryable);
    }
    return jsonError(500, "INTERNAL", "Unexpected error.", reqId, true);
  }
  const isGuest = ctx.isGuest;
  const internalUserId = ctx.userId;

  // 2. Parse + validate request body
  let body: CalculateRequest;
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

  const validationError = validateCalculateRequest(body);
  if (validationError) {
    return jsonError(422, "VALIDATION_ERROR", validationError, reqId, false);
  }

  // Reject no-op routes early (spec: same origin/destination is blocked before calculation)
  if (
    body.origin.lat === body.destination.lat &&
    body.origin.lng === body.destination.lng
  ) {
    return jsonError(
      422,
      "SAME_ORIGIN_DESTINATION",
      "Origin and destination cannot be the same place.",
      reqId,
      false,
    );
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // 3. internalUserId was resolved (and provisioned if needed) in authRequest.

  // 4. Kick off the three independent slow paths in parallel: routing
  //    (Valhalla), phase flags (DB) and fuel price (provider/DB). None of them
  //    depends on the others, so running them concurrently cuts wall-clock
  //    latency from their sum to the slowest.
  const routingProvider = getRoutingProvider();
  const routingPromise = routingProvider.getRouteAlternatives({
    origin: body.origin,
    destination: body.destination,
    roundTrip: body.trip_type === "round_trip",
  });
  const flagsPromise = readPhaseFlags(supabase);
  const fuelPromise = resolveFuelPrice(body);

  let routeAlternatives;
  try {
    routeAlternatives = await routingPromise;
  } catch (err) {
    return jsonError(
      502,
      "ROUTE_PROVIDER_UNAVAILABLE",
      "Route data is temporarily unavailable. Please try again.",
      reqId,
      true,
    );
  }

  if (!routeAlternatives || routeAlternatives.length === 0) {
    return jsonError(
      404,
      "NO_ROUTE_FOUND",
      "No route available for this input. Check the locations or try a nearby major town.",
      reqId,
      false,
    );
  }

  // 5. Flags and fuel resolve in parallel with routing (already in flight).
  const phaseFlags = await flagsPromise;
  const {
    perUnit: fuelPricePerUnit,
    source: fuelPriceSource,
    freshness: fuelPriceFreshness,
  } = await fuelPromise;

  const tollProvider = getTollProvider();

  // 6. Compute cost for each route alternative
  const computedRoutes = [];
  for (const alt of routeAlternatives) {
    const fuelResult = computeFuelCost({
      distanceKm: alt.distanceKm,
      vehicle: body.vehicle,
      fuelPricePerUnit,
      phase2Ev: phaseFlags["phase2_ev"],
      phase2Cng: phaseFlags["phase2_cng"],
    });

    let tollResult;
    try {
      tollResult = await tollProvider.getTollsForRoute(alt.segments);
    } catch {
      tollResult = {
        totalToll: 0,
        confidence: "unavailable" as const,
        plazas: [],
      };
    }

    const totalCost = round2((fuelResult.cost ?? 0) + tollResult.totalToll);

    computedRoutes.push({
      route_type: alt.routeType,
      distance_km: alt.distanceKm,
      duration_min: alt.durationMin,
      fuel_cost: fuelResult.cost,
      fuel_cost_confidence: fuelResult.confidence,
      fuel_price_source: fuelPriceSource,
      fuel_price_freshness: fuelPriceFreshness,
      toll_cost: tollResult.totalToll,
      toll_confidence: tollResult.confidence,
      total_cost: totalCost,
      provider: alt.provider,
      geometry: alt.geometry,
      steps: alt.steps,
      fetched_at: new Date().toISOString(),
    });
  }

  // 7. Budget status (if a budget was supplied)
  let budgetStatus = null;
  if (body.budget_total && body.budget_total > 0) {
    const cheapestTotal = Math.min(...computedRoutes.map((r) => r.total_cost));
    budgetStatus = computeBudgetStatus({
      transport: cheapestTotal,
      accommodation: 0, // populated once stays are selected — Section 13 aggregates over the full trip
      food: 0,
      misc: 0,
      budgetTotal: body.budget_total,
    });
  }

  // 8. Persist against a trip if we have one (authenticated flow only)
  let tripId = body.trip_id ?? null;
  if (!isGuest && internalUserId) {
    if (!tripId) {
      const { data: newTrip, error: tripErr } = await supabase
        .from("trips")
        .insert({
          user_id: internalUserId,
          origin_label: body.origin.label,
          origin_lat: body.origin.lat,
          origin_lng: body.origin.lng,
          destination_label: body.destination.label,
          destination_lat: body.destination.lat,
          destination_lng: body.destination.lng,
          trip_type: body.trip_type,
          budget_total: body.budget_total ?? null,
          fuel_price_per_litre: fuelPricePerUnit,
          status: "calculated",
        })
        .select("id")
        .single();
      if (tripErr) {
        return jsonError(500, "DB_ERROR", "Could not save trip.", reqId, true);
      }
      tripId = newTrip.id;
    }

    const routeRows = computedRoutes.map((r) => ({
      trip_id: tripId,
      route_type: r.route_type,
      distance_km: r.distance_km,
      duration_min: r.duration_min,
      fuel_cost: r.fuel_cost,
      toll_cost: r.toll_cost,
      total_cost: r.total_cost,
      geometry: r.geometry,
      provider: r.provider,
      freshness_note: r.toll_confidence === "estimated"
        ? "Toll costs are estimated for this corridor."
        : null,
    }));

    const { error: routesErr } = await supabase.from("routes").insert(
      routeRows,
    );
    if (routesErr) {
      return jsonError(
        500,
        "DB_ERROR",
        "Could not save route options.",
        reqId,
        true,
      );
    }
  }

  return jsonOk(
    {
      trip_id: tripId,
      routes: computedRoutes,
      budget_status: budgetStatus,
    },
    reqId,
  );
});

// ============================================================
// Budget engine — matches spec Section 13 exactly
// ============================================================
function computeBudgetStatus(params: {
  transport: number;
  accommodation: number;
  food: number;
  misc: number;
  budgetTotal: number;
}) {
  const totalEstimated = params.transport + params.accommodation + params.food +
    params.misc;
  const usedPct = params.budgetTotal > 0
    ? totalEstimated / params.budgetTotal
    : 1;

  let status: "GREEN" | "YELLOW" | "RED";
  if (usedPct < 0.8) status = "GREEN";
  else if (usedPct <= 1.0) status = "YELLOW";
  else status = "RED";

  const suggestions = status === "RED"
    ? [
      "Switch to a cheaper accommodation tier",
      "Remove the lowest-priority attraction",
      "Switch to the no-toll or cheaper route",
      "Reduce the trip duration by a day",
      "Choose a lower-cost food stop tier",
    ]
    : [];

  return {
    status,
    total_estimated: round2(totalEstimated),
    budget_total: params.budgetTotal,
    used_pct: round2(usedPct * 100),
    remaining: round2(params.budgetTotal - totalEstimated),
    suggestions,
  };
}

function validateCalculateRequest(body: CalculateRequest): string | null {
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
  if (!["one_way", "round_trip"].includes(body.trip_type)) {
    return "trip_type must be 'one_way' or 'round_trip'.";
  }
  if (
    !body.vehicle ||
    !["petrol", "diesel", "ev", "cng"].includes(body.vehicle.fuel_type)
  ) {
    return "vehicle.fuel_type must be one of petrol, diesel, ev, cng.";
  }
  if (
    body.vehicle.fuel_type === "petrol" || body.vehicle.fuel_type === "diesel"
  ) {
    if (body.vehicle.mileage_kmpl !== undefined) {
      if (body.vehicle.mileage_kmpl <= 0 || body.vehicle.mileage_kmpl > 60) {
        return "mileage_kmpl looks out of the realistic range for this fuel type.";
      }
    }
  }
  if (body.budget_total !== undefined && body.budget_total < 0) {
    return "budget_total cannot be negative.";
  }
  if (body.ev_price_per_kwh !== undefined && body.ev_price_per_kwh < 0) {
    return "ev_price_per_kwh cannot be negative.";
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
