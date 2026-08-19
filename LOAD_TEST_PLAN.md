# LOAD_TEST_PLAN.md

How to actually answer "can Route2Go serve N concurrent users?" on owned
infrastructure. **No result is claimed until a run from this plan records it.**
The 3K-concurrency figure in the completion report is a planning target, not a
measurement.

## 1. What we are testing

- **Supabase Edge Functions** (Deno) — `/trip-calculate`, `/search`, `/geocode`,
  `/poi-search`, `/trip`, `/favorites`, `/feature-flags`, … on project
  `ginurkwywgqpcvzpfaop` (region `ap-northeast-2`).
- **Self-hosted Valhalla** — the routing workload (`infra/valhalla/`,
  container serves `:8002`). This is the highest-latency upstream and the most
  likely bottleneck.
- **AuthN path** — rate-limited public endpoints (`/search`, `/geocode`,
  `/poi-search`: 120/min/IP via `_shared/rateLimit.ts`) are exercised to confirm
  429s behave (with `Retry-After`) rather than degrading other users.

## 2. Non-goals (do not fake these)

- No traffic data; no real-time ETA; no Google APIs. None of this appears in
  the load model.
- Public Photon/Overpass/OSM-tile upstreams are **not** load targets — hammering
  them would get Route2Go banned. Their latency is mocked/bounded in the test
  model and the app already degrades when they fail.
- No claims about the Android/iOS client beyond the client targets in
  `docs/PERFORMANCE_TARGETS.md`.

## 3. Scenarios (k6, `infra/load/k6/`)

Baseline realistic mix; each virtual user (VU) performs the happy path:

1. `auth` (optional): sign in once per VU (Firebase → Supabase) to exercise the
   authed functions too.
2. `search`: GET `/search?q=<city>&lat=<lng>` — p50 target < 400 ms end-to-end.
3. `geocode`: GET `/geocode` (forward) + `poi-search` category query near the
   reference point — confirm the rate limiter returns 429 + `Retry-After`, and
   the client (via the 300 ms debounce) never triples traffic.
4. `calculate`: POST `/trip-calculate` BLR→Mysuru (the real 148.4 km route) —
   p95 target < 2 s.
4b. `route`: POST `/route-nav` (fixed set: BLR→Mysuru, HYD→BLR, BOM→Pune,
   MAA→BLR, BLR→MAA via Vellore) — p95 target < 2 s. `mix.js` splits sessions
   search 90% / route 7% / calculate 3%, so ~10% of sessions are actively
   routing.
5. `read` endpoints: GET `/trip`, `/favorites`, `/feature-flags` — steady load.

Suggested ramp (document every run's parameters):

| Stage | VUs | Duration | Notes |
|---|---|---|---|
| Ramp | 0 → 1K | 5 min | cold-start watch |
| Soak | 1K | 10 min | p50/p95/p99, error rate |
| Spike | 1K → 3K | 2 min | sustained target |
| Spike hold | 3K | 5 min | acceptance window |
| Recovery | 3K → 0 | 2 min | drains cleanly, no 5xx tail |

Acceptance criteria (must all hold):

- Error rate (non-4xx client, non-expected-429) **< 0.5%** at every stage.
- `calculate` p95 **< 2 s**; `search` p50 **< 400 ms**; no p99 cliff ≥ 2× p95.
- No upstream ban/cooldown triggered on Photon/Overpass (mock them in the test
  model; monitor real calls stay at baseline).
- Edge-function isolates: no OOM/restart churn beyond platform norms.
- Valhalla CPU/memory stay within the container limits set in
  `infra/valhalla/docker-compose.yml` (documented as `VALHALLA_*` overrides).

## 4. Infrastructure under test

- **Valhalla horizontal scaling**: run 2–3 Valhalla replicas behind a load
  balancer (e.g. Caddy/Nginx with active healthcheck on `GET /status`). The
  routing provider in `_shared/providers/valhalla.ts` hits
  `VALHALLA_BASE_URL`, so a LB base URL is the single config change.
  Ready-made: `infra/valhalla/docker-compose.loadtest.yml` (3 replicas + Caddy
  LB on `:8302`; node health on `:8002`/`:8102`/`:8202`) with
  `infra/valhalla/Caddyfile.loadtest` (round-robin, `/status` healthcheck,
  10 s fail_duration).
- **Supabase**: plan an add-on (compute/memory) before the run; log the exact
  project tier in the results.
- **Failover drill**: `kill -9` one Valhalla replica mid-run — assert
  `ValhallaRoutingProvider`'s bounded retry + 502-on-outage path returns correct
  errors to clients (never hangs past the 10 s abort).

## 5. How to run

1. `cd infra/load/k6`; install k6 (`brew install k6` / k6 CLI).
2. Set env: `K6_SUPABASE_URL`, `K6_SUPABASE_ANON_KEY`, `K6_VALHALLA_URL` (the LB
   base URL).
3. `k6 run --vus <vus> --duration <d> scenarios/search.js` (and `route.js`,
   `calculate.js`, `mix.js` for the combined scenario; `geocode.js` to verify
   429 behavior).
4. Record output CSV (`--out csv=results/<date>-<scenario>.csv`).

## 6. Reporting (required fields)

| Field | Value |
|---|---|
| Date / commit | |
| Infra (Supabase tier, Valhalla replicas, LB) | |
| k6 scenario file + VU/duration matrix | |
| Latencies p50 / p95 / p99 per endpoint | |
| Error rate + 429 counts | |
| Valhalla CPU/RAM peak vs limits | |
| Node-kill recovery result | |
| Pass/fail vs acceptance criteria | |
| Anything that needed changing | |

Results belong in `infra/load/results/`; a **green run does not update
`BUILD_STATUS.md`** unless the criteria above all hold and the numbers are
attached.

## 7. What never gets claimed without a recorded run

- "Serves 3K concurrent users."
- Any p50/p95 number from this plan.
- "Production-ready under load."
