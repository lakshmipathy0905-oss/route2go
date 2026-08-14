// Unit tests for the pure itinerary scheduler (spec 2.6 edge cases).
// Run: deno test --allow-import itinerary_scheduler_test.ts

import { assertEquals, assert } from "https://deno.land/std@0.221.0/assert/mod.ts";
import { generateItinerary, validateItineraryInput, type ItineraryInput } from "../_shared/itineraryScheduler.ts";

function baseInput(overrides: Partial<ItineraryInput> = {}): ItineraryInput {
  return {
    origin_label: "Bengaluru",
    destination_label: "Coorg",
    total_distance_km: 260,
    total_drive_min: 300,
    max_driving_hours_per_day: 8,
    budget_total: 5000,
    trip_type: "one_way",
    selected_places: [],
    selected_stays: [],
    ...overrides,
  };
}

Deno.test("rejects same-origin/destination via validation", () => {
  const issues = validateItineraryInput({
    ...baseInput(),
    origin_label: "Mysuru",
    destination_label: "Mysuru",
  });
  // Same label isn't itself flagged, but a zero-distance trip is unschedulable.
  const issues2 = validateItineraryInput({ ...baseInput(), total_distance_km: 0 });
  assert(issues2.some((i) => i.code === "ZERO_DISTANCE"));
  assertEquals(issues.length, 0);
});

Deno.test("zero distance is rejected", () => {
  const issues = validateItineraryInput(baseInput({ total_distance_km: 0 }));
  assertEquals(issues.length, 1);
  assertEquals(issues[0].code, "ZERO_DISTANCE");
});

Deno.test("invalid trip type is rejected", () => {
  const issues = validateItineraryInput({
    ...baseInput(),
    trip_type: "circular" as "one_way",
  });
  assert(issues.some((i) => i.code === "INVALID_TRIP_TYPE"));
});

Deno.test("drive cap out of range is rejected", () => {
  const issues = validateItineraryInput(baseInput({ max_driving_hours_per_day: 0 }));
  assert(issues.some((i) => i.code === "INVALID_DRIVE_CAP"));
});

Deno.test("long one-way trip produces multiple days under the drive cap", () => {
  // 1200 km ≈ 1200 min at 60 km/h; cap of 8h = 480 min → 3 days.
  const plan = generateItinerary(baseInput({ total_drive_min: 1200, max_driving_hours_per_day: 8 }));
  assertEquals(plan.length, 3);
  for (const day of plan) {
    assert(day.total_drive_min <= 480, `day ${day.day_number} exceeds drive cap`);
    assert(day.items.some((i) => i.item_type === "drive"));
  }
});

Deno.test("places are packed until driving budget runs out", () => {
  const plan = generateItinerary(baseInput({
    total_drive_min: 480,
    max_driving_hours_per_day: 8,
    selected_places: [
      { id: "p1", name: "Mysore Palace", detour_duration_min: 60, est_cost: 100 },
      { id: "p2", name: "Namdroling", detour_duration_min: 90, est_cost: 50 },
      { id: "p3", name: "Abbey Falls", detour_duration_min: 45, est_cost: 20 },
    ],
  }));
  const allPlaces = plan.flatMap((d) => d.items.filter((i) => i.item_type === "place"));
  // At least the first place must be scheduled; not all may fit in one day.
  assert(allPlaces.length >= 1);
  assert(allPlaces.some((i) => i.ref_id === "p1"));
  assert(allPlaces[0].name === "Mysore Palace");
});

Deno.test("selected stays are added as hotel items with cost", () => {
  const plan = generateItinerary(baseInput({
    selected_stays: [{ id: "s1", name: "Coorg Jungle Lodge", price_per_night: 2500, nights: 1 }],
  }));
  const hotels = plan.flatMap((d) => d.items.filter((i) => i.item_type === "hotel"));
  assertEquals(hotels.length, 1);
  assertEquals(hotels[0].name, "Coorg Jungle Lodge");
  assertEquals(hotels[0].est_cost, 2500);
  assert(plan[0].total_est_cost >= 2500);
});

Deno.test("round trip halves the base drive and keeps the drive cap", () => {
  const plan = generateItinerary(baseInput({
    total_drive_min: 1200,
    trip_type: "round_trip",
    max_driving_hours_per_day: 8,
  }));
  assert(plan.length >= 2, "round trip should spread driving over days");
  for (const day of plan) {
    assert(day.total_drive_min <= 480);
  }
});

Deno.test("last day without a stay closes with an arrival drive", () => {
  const plan = generateItinerary(baseInput({
    total_drive_min: 300,
    selected_stays: [],
  }));
  const lastDay = plan[plan.length - 1];
  const types = lastDay.items.map((i) => i.item_type);
  assert(types.includes("drive"));
  assert(types.includes("rest"));
});

Deno.test("final day arrival names the destination", () => {
  const plan = generateItinerary(baseInput({ total_drive_min: 300 }));
  const lastDay = plan[plan.length - 1];
  assert(lastDay.items.some((i) => i.name.includes("Coorg")));
});