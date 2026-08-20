// Route2Go k6 Comprehensive Load Test
//
// Covers all 8 production endpoints across 4 load levels.
// Run with:
//   K6_SUPABASE_URL=https://<ref>.supabase.co \
//   K6_SUPABASE_ANON_KEY=<anon_key> \
//   K6_TARGET_VUS=100 \
//   K6_PROFILE=baseline \
//   k6 run infra/load/k6/scenarios/full_suite.js
//
// K6_PROFILE options:
//   baseline  -> ramp 10->25->50->100 VUs, 1 min each, 3 min soak
//   plan      -> ramp to K6_TARGET_VUS over 5 min, 10 min soak (default)
//
// K6_TARGET_VUS: 10 | 50 | 100 | 500 | 1000 (default: 100)
//
// Thresholds reflect real SLOs; exceeding any threshold = failed test.

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';
import { randomItem } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';
import { BASE, headers, guestHeaders, buildStages, scaleStages, target, profile } from '../lib/config.js';
import {
  ROUTES, VEHICLES, SEARCH_TERMS, NEARBY_REF, ITINERARY_BODY,
  randomRoute, randomVehicle, randomSearchTerm, buildCalculateBody,
} from '../lib/fixtures.js';

// ── Custom metrics ──────────────────────────────────────────────────────────
const routeNavDuration   = new Trend('route_nav_duration_ms', true);
const calculateDuration  = new Trend('calculate_duration_ms', true);
const searchDuration     = new Trend('search_duration_ms', true);
const placesNearDuration = new Trend('places_near_duration_ms', true);
const staysNearDuration  = new Trend('stays_near_duration_ms', true);
const itineraryDuration  = new Trend('itinerary_duration_ms', true);
const tripDuration       = new Trend('trip_crud_duration_ms', true);
const favoritesDuration  = new Trend('favorites_duration_ms', true);

const rateLimitHits = new Counter('rate_limit_429_total');
const serverErrors  = new Counter('server_error_5xx_total');
const authFailures  = new Counter('auth_failure_total');

// ── Workload shares (must sum to 1.0) ────────────────────────────────────────
// Based on expected real-world usage distribution:
//   Search/geocode is the most frequent; trip-calculate & navigation are sparser.
const SHARES = {
  search:        0.30,
  routeNav:      0.20,
  calculate:     0.15,
  placesNear:    0.15,
  staysNear:     0.10,
  itinerary:     0.05,
  trip:          0.03,
  favorites:     0.02,
};

// ── k6 options ───────────────────────────────────────────────────────────────
const totalVus  = target();
const stageProfile = profile();
const baseStages = buildStages(totalVus, stageProfile);

export const options = {
  scenarios: {
    search: {
      executor: 'ramping-vus',
      exec: 'searchScenario',
      startVUs: 0,
      stages: scaleStages(baseStages, SHARES.search),
      gracefulRampDown: '30s',
    },
    routeNav: {
      executor: 'ramping-vus',
      exec: 'routeNavScenario',
      startVUs: 0,
      stages: scaleStages(baseStages, SHARES.routeNav),
      gracefulRampDown: '30s',
    },
    calculate: {
      executor: 'ramping-vus',
      exec: 'calculateScenario',
      startVUs: 0,
      stages: scaleStages(baseStages, SHARES.calculate),
      gracefulRampDown: '30s',
    },
    placesNear: {
      executor: 'ramping-vus',
      exec: 'placesNearScenario',
      startVUs: 0,
      stages: scaleStages(baseStages, SHARES.placesNear),
      gracefulRampDown: '30s',
    },
    staysNear: {
      executor: 'ramping-vus',
      exec: 'staysNearScenario',
      startVUs: 0,
      stages: scaleStages(baseStages, SHARES.staysNear),
      gracefulRampDown: '30s',
    },
    itinerary: {
      executor: 'ramping-vus',
      exec: 'itineraryScenario',
      startVUs: 0,
      stages: scaleStages(baseStages, SHARES.itinerary),
      gracefulRampDown: '30s',
    },
    trip: {
      executor: 'ramping-vus',
      exec: 'tripScenario',
      startVUs: 0,
      stages: scaleStages(baseStages, SHARES.trip),
      gracefulRampDown: '30s',
    },
    favorites: {
      executor: 'ramping-vus',
      exec: 'favoritesScenario',
      startVUs: 0,
      stages: scaleStages(baseStages, SHARES.favorites),
      gracefulRampDown: '30s',
    },
  },

  thresholds: {
    // Global error floor: any scenario failing > 0.5% is a blocker.
    http_req_failed: ['rate<0.005'],

    // Per-scenario SLO thresholds (p50/p95/p99):
    // Search: DB + geocoder + POI — fast because catalog data is indexed.
    'http_req_duration{scenario:search}':    ['p(50)<400', 'p(95)<800', 'p(99)<1500'],

    // Route nav: single Valhalla call, no DB writes.
    'http_req_duration{scenario:routeNav}':  ['p(50)<800', 'p(95)<2000', 'p(99)<4000'],

    // Calculate: Valhalla + fuel + toll + DB writes (most complex).
    'http_req_duration{scenario:calculate}': ['p(50)<1500', 'p(95)<3000', 'p(99)<6000'],

    // Catalog reads: indexed PostgREST queries + corridor math.
    'http_req_duration{scenario:placesNear}':['p(50)<400', 'p(95)<800', 'p(99)<1500'],
    'http_req_duration{scenario:staysNear}': ['p(50)<400', 'p(95)<800', 'p(99)<1500'],

    // Itinerary: pure CPU scheduling (no network after auth).
    'http_req_duration{scenario:itinerary}': ['p(50)<500', 'p(95)<1000', 'p(99)<2000'],

    // Trip CRUD: simple authenticated DB operations.
    'http_req_duration{scenario:trip}':      ['p(50)<400', 'p(95)<800', 'p(99)<1500'],
    'http_req_duration{scenario:favorites}': ['p(50)<400', 'p(95)<800', 'p(99)<1500'],

    // Custom metric SLOs (Trend metrics).
    route_nav_duration_ms:   ['p(95)<2000'],
    calculate_duration_ms:   ['p(95)<3000'],
    search_duration_ms:      ['p(95)<800'],
    places_near_duration_ms: ['p(95)<800'],
    stays_near_duration_ms:  ['p(95)<800'],
    itinerary_duration_ms:   ['p(95)<1000'],
    trip_crud_duration_ms:   ['p(95)<800'],
    favorites_duration_ms:   ['p(95)<800'],
  },
};

