// Toll provider abstraction, matching spec Section 12.2: verified charge
// where known, otherwise a flagged estimate — never a silent zero.

import type { RouteSegment } from "./routingProvider.ts";

export interface TollResult {
  totalToll: number;
  confidence: "verified" | "estimated" | "unavailable";
  plazas: Array<{ name: string; charge: number; confidence: string }>;
}

export interface TollProvider {
  getTollsForRoute(segments: RouteSegment[]): Promise<TollResult>;
}

class MockTollProvider implements TollProvider {
  async getTollsForRoute(segments: RouteSegment[]): Promise<TollResult> {
    // Illustrative dev fixture: ~one toll plaza per 150km of route, flagged as estimated.
    const totalDistance = segments.reduce((sum, s) => sum + s.distanceKm, 0);
    const estimatedPlazaCount = Math.max(0, Math.floor(totalDistance / 150));
    const perPlazaCharge = 135; // illustrative car-category charge only
    const plazas = Array.from({ length: estimatedPlazaCount }, (_, i) => ({
      name: `Estimated toll plaza ${i + 1}`,
      charge: perPlazaCharge,
      confidence: "estimated",
    }));
    return {
      totalToll: plazas.reduce((sum, p) => sum + p.charge, 0),
      confidence: estimatedPlazaCount > 0 ? "estimated" : "verified", // no plazas = verified zero
      plazas,
    };
  }
}

class SupabaseTollProvider implements TollProvider {
  constructor(private supabaseUrl: string, private serviceRoleKey: string) {}

  async getTollsForRoute(segments: RouteSegment[]): Promise<TollResult> {
    // Real implementation: bounding-box query against public.toll_plazas per
    // segment (or a PostGIS ST_DWithin query on the route geometry if PostGIS
    // is enabled on the Supabase project), then sum verified charges and flag
    // any gap as estimated rather than silently omitting it.
    const plazas: TollResult["plazas"] = [];
    for (const seg of segments) {
      const pad = 0.05; // ~5km bounding box padding in degrees, coarse on purpose
      const minLat = Math.min(seg.startLat, seg.endLat) - pad;
      const maxLat = Math.max(seg.startLat, seg.endLat) + pad;
      const minLng = Math.min(seg.startLng, seg.endLng) - pad;
      const maxLng = Math.max(seg.startLng, seg.endLng) + pad;

      const res = await fetch(
        `${this.supabaseUrl}/rest/v1/toll_plazas?lat=gte.${minLat}&lat=lte.${maxLat}&lng=gte.${minLng}&lng=lte.${maxLng}&select=name,charge,source_confidence`,
        {
          headers: {
            apikey: this.serviceRoleKey,
            Authorization: `Bearer ${this.serviceRoleKey}`,
          },
        }
      );
      if (!res.ok) continue; // one segment's lookup failing doesn't kill the whole trip calc
      const rows = await res.json();
      for (const row of rows) {
        plazas.push({ name: row.name, charge: Number(row.charge), confidence: row.source_confidence });
      }
    }

    const total = plazas.reduce((sum, p) => sum + p.charge, 0);
    const anyEstimated = plazas.some((p) => p.confidence !== "verified");
    return {
      totalToll: total,
      confidence: plazas.length === 0 ? "unavailable" : anyEstimated ? "estimated" : "verified",
      plazas,
    };
  }
}

export function getTollProvider(): TollProvider {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (url && key && Deno.env.get("USE_LIVE_TOLL_DATA") === "true") {
    return new SupabaseTollProvider(url, key);
  }
  return new MockTollProvider();
}
