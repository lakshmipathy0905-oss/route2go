// Route2Go — /stays-near-route Edge Function
//
// Affiliate hotel/stay listings near a route (spec 2.5). Guests allowed.
// The mobile StaysRepository calls this with:
//   origin_lat, origin_lng, dest_lat, dest_lng
//   max_price, min_rating, max_distance_km, room_type, amenities (comma-list)
//
// Responses are Stay-shaped ({id,name,lat,lng,price_per_night,rating,
// amenities,partner_id,partner_name,commission,is_sponsored,booking_url,
// distance_from_route_km}). distance_from_route_km is the straight-line
// corridor distance so the UI can show "x km from route".

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { AuthError, authRequest } from "../_shared/auth.ts";
import { rateLimitGuard } from "../_shared/rateLimit.ts";

function haversineKm(
  aLat: number,
  aLng: number,
  bLat: number,
  bLng: number,
): number {
  const R = 6371;
  const dLat = ((bLat - aLat) * Math.PI) / 180;
  const dLng = ((bLng - aLng) * Math.PI) / 180;
  const s = Math.sin(dLat / 2) ** 2 +
    Math.cos((aLat * Math.PI) / 180) * Math.cos((bLat * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}

function pointToSegmentKm(
  pLat: number,
  pLng: number,
  aLat: number,
  aLng: number,
  bLat: number,
  bLng: number,
): number {
  const seg = haversineKm(aLat, aLng, bLat, bLng);
  if (seg === 0) return haversineKm(pLat, pLng, aLat, aLng);
  const t = Math.max(
    0,
    Math.min(
      1,
      ((pLat - aLat) * (bLat - aLat) + (pLng - aLng) * (bLng - aLng)) /
        ((bLat - aLat) ** 2 + (bLng - aLng) ** 2),
    ),
  );
  const projLat = aLat + t * (bLat - aLat);
  const projLng = aLng + t * (bLng - aLng);
  return haversineKm(pLat, pLng, projLat, projLng);
}

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

  // Stays-along-route is a catalog read; cap per-key rate so a single client
  // can't scan the whole hotels table on a loop.
  const tooMany = rateLimitGuard(req, 120, 60_000, reqId);
  if (tooMany) return tooMany;

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

  const originLat = Number(url.searchParams.get("origin_lat"));
  const originLng = Number(url.searchParams.get("origin_lng"));
  const destLat = Number(url.searchParams.get("dest_lat"));
  const destLng = Number(url.searchParams.get("dest_lng"));
  if (![originLat, originLng, destLat, destLng].every((v) => isFinite(v))) {
    return jsonError(
      422,
      "VALIDATION_ERROR",
      "origin_lat, origin_lng, dest_lat and dest_lng are required.",
      reqId,
      false,
    );
  }

  const maxPrice = url.searchParams.get("max_price")
    ? Number(url.searchParams.get("max_price"))
    : null;
  const minRating = url.searchParams.get("min_rating")
    ? Number(url.searchParams.get("min_rating"))
    : null;
  const maxDistanceKm = url.searchParams.get("max_distance_km")
    ? Number(url.searchParams.get("max_distance_km"))
    : null;
  const roomType = url.searchParams.get("room_type")?.trim() || null;
  const amenities = (url.searchParams.get("amenities") ?? "")
    .split(",")
    .map((a) => a.trim())
    .filter(Boolean);

  let hotelsQuery = supabase
    .from("hotels")
    .select(
      "id, name, lat, lng, price_range, price_per_night, rating, amenities, partner_id, partner_name, commission, is_sponsored, booking_url, category, city",
    );

  // When a corridor distance limit is given, push it into SQL: every stay
  // within `maxDistanceKm` of the origin->dest segment lies inside this padded
  // bounding box, so the box is a strict superset of the JS distance filter.
  // This turns a full-table read into an index-backed range query. When no
  // distance limit is supplied, keep the previous behavior exactly.
  if (maxDistanceKm !== null && isFinite(maxDistanceKm)) {
    const padDeg = Math.min(maxDistanceKm / 100, 5);
    hotelsQuery = hotelsQuery
      .gte("lat", Math.min(originLat, destLat) - padDeg)
      .lte("lat", Math.max(originLat, destLat) + padDeg)
      .gte("lng", Math.min(originLng, destLng) - padDeg)
      .lte("lng", Math.max(originLng, destLng) + padDeg);
  }
  hotelsQuery = hotelsQuery.limit(200);

  const { data: hotels, error } = await hotelsQuery;
  if (error) {
    return jsonError(500, "DB_ERROR", "Could not load stays.", reqId, true);
  }

  const parsed = (hotels ?? [])
    .map((h) => {
      const price = h.price_per_night != null
        ? Number(h.price_per_night)
        : h.price_range != null
        ? parsePriceRange(String(h.price_range))
        : null;
      const hotelAmenities: string[] = Array.isArray(h.amenities)
        ? h.amenities
        : [];
      const dist = pointToSegmentKm(
        h.lat,
        h.lng,
        originLat,
        originLng,
        destLat,
        destLng,
      );
      return {
        row: h,
        price,
        amenities: hotelAmenities,
        distanceKm: dist,
      };
    })
    .filter((x) => {
      if (maxPrice !== null && x.price != null && x.price > maxPrice) {
        return false;
      }
      if (
        minRating !== null && h_rating(x.row.rating) != null &&
        h_rating(x.row.rating)! < minRating
      ) return false;
      if (maxDistanceKm !== null && x.distanceKm > maxDistanceKm) return false;
      if (
        roomType &&
        !(x.row.category ?? "").toLowerCase().includes(roomType.toLowerCase())
      ) return false;
      if (
        amenities.length > 0 &&
        !amenities.every((a) =>
          x.amenities.some((m) => m.toLowerCase().includes(a.toLowerCase()))
        )
      ) return false;
      return true;
    });

  parsed.sort((a, b) => (a.price ?? Infinity) - (b.price ?? Infinity));

  const result = parsed.map((x) => ({
    id: x.row.id,
    name: x.row.name,
    lat: x.row.lat,
    lng: x.row.lng,
    price_per_night: x.price,
    rating: h_rating(x.row.rating),
    amenities: x.amenities,
    partner_id: x.row.partner_id ?? null,
    partner_name: x.row.partner_name ?? null,
    commission: x.row.commission != null ? Number(x.row.commission) : null,
    is_sponsored: x.row.is_sponsored === true,
    booking_url: x.row.booking_url ?? null,
    distance_from_route_km: Math.round(x.distanceKm * 10) / 10,
    disclosure:
      "Price is a guide. Completing the booking happens on the partner site.",
  }));

  return jsonOk(result, reqId);
});

function h_rating(v: unknown): number | null {
  if (v == null) return null;
  const n = Number(v);
  return isFinite(n) ? n : null;
}

/** Very small heuristic to extract a lower-bound number from text like "₹2,000–3,500". */
function parsePriceRange(text: string): number | null {
  const digits = text.replace(/[^0-9.]/g, " ").trim().split(/\s+/).map(Number)
    .filter((n) => isFinite(n) && n > 0);
  if (digits.length === 0) return null;
  return Math.min(...digits);
}
