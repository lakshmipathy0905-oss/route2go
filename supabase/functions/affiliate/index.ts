// Route2Go — /affiliate Edge Function
//
// Server-side affiliate click logging (spec 2.5). Guests allowed: the
// affiliate disclosure + click logging happens even for guest planning
// sessions, with null user_id for guests.
//
// Mobile contract (favorites_repository AffiliateRepository.logClick):
//   POST /affiliate {action: click, stay_id, partner_id, trip_id?}

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { authRequest, AuthError } from "../_shared/auth.ts";

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

  const action = String(body.action ?? "");
  if (action !== "click") {
    return jsonError(422, "VALIDATION_ERROR", "action must be 'click'.", reqId, false);
  }

  const stayId = String(body.stay_id ?? "");
  const partnerId = body.partner_id != null ? String(body.partner_id) : null;
  const tripId = body.trip_id != null ? String(body.trip_id) : null;

  if (!stayId) return jsonError(422, "VALIDATION_ERROR", "stay_id is required.", reqId, false);
  if (!partnerId) return jsonError(422, "VALIDATION_ERROR", "partner_id is required.", reqId, false);

  const { error } = await ctx.supabase.from("affiliate_clicks").insert({
    user_id: ctx.userId ?? null,
    stay_id: stayId,
    partner_id: partnerId,
    trip_id: tripId,
  });
  if (error) {
    console.error("affiliate click insert failed", error);
    return jsonError(500, "DB_ERROR", "Could not log affiliate click.", reqId, true);
  }

  return jsonOk({ logged: true }, reqId, 201);
});