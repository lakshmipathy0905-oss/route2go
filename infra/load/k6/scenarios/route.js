import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE, headers, ROUTES, buildStages, target, profile } from '../lib/config.js';

export const options = {
  scenarios: {
    route: {
      executor: 'ramping-vus',
      exec: 'route',
      startVUs: 0,
      stages: buildStages(target(), profile()),
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.005'],
    'http_req_duration{scenario:route}': ['p(50)<1000', 'p(95)<2000', 'p(99)<4000'],
  },
};

export function route() {
  const r = ROUTES[Math.floor(Math.random() * ROUTES.length)];
  const body = JSON.stringify({ origin: r.origin, destination: r.destination, waypoints: r.waypoints || [] });
  const res = http.post(`${BASE}/route-nav`, body, { headers: headers() });
  check(res, { 'status is 2xx': (r) => r.status >= 200 && r.status < 300 });
  sleep(1);
}