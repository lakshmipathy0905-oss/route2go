import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';
import { BASE, headers, NEARBY_REF, buildStages, target, profile } from '../lib/config.js';

const geo5xx = new Counter('geocode_5xx');

const FORWARD = ['Bengaluru', 'Mysuru', 'Chennai', 'Mumbai', 'Pune'];

export const options = {
  scenarios: {
    geocode: {
      executor: 'ramping-vus',
      exec: 'geocode',
      startVUs: 0,
      stages: buildStages(target(), profile()),
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    'rate[geocode_5xx]': ['rate<0.005'],
    'http_req_duration{scenario:geocode}': ['p(95)<1000'],
  },
};

export function geocode() {
  const reverse = Math.random() < 0.3;
  const path = reverse
    ? `/geocode?lat=${NEARBY_REF.lat}&lng=${NEARBY_REF.lng}`
    : `/geocode?q=${encodeURIComponent(FORWARD[Math.floor(Math.random() * FORWARD.length)])}`;
  const res = http.get(`${BASE}${path}`, { headers: headers() });
  if (res.status >= 500) geo5xx.add(1);
  check(res, { '200 or graceful 429': (r) => r.status === 200 || r.status === 429 });
  sleep(0.3);
}