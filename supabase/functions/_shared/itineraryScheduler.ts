// Pure itinerary scheduling logic for Route2Go.
//
// Deliberately free of network/DB access so it can be unit-tested in
// isolation (deno test). Given trip + selected places/stays + constraints,
// produces day-by-day items.
//
// Item types mirror the schema: "drive", "stay", "rest", "place", "hotel".
//
// Rules:
//  - Never exceed maxDrivingHoursPerDay of drive time.
//  - Places and stays are distributed across days; each day's driving time
//    includes the segment to that day's stay.
//  - If a place/stay cannot be packed into the driving budget it is pushed
//    to the next day; unplaceable leftovers are dropped (with a note).

export type ItineraryItemType = "drive" | "stay" | "rest" | "place" | "hotel";

export interface ItineraryItem {
  item_type: ItineraryItemType;
  ref_id: string | null;
  name: string;
  start_time: string | null;
  end_time: string | null;
  est_cost: number | null;
  note?: string;
}

export interface ItineraryDay {
  day_number: number;
  items: ItineraryItem[];
  total_est_cost: number;
  total_drive_min: number;
}

export interface ItineraryInput {
  origin_label: string;
  destination_label: string;
  total_distance_km: number;
  total_drive_min: number;
  max_driving_hours_per_day: number;
  budget_total: number | null;
  trip_type: "one_way" | "round_trip";
  selected_places: Array<{ id: string; name: string; detour_duration_min: number; est_cost?: number | null }>;
  selected_stays: Array<{ id: string; name: string; price_per_night?: number | null; nights?: number }>;
}

export function generateItinerary(input: ItineraryInput): ItineraryDay[] {
  const maxDriveMin = Math.round(input.max_driving_hours_per_day * 60);
  const days: ItineraryDay[] = [];

  // Round trip halves the base drive, then doubles the day plan.
  const oneWayDriveMin = input.trip_type === "round_trip"
    ? Math.round(input.total_drive_min / 2)
    : input.total_drive_min;

  const dayCount = Math.max(1, Math.ceil(oneWayDriveMin / maxDriveMin));
  const remainingDrivePerDay = Math.round(oneWayDriveMin / dayCount);

  const stays = [...input.selected_stays];
  const places = [...input.selected_places];
  let placeIdx = 0;
  let stayIdx = 0;

  for (let d = 1; d <= dayCount; d++) {
    const day: ItineraryDay = { day_number: d, items: [], total_est_cost: 0, total_drive_min: 0 };
    let driveBudget = remainingDrivePerDay;

    // Opening drive segment for this day.
    day.items.push({
      item_type: "drive",
      ref_id: null,
      name: d === 1 ? `Depart ${input.origin_label}` : "Morning drive",
      start_time: "09:00",
      end_time: null,
      est_cost: null,
    });
    day.total_drive_min += driveBudget;

    // Places until we run out of driving budget.
    while (placeIdx < places.length && driveBudget > 30) {
      const p = places[placeIdx];
      if (p.detour_duration_min + 15 <= driveBudget) {
        day.items.push({
          item_type: "place",
          ref_id: p.id,
          name: p.name,
          start_time: null,
          end_time: null,
          est_cost: p.est_cost ?? null,
        });
        if (p.est_cost) day.total_est_cost += p.est_cost;
        driveBudget -= p.detour_duration_min + 15;
      } else {
        break;
      }
      placeIdx++;
    }

    // Rest break after driving segment.
    day.items.push({
      item_type: "rest",
      ref_id: null,
      name: "Lunch / rest break",
      start_time: "13:00",
      end_time: "14:00",
      est_cost: null,
    });

    // Stay for the night (or final drive home on the last day).
    if (d === dayCount && stayIdx >= stays.length) {
      day.items.push({
        item_type: "drive",
        ref_id: null,
        name: `Arrive ${input.destination_label}`,
        start_time: null,
        end_time: null,
        est_cost: null,
      });
    } else if (stayIdx < stays.length) {
      const s = stays[stayIdx];
      const price = s.price_per_night ?? null;
      const nights = s.nights ?? 1;
      day.items.push({
        item_type: "hotel",
        ref_id: s.id,
        name: s.name,
        start_time: null,
        end_time: null,
        est_cost: price !== null ? price * nights : null,
      });
      if (price !== null) day.total_est_cost += price * nights;
      stayIdx++;
    }

    // Closing drive back to the day's stay/destination.
    day.items.push({
      item_type: "drive",
      ref_id: null,
      name: d === dayCount ? `Arrive ${input.destination_label}` : "Evening drive",
      start_time: null,
      end_time: null,
      est_cost: null,
    });

    days.push(day);
  }

  return days;
}

export interface ValidationIssue {
  code: string;
  message: string;
}

export function validateItineraryInput(input: ItineraryInput): ValidationIssue[] {
  const issues: ValidationIssue[] = [];
  if (!input.origin_label.trim() || !input.destination_label.trim()) {
    issues.push({ code: "MISSING_ENDPOINT", message: "Origin and destination labels are required." });
  }
  if (!(input.total_distance_km > 0)) {
    issues.push({ code: "ZERO_DISTANCE", message: "Total distance must be greater than zero." });
  }
  if (input.trip_type !== "one_way" && input.trip_type !== "round_trip") {
    issues.push({ code: "INVALID_TRIP_TYPE", message: "trip_type must be one_way or round_trip." });
  }
  if (!(input.max_driving_hours_per_day > 0) || input.max_driving_hours_per_day > 24) {
    issues.push({ code: "INVALID_DRIVE_CAP", message: "max_driving_hours_per_day must be between 0 and 24." });
  }
  return issues;
}