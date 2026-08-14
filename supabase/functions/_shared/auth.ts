// Shared authentication + DB wiring for Route2Go edge functions.
//
// Every privileged endpoint must:
//   1. verify the Firebase ID token from `Authorization: Bearer <token>`
//   2. resolve firebase_uid -> internal public.users.id
//   3. use the SERVICE_ROLE client (server-only) filtered by that id
//
// A literal "guest" token is accepted ONLY where the endpoint opts in
// (`allowGuest`). Guests are never persisted and get no user id back.
//
// Key resolution: prefers the new-style secret key injected by Supabase as
// `SUPABASE_SECRET_KEYS` (a JSON object keyed by name), falling back to the
// legacy `SUPABASE_SERVICE_ROLE_KEY` JWT. This keeps functions working if the
// legacy keys are disabled after a service-role key rotation.

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { verifyFirebaseToken, DecodedFirebaseToken } from "./firebaseAuth.ts";

export interface AuthedContext {
  supabase: SupabaseClient;
  /** Internal public.users.id; null for guests. */
  userId: string | null;
  /** Verified Firebase uid; null for guests. */
  firebaseUid: string | null;
  isGuest: boolean;
  /** Human-readable role for admin endpoints; null for non-admins. */
  adminRole: string | null;
}

/** Resolves the server-side Supabase key: new secret key first, legacy JWT fallback. */
export function resolveServiceRoleKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const json = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (json) {
    try {
      const keys: Record<string, string> = JSON.parse(json);
      const preferred = keys["route2go_backend"] ?? keys["default"];
      if (preferred) return preferred;
    } catch {
      // fall through to legacy if the env isn't valid JSON
    }
  }
  return legacy ?? "";
}

function supabaseClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = resolveServiceRoleKey();
  if (!url || !key) {
    throw new Error("SUPABASE_URL and a service key are required.");
  }
  return createClient(url, key);
}

export async function authRequest(req: Request, opts: { allowGuest?: boolean } = {}): Promise<AuthedContext> {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) {
    throw new AuthError(401, "UNAUTHENTICATED", "Missing bearer token.");
  }

  let firebaseUid: string | null = null;
  let isGuest = false;
  let decoded: DecodedFirebaseToken | null = null;

  if (token === "guest") {
    if (!opts.allowGuest) {
      throw new AuthError(401, "GUEST_NOT_ALLOWED", "This action requires an account.");
    }
    isGuest = true;
  } else {
    try {
      decoded = await verifyFirebaseToken(token);
      firebaseUid = decoded.uid;
    } catch {
      throw new AuthError(401, "INVALID_TOKEN", "Firebase token could not be verified.");
    }
  }

  const supabase = supabaseClient();

  let userId: string | null = null;
  let adminRole: string | null = null;

  if (!isGuest && firebaseUid) {
    const { data: userRow, error } = await supabase
      .from("users")
      .select("id")
      .eq("firebase_uid", firebaseUid)
      .maybeSingle();
    if (error) {
      throw new AuthError(500, "DB_ERROR", "Could not resolve user.");
    }
    userId = userRow?.id ?? null;

    // Lazy provisioning: a verified Firebase identity is the source of truth
    // for who the user is, so the first authenticated call creates the
    // internal users row (and the default profile). Without this, a brand-new
    // Firebase sign-in would 404 on every endpoint. Upsert keeps this
    // idempotent under concurrent first calls.
    if (!userId) {
      const { data: provisioned, error: provErr } = await supabase
        .from("users")
        .upsert({
          firebase_uid: firebaseUid,
          email: decoded?.email ?? null,
          phone: decoded?.phone_number ?? null,
          auth_provider: inferAuthProvider(decoded),
        }, { onConflict: "firebase_uid", ignoreDuplicates: false })
        .select("id")
        .single();
      if (provErr) {
        throw new AuthError(500, "DB_ERROR", "Could not provision user.");
      }
      userId = provisioned?.id ?? null;

      if (userId) {
        const { error: profileErr } = await supabase.from("profiles").upsert(
          { user_id: userId, language: "en", travel_pref: "balanced", analytics_opt_out: false },
          { onConflict: "user_id", ignoreDuplicates: true }
        );
        if (profileErr) {
          console.error("profile provision failed", profileErr);
        }
      }
    }

    if (userId) {
      const { data: adminRow, error: adminErr } = await supabase
        .from("admin_users")
        .select("role")
        .eq("firebase_uid", firebaseUid)
        .maybeSingle();
      if (!adminErr && adminRow?.role) {
        adminRole = adminRow.role;
      }
    }
  }

  return { supabase, userId, firebaseUid, isGuest, adminRole };
}

/** Requires an authenticated (non-guest) user, or throws a typed AuthError. */
export async function requireUser(ctx: AuthedContext): Promise<string> {
  if (ctx.isGuest || !ctx.userId) {
    throw new AuthError(401, "AUTH_REQUIRED", "This action requires an account.");
  }
  return ctx.userId;
}

/** Requires an admin role (any role) and returns it. */
export async function requireAdmin(ctx: AuthedContext): Promise<string> {
  if (!ctx.adminRole) {
    throw new AuthError(403, "FORBIDDEN", "Admin access required.");
  }
  return ctx.adminRole;
}

/**
 * Writes an audit log row. Fails softly: an audit failure must never break
 * the primary operation (we just log to console and continue).
 */
export async function auditLog(ctx: AuthedContext, entry: {
  action: string;
  entityType: string;
  entityId?: string | null;
  beforeSummary?: Record<string, unknown> | null;
  afterSummary?: Record<string, unknown> | null;
}): Promise<void> {
  try {
    await ctx.supabase.from("audit_logs").insert({
      actor_firebase_uid: ctx.firebaseUid,
      action: entry.action,
      entity_type: entry.entityType,
      entity_id: entry.entityId ?? null,
      before_summary: entry.beforeSummary ?? null,
      after_summary: entry.afterSummary ?? null,
    });
  } catch (err) {
    console.error("audit_log write failed", err);
  }
}

export class AuthError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public retryable = false
  ) {
    super(message);
  }
}

export function isOwnedByUser(ctx: AuthedContext, rowUser: string | null | undefined): boolean {
  return ctx.userId !== null && rowUser === ctx.userId;
}

/** Best-effort provider label from token claims (google | email | phone). */
function inferAuthProvider(decoded: DecodedFirebaseToken | null): string {
  if (!decoded) return "unknown";
  const firebase = decoded.firebase as { sign_in_provider?: string } | undefined;
  if (firebase?.sign_in_provider) {
    const p = firebase.sign_in_provider;
    if (p === "password") return "email";
    return p;
  }
  if (decoded.email) return "email";
  if (decoded.phone_number) return "phone";
  return "unknown";
}
