// Route2Go — /notifications Edge Function
//
// Notification feed + read state + FCM token registration (spec 2.10).
// Authenticated only.
//   GET    /notifications                    -> list
//   GET    /notifications?unread_count=1     -> unread count
//   POST   /notifications {action: register_token, token} -> register FCM token
//   PATCH  /notifications {notification_id}  -> mark one read
//   PATCH  /notifications {mark_all_read: true} -> mark all read
//   DELETE /notifications?notification_id=.. -> delete one

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { authRequest, requireUser, AuthError } from "../_shared/auth.ts";

const VALID_TYPES = ["trip_reminder", "budget_warning", "trip_status", "marketing"];

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
    if (url.searchParams.get("unread_count") === "1") {
      const { count, error } = await supabase
        .from("notifications")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId)
        .is("read_at", null);
      if (error) return jsonError(500, "DB_ERROR", "Could not count notifications.", reqId, true);
      return jsonOk(count ?? 0, reqId);
    }

    const { data, error } = await supabase
      .from("notifications")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(100);
    if (error) return jsonError(500, "DB_ERROR", "Could not load notifications.", reqId, true);

    const normalized = (data ?? []).map((n) => {
      const payload = (typeof n.payload === "object" && n.payload !== null ? n.payload : {}) as Record<string, unknown>;
      return {
        id: n.id,
        type: n.type,
        title: typeof payload.title === "string" ? payload.title : null,
        body: typeof payload.body === "string" ? payload.body : null,
        read: n.read_at != null,
        sent_at: n.sent_at ?? n.created_at,
      };
    });
    return jsonOk(normalized, reqId);
  }

  if (req.method === "POST") {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
    }

    if (body.action === "register_token") {
      const token = String(body.token ?? "");
      if (!token) return jsonError(422, "VALIDATION_ERROR", "token is required.", reqId, false);

      // Notification prefs live per user; keep tokens on the same row.
      const { data: prefs, error: fetchErr } = await supabase
        .from("notification_prefs")
        .select("fcm_tokens")
        .eq("user_id", userId)
        .maybeSingle();

      if (fetchErr) return jsonError(500, "DB_ERROR", "Could not load notification preferences.", reqId, true);

      const existing: string[] = prefs?.fcm_tokens ?? [];
      if (existing.includes(token)) return jsonOk({ registered: true }, reqId);

      const { error } = await supabase.from("notification_prefs").upsert(
        { user_id: userId, fcm_tokens: [...existing, token], updated_at: new Date().toISOString() },
        { onConflict: "user_id" }
      );
      if (error) return jsonError(500, "DB_ERROR", "Could not register push token.", reqId, true);
      return jsonOk({ registered: true }, reqId);
    }

    return jsonError(422, "VALIDATION_ERROR", "action must be register_token.", reqId, false);
  }

  if (req.method === "PATCH") {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
    }

    if (body.mark_all_read === true) {
      const { error } = await supabase
        .from("notifications")
        .update({ read_at: new Date().toISOString() })
        .eq("user_id", userId)
        .is("read_at", null);
      if (error) return jsonError(500, "DB_ERROR", "Could not mark notifications read.", reqId, true);
      return jsonOk({ updated: true }, reqId);
    }

    const notificationId = String(body.notification_id ?? "");
    if (!notificationId) {
      return jsonError(422, "VALIDATION_ERROR", "notification_id or mark_all_read is required.", reqId, false);
    }

    const { data: existing, error: fetchErr } = await supabase
      .from("notifications")
      .select("id")
      .eq("id", notificationId)
      .eq("user_id", userId)
      .maybeSingle();
    if (fetchErr) return jsonError(500, "DB_ERROR", "Could not load notification.", reqId, true);
    if (!existing) return jsonError(404, "NOT_FOUND", "Notification not found.", reqId, false);

    const { error } = await supabase
      .from("notifications")
      .update({ read_at: new Date().toISOString() })
      .eq("id", notificationId);
    if (error) return jsonError(500, "DB_ERROR", "Could not update notification.", reqId, true);
    return jsonOk({ updated: true }, reqId);
  }

  if (req.method === "DELETE") {
    const url = new URL(req.url);
    const notificationId = url.searchParams.get("notification_id");
    if (!notificationId) return jsonError(422, "VALIDATION_ERROR", "notification_id is required.", reqId, false);

    const { data: existing, error: fetchErr } = await supabase
      .from("notifications")
      .select("id")
      .eq("id", notificationId)
      .eq("user_id", userId)
      .maybeSingle();
    if (fetchErr) return jsonError(500, "DB_ERROR", "Could not load notification.", reqId, true);
    if (!existing) return jsonError(404, "NOT_FOUND", "Notification not found.", reqId, false);

    const { error } = await supabase.from("notifications").delete().eq("id", notificationId);
    if (error) return jsonError(500, "DB_ERROR", "Could not delete notification.", reqId, true);
    return jsonOk({ deleted: true }, reqId);
  }

  return jsonError(405, "METHOD_NOT_ALLOWED", "Method not allowed.", reqId, false);
});