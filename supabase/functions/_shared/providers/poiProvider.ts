// POI (point of interest) provider abstraction for Route2Go edge functions.
//
// Searches worldwide OSM points of interest by category around a location
// using the public Overpass API. A mock adapter is used in dev so local work
// never hits a public service. The category matcher and query builder/parser
// are pure so they can be unit-tested without network access.

export interface PoiResult {
  name: string;
  category: string;
  lat: number;
  lng: number;
  tags: Record<string, string>;
  // Optional city from the element's addr:city tag when the OSM data has one.
  city?: string;
}

export interface PoiSearchParams {
  query: string;
  lat: number;
  lng: number;
  radiusKm: number;
}

export interface PoiProvider {
  searchNear(params: PoiSearchParams): Promise<PoiResult[]>;
  // True when the last search was answered from the degraded path (cooldown
  // active or the upstream failed) rather than from live/cached data. Lets
  // callers distinguish "no POIs exist" from "POIs exist but we couldn't
  // reach the provider".
  isDegraded(): boolean;
}

export interface OsmTag {
  key: string;
  value: string;
}

// Human category keywords -> OSM tag pairs. Each keyword list maps to one or
// more concrete tag values. Rules are checked in order; every rule whose
// keyword appears in the query contributes its tags.
const CATEGORY_RULES: Array<{
  keywords: string[];
  key: string;
  values: string[];
}> = [
  { keywords: ["cafe", "coffee", "chai"], key: "amenity", values: ["cafe"] },
  { keywords: ["restaurant"], key: "amenity", values: ["restaurant"] },
  {
    keywords: ["food", "eat", "dining"],
    key: "amenity",
    values: ["restaurant", "fast_food", "cafe", "bar", "pub"],
  },
  {
    keywords: ["fuel", "petrol", "gas station", "gas", "petrol pump"],
    key: "amenity",
    values: ["fuel"],
  },
  {
    keywords: ["charging", "ev", "charge point"],
    key: "amenity",
    values: ["charging_station"],
  },
  { keywords: ["hospital"], key: "amenity", values: ["hospital"] },
  {
    keywords: ["pharmacy", "chemist", "medical"],
    key: "amenity",
    values: ["pharmacy"],
  },
  { keywords: ["atm", "cash machine"], key: "amenity", values: ["atm"] },
  { keywords: ["bank"], key: "amenity", values: ["bank"] },
  { keywords: ["parking", "car park"], key: "amenity", values: ["parking"] },
  { keywords: ["hotel"], key: "tourism", values: ["hotel"] },
  { keywords: ["hostel"], key: "tourism", values: ["hostel"] },
  {
    keywords: ["attraction", "museum", "sightseeing", "tourist"],
    key: "tourism",
    values: ["attraction", "museum"],
  },
  { keywords: ["park", "garden"], key: "leisure", values: ["park", "garden"] },
  { keywords: ["playground"], key: "leisure", values: ["playground"] },
  {
    keywords: ["school", "college", "university", "campus"],
    key: "amenity",
    values: ["school", "college", "university"],
  },
  {
    keywords: ["temple", "worship", "church", "mosque", "gurudwara"],
    key: "amenity",
    values: ["place_of_worship"],
  },
  { keywords: ["airport"], key: "aeroway", values: ["aerodrome"] },
  {
    keywords: ["station", "train station"],
    key: "railway",
    values: ["station"],
  },
  {
    keywords: ["supermarket", "grocery", "mall", "shopping"],
    key: "shop",
    values: ["supermarket", "convenience", "mall"],
  },
  { keywords: ["bakery"], key: "shop", values: ["bakery"] },
];

