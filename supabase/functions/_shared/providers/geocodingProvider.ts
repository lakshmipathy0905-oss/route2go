// Geocoding provider abstraction for Route2Go edge functions.
//
// Forward (text -> coords) and reverse (coords -> label) geocoding. A mock
// adapter is used when GEOCODING_PROVIDER_KEY is absent so local dev works
// without external keys; real deployments should set the key and use a
// provider like Nominatim (OSM) — the interface below is provider-agnostic.

export interface GeocodedPlace {
  label: string;
  lat: number;
  lng: number;
  subtitle?: string;
}

export interface GeocodingProvider {
  forward(query: string): Promise<GeocodedPlace[]>;
  reverse(lat: number, lng: number): Promise<GeocodedPlace | null>;
}

class MockGeocodingProvider implements GeocodingProvider {
  private static known = [
    { label: "Bengaluru", lat: 12.9716, lng: 77.5946, subtitle: "Karnataka" },
    { label: "Mysuru", lat: 12.2958, lng: 76.6394, subtitle: "Karnataka" },
    { label: "Chennai", lat: 13.0827, lng: 80.2707, subtitle: "Tamil Nadu" },
    { label: "Hyderabad", lat: 17.3850, lng: 78.4867, subtitle: "Telangana" },
    { label: "Mumbai", lat: 19.0760, lng: 72.8777, subtitle: "Maharashtra" },
    { label: "Pune", lat: 18.5204, lng: 73.8567, subtitle: "Maharashtra" },
    { label: "Coorg", lat: 12.3375, lng: 75.8069, subtitle: "Karnataka" },
    { label: "Ooty", lat: 11.4064, lng: 76.6932, subtitle: "Tamil Nadu" },
    { label: "Kodaikanal", lat: 10.2381, lng: 77.4892, subtitle: "Tamil Nadu" },
    { label: "Goa", lat: 15.2993, lng: 74.1240, subtitle: "Goa" },
  ];

  async forward(query: string): Promise<GeocodedPlace[]> {
    const q = query.toLowerCase();
    return MockGeocodingProvider.known
      .filter((p) => p.label.toLowerCase().includes(q))
      .slice(0, 6);
  }

  async reverse(lat: number, lng: number): Promise<GeocodedPlace | null> {
    let best: GeocodedPlace | null = null;
    let bestDist = Infinity;
    for (const p of MockGeocodingProvider.known) {
      const d = (p.lat - lat) ** 2 + (p.lng - lng) ** 2;
      if (d < bestDist) {
        bestDist = d;
        best = p;
      }
    }
    return best;
  }
}

// Build a readable label for a Photon feature's properties. Prefers a real
// name; falls back to the most specific named place parts so results are
// never blank. Pure so it can be unit-tested without network access.
export function photonLabel(props: Record<string, unknown>): string {
  const name = typeof props.name === "string" ? props.name : "";
  const housenumber = typeof props.housenumber === "string"
    ? props.housenumber
    : "";
  const street = typeof props.street === "string" ? props.street : "";
  const city = typeof props.city === "string" ? props.city : "";
  const state = typeof props.state === "string" ? props.state : "";
  const country = typeof props.country === "string" ? props.country : "";
  const named = name || street || housenumber || city || state || country || "";
  const parts = [
    name,
    street ? (housenumber ? `${housenumber} ${street}` : street) : housenumber,
    city,
    state,
    country,
  ].filter((p) => typeof p === "string" && p.length > 0);
  return parts.length > 0 ? parts.join(", ") : named;
}

// Map a Photon /api response body to Route2Go places. Pure and unit-testable.
export function mapPhotonFeatures(
  features: unknown,
  query: string,
): GeocodedPlace[] {
  if (!Array.isArray(features)) return [];
  return features
    .map((f) => {
      const props =
        (f as { properties?: Record<string, unknown> })?.properties ?? {};
      const coords = (f as { geometry?: { coordinates?: unknown } })?.geometry
        ?.coordinates;
      if (!Array.isArray(coords) || coords.length < 2) return null;
      const lng = Number(coords[0]);
      const lat = Number(coords[1]);
      if (!isFinite(lat) || !isFinite(lng)) return null;
      const label = photonLabel(props);
      if (!label) return null;
      return {
        label,
        lat,
        lng,
        subtitle: typeof props.osm_value === "string"
          ? props.osm_value
          : undefined,
      } as GeocodedPlace;
    })
    .filter((p): p is GeocodedPlace => p !== null);
}

