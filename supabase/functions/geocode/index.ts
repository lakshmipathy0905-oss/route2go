// Route2Go — /geocode Edge Function
//
// Forward (q=) and reverse (lat= & lng=) geocoding. Guests are allowed
// (spec 5.2): picking locations is part of the guest planning flow. Empty
// results are a legitimate "no matches", not an error.

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { getGeocodingProvider } from "../_shared/providers/geocodingProvider.ts";

Deno.serve(async (req: Request) => {
  const reqId = requestId();

  if (req.method !== "GET") {
    return jsonError(405, "METHOD_NOT_ALLOWED", "Only GET is supported.", reqId, false);
  }

  const url = new URL(req.url);
  const q = url.searchParams.get("q");
  const latRaw = url.searchParams.get("lat");
  const lngRaw = url.searchParams.get("lng");

  const provider = getGeocodingProvider();

  try {
    if (q !== null && q.trim().length > 0) {
      if (q.trim().length < 2) {
        return jsonOk([], reqId);
      }
      const results = await provider.forward(q.trim());
      return jsonOk(results, reqId);
    }

    if (latRaw !== null && lngRaw !== null) {
      const lat = Number(latRaw);
      const lng = Number(lngRaw);
      if (!isFinite(lat) || !isFinite(lng)) {
        return jsonError(422, "VALIDATION_ERROR", "lat and lng must be numbers.", reqId, false);
      }
      const place = await provider.reverse(lat, lng);
      return jsonOk(place ? [place] : [], reqId);
    }

    return jsonError(422, "VALIDATION_ERROR", "Provide q= or lat= & lng=.", reqId, false);
  } catch {
    return jsonError(502, "GEOCODING_UNAVAILABLE", "Geocoding is temporarily unavailable.", reqId, true);
  }
});
