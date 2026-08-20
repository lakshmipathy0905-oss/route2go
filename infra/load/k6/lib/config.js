const rawUrl = __ENV.K6_SUPABASE_URL;
const rawKey = __ENV.K6_SUPABASE_ANON_KEY;

export const SUPABASE_URL = rawUrl || '';
export const BASE = SUPABASE_URL ? `${SUPABASE_URL}/functions/v1` : '';

export const SEARCH_TERMS = ['Bengaluru', 'Mysuru', 'coffee', 'restaurants', 'hospitals', 'petrol', 'hotels', 'parks'];

export const NEARBY_REF = { lat: 12.9716, lng: 77.5946 };

export const ROUTES = [
  { name: 'BLR->MYS', origin: { label: 'Bengaluru', lat: 12.9716, lng: 77.5946 }, destination: { label: 'Mysuru', lat: 12.2958, lng: 76.6394 } },
  { name: 'HYD->BLR', origin: { label: 'Hyderabad', lat: 17.385, lng: 78.4867 }, destination: { label: 'Bengaluru', lat: 12.9716, lng: 77.5946 } },
  { name: 'BOM->PNQ', origin: { label: 'Mumbai', lat: 19.076, lng: 72.8777 }, destination: { label: 'Pune', lat: 18.5204, lng: 73.8567 } },
  { name: 'MAA->BLR', origin: { label: 'Chennai', lat: 13.0827, lng: 80.2707 }, destination: { label: 'Bengaluru', lat: 12.9716, lng: 77.5946 } },
  { name: 'BLR->MAA_via_VLR', origin: { label: 'Bengaluru', lat: 12.9716, lng: 77.5946 }, destination: { label: 'Chennai', lat: 13.0827, lng: 80.2707 }, waypoints: [{ label: 'Vellore', lat: 12.9165, lng: 79.1325 }] },
];

// Public (guest-accessible) endpoints: use the literal 'Bearer guest' token.
// The edge functions recognise this string and skip Firebase verification.
export function guestHeaders() {
  return {
    'apikey': rawKey || '',
    'Authorization': 'Bearer guest',
    'Content-Type': 'application/json',
  };
}

// Auth-required endpoints: use the Firebase ID token when available,
// otherwise fall back to anon key (which will correctly 401 in the test).
export function headers() {
  const firebaseToken = __ENV.K6_FIREBASE_TOKEN || '';
  return {
    'apikey': rawKey || '',
    'Authorization': firebaseToken ? `Bearer ${firebaseToken}` : `Bearer ${rawKey}`,
    'Content-Type': 'application/json',
  };
}

export function buildStages(totalVus, profile) {
  if (profile === 'baseline') {
    const steps = [10, 25, 50, 100].filter((v) => v <= totalVus);
    if (steps.length === 0) steps.push(totalVus);
    const stages = steps.map((stepTarget) => ({ target: stepTarget, duration: '1m' }));
    stages.push({ target: totalVus, duration: '3m' });
    stages.push({ target: 0, duration: '1m' });
    return stages;
  }
  const rampPeak = Math.min(1000, totalVus);
  const stages = [{ target: rampPeak, duration: '5m' }];
  if (totalVus <= 1000) {
    stages.push({ target: totalVus, duration: '10m' });
  } else {
    stages.push({ target: 1000, duration: '10m' });
    stages.push({ target: totalVus, duration: '2m' });
    stages.push({ target: totalVus, duration: '5m' });
  }
  stages.push({ target: 0, duration: '2m' });
  return stages;
}

export function scaleStages(stages, share) {
  return stages.map((s) => ({ duration: s.duration, target: Math.max(1, Math.round(s.target * share)) }));
}

export function target() {
  return Number(__ENV.K6_TARGET_VUS || 3000);
}

export function profile() {
  return __ENV.K6_PROFILE || 'plan';
}