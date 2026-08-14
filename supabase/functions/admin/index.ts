// Route2Go — /admin Edge Function
//
// Admin-only operations backing the admin web dashboard (spec 2.13 / Section
// 5.15). Role-gated: any verified admin_users row may read; privileged writes
// (feature flags, audit exports, moderation) require the 'super_admin' role.
//
//   GET  /admin/stats                        -> dashboard counts
//   GET  /admin/audit?limit=..&action=..     -> audit log
//   GET  /admin/flags                        -> all feature flags
//   PATCH /admin/flags  {key, enabled}       -> set a flag (super)
//   GET  /admin/support?status=open          -> support tickets
//   PATCH /admin/support  {ticket_id, status}-> update ticket (super)
//   GET  /admin/affiliate?days=30            -> affiliate click summary
//   GET  /admin/users?q=..                   -> user search (super)

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { authRequest, requireUser, requireAdmin, auditLog, AuthError } from "../_shared/auth.ts";

Deno.serve(async (req: Request) => {
  const reqId = requestId();

  let ctx;
  try {
    ctx = await authRequest(req);
    await requireUser(ctx);
    await requireAdmin(ctx);
  } catch (err) {
    if (err instanceof AuthError) {
      return jsonError(err.status, err.code, err.message, reqId, err.retryable);
    }
    return jsonError(500, "INTERNAL", "Unexpected error.", reqId, true);
  }

  const supabase = ctx.supabase;
  const role = ctx.adminRole!;
  const url = new URL(req.url);
  const path = url.pathname.split("/").filter(Boolean); // e.g. ["admin","stats"]

  if (req.method === "GET" && path[1] === "me") {
    return jsonOk({ role }, reqId);
  }

  if (req.method === "GET" && path[1] === "stats") {
    const [trips, users, tickets, clicks] = await Promise.all([
      supabase.from("trips").select("id", { count: "exact", head: true }),
      supabase.from("users").select("id", { count: "exact", head: true }),
      supabase.from("support_tickets").select("id", { count: "exact", head: true }).eq("status", "open"),
      supabase.from("affiliate_clicks").select("id", { count: "exact", head: true }),
    ]);
    return jsonOk({
      trips: trips.count ?? 0,
      users: users.count ?? 0,
      open_support_tickets: tickets.count ?? 0,
      affiliate_clicks: clicks.count ?? 0,
    }, reqId);
  }

  if (req.method === "GET" && path[1] === "audit") {
    const limit = Math.min(Number(url.searchParams.get("limit") ?? 100) || 100, 500);
    let q = supabase.from("audit_logs").select("*").order("created_at", { ascending: false }).limit(limit);
    const action = url.searchParams.get("action");
    if (action) q = q.eq("action", action);
    const { data, error } = await q;
    if (error) return jsonError(500, "DB_ERROR", "Could not load audit log.", reqId, true);
    return jsonOk(data ?? [], reqId);
  }

  if (req.method === "GET" && path[1] === "flags") {
    const { data, error } = await supabase.from("feature_flags").select("key, enabled, description, updated_at").order("key", { ascending: true });
    if (error) return jsonError(500, "DB_ERROR", "Could not load flags.", reqId, true);
    return jsonOk(data ?? [], reqId);
  }

  if (req.method === "PATCH" && path[1] === "flags") {
    if (role !== "super_admin") return jsonError(403, "FORBIDDEN", "Super admin role required.", reqId, false);
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
    }
    const key = String(body.key ?? "");
    if (!key) return jsonError(422, "VALIDATION_ERROR", "key is required.", reqId, false);
    if (typeof body.enabled !== "boolean") {
      return jsonError(422, "VALIDATION_ERROR", "enabled must be a boolean.", reqId, false);
    }
    const { data, error } = await supabase
      .from("feature_flags")
      .update({ enabled: body.enabled, updated_at: new Date().toISOString() })
      .eq("key", key)
      .select("*")
      .single();
    if (error) return jsonError(500, "DB_ERROR", "Could not update flag.", reqId, true);
    await auditLog(ctx, { action: "admin.flag.update", entityType: "feature_flags", afterSummary: { key, enabled: body.enabled } });
    return jsonOk(data, reqId);
  }

  if (req.method === "GET" && path[1] === "support") {
    const status = url.searchParams.get("status");
    let q = supabase.from("support_tickets").select("*").order("created_at", { ascending: false }).limit(200);
    if (status) q = q.eq("status", status);
    const { data, error } = await q;
    if (error) return jsonError(500, "DB_ERROR", "Could not load tickets.", reqId, true);
    return jsonOk(data ?? [], reqId);
  }

  if (req.method === "PATCH" && path[1] === "support") {
    if (role !== "super_admin") return jsonError(403, "FORBIDDEN", "Super admin role required.", reqId, false);
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
    }
    const ticketId = String(body.ticket_id ?? "");
    const status = String(body.status ?? "");
    if (!ticketId) return jsonError(422, "VALIDATION_ERROR", "ticket_id is required.", reqId, false);
    if (!["open", "in_progress", "resolved", "closed"].includes(status)) {
      return jsonError(422, "VALIDATION_ERROR", "status must be open, in_progress, resolved or closed.", reqId, false);
    }
    const { data, error } = await supabase.from("support_tickets").update({ status }).eq("id", ticketId).select("*").single();
    if (error) return jsonError(500, "DB_ERROR", "Could not update ticket.", reqId, true);
    await auditLog(ctx, { action: "admin.support.update", entityType: "support_tickets", entityId: ticketId, afterSummary: { status } });
    return jsonOk(data, reqId);
  }

  if (req.method === "GET" && path[1] === "affiliate") {
    const days = Math.min(Number(url.searchParams.get("days") ?? 30) || 30, 365);
    const since = new Date(Date.now() - days * 86400000).toISOString();
    const { data, error } = await supabase
      .from("affiliate_clicks")
      .select("partner_id, clicked_at")
      .gte("clicked_at", since);
    if (error) return jsonError(500, "DB_ERROR", "Could not load affiliate clicks.", reqId, true);
    const counts: Record<string, number> = {};
    for (const c of data ?? []) {
      const key = c.partner_id ?? "unknown";
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return jsonOk({ days, total: (data ?? []).length, by_partner: counts }, reqId);
  }

  if (req.method === "GET" && path[1] === "users") {
    if (role !== "super_admin") return jsonError(403, "FORBIDDEN", "Super admin role required.", reqId, false);
    const q = (url.searchParams.get("q") ?? "").trim();
    const limit = Math.min(Number(url.searchParams.get("limit") ?? 50) || 50, 200);
    let query = supabase.from("users").select("id, email, phone, auth_provider, created_at").limit(limit);
    if (q) query = query.or(`email.ilike.%${q}%,phone.ilike.%${q}%`);
    const { data, error } = await query;
    if (error) return jsonError(500, "DB_ERROR", "Could not load users.", reqId, true);
    return jsonOk(data ?? [], reqId);
  }

  return jsonError(404, "NOT_FOUND", "Unknown admin endpoint.", reqId, false);
});