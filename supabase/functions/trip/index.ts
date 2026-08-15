// Route2Go — /trip Edge Function
//
// Saved-trip management (spec 2.8 / Section 5.11). Authenticated only.
//   GET    /trip                    -> list the user's saved trips (with best route cost)
//   POST   /trip  {action: save}    -> persist a draft trip
//   PATCH  /trip  {action: rename}  -> rename a trip
//   PATCH  /trip  {action: duplicate} -> duplicate a trip
//   DELETE /trip?trip_id=...        -> delete a trip (cascades children)

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
    const { data: trips, error } = await supabase
      .from("trips")
      .select(`
        id, origin_label, destination_label, trip_type, start_date, end_date,
        travellers, budget_total, status, created_at,
        origin_lat, origin_lng, destination_lat, destination_lng,
        routes ( total_cost, duration_min, distance_km, geometry )
      `)
      .eq("user_id", userId)
      .order("created_at", { ascending: false });
    if (error) return jsonError(500, "DB_ERROR", "Could not load trips.", reqId, true);

    const summary = (trips ?? []).map((t) => {
      const routes = (t.routes ?? []) as Array<{ total_cost: number | null; duration_min: number | null; distance_km: number | null; geometry: unknown }>;
      let best: { total_cost: number | null; duration_min: number | null; distance_km: number | null; geometry: unknown } | null = null;
      for (const r of routes) {
        if (!best || (r.total_cost !== null && (best.total_cost === null || r.total_cost < best.total_cost))) {
          best = r;
        }
      }
      return {
        id: t.id,
        origin_label: t.origin_label,
        destination_label: t.destination_label,
        trip_type: t.trip_type,
        start_date: t.start_date,
        end_date: t.end_date,
        travellers: t.travellers,
        budget_total: t.budget_total,
        status: t.status,
        created_at: t.created_at,
        origin_lat: t.origin_lat,
        origin_lng: t.origin_lng,
        destination_lat: t.destination_lat,
        destination_lng: t.destination_lng,
        best_route_geometry: best?.geometry ?? null,
        best_route_cost: best?.total_cost ?? null,
        best_duration_min: best?.duration_min ?? null,
        best_distance_km: best?.distance_km ?? null,
      };
    });

    return jsonOk(summary, reqId);
  }

  if (req.method === "POST") {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
    }

    if (body.action !== "save") {
      return jsonError(422, "VALIDATION_ERROR", "action must be 'save'.", reqId, false);
    }

    const originLabel = String(body.origin_label ?? "").trim();
    const destinationLabel = String(body.destination_label ?? "").trim();
    const originLat = Number(body.origin_lat);
    const originLng = Number(body.origin_lng);
    const destLat = Number(body.destination_lat);
    const destLng = Number(body.destination_lng);
    const tripType = String(body.trip_type ?? "one_way");
    const travellers = Number(body.travellers ?? 1);

    if (!originLabel || !destinationLabel) {
      return jsonError(422, "VALIDATION_ERROR", "origin_label and destination_label are required.", reqId, false);
    }
    if (!["one_way", "round_trip"].includes(tripType)) {
      return jsonError(422, "VALIDATION_ERROR", "trip_type must be one_way or round_trip.", reqId, false);
    }
    if (originLat === destLat && originLng === destLng) {
      return jsonError(422, "SAME_ORIGIN_DESTINATION", "Origin and destination cannot be the same place.", reqId, false);
    }
    if (!isFinite(originLat) || !isFinite(originLng) || !isFinite(destLat) || !isFinite(destLng)) {
      return jsonError(422, "VALIDATION_ERROR", "Coordinates must be numbers.", reqId, false);
    }

    const { data, error } = await supabase
      .from("trips")
      .insert({
        user_id: userId,
        origin_label: originLabel,
        origin_lat: originLat,
        origin_lng: originLng,
        destination_label: destinationLabel,
        destination_lat: destLat,
        destination_lng: destLng,
        trip_type: tripType,
        start_date: body.start_date ?? null,
        end_date: body.end_date ?? null,
        travellers,
        vehicle_id: body.vehicle_id ?? null,
        budget_total: body.budget_total ?? null,
        status: "draft",
      })
      .select("id")
      .single();
    if (error) return jsonError(500, "DB_ERROR", "Could not save trip.", reqId, true);

    await auditLog(ctx, {
      action: "trip.save",
      entityType: "trips",
      entityId: data.id,
      afterSummary: { origin_label: originLabel, destination_label: destinationLabel, trip_type: tripType },
    });

    return jsonOk({ trip_id: data.id }, reqId, 201);
  }

  if (req.method === "PATCH") {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
    }

    const tripId = String(body.trip_id ?? "");
    if (!tripId) return jsonError(422, "VALIDATION_ERROR", "trip_id is required.", reqId, false);

    const { data: trip, error: fetchErr } = await supabase
      .from("trips")
      .select("id, origin_label, destination_label")
      .eq("id", tripId)
      .eq("user_id", userId)
      .maybeSingle();
    if (fetchErr) return jsonError(500, "DB_ERROR", "Could not load trip.", reqId, true);
    if (!trip) return jsonError(404, "NOT_FOUND", "Trip not found.", reqId, false);

    if (body.action === "rename") {
      const newLabel = String(body.origin_label ?? "").trim();
      if (!newLabel) return jsonError(422, "VALIDATION_ERROR", "origin_label is required to rename.", reqId, false);

      const { data: updated, error } = await supabase
        .from("trips")
        .update({ origin_label: newLabel, updated_at: new Date().toISOString() })
        .eq("id", tripId)
        .select("id, origin_label, destination_label, trip_type, status, budget_total, travellers, created_at")
        .single();
      if (error) return jsonError(500, "DB_ERROR", "Could not rename trip.", reqId, true);

      await auditLog(ctx, { action: "trip.rename", entityType: "trips", entityId: tripId, beforeSummary: { origin_label: trip.origin_label }, afterSummary: { origin_label: newLabel } });

      return jsonOk(updated, reqId);
    }

    if (body.action === "duplicate") {
      const { data: full, error: fullErr } = await supabase
        .from("trips")
        .select("*")
        .eq("id", tripId)
        .eq("user_id", userId)
        .maybeSingle();
      if (fullErr) return jsonError(500, "DB_ERROR", "Could not load trip.", reqId, true);
      if (!full) return jsonError(404, "NOT_FOUND", "Trip not found.", reqId, false);

      const { data: dup, error } = await supabase
        .from("trips")
        .insert({
          user_id: userId,
          origin_label: `${full.origin_label} (copy)`,
          origin_lat: full.origin_lat,
          origin_lng: full.origin_lng,
          destination_label: full.destination_label,
          destination_lat: full.destination_lat,
          destination_lng: full.destination_lng,
          trip_type: full.trip_type,
          start_date: full.start_date,
          end_date: full.end_date,
          travellers: full.travellers,
          vehicle_id: full.vehicle_id,
          budget_total: full.budget_total,
          status: "draft",
        })
        .select("id, origin_label, destination_label, trip_type, status, budget_total, travellers, created_at")
        .single();
      if (error) return jsonError(500, "DB_ERROR", "Could not duplicate trip.", reqId, true);

      await auditLog(ctx, { action: "trip.duplicate", entityType: "trips", entityId: dup.id, afterSummary: { source: tripId, origin_label: dup.origin_label } });

      return jsonOk(dup, reqId);
    }

    return jsonError(422, "VALIDATION_ERROR", "action must be rename or duplicate.", reqId, false);
  }

  if (req.method === "DELETE") {
    const url = new URL(req.url);
    const tripId = url.searchParams.get("trip_id");
    if (!tripId) return jsonError(422, "VALIDATION_ERROR", "trip_id is required.", reqId, false);

    const { data: trip, error: fetchErr } = await supabase
      .from("trips")
      .select("id, origin_label")
      .eq("id", tripId)
      .eq("user_id", userId)
      .maybeSingle();
    if (fetchErr) return jsonError(500, "DB_ERROR", "Could not load trip.", reqId, true);
    if (!trip) return jsonError(404, "NOT_FOUND", "Trip not found.", reqId, false);

    const { error } = await supabase.from("trips").delete().eq("id", tripId).eq("user_id", userId);
    if (error) return jsonError(500, "DB_ERROR", "Could not delete trip.", reqId, true);

    await auditLog(ctx, { action: "trip.delete", entityType: "trips", entityId: tripId, beforeSummary: { origin_label: trip.origin_label } });

    return jsonOk({ deleted: true }, reqId);
  }

  return jsonError(405, "METHOD_NOT_ALLOWED", "Method not allowed.", reqId, false);
});