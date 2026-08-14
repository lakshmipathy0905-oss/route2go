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

class NominatimProvider implements GeocodingProvider {
  private static BASE = "https://nominatim.openstreetmap.org";

  private async fetchJson(url: string): Promise<unknown> {
    const res = await fetch(url, {
      headers: { "User-Agent": "Route2Go/0.1 (contact: support@route2go.example)" },
    });
    if (!res.ok) throw new Error(`Geocoding provider error ${res.status}`);
    return res.json();
  }

  async forward(query: string): Promise<GeocodedPlace[]> {
    const url = `${NominatimProvider.BASE}/search?format=json&limit=6&q=${encodeURIComponent(query)}`;
    const data = (await this.fetchJson(url)) as Array<Record<string, unknown>>;
    return data.map((r) => ({
      label: (r.display_name as string) ?? query,
      lat: Number(r.lat),
      lng: Number(r.lon),
      subtitle: (r.type as string) ?? undefined,
    }));
  }

  async reverse(lat: number, lng: number): Promise<GeocodedPlace | null> {
    const url = `${NominatimProvider.BASE}/reverse?format=json&lat=${lat}&lon=${lng}&zoom=12`;
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

export function getGeocodingProvider(): GeocodingProvider {
  if (Deno.env.get("GEOCODING_PROVIDER_KEY")) {
    return new NominatimProvider();
  }
  return new MockGeocodingProvider();
}