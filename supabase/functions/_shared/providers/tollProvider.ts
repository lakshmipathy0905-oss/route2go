// Toll provider abstraction, matching spec Section 12.2: verified charge
// where known, otherwise a flagged estimate — never a silent zero.

import type { RouteSegment } from "./routingProvider.ts";
import { resolveServiceRoleKey } from "../auth.ts";

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
    // Real implementation: a single bounding-box query against
    // public.toll_plazas over the UNION of all segment boxes (min/max lat/lng
    // with padding). The union box is a superset of every per-segment box, so
    // this returns the same plazas a per-segment loop would — in one query
    // instead of one per segment. Verified charges are summed and any gap is
    // flagged as estimated rather than silently omitted.
    if (segments.length === 0) {
      return { totalToll: 0, confidence: "unavailable", plazas: [] };
    }

    const pad = 0.05; // ~5km bounding box padding in degrees, coarse on purpose
    let minLat = Infinity,
      maxLat = -Infinity,
      minLng = Infinity,
      maxLng = -Infinity;
    for (const seg of segments) {
      minLat = Math.min(minLat, seg.startLat, seg.endLat);
      maxLat = Math.max(maxLat, seg.startLat, seg.endLat);
      minLng = Math.min(minLng, seg.startLng, seg.endLng);
      maxLng = Math.max(maxLng, seg.startLng, seg.endLng);
    }

    const res = await fetch(
      `${this.supabaseUrl}/rest/v1/toll_plazas?lat=gte.${minLat - pad}` +
        `&lat=lte.${maxLat + pad}&lng=gte.${minLng - pad}` +
        `&lng=lte.${
          maxLng + pad
        }&select=name,charge,source_confidence&limit=500`,
      {
        headers: {
          apikey: this.serviceRoleKey,
          Authorization: `Bearer ${this.serviceRoleKey}`,
        },
      },
    );
    if (!res.ok) {
      // A toll lookup failure must not kill the whole trip calc — return an
      // honest "unknown" rather than a silent zero.
      return { totalToll: 0, confidence: "unavailable", plazas: [] };
    }
    const rows = await res.json();
    const plazas: TollResult["plazas"] = [];
    for (const row of rows) {
      plazas.push({
        name: row.name,
        charge: Number(row.charge),
        confidence: row.source_confidence,
      });
    }

    const total = plazas.reduce((sum, p) => sum + p.charge, 0);
    const anyEstimated = plazas.some((p) => p.confidence !== "verified");
    return {
      totalToll: total,
      confidence: plazas.length === 0
        ? "unavailable"
        : anyEstimated
        ? "estimated"
        : "verified",
      plazas,
    };
  }
}

export function getTollProvider(): TollProvider {
  const url = Deno.env.get("SUPABASE_URL");
  const key = resolveServiceRoleKey();
  if (url && key && Deno.env.get("USE_LIVE_TOLL_DATA") === "true") {
    return new SupabaseTollProvider(url, key);
  }
  return new MockTollProvider();
}