// ── Helpers ───────────────────────────────────────────────────────────────────
function trackResponse(res, trendMetric, scenarioLabel) {
  if (res.status === 429) rateLimitHits.add(1);
  if (res.status >= 500) serverErrors.add(1);
  if (res.status === 401 || res.status === 403) authFailures.add(1);
  trendMetric.add(res.timings.duration);
  check(res, {
    [`${scenarioLabel} 2xx`]: (r) => r.status >= 200 && r.status < 300,
    [`${scenarioLabel} not 5xx`]: (r) => r.status < 500,
    [`${scenarioLabel} response is JSON`]: (r) => {
      try { JSON.parse(r.body); return true; } catch { return false; }
    },
  });
}

// ── Scenario functions ────────────────────────────────────────────────────────

export function searchScenario() {
  const q = randomSearchTerm();
  const useNearby = Math.random() < 0.4;
  const path = useNearby
    ? `/search?q=${encodeURIComponent(q)}&lat=${NEARBY_REF.lat}&lng=${NEARBY_REF.lng}&limit=10`
    : `/search?q=${encodeURIComponent(q)}&limit=10`;
  const res = http.get(`${BASE}${path}`, { headers: guestHeaders(), timeout: '10s' });
  trackResponse(res, searchDuration, 'search');
  sleep(0.3 + Math.random() * 0.4);
}

export function routeNavScenario() {
  const r = randomRoute();
  const body = JSON.stringify({
    origin: r.origin,
    destination: r.destination,
    waypoints: r.waypoints || [],
  });
  const res = http.post(`${BASE}/route-nav`, body, { headers: headers(), timeout: '15s' });
  trackResponse(res, routeNavDuration, 'routeNav');
  sleep(0.8 + Math.random() * 0.5);
}

export function calculateScenario() {
  const r = randomRoute();
  const v = randomVehicle();
  const body = JSON.stringify(buildCalculateBody(r, v));
  const res = http.post(`${BASE}/trip-calculate`, body, { headers: headers(), timeout: '20s' });
  trackResponse(res, calculateDuration, 'calculate');
  sleep(1 + Math.random() * 0.5);
}

export function placesNearScenario() {
  const r = randomRoute();
  const url = `${BASE}/places-near-route?origin_lat=${r.origin.lat}&origin_lng=${r.origin.lng}` +
              `&dest_lat=${r.destination.lat}&dest_lng=${r.destination.lng}&radius_km=30`;
  const res = http.get(url, { headers: guestHeaders(), timeout: '10s' });
  trackResponse(res, placesNearDuration, 'placesNear');
  sleep(0.3 + Math.random() * 0.4);
}

export function staysNearScenario() {
  const r = randomRoute();
  const url = `${BASE}/stays-near-route?origin_lat=${r.origin.lat}&origin_lng=${r.origin.lng}` +
              `&dest_lat=${r.destination.lat}&dest_lng=${r.destination.lng}&max_distance_km=20`;
  const res = http.get(url, { headers: guestHeaders(), timeout: '10s' });
  trackResponse(res, staysNearDuration, 'staysNear');
  sleep(0.3 + Math.random() * 0.4);
}

export function itineraryScenario() {
  const body = JSON.stringify(ITINERARY_BODY);
  const res = http.post(`${BASE}/itinerary-generate`, body, { headers: headers(), timeout: '15s' });
  trackResponse(res, itineraryDuration, 'itinerary');
  sleep(0.5 + Math.random() * 0.5);
}

// Trip CRUD scenario: simulates the authenticated trip list flow.
// NOTE: Authenticated trip creation/rename/delete requires a real Firebase
// token. Without K6_FIREBASE_TOKEN set, this hits guest-accessible paths only
// (returns 401 for write operations; list is unauthenticated-rejected).
// To test the full CRUD flow, provide K6_FIREBASE_TOKEN=<valid_jwt>.
export function tripScenario() {
  const firebaseToken = __ENV.K6_FIREBASE_TOKEN;
  const authHeaders = firebaseToken
    ? { ...headers(), Authorization: `Bearer ${firebaseToken}` }
    : headers();

  // GET list (will 401 without token — counted as auth_failure, expected)
  const listRes = http.get(`${BASE}/trip`, { headers: authHeaders, timeout: '10s' });
  trackResponse(listRes, tripDuration, 'trip');
  sleep(0.5);
}

export function favoritesScenario() {
  const firebaseToken = __ENV.K6_FIREBASE_TOKEN;
  const authHeaders = firebaseToken
    ? { ...headers(), Authorization: `Bearer ${firebaseToken}` }
    : headers();

  const res = http.get(`${BASE}/favorites?kind=trip`, { headers: authHeaders, timeout: '10s' });
  trackResponse(res, favoritesDuration, 'favorites');
  sleep(0.3 + Math.random() * 0.3);
}
