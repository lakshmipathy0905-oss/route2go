// Unit tests for the pure fuel cost engine (spec Section 12.1), including the
// phase2_ev / phase2_cng gating. Run: deno test --allow-import fuelCostEngine_test.ts

import { assertEquals } from "https://deno.land/std@0.221.0/assert/mod.ts";
import {
  computeFuelCost,
  type FuelCostVehicle,
} from "../_shared/fuelCostEngine.ts";

function vehicle(overrides: Partial<FuelCostVehicle> = {}): FuelCostVehicle {
  return { fuel_type: "petrol", mileage_kmpl: 15, ...overrides };
}

Deno.test("petrol cost is calculated with mileage + price", () => {
  const r = computeFuelCost({
    distanceKm: 100,
    vehicle: vehicle(),
    fuelPricePerUnit: 100,
    phase2Ev: false,
    phase2Cng: false,
  });
  // 100/15 * 100 * 1.06 = 706.67
  assertEquals(r, { cost: 706.67, confidence: "calculated" });
});

Deno.test("petrol without mileage or price is unavailable (never fabricated)", () => {
  const noMileage = computeFuelCost({
    distanceKm: 100,
    vehicle: vehicle({ mileage_kmpl: undefined }),
    fuelPricePerUnit: 100,
    phase2Ev: false,
    phase2Cng: false,
  });
  assertEquals(noMileage, { cost: null, confidence: "unavailable" });

  const noPrice = computeFuelCost({
    distanceKm: 100,
    vehicle: vehicle(),
    fuelPricePerUnit: null,
    phase2Ev: false,
    phase2Cng: false,
  });
  assertEquals(noPrice, { cost: null, confidence: "unavailable" });
});

Deno.test("EV is gated behind phase2_ev", () => {
  const ev = vehicle({
    fuel_type: "ev",
    ev_efficiency_kwh_per_km: 0.15,
    mileage_kmpl: undefined,
  });

  const gated = computeFuelCost({
    distanceKm: 100,
    vehicle: ev,
    fuelPricePerUnit: 8,
    phase2Ev: false,
    phase2Cng: false,
  });
  assertEquals(gated, { cost: null, confidence: "unavailable" });

  const open = computeFuelCost({
    distanceKm: 100,
    vehicle: ev,
    fuelPricePerUnit: 8,
    phase2Ev: true,
    phase2Cng: false,
  });
  // 100*0.15 kWh * ₹8 * 1.06 = ₹127.20
  assertEquals(open, { cost: 127.2, confidence: "calculated" });
});

Deno.test("EV without efficiency or charging price is unavailable", () => {
  const noEff = computeFuelCost({
    distanceKm: 100,
    vehicle: vehicle({ fuel_type: "ev", mileage_kmpl: undefined }),
    fuelPricePerUnit: 8,
    phase2Ev: true,
    phase2Cng: false,
  });
  assertEquals(noEff, { cost: null, confidence: "unavailable" });

  const noPrice = computeFuelCost({
    distanceKm: 100,
    vehicle: vehicle({
      fuel_type: "ev",
      ev_efficiency_kwh_per_km: 0.15,
      mileage_kmpl: undefined,
    }),
    fuelPricePerUnit: null,
    phase2Ev: true,
    phase2Cng: false,
  });
  assertEquals(noPrice, { cost: null, confidence: "unavailable" });
});

Deno.test("CNG is gated behind phase2_cng", () => {
  const cng = vehicle({
    fuel_type: "cng",
    cng_mileage_km_per_kg: 22,
    mileage_kmpl: undefined,
  });

  const gated = computeFuelCost({
    distanceKm: 110,
    vehicle: cng,
    fuelPricePerUnit: 78,
    phase2Ev: false,
    phase2Cng: false,
  });
  assertEquals(gated, { cost: null, confidence: "unavailable" });

  const open = computeFuelCost({
    distanceKm: 110,
    vehicle: cng,
    fuelPricePerUnit: 78,
    phase2Ev: false,
    phase2Cng: true,
  });
  // 110/22 kg * ₹78 * 1.06 = ₹413.40
  assertEquals(open, { cost: 413.4, confidence: "calculated" });
});

Deno.test("CNG without mileage or price is unavailable", () => {
  const noMileage = computeFuelCost({
    distanceKm: 110,
    vehicle: vehicle({ fuel_type: "cng", mileage_kmpl: undefined }),
    fuelPricePerUnit: 78,
    phase2Ev: false,
    phase2Cng: true,
  });
  assertEquals(noMileage, { cost: null, confidence: "unavailable" });

  const noPrice = computeFuelCost({
    distanceKm: 110,
    vehicle: vehicle({
      fuel_type: "cng",
      cng_mileage_km_per_kg: 22,
      mileage_kmpl: undefined,
    }),
    fuelPricePerUnit: null,
    phase2Ev: false,
    phase2Cng: true,
  });
  assertEquals(noPrice, { cost: null, confidence: "unavailable" });
});