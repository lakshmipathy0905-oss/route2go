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
import {
  getPoiProvider,
  type PoiResult,
} from "../_shared/providers/poiProvider.ts";
import { rateLimitGuard } from "../_shared/rateLimit.ts";
import { sanitizeSearchPattern } from "../_shared/searchSanitize.ts";

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

  // This endpoint also proxies the public geocoder/POI providers: bound how
  // often one client key can hit them through us (per-isolate, IP-keyed).
  const tooMany = rateLimitGuard(req, 120, 60_000, reqId);
  if (tooMany) return tooMany;

  const url = new URL(req.url);
  const q = (url.searchParams.get("q") ?? "").trim();
  const limit = Math.min(Number(url.searchParams.get("limit") ?? 10) || 10, 20);

  if (!q || q.length < 2) return jsonOk([], reqId);

  const supabase = ctx.supabase;
  // Sanitize the search term before it enters PostgREST filters (see
  // sanitizeSearchPattern): `%`/`*` would widen the match, and `,` `(` `)` `.`
  // quotes/backslashes would be parsed as extra filter syntax.
  const pattern = sanitizeSearchPattern(q);
  const results: Array<
    {
      kind: string;
      id: string;
      title: string;
      subtitle: string | null;
      lat?: number;
      lng?: number;
      category?: string;
      city?: string;
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
          category: cat?.name ?? undefined,
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
          category: "Hotel",
          city: h.city ?? undefined,
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
  // Geocoding and the POI search are independent, so they run concurrently —
  // this halves worst-case search latency on queries that hit both.
  let nearbyDegraded = false;
  try {
    const latRaw = url.searchParams.get("lat");
    const lngRaw = url.searchParams.get("lng");
    const lat = latRaw !== null ? Number(latRaw) : NaN;
    const lng = lngRaw !== null ? Number(lngRaw) : NaN;
    const refValid = isFinite(lat) && isFinite(lng);

    const provider = getPoiProvider();
    const [geocoded, pois] = await Promise.all([
      getGeocodingProvider().forward(q),
      refValid
        ? provider.searchNear({ query: q, lat, lng, radiusKm: 10 })
        : Promise.resolve([] as PoiResult[]),
    ]);

    for (const g of geocoded.slice(0, limit)) {
      results.push({
        kind: "nearby",
        id: `geocode:${g.lat}:${g.lng}`,
        title: g.label,
        subtitle: g.subtitle ?? "Place",
        lat: g.lat,
        lng: g.lng,
        category: g.category,
        city: g.city,
      });
    }

    if (refValid) {
      nearbyDegraded = provider.isDegraded();
      for (const p of pois.slice(0, limit)) {
        results.push({
          kind: "nearby",
          id: `poi:${p.lat}:${p.lng}`,
          title: p.name,
          subtitle: p.category.replaceAll("_", " "),
          lat: p.lat,
          lng: p.lng,
          category: p.category.replaceAll("_", " "),
          city: p.city,
        });
      }
    }
  } catch {
    // Nearby search is best-effort.
    nearbyDegraded = true;
  }

  return jsonOk(results.slice(0, limit * 3), reqId, { nearbyDegraded });
});
