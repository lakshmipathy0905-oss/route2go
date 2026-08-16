import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.221.0/assert/mod.ts";
import { GeocoderCache } from "./_shared/providers/geocodingProvider.ts";
import { sanitizeSearchPattern } from "./_shared/searchSanitize.ts";
import { clientKey, rateLimitGuard } from "./_shared/rateLimit.ts";

// --- geocoder cache --------------------------------------------------------

Deno.test("GeocoderCache serves a cached value for the same key", () => {
  GeocoderCache.clear();
  GeocoderCache.set("f:bengaluru", [{ label: "Bengaluru" }], 1_000);
  assertEquals(GeocoderCache.get("f:bengaluru", 1_100), [
    { label: "Bengaluru" },
  ]);
  GeocoderCache.clear();
});

Deno.test("GeocoderCache expires entries after the TTL", () => {
  GeocoderCache.clear();
  const now = 1_000_000;
  GeocoderCache.set("k", "v", now);
  assertEquals(GeocoderCache.get("k", now + 30 * 60 * 1000 - 1), "v");
  assertEquals(GeocoderCache.get("k", now + 30 * 60 * 1000 + 1), undefined);
  GeocoderCache.clear();
});

Deno.test("GeocoderCache is keyed exactly (no prefix collision)", () => {
  GeocoderCache.clear();
  GeocoderCache.set("f:bengaluru", "one", 1_000);
  assertEquals(GeocoderCache.get("f:bengaluru "), undefined);
  GeocoderCache.clear();
});

Deno.test("GeocoderCache evicts the oldest entry when full", () => {
  GeocoderCache.clear();
  const clock = 1_000_000;
  for (let i = 0; i < 65; i++) GeocoderCache.set(`key-${i}`, i, clock + i);
  // First inserted key was evicted to make room for the 65th.
  assertEquals(GeocoderCache.get("key-0", clock + 1), undefined);
  assertEquals(GeocoderCache.get("key-64", clock + 65), 64);
  GeocoderCache.clear();
});

// --- search pattern sanitization -------------------------------------------

Deno.test("sanitizeSearchPattern keeps plain queries intact", () => {
  assertEquals(sanitizeSearchPattern("MG Road"), "%MG Road%");
});

Deno.test("sanitizeSearchPattern neutralises filter-significant characters", () => {
  // A raw `,` or `(` would be parsed as extra PostgREST filter syntax.
  assert(!sanitizeSearchPattern("cafe,restaurant").includes(","));
  assert(!sanitizeSearchPattern("cafe(1)").includes("("));
  assert(!sanitizeSearchPattern("cafe(1)").includes(")"));
  assert(!sanitizeSearchPattern("'quoted'").includes("'"));
  assert(!sanitizeSearchPattern('"dq"').includes('"'));
  assert(!sanitizeSearchPattern("back\\slash").includes("\\"));
  assertEquals(sanitizeSearchPattern("cafe,restaurant"), "%cafe restaurant%");
});

Deno.test("sanitizeSearchPattern stops wildcard widening", () => {
  // A raw `%` would turn the ilike into a full-table match.
  assertEquals(sanitizeSearchPattern("%_all"), "%_all%");
  assertEquals(sanitizeSearchPattern("a*b"), "%a b%");
});

Deno.test("sanitizeSearchPattern collapses runs of whitespace", () => {
  assertEquals(sanitizeSearchPattern("  a   b  "), "%a b%");
});

// --- rate-limit guard ------------------------------------------------------

Deno.test("rateLimitGuard returns null under the cap and 429 over it", () => {
  const req = new Request("http://local", {
    headers: { "x-forwarded-for": "198.51.100.10" },
  });
  const first = rateLimitGuard(req, 2, 60_000, "req-1");
  assertEquals(first, null);
  const second = rateLimitGuard(req, 2, 60_000, "req-2");
  assertEquals(second, null);
  const third = rateLimitGuard(req, 2, 60_000, "req-3");
  assert(third !== null);
  assertEquals(third.status, 429);
  assert(third.headers.get("Retry-After") !== null);
});

Deno.test("rateLimitGuard uses the trusted last x-forwarded-for hop", () => {
  const spoofed = new Request("http://local", {
    headers: {
      "x-forwarded-for": "6.6.6.6, 198.51.100.11",
    },
  });
  assertEquals(clientKey(spoofed), "198.51.100.11");
  const first = rateLimitGuard(spoofed, 1, 60_000, "req-1");
  assertEquals(first, null);
  const second = rateLimitGuard(spoofed, 1, 60_000, "req-2");
  assert(second !== null, "spoofed leading hop must not bypass the limit");
});
