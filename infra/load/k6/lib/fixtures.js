// Route2Go k6 Load-Test Fixtures Library
//
// Shared realistic test data for all load-test scenarios.
// Every route, user body, and fixture here represents a real-world Indian
// road trip that Valhalla can actually route.

export const ROUTES = [
  {
    name: 'BLR->MYS',
    origin: { label: 'Bengaluru', lat: 12.9716, lng: 77.5946 },
    destination: { label: 'Mysuru', lat: 12.2958, lng: 76.6394 },
  },
  {
    name: 'HYD->BLR',
    origin: { label: 'Hyderabad', lat: 17.3850, lng: 78.4867 },
    destination: { label: 'Bengaluru', lat: 12.9716, lng: 77.5946 },
  },
  {
    name: 'BOM->PNQ',
    origin: { label: 'Mumbai', lat: 19.0760, lng: 72.8777 },
    destination: { label: 'Pune', lat: 18.5204, lng: 73.8567 },
  },
  {
    name: 'MAA->BLR',
    origin: { label: 'Chennai', lat: 13.0827, lng: 80.2707 },
    destination: { label: 'Bengaluru', lat: 12.9716, lng: 77.5946 },
  },
  {
    name: 'BLR->MAA_via_VLR',
    origin: { label: 'Bengaluru', lat: 12.9716, lng: 77.5946 },
    destination: { label: 'Chennai', lat: 13.0827, lng: 80.2707 },
    waypoints: [{ label: 'Vellore', lat: 12.9165, lng: 79.1325 }],
  },
  {
    name: 'DEL->AGR',
    origin: { label: 'Delhi', lat: 28.6139, lng: 77.2090 },
    destination: { label: 'Agra', lat: 27.1767, lng: 78.0081 },
  },
  {
    name: 'PNQ->GOA',
    origin: { label: 'Pune', lat: 18.5204, lng: 73.8567 },
    destination: { label: 'Panaji', lat: 15.4909, lng: 73.8278 },
  },
];

export const VEHICLES = [
  { fuel_type: 'petrol', mileage_kmpl: 15, label: 'Maruti Swift' },
  { fuel_type: 'diesel', mileage_kmpl: 20, label: 'Mahindra XUV500' },
  { fuel_type: 'ev', ev_battery_kwh: 40.5, ev_efficiency_kwh_per_km: 0.16, label: 'Tata Nexon EV' },
  { fuel_type: 'cng', cng_mileage_km_per_kg: 25, label: 'Maruti Dzire CNG' },
];

export const SEARCH_TERMS = [
  'coffee', 'petrol pump', 'hospital', 'restaurant', 'hotel',
  'Bengaluru', 'Mysuru', 'Goa', 'highway', 'toll',
];

export const NEARBY_REF = { lat: 12.9716, lng: 77.5946 }; // Bengaluru

export const ITINERARY_BODY = {
  trip: {
    origin_label: 'Bengaluru',
    origin_lat: 12.9716,
    origin_lng: 77.5946,
    destination_label: 'Mysuru',
    destination_lat: 12.2958,
    destination_lng: 76.6394,
    trip_type: 'one_way',
    travellers: 2,
  },
  selected_places: [
    { id: 'place-1', name: 'Brindavan Gardens', detour_duration_min: 60, est_cost: 200 },
    { id: 'place-2', name: 'Ranganthittu Bird Sanctuary', detour_duration_min: 90, est_cost: 150 },
  ],
  selected_stays: [
    { id: 'stay-1', name: 'Royal Orchid Brindavan Garden', price_per_night: 3500, nights: 1 },
  ],
  budget_total: 10000,
  max_driving_hours_per_day: 6,
};

export function randomRoute() {
  return ROUTES[Math.floor(Math.random() * ROUTES.length)];
}

export function randomVehicle() {
  return VEHICLES[Math.floor(Math.random() * VEHICLES.length)];
}

export function randomSearchTerm() {
  return SEARCH_TERMS[Math.floor(Math.random() * SEARCH_TERMS.length)];
}

export function buildCalculateBody(route, vehicle) {
  const r = route || randomRoute();
  const v = vehicle || randomVehicle();
  return {
    origin: r.origin,
    destination: r.destination,
    trip_type: 'one_way',
    vehicle: v,
    budget_total: 5000,
  };
}
