// Fuel price provider abstraction. A real deployment should back this with a
// Supabase table (public.fuel_prices) refreshed by a scheduled job pulling
// from a licensed fuel-price feed, falling back to the mock only in dev.

export interface FuelPriceResult {
  price: number;
  lastUpdated: string;
  confidence: "verified" | "estimated";
}

export interface FuelPriceProvider {
  getPrice(params: { region: string; fuelType: "petrol" | "diesel" | "cng" }): Promise<FuelPriceResult>;
}

class MockFuelPriceProvider implements FuelPriceProvider {
  async getPrice(params: { region: string; fuelType: "petrol" | "diesel" | "cng" }): Promise<FuelPriceResult> {
    // Illustrative dev fixture only — NEVER present these as live prices in production.
    const fixture: Record<string, number> = { petrol: 104.5, diesel: 92.3, cng: 78.0 };
    return {
      price: fixture[params.fuelType] ?? 100,
      lastUpdated: new Date().toISOString(),
      confidence: "estimated",
    };
  }
}

class SupabaseFuelPriceProvider implements FuelPriceProvider {
  constructor(private supabaseUrl: string, private serviceRoleKey: string) {}

  async getPrice(params: { region: string; fuelType: "petrol" | "diesel" | "cng" }): Promise<FuelPriceResult> {
    const res = await fetch(
      `${this.supabaseUrl}/rest/v1/fuel_prices?region=eq.${encodeURIComponent(params.region)}&fuel_type=eq.${params.fuelType}&select=price,last_updated`,
      {
        headers: {
          apikey: this.serviceRoleKey,
          Authorization: `Bearer ${this.serviceRoleKey}`,
        },
      }
    );
    if (!res.ok) throw new Error(`Fuel price lookup failed with ${res.status}`);
    const rows = await res.json();
    if (!rows.length) throw new Error("No fuel price on record for this region/fuel type.");
    return {
      price: Number(rows[0].price),
      lastUpdated: rows[0].last_updated,
      confidence: "verified",
    };
  }
}

export function getFuelPriceProvider(): FuelPriceProvider {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (url && key && Deno.env.get("USE_LIVE_FUEL_PRICES") === "true") {
    return new SupabaseFuelPriceProvider(url, key);
  }
  return new MockFuelPriceProvider();
}
