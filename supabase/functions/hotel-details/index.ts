// Route2Go — /hotel-details Edge Function
//
// Returns real photo + rating/reviews/price/booking-link for one specific
// hotel, fetched from the SerpAPI Google Hotels endpoint server-side (the
// SERPAPI_KEY never leaves the backend). Guests are allowed — a single hotel
// lookup is lightweight and rate-limited — and no user data is persisted.
//
// Honest by design: when no live listing matches the requested hotel name, or
// SERPAPI_KEY is not configured, the response is { details: null } and the
// client keeps its existing no-photo card instead of showing a stock image.

import { jsonError, jsonOk, requestId } from "../_shared/http.ts";
import { getHotelDetails } from "../_shared/providers/hotelDetailsProvider.ts";
import { rateLimitGuard } from "../_shared/rateLimit.ts";

interface HotelDetailsRequest {
  name: string;
  city?: string;
}

Deno.serve(async (req: Request) => {
  const reqId = requestId();

  if (req.method !== "POST") {
    return jsonError(
      405,
      "METHOD_NOT_ALLOWED",
      "Only POST is supported.",
      reqId,
      false,
    );
  }

  const tooMany = rateLimitGuard(req, 30, 60_000, reqId);
  if (tooMany) return tooMany;

  let body: HotelDetailsRequest;
  try {
    body = await req.json();
  } catch {
    return jsonError(
      422,
      "INVALID_JSON",
      "Request body must be valid JSON.",
      reqId,
      false,
    );
  }

  const name = typeof body?.name === "string" ? body.name.trim() : "";
  if (!name) {
    return jsonError(
      422,
      "VALIDATION_ERROR",
      "name is required.",
      reqId,
      false,
    );
  }

  const details = await getHotelDetails({
    name,
    city: typeof body.city === "string" ? body.city : undefined,
  });

  return jsonOk({ details }, reqId);
});