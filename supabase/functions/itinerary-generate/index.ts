// Route2Go — /itinerary-generate Edge Function
//
// Generates a day-by-day itinerary for a trip from selected places/stays
// (spec 2.6). Guests allowed: itinerary preview is part of the guest flow,
// but nothing is persisted for guests.
//
// Mobile contract (itinerary_repository.generate):
//   POST /itinerary-generate
//   Body: {
//     trip: {
//       origin_label, origin_lat, origin_lng,
//       destination_label, destination_lat, destination_lng,
//       trip_type, travellers, budget_total?
//     },
//     selected_places: [{id, name, detour_duration_min?, est_cost?|detour_added_cost?, ...}],
//     selected_stays:  [{id, name, price_per_night?, nights?, ...}],
//     budget_total?, max_driving_hours_per_day
//   }
//   Response data: { duration_days, days: [{day_number, items: [{item_type,
//     ref_id, name, start_time, end_time, est_cost}]}] }
//
// The heavy lifting lives in _shared/itineraryScheduler.ts so it is
// unit-testable; this file is a thin HTTP + persistence wrapper.

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { authRequest, AuthError } from "../_shared/auth.ts";
import { generateItinerary, validateItineraryInput, type ItineraryInput } from "../_shared/itineraryScheduler.ts";

function asMap(v: unknown): Record<string, unknown> {
  return typeof v === "object" && v !== null ? (v as Record<string, unknown>) : {};
}

Deno.serve(async (req: Request) => {
  const reqId = requestId();

  if (req.method !== "POST") {
    return jsonError(405, "METHOD_NOT_ALLOWED", "Only POST is supported.", reqId, false);
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

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
  }

  const trip = asMap(body.trip);
  const selectedPlaces = Array.isArray(body.selected_places) ? body.selected_places.map(asMap) : [];
  const selectedStays = Array.isArray(body.selected_stays) ? body.selected_stays.map(asMap) : [];

  // Estimate distance/duration when not supplied: straight-line * road factor.
  const originLat = Number(trip.origin_lat);
  const originLng = Number(trip.origin_lng);
  const destLat = Number(trip.destination_lat);
  const destLng = Number(trip.destination_lng);
  const hasCoords = [originLat, originLng, destLat, destLng].every((v) => isFinite(v));

  function haversineKm(aLat: number, aLng: number, bLat: number, bLng: number): number {
    const R = 6371;
    const dLat = ((bLat - aLat) * Math.PI) / 180;
    const dLng = ((bLng - aLng) * Math.PI) / 180;
    const s =
      Math.sin(dLat / 2) ** 2 +
      Math.cos((aLat * Math.PI) / 180) * Math.cos((bLat * Math.PI) / 180) * Math.sin(dLng / 2) ** 2;
    return 2 * R * Math.asin(Math.sqrt(s));
  }

  let totalDistanceKm = Number(body.total_distance_km ?? 0);
  let totalDriveMin = Number(body.total_drive_min ?? 0);
  if (hasCoords) {
    const straight = haversineKm(originLat, originLng, destLat, destLng);
    if (!(totalDistanceKm > 0)) totalDistanceKm = Math.round(straight * 1.3);
    if (!(totalDriveMin > 0)) totalDriveMin = Math.round((totalDistanceKm / 50) * 60);
  }

  const maxDriveHours = Number(body.max_driving_hours_per_day ?? 8);

  const input: ItineraryInput = {
    origin_label: String(trip.origin_label ?? ""),
    destination_label: String(trip.destination_label ?? ""),
    total_distance_km: totalDistanceKm,
    total_drive_min: totalDriveMin,
    max_driving_hours_per_day: maxDriveHours,
    budget_total: body.budget_total != null ? Number(body.budget_total) : trip.budget_total != null ? Number(trip.budget_total) : null,
    trip_type: String(trip.trip_type ?? "one_way") === "round_trip" ? "round_trip" : "one_way",
    selected_places: selectedPlaces.map((p) => ({
      id: String(p.id ?? ""),
      name: String(p.name ?? "Place"),
      detour_duration_min: Number(p.detour_duration_min ?? 0) || 30,
      est_cost: p.est_cost != null ? Number(p.est_cost) : p.detour_added_cost != null ? Number(p.detour_added_cost) : null,
    })),
    selected_stays: selectedStays.map((s) => ({
      id: String(s.id ?? ""),
      name: String(s.name ?? "Stay"),
      price_per_night: s.price_per_night != null ? Number(s.price_per_night) : null,
      nights: s.nights != null ? Number(s.nights) : 1,
    })),
  };

  const issues = validateItineraryInput(input);
  if (issues.length > 0) {
    return jsonError(422, "VALIDATION_ERROR", issues.map((i) => i.message).join(" "), reqId, false);
  }

  const days = generateItinerary(input);
  const durationDays = Math.max(days.length, 1);

  // Persist only for authenticated users with a trip_id they own.
  if (!ctx.isGuest && ctx.userId && body.trip_id) {
    const tripId = String(body.trip_id);
    const { data: owned, error: tripErr } = await ctx.supabase
      .from("trips")
      .select("id")
      .eq("id", tripId)
      .eq("user_id", ctx.userId)
      .maybeSingle();
    if (tripErr) {
      return jsonError(500, "DB_ERROR", "Could not verify trip.", reqId, true);
    }
    if (owned) {
      await ctx.supabase.from("itinerary_items").delete().eq("trip_id", tripId);
      const rows: Array<Record<string, unknown>> = [];
      for (const day of days) {
        day.items.forEach((item, idx) => {
          rows.push({
            trip_id: tripId,
            day_number: day.day_number,
            sequence: idx,
            item_type: item.item_type,
            ref_id: item.ref_id,
            name: item.name,
            start_time: item.start_time,
            end_time: item.end_time,
            est_cost: item.est_cost,
          });
        });
      }
      if (rows.length > 0) {
        const { error: insErr } = await ctx.supabase.from("itinerary_items").insert(rows);
        if (insErr) {
          return jsonError(500, "DB_ERROR", "Could not save itinerary.", reqId, true);
        }
      }
    }
  }

  return jsonOk({ duration_days: durationDays, days }, reqId);
});