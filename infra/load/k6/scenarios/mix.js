import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE, headers, SEARCH_TERMS, NEARBY_REF, ROUTES, buildStages, scaleStages, target, profile } from '../lib/config.js';

const SHARES = { search: 0.9, route: 0.07, calculate: 0.03 };

export const options = {
  scenarios: {
    search: {
      executor: 'ramping-vus',
      exec: 'search',
      startVUs: 0,
      stages: scaleStages(buildStages(target(), profile()), SHARES.search),
      gracefulRampDown: '30s',
    },
    route: {
      executor: 'ramping-vus',
      exec: 'route',
      startVUs: 0,
      stages: scaleStages(buildStages(target(), profile()), SHARES.route),
      gracefulRampDown: '30s',
    },
    calculate: {
      executor: 'ramping-vus',
      exec: 'calculate',
      startVUs: 0,
      stages: scaleStages(buildStages(target(), profile()), SHARES.calculate),
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.005'],
    'http_req_duration{scenario:search}': ['p(50)<400', 'p(95)<600', 'p(99)<800'],
    'http_req_duration{scenario:route}': ['p(50)<1000', 'p(95)<2000', 'p(99)<4000'],
    'http_req_duration{scenario:calculate}': ['p(50)<1000', 'p(95)<2000', 'p(99)<4000'],
  },
};

export function search() {
  const q = SEARCH_TERMS[Math.floor(Math.random() * SEARCH_TERMS.length)];
  const nearby = Math.random() < 0.5;
  const path = nearby
    ? `/search?q=${encodeURIComponent(q)}&lat=${NEARBY_REF.lat}&lng=${NEARBY_REF.lng}`
    : `/search?q=${encodeURIComponent(q)}`;
  const res = http.get(`${BASE}${path}`, { headers: headers() });
  check(res, { 'search 2xx': (r) => r.status >= 200 && r.status < 300 });
  sleep(0.5);
}

export function route() {
  const r = ROUTES[Math.floor(Math.random() * ROUTES.length)];
  const res = http.post(
    `${BASE}/route-nav`,
    JSON.stringify({ origin: r.origin, destination: r.destination, waypoints: r.waypoints || [] }),
    { headers: headers() },
  );
  check(res, { 'route 2xx': (r) => r.status >= 200 && r.status < 300 });
  sleep(1);
}

export function calculate() {
  const r = ROUTES[0];
  const res = http.post(
    `${BASE}/trip-calculate`,
    JSON.stringify({ origin: r.origin, destination: r.destination }),
    { headers: headers() },
  );
  check(res, { 'calculate 2xx': (r) => r.status >= 200 && r.status < 300 });
  sleep(1);
}