// Map a free-text query to concrete OSM tag pairs. Returns [] for queries
// that are not a recognised category, so callers only hit Overpass when the
// query actually describes a POI category.
export function matchCategory(query: string): OsmTag[] {
  const q = query.toLowerCase();
  const seen = new Set<string>();
  const hits: OsmTag[] = [];
  for (const rule of CATEGORY_RULES) {
    if (rule.keywords.some((k) => q.includes(k))) {
      for (const value of rule.values) {
        const key = `${rule.key}=${value}`;
        if (!seen.has(key)) {
          seen.add(key);
          hits.push({ key: rule.key, value });
        }
      }
    }
  }
  return hits;
}

// Build an Overpass QL body that searches node/way/relation around a point.
// The server timeout is aligned with the client abort budget (10s, see
// OverpassPoiProvider.searchNear) so we never ask a public server to keep
// computing longer than we are willing to wait.
export function buildOverpassQuery(
  tags: OsmTag[],
  lat: number,
  lng: number,
  radiusMeters: number,
): string {
  const r = Math.round(radiusMeters);
  const blocks = tags.map(
    (t) => `nwr["${t.key}"="${t.value}"](around:${r},${lat},${lng});`,
  );
  return `[out:json][timeout:10];\n(\n  ${
    blocks.join("\n  ")
  }\n);\nout center tags 40;`;
}

// Parse an Overpass JSON body into POI results. Only named elements with a
// resolvable coordinate are kept; unnamed OSM nodes are noise.
export function parseOverpassResponse(data: unknown): PoiResult[] {
  if (!data || typeof data !== "object") return [];
  const elements = (data as { elements?: unknown }).elements;
  if (!Array.isArray(elements)) return [];
  const out: PoiResult[] = [];
  for (const raw of elements) {
    const e = raw as {
      tags?: Record<string, string>;
      lat?: number;
      lon?: number;
      center?: { lat?: number; lon?: number };
    };
    const tags = e.tags;
    if (!tags) continue;
    const name = typeof tags.name === "string" ? tags.name.trim() : "";
    if (!name) continue;
    const lat = e.lat ?? e.center?.lat;
    const lng = e.lon ?? e.center?.lon;
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) continue;
    const category = tags.amenity ||
      tags.shop ||
      tags.tourism ||
      tags.leisure ||
      tags.aeroway ||
      tags.railway;
    if (!category) continue; // no recognisable POI category -> not a POI
    const addrCity = typeof tags["addr:city"] === "string"
      ? tags["addr:city"].trim()
      : "";
    out.push({
      name,
      category,
      lat: lat as number,
      lng: lng as number,
      tags,
      city: addrCity.length > 0 ? addrCity : undefined,
    });
  }
  return out;
}

function fetchWithTimeout(
  url: string,
  init: RequestInit,
  ms: number,
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  return fetch(url, { ...init, signal: controller.signal }).finally(() =>
    clearTimeout(timer)
  );
}

class OverpassPoiProvider implements PoiProvider {
  // Public Overpass endpoints. The main instance rate-limits aggressively and
  // egress from some regions is flaky, so mirrors are tried in order with a
  // bounded timeout. Order favours the endpoints observed to respond fastest
  // and most reliably from the deploy region; dead instances are removed
  // rather than left to burn timeout budget. Route2Go only queries these for
  // explicit POI category searches (never per keystroke without a category
  // match).
  private static MIRRORS = [
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    "https://overpass-api.de/api/interpreter",
    "https://overpass.openstreetmap.fr/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
  ];

  // Small in-memory cache: identical "category near X" searches are common
  // while a user types (debounced), so serve repeats without hammering the
  // public Overpass servers.
  private static cache = new Map<
    string,
    { at: number; results: PoiResult[] }
  >();
  private static readonly TTL_MS = 30 * 60 * 1000;
  private static readonly MAX_CACHE = 64;

  // Circuit breaker: after a total failure, back off for a while instead of
  // re-hammering the public servers on every keystroke. Kept short so a brief
  // mirror outage doesn't silence category searches for long.
  private static cooldownUntil = 0;
  private static readonly COOLDOWN_MS = 45 * 1000;

  // Whether the most recent searchNear was served while degraded (cooldown
  // active with no cached answer). Reset on any live/cached success.
  private static wasDegraded = false;

