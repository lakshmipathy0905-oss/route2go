// Real hotel details provider for Route2Go edge functions.
//
// Fetches live photo + rating/review/price/link for a specific hotel from the
// SerpAPI Google Hotels endpoint. The photo is the actual listing thumbnail for
// the matched property — never a stock placeholder, and never attributed to a
// different hotel: if no returned listing matches the requested hotel name the
// provider returns null instead of guessing.
//
// Requires SERPAPI_KEY (server-side secret, set with `supabase secrets set`).
// When the key is absent the provider returns null so the client degrades
// honestly to its existing no-photo card layout instead of faking images.

export interface HotelDetails {
  name: string;
  photoUrl?: string;
  rating?: number;
  reviewCount?: number;
  pricePerNight?: number;
  bookingUrl?: string;
}

const SERPAPI_ENDPOINT = "https://serpapi.com/search.json";
const HTTP_TIMEOUT_MS = 6_000;

export async function getHotelDetails(opts: {
  name: string;
  city?: string;
}): Promise<HotelDetails | null> {
  const key = Deno.env.get("SERPAPI_KEY");
  if (!key) return null;

  const query = opts.city ? `${opts.name}, ${opts.city}` : opts.name;
  const url = new URL(SERPAPI_ENDPOINT);
  url.searchParams.set("engine", "google_hotels");
  url.searchParams.set("q", query);
  url.searchParams.set("hl", "en");
  url.searchParams.set("gl", "in");
  url.searchParams.set("api_key", key);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), HTTP_TIMEOUT_MS);
  let res: Response;
  try {
    res = await fetch(url, { signal: controller.signal });
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
  if (!res.ok) return null;

  const data: unknown = await res.json().catch(() => null);
  if (typeof data !== "object" || data === null) return null;
  const results = (data as { hotel_results?: unknown }).hotel_results;
  if (!Array.isArray(results) || results.length === 0) return null;

  const wanted = opts.name.toLowerCase();
  const match = (results as Array<Record<string, unknown>>).find((r) =>
    typeof r?.name === "string" &&
    r.name.toLowerCase().includes(wanted)
  );
  if (!match) return null;

  const rating = Number(match.rating);
  const reviews = Number(match.reviews);
  const priceNum = typeof match.price === "string"
    ? Number(match.price.replace(/[^0-9.]/g, ""))
    : NaN;

  return {
    name: typeof match.name === "string" ? match.name : opts.name,
    photoUrl: typeof match.thumbnail === "string" ? match.thumbnail : undefined,
    rating: Number.isFinite(rating) ? rating : undefined,
    reviewCount: Number.isFinite(reviews) ? reviews : undefined,
    pricePerNight: Number.isFinite(priceNum) && priceNum > 0 ? priceNum : undefined,
    bookingUrl: typeof match.link === "string" ? match.link : undefined,
  };
}