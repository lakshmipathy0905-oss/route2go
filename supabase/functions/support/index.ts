// Route2Go — /support Edge Function
//
// Support ticket creation + FAQ retrieval (spec 2.12 / Section 5.16).
//   GET  /support?faqs=1     -> FAQ list (guests allowed)
//   POST /support {action: open, subject, message}  -> open a ticket (auth required)

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { authRequest, requireUser, auditLog, AuthError } from "../_shared/auth.ts";

const STATIC_FAQS = [
  { id: "faq-1", question: "How do I add a vehicle?", answer: "Open Settings → Profile → Vehicle Garage (or Plan Trip → Vehicle). Enter the label and fuel type, then save. Mark it as your default if it's the one you usually drive." },
  { id: "faq-2", question: "Can I plan a trip without an account?", answer: "Yes. Guests can plan routes and browse places, stays and itineraries. You'll need an account to save trips, track expenses, and sync across devices." },
  { id: "faq-3", question: "How is the estimated trip cost calculated?", answer: "We estimate fuel from your vehicle's mileage (or a sensible default), add tolls from our route data, and let you set a trip budget. Actual amounts are yours to record in the Expense Tracker." },
  { id: "faq-4", question: "How do I delete my account?", answer: "Open Settings → Delete account. We schedule deletion of your data and then remove your sign-in identity. You'll get a confirmation screen before anything is deleted." },
  { id: "faq-5", question: "How do stays work?", answer: "Stays are affiliate listings shown near your route. The price is a guide; clicking through opens the partner site where you complete the booking. We log the click to attribute the listing." },
];

Deno.serve(async (req: Request) => {
  const reqId = requestId();

  if (req.method === "GET") {
    const url = new URL(req.url);
    if (url.searchParams.get("faqs") === "1") {
      return jsonOk(STATIC_FAQS, reqId);
    }
    return jsonError(422, "VALIDATION_ERROR", "Use ?faqs=1 to list FAQs.", reqId, false);
  }

  if (req.method !== "POST") {
    return jsonError(405, "METHOD_NOT_ALLOWED", "Method not allowed.", reqId, false);
  }

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

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonError(422, "INVALID_JSON", "Request body must be valid JSON.", reqId, false);
  }

  if (body.action !== "open") {
    return jsonError(422, "VALIDATION_ERROR", "action must be 'open'.", reqId, false);
  }

  const subject = String(body.subject ?? "").trim();
  const message = String(body.message ?? "").trim();
  if (!subject) return jsonError(422, "VALIDATION_ERROR", "subject is required.", reqId, false);
  if (!message) return jsonError(422, "VALIDATION_ERROR", "message is required.", reqId, false);
  if (subject.length > 200) return jsonError(422, "VALIDATION_ERROR", "subject is too long.", reqId, false);
  if (message.length > 2000) return jsonError(422, "VALIDATION_ERROR", "message is too long.", reqId, false);

  const { data, error } = await ctx.supabase.from("support_tickets").insert({
    user_id: ctx.userId,
    subject,
    message,
    status: "open",
  }).select("id, status, created_at").single();
  if (error) return jsonError(500, "DB_ERROR", "Could not open a ticket.", reqId, true);

  await auditLog(ctx, { action: "support.ticket.open", entityType: "support_tickets", entityId: data.id, afterSummary: { subject } });
  return jsonOk({ ticket_id: data.id, status: data.status }, reqId, 201);
});