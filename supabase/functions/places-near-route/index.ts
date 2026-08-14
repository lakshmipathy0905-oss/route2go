// Route2Go — /places-near-route Edge Function
//
// Places along a route corridor (spec 2.4). Guests allowed.
// The mobile PlacesRepository calls this with:
//   origin_lat, origin_lng, dest_lat, dest_lng
//   radius_km (detour radius), route_distance_km, route_duration_min,
//   fuel_cost_per_km, category_ids (comma-separated)
// Plus two alternate modes:
//   categories=1            -> list of place_categories ({id,name})
//   place_id=...            -> a single place by id
//
// Detour delta is computed per place from the straight-line corridor:
// detour_km ≈ perpendicular/nearest-point distance; duration and added cost
// scale from route duration + fuel cost so the value is never shown as free.

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { authRequest, AuthError } from "../_shared/auth.ts";

function haversineKm(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const R = 6371;
  const dLat = ((bLat - aLat) * Math.PI) / 180;
  const dLng = ((bLng - aLng) * Math.PI) / 180;
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((aLat * Math.PI) / 180) * Math.cos((bLat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

/** Distance from a point to the great-circle segment origin->dest (km). */
function pointToSegmentKm(pLat: number, pLng: number, aLat: number, aLng: number, bLat: number, bLng: number): number {
  const seg = haversineKm(aLat, aLng, bLat, bLng);
  if (seg === 0) return haversineKm(pLat, pLng, aLat, aLng);
  // Project point onto segment using equirectangular approximation in km.
  const t = Math.max(
    0,
    Math.min(1, ((pLat - aLat) * (bLat - aLat) + (pLng - aLng) * (bLng - aLng)) / ((bLat - aLat) ** 2 + (bLng - aLng) ** 2))
  );
  const projLat = aLat + t * (bLat - aLat);
  const projLng = aLng + t * (bLng - aLng);
  return haversineKm(pLat, pLng, projLat, projLng);
}

Deno.serve(async (req: Request) => {
  const reqId = requestId();

  if (req.method !== "GET") {
    return jsonError(405, "METHOD_NOT_ALLOWED", "Only GET is supported.", reqId, false);
  }

  let ctx;
  try {
    ctx = await authRequest(req, { allowGuest: true });
  } catch (err) {
    if (err instanceof AuthError) {
      return jsonError(err.status, err.code, err.message, reqId, err.retryable);
    }
    return jsonError(500, "INTERNAL", "Unexpected error.", reqId, true);
  }

  const supabase = ctx.supabase;
  const url = new URL(req.url);

  if (url.searchParams.get("categories") === "1") {
    const { data, error } = await supabase.from("place_categories").select("id, name").order("name", { ascending: true });
    if (error) return jsonError(500, "DB_ERROR", "Could not load categories.", reqId, true);
    return jsonOk(data ?? [], reqId);
  }

  const placeId = url.searchParams.get("place_id");
  if (placeId) {
    const { data, error } = await supabase
      .from("places")
      .select("id, name, category_id, lat, lng, photos, hours, entry_fee, rating, description")
      .eq("id", placeId)
      .maybeSingle();
    if (error) return jsonError(500, "DB_ERROR", "Could not load place.", reqId, true);
    if (!data) return jsonOk([], reqId);
    const { data: cat, error: catErr } = await supabase.from("place_categories").select("name").eq("id", data.category_id).maybeSingle();
    const category = catErr ? null : (cat?.name ?? null);
    return jsonOk([{ ...data, category }], reqId);
  }

  const originLat = Number(url.searchParams.get("origin_lat"));
  const originLng = Number(url.searchParams.get("origin_lng"));
  const destLat = Number(url.searchParams.get("dest_lat"));
  const destLng = Number(url.searchParams.get("dest_lng"));
  if (![originLat, originLng, destLat, destLng].every((v) => isFinite(v))) {
    return jsonError(422, "VALIDATION_ERROR", "origin_lat, origin_lng, dest_lat and dest_lng are required.", reqId, false);
  }

  const radiusKm = Number(url.searchParams.get("radius_km") ?? 30) || 30;
  const routeDistanceKm = url.searchParams.get("route_distance_km") ? Number(url.searchParams.get("route_distance_km")) : null;
  const routeDurationMin = url.searchParams.get("route_duration_min") ? Number(url.searchParams.get("route_duration_min")) : null;
  const fuelCostPerKm = url.searchParams.get("fuel_cost_per_km") ? Number(url.searchParams.get("fuel_cost_per_km")) : null;
  const categoryIds = (url.searchParams.get("category_ids") ?? "")
    .split(",")
    .map((c) => c.trim())
    .filter(Boolean);

  let q = supabase.from("places").select("id, name, category_id, lat, lng, photos, hours, entry_fee, rating, description, place_categories(name)");
  if (categoryIds.length > 0) q = q.in("category_id", categoryIds);

  const { data: places, error } = await q;
  if (error) return jsonError(500, "DB_ERROR", "Could not load places.", reqId, true);

  const corridorKm = routeDistanceKm ?? haversineKm(originLat, originLng, destLat, destLng);

  const scored = (places ?? [])
    .map((p) => {
      const distKm = pointToSegmentKm(p.lat, p.lng, originLat, originLng, destLat, destLng);
      if (distKm > radiusKm) return null;
      const detourKm = routeDistanceKm !== null ? (distKm + routeDistanceKm * 0.08) : distKm;
      const detourDurationMin = routeDurationMin !== null
        ? Math.round((detourKm / (corridorKm / Math.max((routeDurationMin ?? 60) / 60, 1))) || 15)
        : Math.round((detourKm / 45) * 60);
      const detourAddedCost = fuelCostPerKm !== null ? Math.round(detourKm * fuelCostPerKm * 100) / 100 : Math.round(detourKm * 6 * 100) / 100;
      const cat = p.place_categories as { name?: string } | null;
      return {
        id: p.id,
        name: p.name,
        category_id: p.category_id,
        category: cat?.name ?? null,
        lat: p.lat,
        lng: p.lng,
        photos: p.photos ?? [],
        hours: p.hours,
        entry_fee: p.entry_fee,
        rating: p.rating,
        description: p.description,
        detour_km: Math.round(detourKm * 10) / 10,
        detour_duration_min: detourDurationMin,
        detour_added_cost: detourAddedCost,
      };
    })
    .filter((p): p is NonNullable<typeof p> => p !== null)
    .sort((a, b) => a.detour_km - b.detour_km);

  return jsonOk(scored, reqId);
});