import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.221.0/assert/mod.ts";
import {
  buildOverpassQuery,
  getPoiProvider,
  matchCategory,
  parseOverpassResponse,
  type PoiResult,
} from "./poiProvider.ts";

// --- pure query builder & parser -------------------------------------------

Deno.test("matchCategory recognises explicit category keywords", () => {
  assertEquals(matchCategory("cafes near me"), [{
    key: "amenity",
    value: "cafe",
  }]);
  assertEquals(
    matchCategory("Cafe"),
    [{ key: "amenity", value: "cafe" }],
    "case-insensitive",
  );
  assertEquals(matchCategory("best restaurants"), [{
    key: "amenity",
    value: "restaurant",
  }]);
});

Deno.test("matchCategory maps broad terms to multiple tags once each", () => {
  const tags = matchCategory("food near here");
  assertEquals(tags.length, 5);
  const keys = tags.map((t) => `${t.key}=${t.value}`);
  assertEquals(new Set(keys).size, keys.length, "no duplicate tag pairs");
});

Deno.test("matchCategory returns [] for non-category queries", () => {
  assertEquals(matchCategory("MG Road"), []);
  assertEquals(matchCategory("hello world"), []);
  assertEquals(matchCategory(""), []);
});

Deno.test("buildOverpassQuery produces a scoped around query", () => {
  const q = buildOverpassQuery(
    [{ key: "amenity", value: "cafe" }],
    12.97,
    77.59,
    5000,
  );
  assert(q.includes(`nwr["amenity"="cafe"](around:5000,12.97,77.59);`));
  assert(q.includes("out center tags 40;"));
});

Deno.test("parseOverpassResponse keeps named POIs with coords, drops noise", () => {
  const data = {
    elements: [
      {
        type: "node",
        id: 1,
        lat: 12.97,
        lon: 77.59,
        tags: { name: "Café A", amenity: "cafe" },
      },
      {
        type: "way",
        id: 2,
        center: { lat: 12.98, lon: 77.6 },
        tags: { name: "Café B", amenity: "cafe" },
      },
      {
        type: "node",
        id: 3,
        lat: 12.97,
        lon: 77.59,
        tags: { amenity: "cafe" },
      },
      {
        type: "node",
        id: 4,
        lat: 12.97,
        lon: 77.59,
        tags: { name: "No category" },
      },
      { type: "node", id: 5, tags: { name: "No coords" } },
    ],
  };
  const results: PoiResult[] = parseOverpassResponse(data);
  assertEquals(results.length, 2);
  assertEquals(results[0].name, "Café A");
  assertEquals(results[0].category, "cafe");
  assertEquals(results[1].name, "Café B");
  assert("lat" in results[1], "way centre is resolved");
});

Deno.test("parseOverpassResponse handles garbage input", () => {
  assertEquals(parseOverpassResponse(null), []);
  assertEquals(parseOverpassResponse({}), []);
  assertEquals(parseOverpassResponse({ elements: "x" }), []);
});

// --- provider selection -----------------------------------------------------

const SAVED_ENV: Record<string, string | undefined> = {
  POI_PROVIDER: Deno.env.get("POI_PROVIDER"),
  GEOCODING_PROVIDER_KEY: Deno.env.get("GEOCODING_PROVIDER_KEY"),
};

function restoreEnv() {
  for (const [k, v] of Object.entries(SAVED_ENV)) {
    if (v === undefined) Deno.env.delete(k);
    else Deno.env.set(k, v);
  }
}

Deno.test("getPoiProvider defaults to mock on an unconfigured project", () => {
  Deno.env.delete("POI_PROVIDER");
  Deno.env.delete("GEOCODING_PROVIDER_KEY");
  assert(getPoiProvider().constructor.name === "MockPoiProvider");
  restoreEnv();
});

Deno.test("getPoiProvider uses real Overpass on a configured project", () => {
  Deno.env.delete("POI_PROVIDER");
  Deno.env.set("GEOCODING_PROVIDER_KEY", "key");
  assert(getPoiProvider().constructor.name === "OverpassPoiProvider");
  restoreEnv();
});

Deno.test("POI_PROVIDER env overrides the default", () => {
  Deno.env.set("POI_PROVIDER", "mock");
  Deno.env.set("GEOCODING_PROVIDER_KEY", "key");
  assert(getPoiProvider().constructor.name === "MockPoiProvider");
  restoreEnv();
});

Deno.test("mock provider returns honest, labelled fixtures for a category", async () => {
  Deno.env.set("POI_PROVIDER", "mock");
  const provider = getPoiProvider();
  const results = await provider.searchNear({
    query: "cafes near me",
    lat: 12.97,
    lng: 77.59,
    radiusKm: 5,
  });
  assert(results.length === 2, "mock returns two cafes");
  assert(results.every((r) => r.category === "cafe"));
  Deno.env.delete("POI_PROVIDER");
  restoreEnv();
});

Deno.test("mock provider returns [] for non-category queries", async () => {
  Deno.env.set("POI_PROVIDER", "mock");
  const provider = getPoiProvider();
  const results = await provider.searchNear({
    query: "some road",
    lat: 12.97,
    lng: 77.59,
    radiusKm: 5,
  });
  assertEquals(results, []);
  restoreEnv();
});
