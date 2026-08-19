import http from 'k6/http';
import { check, sleep } from 'k6';
import { BASE, headers, SEARCH_TERMS, NEARBY_REF, buildStages, target, profile } from '../lib/config.js';

export const options = {
  scenarios: {
    search: {
      executor: 'ramping-vus',
      exec: 'search',
      startVUs: 0,
      stages: buildStages(target(), profile()),
      gracefulRampDown: '30s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.005'],
    'http_req_duration{scenario:search}': ['p(50)<400', 'p(95)<600', 'p(99)<800'],
  },
};

export function search() {
  const q = SEARCH_TERMS[Math.floor(Math.random() * SEARCH_TERMS.length)];
  const nearby = Math.random() < 0.5;
  const path = nearby
    ? `/search?q=${encodeURIComponent(q)}&lat=${NEARBY_REF.lat}&lng=${NEARBY_REF.lng}`
    : `/search?q=${encodeURIComponent(q)}`;
  const res = http.get(`${BASE}${path}`, { headers: headers() });
  check(res, { 'status is 2xx': (r) => r.status >= 200 && r.status < 300 });
  sleep(0.5);
}