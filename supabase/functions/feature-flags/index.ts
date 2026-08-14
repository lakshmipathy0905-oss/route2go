// Route2Go — /feature-flags Edge Function
//
// Returns feature-flag overrides from the DB, merged with any static
// defaults. Guests allowed (spec 5.2): the client gate must work pre-login.
//   GET /feature-flags

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { authRequest, AuthError } from "../_shared/auth.ts";

const STATIC_DEFAULTS: Record<string, boolean> = {
  phase2_group_split: false,
  phase2_ev: false,
  phase2_cng: false,
  phase2_offline: false,
  phase2_weather: false,
};

Deno.serve(async (req: Request) => {
  const reqId = requestId();

  if (req.method !== "GET") {
    return jsonError(405, "METHOD_NOT_ALLOWED", "Only GET is supported.", reqId, false);
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

  const { data, error } = await ctx.supabase.from("feature_flags").select("key, enabled, description");
  if (error) return jsonError(500, "DB_ERROR", "Could not load feature flags.", reqId, true);

  const dbFlags: Record<string, boolean> = {};
  for (const row of data ?? []) {
    if (typeof row.enabled === "boolean") dbFlags[row.key] = row.enabled;
  }

  const merged: Record<string, boolean> = { ...STATIC_DEFAULTS, ...dbFlags };
  const list = Object.entries(merged).map(([key, enabled]) => ({ key, enabled }));

  return jsonOk(list, reqId);
});