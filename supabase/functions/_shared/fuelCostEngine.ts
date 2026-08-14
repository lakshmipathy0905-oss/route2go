// Pure fuel cost engine — matches spec Section 12.1. Extracted so it is
// unit-testable without a running edge function. No I/O: given a distance,
// vehicle efficiency and a price per unit, returns the cost or an honest
// "unavailable" when the inputs can't support a real calculation.

export interface FuelCostVehicle {
  fuel_type: "petrol" | "diesel" | "ev" | "cng";
  mileage_kmpl?: number;
  ev_efficiency_kwh_per_km?: number;
  cng_mileage_km_per_kg?: number;
}

export interface FuelCostParams {
  distanceKm: number;
  vehicle: FuelCostVehicle;
  fuelPricePerUnit: number | null;
  phase2Ev: boolean;
  phase2Cng: boolean;
}

export interface FuelCostResult {
  cost: number | null;
  confidence: "calculated" | "unavailable";
}

export const SAFETY_BUFFER_PCT = 0.06; // 6%, within spec's 5-8% default range

export function computeFuelCost(params: FuelCostParams): FuelCostResult {
  const { distanceKm, vehicle } = params;

  if (vehicle.fuel_type === "ev") {
    if (!vehicle.ev_efficiency_kwh_per_km) {
      return { cost: null, confidence: "unavailable" };
    }
    if (!params.phase2Ev) {
      // Gated behind phase2_ev: energy is real but cost needs a live EV
      // charging price per kWh, which isn't wired until the flag is on.
      return { cost: null, confidence: "unavailable" };
    }
    if (!params.fuelPricePerUnit) {
      return { cost: null, confidence: "unavailable" };
    }
    const energyKwh = distanceKm * vehicle.ev_efficiency_kwh_per_km;
    const cost = energyKwh * params.fuelPricePerUnit * (1 + SAFETY_BUFFER_PCT);
    return { cost: round2(cost), confidence: "calculated" };
  }

  if (vehicle.fuel_type === "cng") {
    if (!vehicle.cng_mileage_km_per_kg) {
      return { cost: null, confidence: "unavailable" };
    }
    if (!params.phase2Cng) {
      // Gated behind phase2_cng: same reasoning as EV above.
      return { cost: null, confidence: "unavailable" };
    }
    if (!params.fuelPricePerUnit) {
      return { cost: null, confidence: "unavailable" };
    }
    const fuelRequiredKg = distanceKm / vehicle.cng_mileage_km_per_kg;
    const cost = fuelRequiredKg * params.fuelPricePerUnit * (1 + SAFETY_BUFFER_PCT);
    return { cost: round2(cost), confidence: "calculated" };
  }

  // petrol / diesel
  if (!vehicle.mileage_kmpl || !params.fuelPricePerUnit) {
    return { cost: null, confidence: "unavailable" };
  }

  const fuelRequiredLitres = distanceKm / vehicle.mileage_kmpl;
  const cost = fuelRequiredLitres * params.fuelPricePerUnit * (1 + SAFETY_BUFFER_PCT);
  return { cost: round2(cost), confidence: "calculated" };
}

export function round2(n: number): number {
  return Math.round(n * 100) / 100;
}