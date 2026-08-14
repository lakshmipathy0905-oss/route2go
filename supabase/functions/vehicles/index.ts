// Route2Go — /vehicles Edge Function
//
// Vehicle garage CRUD (spec 2.1 / Section 5.4). Authenticated only.
//   GET    /vehicles                 -> list the user's vehicles
//   POST   /vehicles                 -> create (body: label, fuel_type, ...)
//   PATCH  /vehicles                 -> update (body: vehicle_id, ...)
//   DELETE /vehicles?vehicle_id=...  -> delete
//
// Setting is_default=true clears the previous default on other rows in the
// same transaction, so at most one vehicle is ever the default.

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { authRequest, requireUser, auditLog, AuthError } from "../_shared/auth.ts";

const FUEL_TYPES = ["petrol", "diesel", "ev", "cng"];

function validateRange(key: string, value: number, min: number, max: number): string | null {
  if (!isFinite(value) || value < min || value > max) {
    return `${key} must be between ${min} and ${max}.`;
  }
  return null;
}

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
    const { data, error } = await supabase
      .from("vehicles")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: true });
    if (error) return jsonError(500, "DB_ERROR", "Could not load vehicles.", reqId, true);
    return jsonOk(data ?? [], reqId);
  }

  if (req.method === "POST") {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
    }

    const label = String(body.label ?? "").trim();
    const fuelType = String(body.fuel_type ?? "");
    if (!label) return jsonError(422, "VALIDATION_ERROR", "label is required.", reqId, false);
    if (!FUEL_TYPES.includes(fuelType)) {
      return jsonError(422, "VALIDATION_ERROR", "fuel_type must be petrol, diesel, ev or cng.", reqId, false);
    }

    const mileage = body.mileage_kmpl as number | undefined;
    const evBattery = body.ev_battery_kwh as number | undefined;
    const evEfficiency = body.ev_efficiency_kwh_per_km as number | undefined;
    const cngMileage = body.cng_mileage_km_per_kg as number | undefined;

    if (mileage !== undefined) {
      const err = validateRange("mileage_kmpl", mileage, 5, 35);
      if (err) return jsonError(422, "VALIDATION_ERROR", err, reqId, false);
    }
    if (evBattery !== undefined) {
      const err = validateRange("ev_battery_kwh", evBattery, 5, 150);
      if (err) return jsonError(422, "VALIDATION_ERROR", err, reqId, false);
    }
    if (evEfficiency !== undefined) {
      const err = validateRange("ev_efficiency_kwh_per_km", evEfficiency, 0.05, 0.5);
      if (err) return jsonError(422, "VALIDATION_ERROR", err, reqId, false);
    }
    if (cngMileage !== undefined) {
      const err = validateRange("cng_mileage_km_per_kg", cngMileage, 8, 40);
      if (err) return jsonError(422, "VALIDATION_ERROR", err, reqId, false);
    }

    const makeDefault = body.is_default === true;

    // Transactional default: clear any existing default first.
    if (makeDefault) {
      await supabase.from("vehicles").update({ is_default: false }).eq("user_id", userId);
    }

    const { data, error } = await supabase
      .from("vehicles")
      .insert({
        user_id: userId,
        label,
        fuel_type: fuelType,
        mileage_kmpl: mileage ?? null,
        ev_battery_kwh: evBattery ?? null,
        ev_efficiency_kwh_per_km: evEfficiency ?? null,
        cng_mileage_km_per_kg: cngMileage ?? null,
        is_default: makeDefault,
      })
      .select("*")
      .single();

    if (error) return jsonError(500, "DB_ERROR", "Could not create vehicle.", reqId, true);

    await auditLog(ctx, {
      action: "vehicle.create",
      entityType: "vehicles",
      entityId: (data as { id?: string } | null)?.id ?? null,
      afterSummary: { label, fuelType, isDefault: makeDefault },
    });

    return jsonOk(data, reqId, 201);
  }

  if (req.method === "PATCH") {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
    }

    const vehicleId = String(body.vehicle_id ?? "");
    if (!vehicleId) return jsonError(422, "VALIDATION_ERROR", "vehicle_id is required.", reqId, false);

    const { data: existing, error: fetchErr } = await supabase
      .from("vehicles")
      .select("*")
      .eq("id", vehicleId)
      .eq("user_id", userId)
      .maybeSingle();
    if (fetchErr) return jsonError(500, "DB_ERROR", "Could not load vehicle.", reqId, true);
    if (!existing) return jsonError(404, "NOT_FOUND", "Vehicle not found.", reqId, false);

    const patch: Record<string, unknown> = {
      user_id: userId,
      label: body.label ?? existing.label,
      fuel_type: body.fuel_type ?? existing.fuel_type,
      mileage_kmpl: body.mileage_kmpl ?? existing.mileage_kmpl,
      ev_battery_kwh: body.ev_battery_kwh ?? existing.ev_battery_kwh,
      ev_efficiency_kwh_per_km: body.ev_efficiency_kwh_per_km ?? existing.ev_efficiency_kwh_per_km,
      cng_mileage_km_per_kg: body.cng_mileage_km_per_kg ?? existing.cng_mileage_km_per_kg,
      updated_at: new Date().toISOString(),
    };
    const makeDefault = body.is_default === true;

    // Transactional: clear any existing default first when making this one default.
    if (makeDefault) {
      await supabase.from("vehicles").update({ is_default: false }).eq("user_id", userId);
    }
    patch.is_default = makeDefault;

    const { data, error } = await supabase.from("vehicles").update(patch).eq("id", vehicleId).select("*").single();
    if (error) return jsonError(500, "DB_ERROR", "Could not update vehicle.", reqId, true);

    await auditLog(ctx, {
      action: "vehicle.update",
      entityType: "vehicles",
      entityId: vehicleId,
      beforeSummary: { label: existing.label, fuel_type: existing.fuel_type },
      afterSummary: { label: patch.label, fuel_type: patch.fuel_type, isDefault: makeDefault },
    });

    return jsonOk(data, reqId);
  }

  if (req.method === "DELETE") {
    const url = new URL(req.url);
    const vehicleId = url.searchParams.get("vehicle_id");
    if (!vehicleId) return jsonError(422, "VALIDATION_ERROR", "vehicle_id is required.", reqId, false);

    const { data: existing, error: fetchErr } = await supabase
      .from("vehicles")
      .select("*")
      .eq("id", vehicleId)
      .eq("user_id", userId)
      .maybeSingle();
    if (fetchErr) return jsonError(500, "DB_ERROR", "Could not load vehicle.", reqId, true);
    if (!existing) return jsonError(404, "NOT_FOUND", "Vehicle not found.", reqId, false);

    const { error } = await supabase.from("vehicles").delete().eq("id", vehicleId).eq("user_id", userId);
    if (error) return jsonError(500, "DB_ERROR", "Could not delete vehicle.", reqId, true);

    await auditLog(ctx, {
      action: "vehicle.delete",
      entityType: "vehicles",
      entityId: vehicleId,
      beforeSummary: { label: existing.label },
    });

    return jsonOk({ deleted: true }, reqId);
  }

  return jsonError(405, "METHOD_NOT_ALLOWED", "Method not allowed.", reqId, false);
});