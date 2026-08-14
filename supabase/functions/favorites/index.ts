// Route2Go — /favorites Edge Function
//
// Saved places + saved trips (spec 2.11 / 5.11). Authenticated only.
// The schema models these as saved_places and saved_trips; there is no
// generic favorites table, so hotels/routes are NOT saved (spec only lists
// places and trips in the Favorites screen). Unknown kinds return an empty
// list, not an error.
//
//   GET  /favorites?kind=place|trip
//   POST /favorites {action: save_place, place_id}
//   POST /favorites {action: unsave_place, place_id}
//   POST /favorites {action: save_trip, trip_id}
//   POST /favorites {action: unsave_trip, trip_id}
//
// All responses are SearchResult-shaped ({kind,id,title,subtitle}) so the
// mobile Favorites screen can render them uniformly.

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { authRequest, requireUser, auditLog, AuthError } from "../_shared/auth.ts";

Deno.serve(async (req: Request) => {
  const reqId = requestId();

  let ctx;
  try {
    ctx = await authRequest(req);
    await requireUser(ctx);
  } catch (err) {
    if (err instanceof AuthError) {
      return jsonError(err.status, err.code, err.message, reqId, err.retryable);
    }
    return jsonError(500, "INTERNAL", "Unexpected error.", reqId, true);
  }

  const supabase = ctx.supabase;
  const userId = ctx.userId!;

  if (req.method === "GET") {
    const url = new URL(req.url);
    const kind = url.searchParams.get("kind");

    if (kind === "trip") {
      const { data, error } = await supabase
        .from("saved_trips")
        .select("trip_id, saved_at, trips(origin_label, destination_label, status)")
        .eq("user_id", userId)
        .order("saved_at", { ascending: false });
      if (error) return jsonError(500, "DB_ERROR", "Could not load saved trips.", reqId, true);
      const items = (data ?? []).map((s) => {
        const t = s.trips as { origin_label?: string; destination_label?: string; status?: string } | null;
        return {
          kind: "saved_trip",
          id: s.trip_id as string,
          title: t?.origin_label ?? "Saved trip",
          subtitle: t?.destination_label ? `to ${t.destination_label}` : "",
          saved_at: s.saved_at,
        };
      });
      return jsonOk(items, reqId);
    }

    if (kind === "place") {
      const { data, error } = await supabase
        .from("saved_places")
        .select("place_id, saved_at, places(name, category_id, place_categories(name))")
        .eq("user_id", userId)
        .order("saved_at", { ascending: false });
      if (error) return jsonError(500, "DB_ERROR", "Could not load saved places.", reqId, true);
      const items = (data ?? []).map((s) => {
        const p = s.places as { name?: string; category_id?: string | null; place_categories?: { name?: string } | null } | null;
        return {
          kind: "place",
          id: s.place_id as string,
          title: p?.name ?? "Saved place",
          subtitle: p?.place_categories?.name ?? p?.category_id ?? "",
          saved_at: s.saved_at,
        };
      });
      return jsonOk(items, reqId);
    }

    // hotel | route | unknown -> nothing saved for those kinds in this schema.
    return jsonOk([], reqId);
  }

  if (req.method === "POST") {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
    }

    const action = String(body.action ?? "");

    if (action === "save_place" || action === "unsave_place") {
      const placeId = String(body.place_id ?? "");
      if (!placeId) return jsonError(422, "VALIDATION_ERROR", "place_id is required.", reqId, false);

      const { data: place, error: placeErr } = await supabase
        .from("places")
        .select("id")
        .eq("id", placeId)
        .maybeSingle();
      if (placeErr) return jsonError(500, "DB_ERROR", "Could not verify place.", reqId, true);
      if (!place) return jsonError(404, "NOT_FOUND", "Place not found.", reqId, false);

      if (action === "save_place") {
        const { error } = await supabase.from("saved_places").upsert(
          { user_id: userId, place_id: placeId, saved_at: new Date().toISOString() },
          { onConflict: "user_id,place_id" }
        );
        if (error) return jsonError(500, "DB_ERROR", "Could not save place.", reqId, true);
        await auditLog(ctx, { action: "favorite.place.save", entityType: "saved_places", afterSummary: { place_id: placeId } });
        return jsonOk({ saved: true }, reqId, 201);
      }

      const { error } = await supabase.from("saved_places").delete().eq("user_id", userId).eq("place_id", placeId);
      if (error) return jsonError(500, "DB_ERROR", "Could not remove place.", reqId, true);
      await auditLog(ctx, { action: "favorite.place.unsave", entityType: "saved_places", afterSummary: { place_id: placeId } });
      return jsonOk({ saved: false }, reqId);
    }

    if (action === "save_trip" || action === "unsave_trip") {
      const tripId = String(body.trip_id ?? "");
      if (!tripId) return jsonError(422, "VALIDATION_ERROR", "trip_id is required.", reqId, false);

      const { data: trip, error: tripErr } = await supabase
        .from("trips")
        .select("id")
        .eq("id", tripId)
        .eq("user_id", userId)
        .maybeSingle();
      if (tripErr) return jsonError(500, "DB_ERROR", "Could not verify trip.", reqId, true);
      if (!trip) return jsonError(404, "NOT_FOUND", "Trip not found.", reqId, false);

      if (action === "save_trip") {
        const { error } = await supabase.from("saved_trips").upsert(
          { user_id: userId, trip_id: tripId, saved_at: new Date().toISOString() },
          { onConflict: "user_id,trip_id" }
        );
        if (error) return jsonError(500, "DB_ERROR", "Could not save trip.", reqId, true);
        await auditLog(ctx, { action: "favorite.trip.save", entityType: "saved_trips", afterSummary: { trip_id: tripId } });
        return jsonOk({ saved: true }, reqId, 201);
      }

      const { error } = await supabase.from("saved_trips").delete().eq("user_id", userId).eq("trip_id", tripId);
      if (error) return jsonError(500, "DB_ERROR", "Could not remove trip.", reqId, true);
      await auditLog(ctx, { action: "favorite.trip.unsave", entityType: "saved_trips", afterSummary: { trip_id: tripId } });
      return jsonOk({ saved: false }, reqId);
    }

    return jsonError(422, "VALIDATION_ERROR", "action must be save_place, unsave_place, save_trip or unsave_trip.", reqId, false);
  }

  return jsonError(405, "METHOD_NOT_ALLOWED", "Method not allowed.", reqId, false);
});