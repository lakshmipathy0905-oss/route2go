// Route2Go — /profile Edge Function
//
// User profile get/update (spec 2.11). Authenticated only.
//   GET   /profile
//   PATCH /profile   (body: name?, photo_url?, language?, home_location_lat?,
//                     home_location_lng?, home_location_label?, travel_pref?,
//                     accommodation_pref?, analytics_opt_out?)
//
// Schema columns: user_id, name, photo_url, language, home_location_lat,
// home_location_lng, home_location_label, travel_pref, accommodation_pref,
// analytics_opt_out. Profile is created lazily on first GET so new users get
// sensible defaults (spec Section 5.3).

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { authRequest, requireUser, auditLog, AuthError } from "../_shared/auth.ts";

const LANGUAGES = ["en", "hi", "kn", "ta"];
const TRAVEL_PREFS = ["budget", "balanced", "premium"];

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

  async function loadProfile() {
    const { data, error } = await supabase
      .from("profiles")
      .select("user_id, name, photo_url, language, home_location_lat, home_location_lng, home_location_label, travel_pref, accommodation_pref, analytics_opt_out, updated_at")
      .eq("user_id", userId)
      .maybeSingle();
    if (error) throw error;
    if (!data) {
      const { data: created, error: insErr } = await supabase
        .from("profiles")
        .insert({ user_id: userId, language: "en", travel_pref: "balanced", analytics_opt_out: false })
        .select("user_id, name, photo_url, language, home_location_lat, home_location_lng, home_location_label, travel_pref, accommodation_pref, analytics_opt_out, updated_at")
        .single();
      if (insErr) throw insErr;
      return created;
    }
    return data;
  }

  if (req.method === "GET") {
    try {
      const profile = await loadProfile();
      return jsonOk(profile, reqId);
    } catch {
      return jsonError(500, "DB_ERROR", "Could not load profile.", reqId, true);
    }
  }

  if (req.method === "PATCH") {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
    }

    const patch: Record<string, unknown> = { updated_at: new Date().toISOString() };

    if (body.name !== undefined) {
      const name = String(body.name).trim();
      if (name.length > 80) return jsonError(422, "VALIDATION_ERROR", "name is too long.", reqId, false);
      patch.name = name || null;
    }
    if (body.photo_url !== undefined) patch.photo_url = body.photo_url ? String(body.photo_url) : null;
    if (body.language !== undefined) {
      if (!LANGUAGES.includes(String(body.language))) {
        return jsonError(422, "VALIDATION_ERROR", "language must be one of en, hi, kn, ta.", reqId, false);
      }
      patch.language = String(body.language);
    }
    if (body.home_location_lat !== undefined) patch.home_location_lat = body.home_location_lat;
    if (body.home_location_lng !== undefined) patch.home_location_lng = body.home_location_lng;
    if (body.home_location_label !== undefined) patch.home_location_label = body.home_location_label ? String(body.home_location_label) : null;
    if (body.travel_pref !== undefined) {
      if (!TRAVEL_PREFS.includes(String(body.travel_pref))) {
        return jsonError(422, "VALIDATION_ERROR", "travel_pref must be budget, balanced or premium.", reqId, false);
      }
      patch.travel_pref = String(body.travel_pref);
    }
    if (body.accommodation_pref !== undefined) patch.accommodation_pref = body.accommodation_pref ? String(body.accommodation_pref) : null;
    if (body.analytics_opt_out !== undefined) patch.analytics_opt_out = body.analytics_opt_out === true;

    try {
      const { data, error } = await supabase.from("profiles").update(patch).eq("user_id", userId).select("*").single();
      if (error) throw error;

      await auditLog(ctx, { action: "profile.update", entityType: "profiles", entityId: data.user_id, afterSummary: patch });
      return jsonOk(data, reqId);
    } catch {
      return jsonError(500, "DB_ERROR", "Could not update profile.", reqId, true);
    }
  }

  return jsonError(405, "METHOD_NOT_ALLOWED", "Method not allowed.", reqId, false);
});