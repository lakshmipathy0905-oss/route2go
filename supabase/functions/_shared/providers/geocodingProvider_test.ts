import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.221.0/assert/mod.ts";
import {
  type GeocodedPlace,
  getGeocodingProvider,
  mapPhotonFeatures,
  photonLabel,
  resolvePhotonQuery,
} from "./geocodingProvider.ts";

// --- pure mapping helpers ---------------------------------------------------

Deno.test("photonLabel builds a readable label from available parts", () => {
  assertEquals(
    photonLabel({
      name: "MG Road",
      city: "Bengaluru",
      state: "Karnataka",
      country: "India",
    }),
    "MG Road, Bengaluru, Karnataka, India",
  );
  assertEquals(
    photonLabel({
      housenumber: "12",
      street: "Residency Rd",
      city: "Bengaluru",
    }),
    "12 Residency Rd, Bengaluru",
  );
  assertEquals(
    photonLabel({ city: "Paris", country: "France" }),
    "Paris, France",
  );
  assertEquals(photonLabel({}), "");
});

Deno.test("mapPhotonFeatures maps features and drops malformed entries", () => {
  const features = [
    {
      properties: { name: "MG Road", osm_value: "road" },
      geometry: { coordinates: [77.5946, 12.9716] },
    },
    { properties: { name: "No coords" }, geometry: null },
    {
      properties: { name: "Bad lat" },
      geometry: { coordinates: [77.6, "nope"] },
    },
    { properties: {}, geometry: { coordinates: [10.0, 20.0] } },
  ];
  const places: GeocodedPlace[] = mapPhotonFeatures(features, "mg road");
  assertEquals(places.length, 1, "unnamed and malformed features are dropped");
  assertEquals(places[0].label, "MG Road");
  assertEquals(places[0].lat, 12.9716);
  assertEquals(places[0].lng, 77.5946);
  assertEquals(places[0].subtitle, "road");
});

Deno.test("mapPhotonFeatures returns [] for non-array input", () => {
  assertEquals(mapPhotonFeatures(null, "x"), []);
  assertEquals(mapPhotonFeatures({}, "x"), []);
});

// --- near-phrase handling ---------------------------------------------------

Deno.test("resolvePhotonQuery strips proximity phrasing to the place term", () => {
  assertEquals(resolvePhotonQuery("cafes near MG Road"), "MG Road");
  assertEquals(resolvePhotonQuery("hotels near Bengaluru"), "Bengaluru");
  assertEquals(resolvePhotonQuery("MG Road"), "MG Road");
});

Deno.test("resolvePhotonQuery skips pure near-me category queries", () => {
  assertEquals(resolvePhotonQuery("cafes near me"), null);
  assertEquals(resolvePhotonQuery("restaurants near me"), null);
  assertEquals(resolvePhotonQuery("near me"), null);
});

// --- provider selection -----------------------------------------------------

const SAVED_ENV: Record<string, string | undefined> = {
  GEOCODING_PROVIDER_KEY: Deno.env.get("GEOCODING_PROVIDER_KEY"),
  GEOCODING_BACKEND: Deno.env.get("GEOCODING_BACKEND"),
};

function restoreEnv() {
  for (const [k, v] of Object.entries(SAVED_ENV)) {
    if (v === undefined) Deno.env.delete(k);
    else Deno.env.set(k, v);
  }
}

Deno.test("getGeocodingProvider returns mock when unconfigured", () => {
  Deno.env.delete("GEOCODING_PROVIDER_KEY");
  Deno.env.delete("GEOCODING_BACKEND");
  const provider = getGeocodingProvider();
  assert(provider.constructor.name === "MockGeocodingProvider");
  restoreEnv();
});

Deno.test("getGeocodingProvider returns Photon by default (worldwide, no bias)", () => {
  Deno.env.set("GEOCODING_PROVIDER_KEY", "key");
  Deno.env.delete("GEOCODING_BACKEND");
  const provider = getGeocodingProvider();
  assert(provider.constructor.name === "PhotonGeocodingProvider");
  restoreEnv();
});

Deno.test("getGeocodingProvider returns Nominatim when explicitly requested", () => {
  Deno.env.set("GEOCODING_PROVIDER_KEY", "key");
  Deno.env.set("GEOCODING_BACKEND", "nominatim");
  const provider = getGeocodingProvider();
  assert(provider.constructor.name === "NominatimProvider");
  restoreEnv();
});
