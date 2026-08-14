// Route2Go — /privacy Edge Function
//
// Consent logging + account deletion requests (spec 2.12 / Section 5.14).
// Authenticated only.
//   POST /privacy {action: consent, consent_type, granted}
//   POST /privacy {action: request_delete, reason?}
//
// Deletion is a two-phase flow handled by the client: (1) this endpoint
// schedules/records the request against Supabase-owned data, (2) the client
// then deletes the Firebase identity. Server-side scheduled cleanup can key
// off privacy_requests.status='pending'.

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { authRequest, requireUser, auditLog, AuthError } from "../_shared/auth.ts";

const CONSENT_TYPES = ["analytics", "marketing", "data_policy"];

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
  const firebaseUid = ctx.firebaseUid;

  if (req.method !== "POST") {
    return jsonError(405, "METHOD_NOT_ALLOWED", "Only POST is supported.", reqId, false);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
  }

  const action = String(body.action ?? "");

  if (action === "consent") {
    const consentType = String(body.consent_type ?? "");
    const granted = body.granted === true;
    if (!CONSENT_TYPES.includes(consentType)) {
      return jsonError(422, "VALIDATION_ERROR", "consent_type must be analytics, marketing or data_policy.", reqId, false);
    }

    const { error } = await supabase.from("consent_records").insert({
      user_id: userId,
      consent_type: consentType,
      granted,
    });
    if (error) return jsonError(500, "DB_ERROR", "Could not record consent.", reqId, true);

    // The mobile client parses the consent response as a Profile and persists
    // analytics_opt_out there (profile_repository.setAnalyticsOptOut), so for
    // analytics consent we also flip the profile flag and return the row.
    if (consentType === "analytics") {
      const { data: profile, error: profErr } = await supabase
        .from("profiles")
        .update({ analytics_opt_out: !granted, updated_at: new Date().toISOString() })
        .eq("user_id", userId)
        .select("*")
        .single();
      if (profErr) return jsonError(500, "DB_ERROR", "Could not update analytics preference.", reqId, true);
      await auditLog(ctx, { action: "consent.analytics", entityType: "consent_records", afterSummary: { granted } });
      return jsonOk(profile, reqId, 201);
    }

    await auditLog(ctx, { action: `consent.${consentType}`, entityType: "consent_records", afterSummary: { granted } });
    return jsonOk({ recorded: true }, reqId, 201);
  }

  if (action === "request_delete") {
    const reason = body.reason ? String(body.reason).slice(0, 500) : null;

    const { data, error } = await supabase.from("privacy_requests").insert({
      user_id: userId,
      request_type: "delete_account",
      status: "pending",
    }).select("id").single();
    if (error) return jsonError(500, "DB_ERROR", "Could not record deletion request.", reqId, true);

    await auditLog(ctx, { action: "account.delete.request", entityType: "privacy_requests", entityId: data.id, afterSummary: { reason } });
    return jsonOk({ request_id: data.id, status: "pending" }, reqId, 201);
  }

  return jsonError(422, "VALIDATION_ERROR", "action must be consent or request_delete.", reqId, false);
});