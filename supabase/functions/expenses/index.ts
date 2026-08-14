// Route2Go — /expenses Edge Function
//
// Expense tracking against a saved trip (spec 2.8 / Section 5.12).
// Authenticated only. Ownership is derived through the trip, never trusted
// from a client-supplied user id.
//   GET    /expenses?trip_id=...   -> list
//   POST   /expenses               -> create
//   PATCH  /expenses               -> update / record actual
//   DELETE /expenses?expense_id=.. -> delete

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { authRequest, requireUser, AuthError } from "../_shared/auth.ts";

const CATEGORIES = ["fuel", "toll", "stay", "food", "misc"];

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

  async function ownsTrip(tripId: string): Promise<boolean> {
    const { data, error } = await supabase
      .from("trips")
      .select("id")
      .eq("id", tripId)
      .eq("user_id", userId)
      .maybeSingle();
    if (error || !data) return false;
    return true;
  }

  if (req.method === "GET") {
    const url = new URL(req.url);
    const tripId = url.searchParams.get("trip_id");
    if (!tripId) return jsonError(422, "VALIDATION_ERROR", "trip_id is required.", reqId, false);
    if (!(await ownsTrip(tripId))) return jsonError(404, "NOT_FOUND", "Trip not found.", reqId, false);

    const { data, error } = await supabase
      .from("expenses")
      .select("*")
      .eq("trip_id", tripId)
      .order("created_at", { ascending: false });
    if (error) return jsonError(500, "DB_ERROR", "Could not load expenses.", reqId, true);
    return jsonOk(data ?? [], reqId);
  }

  if (req.method === "POST") {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
    }

    const tripId = String(body.trip_id ?? "");
    const category = String(body.category ?? "");
    const estimated = Number(body.estimated_amount ?? 0);
    if (!tripId) return jsonError(422, "VALIDATION_ERROR", "trip_id is required.", reqId, false);
    if (!CATEGORIES.includes(category)) {
      return jsonError(422, "VALIDATION_ERROR", "category must be fuel, toll, stay, food or misc.", reqId, false);
    }
    if (!isFinite(estimated) || estimated < 0) {
      return jsonError(422, "VALIDATION_ERROR", "estimated_amount must be a non-negative number.", reqId, false);
    }
    if (!(await ownsTrip(tripId))) return jsonError(404, "NOT_FOUND", "Trip not found.", reqId, false);

    const actual = body.actual_amount !== undefined ? Number(body.actual_amount) : null;
    if (actual !== null && (!isFinite(actual) || actual < 0)) {
      return jsonError(422, "VALIDATION_ERROR", "actual_amount must be a non-negative number.", reqId, false);
    }

    const { data, error } = await supabase
      .from("expenses")
      .insert({
        trip_id: tripId,
        category,
        estimated_amount: estimated,
        actual_amount: actual,
        paid_by: body.paid_by ?? null,
        split_type: String(body.split_type ?? "equal"),
        description: body.description ?? null,
      })
      .select("*")
      .single();
    if (error) return jsonError(500, "DB_ERROR", "Could not create expense.", reqId, true);
    return jsonOk(data, reqId, 201);
  }

  if (req.method === "PATCH") {
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
    }

    const expenseId = String(body.expense_id ?? "");
    if (!expenseId) return jsonError(422, "VALIDATION_ERROR", "expense_id is required.", reqId, false);

    const { data: expense, error: fetchErr } = await supabase
      .from("expenses")
      .select("id, trip_id, category, estimated_amount, actual_amount")
      .eq("id", expenseId)
      .maybeSingle();
    if (fetchErr) return jsonError(500, "DB_ERROR", "Could not load expense.", reqId, true);
    if (!expense) return jsonError(404, "NOT_FOUND", "Expense not found.", reqId, false);
    if (!(await ownsTrip(expense.trip_id))) return jsonError(404, "NOT_FOUND", "Trip not found.", reqId, false);

    const patch: Record<string, unknown> = { updated_at: new Date().toISOString() };
    if (body.category !== undefined) {
      const category = String(body.category);
      if (!CATEGORIES.includes(category)) {
        return jsonError(422, "VALIDATION_ERROR", "category must be fuel, toll, stay, food or misc.", reqId, false);
      }
      patch.category = category;
    }
    if (body.estimated_amount !== undefined) {
      const v = Number(body.estimated_amount);
      if (!isFinite(v) || v < 0) return jsonError(422, "VALIDATION_ERROR", "estimated_amount must be non-negative.", reqId, false);
      patch.estimated_amount = v;
    }
    if (body.actual_amount !== undefined) {
      const v = Number(body.actual_amount);
      if (!isFinite(v) || v < 0) return jsonError(422, "VALIDATION_ERROR", "actual_amount must be non-negative.", reqId, false);
      patch.actual_amount = v;
    }
    if (body.paid_by !== undefined) patch.paid_by = body.paid_by;
    if (body.split_type !== undefined) patch.split_type = String(body.split_type);
    if (body.description !== undefined) patch.description = body.description;

    const { data, error } = await supabase.from("expenses").update(patch).eq("id", expenseId).select("*").single();
    if (error) return jsonError(500, "DB_ERROR", "Could not update expense.", reqId, true);
    return jsonOk(data, reqId);
  }

  if (req.method === "DELETE") {
    const url = new URL(req.url);
    const expenseId = url.searchParams.get("expense_id");
    if (!expenseId) return jsonError(422, "VALIDATION_ERROR", "expense_id is required.", reqId, false);

    const { data: expense, error: fetchErr } = await supabase
      .from("expenses")
      .select("id, trip_id")
      .eq("id", expenseId)
      .maybeSingle();
    if (fetchErr) return jsonError(500, "DB_ERROR", "Could not load expense.", reqId, true);
    if (!expense) return jsonError(404, "NOT_FOUND", "Expense not found.", reqId, false);
    if (!(await ownsTrip(expense.trip_id))) return jsonError(404, "NOT_FOUND", "Trip not found.", reqId, false);

    const { error } = await supabase.from("expenses").delete().eq("id", expenseId);
    if (error) return jsonError(500, "DB_ERROR", "Could not delete expense.", reqId, true);
    return jsonOk({ deleted: true }, reqId);
  }

  return jsonError(405, "METHOD_NOT_ALLOWED", "Method not allowed.", reqId, false);
});