// Decide which text to send to Photon for a raw query. Proximity phrasing is
// handled explicitly: "cafes near me" can't be geocoded and returns name-noise
// (OSM businesses literally titled "... near me"), so pure near-me queries are
// skipped and answered by the caller's POI search instead. "cafes near MG
// Road" searches the place term "MG Road" so the map pin lands on the right
// spot. Pure so it can be unit-tested.
export function resolvePhotonQuery(query: string): string | null {
  const nearMe = query.match(
    /^(.+?)\s+near\s+(me|here|my\s*location|current\s*location)\s*$/i,
  );
  if (nearMe) return null;
  if (/^\s*near\s+(me|here)\s*$/i.test(query)) return null;
  const nearPlace = query.match(/(.+?)\s+near\s+(.+)/i);
  if (nearPlace && nearPlace[2].trim().length >= 2) return nearPlace[2].trim();
  return query.trim().length >= 2 ? query.trim() : null;
}

class PhotonGeocodingProvider implements GeocodingProvider {
  // Public Photon (komoot) instance — worldwide, no country bias, typo
  // tolerant free-text search/autocomplete over OSM data.
  private static BASE = "https://photon.komoot.io";

  private async fetchJson(url: string): Promise<unknown> {
    const res = await fetch(url, {
      headers: {
        "User-Agent": "Route2Go/0.1 (contact: support@route2go.example)",
      },
    });
    if (!res.ok) throw new Error(`Geocoding provider error ${res.status}`);
    return res.json();
  }

  async forward(query: string): Promise<GeocodedPlace[]> {
    const searchQuery = resolvePhotonQuery(query);
    if (!searchQuery) return [];
    const url =
      `${PhotonGeocodingProvider.BASE}/api/?q=${
        encodeURIComponent(searchQuery)
      }` +
      `&limit=6&lang=en`;
    const data = (await this.fetchJson(url)) as { features?: unknown };
    return mapPhotonFeatures(data.features, searchQuery);
  }

  async reverse(lat: number, lng: number): Promise<GeocodedPlace | null> {
    const url =
      `${PhotonGeocodingProvider.BASE}/reverse?lat=${lat}&lon=${lng}&lang=en`;
    const data = (await this.fetchJson(url)) as { features?: unknown };
    const features = mapPhotonFeatures(data.features, "");
    if (features.length === 0) return null;
    return { ...features[0], subtitle: "Picked on map" };
  }
}

class NominatimProvider implements GeocodingProvider {
  private static BASE = "https://nominatim.openstreetmap.org";

  private async fetchJson(url: string): Promise<unknown> {
    const res = await fetch(url, {
      headers: {
        "User-Agent": "Route2Go/0.1 (contact: support@route2go.example)",
      },
    });
    if (!res.ok) throw new Error(`Geocoding provider error ${res.status}`);
    return res.json();
  }

  async forward(query: string): Promise<GeocodedPlace[]> {
    // Region-biased search: without a country restriction Nominatim favours
    // large English-speaking geos, so a generic query like "temple" resolves to
    // Texas instead of India. Route2Go is India-first (fuel region IN, India
    // toll data), so bias the search there. `accept-language` keeps place
    // labels in English with Hindi/Kannada as fallback.
    const url = `${NominatimProvider.BASE}/search?format=json&limit=6` +
      `&countrycodes=in&accept-language=en,hi,kn&q=${
        encodeURIComponent(query)
      }`;
    let data = (await this.fetchJson(url)) as Array<Record<string, unknown>>;

    // Nominatim can't parse proximity phrasing like "college near Bengaluru".
    // Fall back to the place term after "near" so the user still gets results.
    if (data.length === 0 && /\bnear\b/i.test(query)) {
      const place = query.split(/\bnear\b/i).pop()?.trim() ?? "";
      if (place.length >= 2) {
        const retryUrl =
          `${NominatimProvider.BASE}/search?format=json&limit=6` +
          `&countrycodes=in&accept-language=en,hi,kn&q=${
            encodeURIComponent(place)
          }`;
        data = (await this.fetchJson(retryUrl)) as Array<
          Record<string, unknown>
        >;
      }
    }

    return data.map((r) => ({
      label: (r.display_name as string) ?? query,
      lat: Number(r.lat),
      lng: Number(r.lon),
      subtitle: (r.type as string) ?? undefined,
    }));
  }

  async reverse(lat: number, lng: number): Promise<GeocodedPlace | null> {
    const url =
      `${NominatimProvider.BASE}/reverse?format=json&lat=${lat}&lon=${lng}&zoom=12`;
    const data = (await this.fetchJson(url)) as Record<string, unknown>;
    if (!data || !data.display_name) return null;
    return {
      label: data.display_name as string,
      lat,
      lng,
      subtitle: "Picked on map",
    };
  }
}

// Photon is the default real backend: worldwide, no country bias, typo
// tolerant. The India-biased Nominatim adapter stays available for
// deployments that want a regional bias via GEOCODING_BACKEND=nominatim.
export function getGeocodingProvider(): GeocodingProvider {
  if (Deno.env.get("GEOCODING_PROVIDER_KEY")) {
    if (Deno.env.get("GEOCODING_BACKEND") === "nominatim") {
      return new NominatimProvider();
    }
    return new PhotonGeocodingProvider();
  }
  return new MockGeocodingProvider();
}
