// Route2Go — /search Edge Function
//
// Global search across places, hotels, and the user's saved trips (spec
// 2.11). Guests allowed: catalog search is part of the guest flow; saved-trip
// hits are only returned for authenticated users.
//   GET /search?q=...&limit=...
//
// Schema notes: `places.category` lives in place_categories (via category_id);
// `routes` rows are per-calculation and have no searchable labels, so the
// "route" kind is served from the user's trips instead.

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { AuthError, authRequest } from "../_shared/auth.ts";
import { getGeocodingProvider } from "../_shared/providers/geocodingProvider.ts";
import { getPoiProvider } from "../_shared/providers/poiProvider.ts";

Deno.serve(async (req: Request) => {
  const reqId = requestId();

  if (req.method !== "GET") {
    return jsonError(
      405,
      "METHOD_NOT_ALLOWED",
      "Only GET is supported.",
      reqId,
      false,
    );
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

  const url = new URL(req.url);
  const q = (url.searchParams.get("q") ?? "").trim();
  const limit = Math.min(Number(url.searchParams.get("limit") ?? 10) || 10, 20);

  if (!q || q.length < 2) return jsonOk([], reqId);

  const supabase = ctx.supabase;
  const pattern = `%${q}%`;
  const results: Array<
    {
      kind: string;
      id: string;
      title: string;
      subtitle: string | null;
      lat?: number;
      lng?: number;
    }
  > = [];

  try {
    const [places, hotels, trips] = await Promise.all([
      supabase
        .from("places")
        .select("id, name, category_id, lat, lng, place_categories(name)")
        .or(`name.ilike.${pattern}`)
        .limit(limit),
      supabase
        .from("hotels")
        .select("id, name, city")
        .or(`name.ilike.${pattern},city.ilike.${pattern}`)
        .limit(limit),
      ctx.userId
        ? supabase
          .from("trips")
          .select("id, origin_label, destination_label, status")
          .eq("user_id", ctx.userId)
          .or(
            `origin_label.ilike.${pattern},destination_label.ilike.${pattern}`,
          )
          .limit(limit)
        : Promise.resolve({ data: [], error: null }),
    ]);

    if (!places.error) {
      for (const p of places.data ?? []) {
        const cat = p.place_categories as { name?: string } | null;
        results.push({
          kind: "place",
          id: p.id,
          title: p.name,
          subtitle: cat?.name ?? null,
        });
      }
    }
    if (!hotels.error) {
      for (const h of hotels.data ?? []) {
        results.push({
          kind: "hotel",
          id: h.id,
          title: h.name,
          subtitle: h.city ?? null,
        });
      }
    }
    if (!trips.error) {
      for (const t of trips.data ?? []) {
        results.push({
          kind: "route",
          id: t.id,
          title: t.origin_label,
          subtitle: `to ${t.destination_label} · ${t.status}`,
        });
      }
    }
  } catch {
    return jsonError(500, "DB_ERROR", "Could not run search.", reqId, true);
  }

  // Worldwwide address/place results from the upgraded provider (Photon by
  // default) and, when a reference point is supplied, POI category results
  // from Overpass. Best-effort: a provider failure never drops the DB hits.
  try {
    const latRaw = url.searchParams.get("lat");
    const lngRaw = url.searchParams.get("lng");

    const geocoded = await getGeocodingProvider().forward(q);
    for (const g of geocoded.slice(0, limit)) {
      results.push({
        kind: "nearby",
        id: `geocode:${g.lat}:${g.lng}`,
        title: g.label,
        subtitle: g.subtitle ?? "Place",
        lat: g.lat,
        lng: g.lng,
      });
    }

    if (latRaw !== null && lngRaw !== null) {
      const lat = Number(latRaw);
      const lng = Number(lngRaw);
      if (isFinite(lat) && isFinite(lng)) {
        const pois = await getPoiProvider().searchNear({
          query: q,
          lat,
          lng,
          radiusKm: 10,
        });
        for (const p of pois.slice(0, limit)) {
          results.push({
            kind: "nearby",
            id: `poi:${p.lat}:${p.lng}`,
            title: p.name,
            subtitle: p.category.replaceAll("_", " "),
            lat: p.lat,
            lng: p.lng,
          });
        }
      }
    }
  } catch {
    // Nearby search is best-effort.
  }

  return jsonOk(results.slice(0, limit * 3), reqId);
});