  isDegraded(): boolean {
    return OverpassPoiProvider.wasDegraded;
  }

  async searchNear(params: PoiSearchParams): Promise<PoiResult[]> {
    const tags = matchCategory(params.query);
    if (tags.length === 0) return [];
    const key = `${params.query.toLowerCase()}|${params.lat.toFixed(3)}|` +
      `${params.lng.toFixed(3)}|${params.radiusKm}`;
    const cached = OverpassPoiProvider.cache.get(key);
    if (cached && Date.now() - cached.at < OverpassPoiProvider.TTL_MS) {
      OverpassPoiProvider.wasDegraded = false;
      return cached.results;
    }
    if (Date.now() < OverpassPoiProvider.cooldownUntil) {
      OverpassPoiProvider.wasDegraded = true;
      return [];
    }

    const meters = Math.min(
      Math.max(Math.round(params.radiusKm * 1000), 250),
      25_000,
    );
    const body = new URLSearchParams({
      data: buildOverpassQuery(tags, params.lat, params.lng, meters),
    });
    let lastError: unknown = null;
    for (const base of OverpassPoiProvider.MIRRORS) {
      try {
        const res = await fetchWithTimeout(
          base,
          {
            method: "POST",
            headers: {
              "User-Agent": "Route2Go/0.1 (contact: support@route2go.example)",
              "Content-Type": "application/x-www-form-urlencoded",
            },
            body: body.toString(),
          },
          10_000,
        );
        if (!res.ok) {
          lastError = new Error(`POI provider error ${res.status}`);
          continue;
        }
        const data: unknown = await res.json();
        const parsed = parseOverpassResponse(data).slice(0, 40);
        // An OK response (empty or not) is a definitive answer; cache it to
        // avoid re-hitting the public servers for the same search.
        if (OverpassPoiProvider.cache.size >= OverpassPoiProvider.MAX_CACHE) {
          OverpassPoiProvider.cache.delete(
            OverpassPoiProvider.cache.keys().next().value as string,
          );
        }
        OverpassPoiProvider.cache.set(key, { at: Date.now(), results: parsed });
        OverpassPoiProvider.cooldownUntil = 0;
        OverpassPoiProvider.wasDegraded = false;
        return parsed;
      } catch (err) {
        lastError = err;
      }
    }
    // All mirrors failed — back off rather than hammering them.
    OverpassPoiProvider.cooldownUntil = Date.now() +
      OverpassPoiProvider.COOLDOWN_MS;
    OverpassPoiProvider.wasDegraded = true;
    if (lastError !== null) {
      if (lastError instanceof Error) throw lastError;
      throw new Error("POI provider error");
    }
    return [];
  }
}

class MockPoiProvider implements PoiProvider {
  isDegraded(): boolean {
    return false;
  }

  async searchNear(params: PoiSearchParams): Promise<PoiResult[]> {
    const tags = matchCategory(params.query);
    if (tags.length === 0) return [];
    const category = tags[0].value;
    return [
      {
        name: `Test ${category}`,
        category,
        lat: params.lat + 0.003,
        lng: params.lng + 0.003,
        city: "Bengaluru",
        tags: { name: `Test ${category}`, [`${tags[0].key}`]: category },
      },
      {
        name: `Another ${category}`,
        category,
        lat: params.lat - 0.003,
        lng: params.lng - 0.004,
        city: "Bengaluru",
        tags: { name: `Another ${category}`, [`${tags[0].key}`]: category },
      },
    ];
  }
}

export function getPoiProvider(): PoiProvider {
  const mode = Deno.env.get("POI_PROVIDER");
  if (mode === "mock") return new MockPoiProvider();
  if (mode === "overpass") return new OverpassPoiProvider();
  // Sensible default: real Overpass on a configured project, mock elsewhere.
  if (Deno.env.get("GEOCODING_PROVIDER_KEY")) return new OverpassPoiProvider();
  return new MockPoiProvider();
}
