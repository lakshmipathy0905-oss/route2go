// Lightweight in-memory fixed-window rate limiter for Route2Go edge functions.
//
// Guards the public (no-JWT, verify_jwt=false) endpoints — /poi-search and
// /geocode — so they can't be used as an unmetered proxy to hammer the public
// open-data servers (Overpass, Photon/Nominatim): if abused, the public
// mirrors ban *our* edge-function IP, not the caller's. This is a per-isolate
// in-memory guard (bounded memory, no persistence) — a reasonable defence in
// depth, not a replacement for platform-level rate limiting in production.

interface Bucket {
  windowStart: number;
  count: number;
}

const buckets = new Map<string, Bucket>();
const MAX_BUCKETS = 10_000;

export interface RateLimitResult {
  allowed: boolean;
  retryAfterMs: number;
}

export function clientKey(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for");
  if (fwd) {
    const first = fwd.split(",")[0].trim();
    if (first) return first;
  }
  return req.headers.get("x-real-ip") ?? "unknown";
}

export function checkRateLimit(
  key: string,
  maxRequests: number,
  windowMs: number,
): RateLimitResult {
  const now = Date.now();
  const bucket = buckets.get(key);
  if (!bucket || now - bucket.windowStart >= windowMs) {
    if (buckets.size >= MAX_BUCKETS) {
      const oldest = buckets.keys().next().value;
      if (oldest !== undefined) buckets.delete(oldest);
    }
    buckets.set(key, { windowStart: now, count: 1 });
    return { allowed: true, retryAfterMs: 0 };
  }
  if (bucket.count >= maxRequests) {
    return {
      allowed: false,
      retryAfterMs: bucket.windowStart + windowMs - now,
    };
  }
  bucket.count += 1;
  return { allowed: true, retryAfterMs: 0 };
}
