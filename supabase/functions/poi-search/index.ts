// Route2Go — /poi-search Edge Function
//
// Category POI search around a point (worldwide OSM via Overpass), e.g.
// ?q=cafes&lat=12.97&lng=77.59&radius_km=5. Guests are allowed (spec 5.2)
// and results are honest: only named, located POIs are returned; an unknown
// category yields an empty list, never fabricated data.

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { getPoiProvider } from "../_shared/providers/poiProvider.ts";
import { checkRateLimit, clientKey } from "../_shared/rateLimit.ts";

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

  // Public endpoint that proxies Overpass: guard the upstream server from
  // being hammered through this function (bounded, per-isolate, IP-keyed).
  const rateLimit = checkRateLimit(clientKey(req), 60, 60_000);
  if (!rateLimit.allowed) {
    return jsonError(
      429,
      "RATE_LIMITED",
      "Too many requests. Try again shortly.",
      reqId,
      true,
      { "Retry-After": String(Math.ceil(rateLimit.retryAfterMs / 1000)) },
    );
  }

  const url = new URL(req.url);
  const q = (url.searchParams.get("q") ?? "").trim();
  const lat = url.searchParams.has("lat") ? Number(url.searchParams.get("lat")) : NaN;
  const lng = url.searchParams.has("lng") ? Number(url.searchParams.get("lng")) : NaN;
  const radiusKm = Number(url.searchParams.get("radius_km") ?? "10");

  if (q.length < 2) {
    return jsonError(
      422,
      "VALIDATION_ERROR",
      "Provide q= with at least 2 characters.",
      reqId,
      false,
    );
  }
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return jsonError(
      422,
      "VALIDATION_ERROR",
      "lat and lng must be numbers.",
      reqId,
      false,
    );
  }
  if (Number.isFinite(radiusKm) && (radiusKm < 0.5 || radiusKm > 25)) {
    return jsonError(
      422,
      "VALIDATION_ERROR",
      "radius_km must be between 0.5 and 25.",
      reqId,
      false,
    );
  }

  try {
    const provider = getPoiProvider();
    const results = await provider.searchNear({
      query: q,
      lat,
      lng,
      radiusKm: Number.isFinite(radiusKm) ? radiusKm : 10,
    });
    // A degraded answer (cooldown active, no cache) means the public Overpass
    // servers were unreachable for this request — say so instead of implying
    // there are no matching places.
    if (provider.isDegraded()) {
      return jsonError(
        502,
        "POI_SEARCH_UNAVAILABLE",
        "Place search is temporarily unavailable.",
        reqId,
        true,
      );
    }
    return jsonOk(results, reqId);
  } catch {
    return jsonError(
      502,
      "POI_SEARCH_UNAVAILABLE",
      "Place search is temporarily unavailable.",
      reqId,
      true,
    );
  }
});
