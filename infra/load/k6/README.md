# Route2Go k6 load-test harness

Runs against the **owned** Valhalla cluster and the Supabase Edge Functions
(`ginurkwywgqpcvzpfaop` by default). Never point these at the public Valhalla
demo or the mobile app; they isolate backend capacity only.

## Prerequisites

- k6 installed: `brew install k6` (or k6 CLI from grafana.com).
- Owned Valhalla cluster up (see `infra/valhalla/docker-compose.loadtest.yml`,
  LB base URL `http://<host>:8302`), and `VALHALLA_BASE_URL` set on the
  Supabase project so the Edge Functions route to it.
- Environment variables (never hard-code secrets into the scripts):

  ```bash
  export K6_SUPABASE_URL="https://<project>.supabase.co"
  export K6_SUPABASE_ANON_KEY="<anon key>"
  ```

## Scenarios

| File | Endpoint | Profile |
|---|---|---|
| `scenarios/search.js` | GET `/search` (50% plain `q`, 50% nearby with lat/lng) | search |
| `scenarios/calculate.js` | POST `/trip-calculate` BLR→Mysuru (the real 148.4 km route) | calculate |
| `scenarios/route.js` | POST `/route-nav` fixed route set (incl. one via-waypoint case) | route |
| `scenarios/geocode.js` | GET `/geocode` forward + reverse; asserts 429s stay graceful | geocode |
| `scenarios/mix.js` | Combined: search 90% / route 7% / calculate 3% (~10% of sessions route) | mix |

Fixed (non-personal) route set: Bengaluru→Mysuru, Hyderabad→Bengaluru,
Mumbai→Pune, Chennai→Bengaluru, Bengaluru→Chennai via Vellore. Synthetic search
terms: Bengaluru, Mysuru, coffee, restaurants, hospitals, petrol, hotels, parks.

## Running

### Stage A — baseline (catches basic problems first)

```bash
k6 run --vus 10 --duration 1m scenarios/search.js
k6 run K6_TARGET_VUS=100 K6_PROFILE=baseline scenarios/search.js
K6_TARGET_VUS=100 K6_PROFILE=baseline k6 run scenarios/calculate.js
K6_TARGET_VUS=100 K6_PROFILE=baseline k6 run scenarios/route.js
K6_TARGET_VUS=100 K6_PROFILE=baseline k6 run scenarios/mix.js
```

`K6_PROFILE=baseline` stages 10 → 25 → 50 → 100 VUs (1 min each), 3 min hold,
1 min drain.

### Stage B — plan ramp (plan table in `LOAD_TEST_PLAN.md`)

Default (`K6_PROFILE=plan`): ramp 0 → min(1000, target) over 5 min, soak
10 min, spike to target over 2 min, hold 5 min, drain 2 min.

```bash
K6_TARGET_VUS=1000 k6 run scenarios/mix.js          # soak target
K6_TARGET_VUS=3000 k6 run scenarios/mix.js          # full 3K run
```

Output every run: `k6 run --out csv=results/<date>-<scenario>.csv ...`

## Thresholds (fixed by LOAD_TEST_PLAN.md acceptance criteria)

| Metric | Threshold |
|---|---|
| `http_req_failed` (all scripts) | < 0.5% |
| search p50 / p95 / p99 | < 400 ms / < 600 ms / < 800 ms |
| calculate + route p50 / p95 / p99 | < 1 s / < 2 s / < 4 s |
| geocode 5xx | < 0.5% (429s are expected and counted as graceful) |

The "no p99 cliff ≥ 2× p95" check is a post-hoc comparison from the results
CSV, since k6 thresholds cannot compare two percentiles.

## Failure drill (node-kill)

Mid-run (during the spike hold), kill one replica and watch recovery:

```bash
docker kill route2go-valhalla-2
# observe: LB stops routing to node 2, error spike, recovery time, node-1/3 saturation
docker start route2go-valhalla-2
```

Assert per LOAD_TEST_PLAN: bounded retry + 502-on-outage from the edge
functions; no client hang past the 10 s abort.

## Reading results

- Latency p50/p95/p99 per scenario from the run summary and CSV.
- `http_req_failed`/429 counts: split expected 429s (rate-limiter) from real
  failures.
- Valhalla per-node CPU/RAM/restarts: `docker stats`
  `route2go-valhalla-{1,2,3}` during the run.
- Supabase: Edge Function invocations, execution duration, 5xx, cold starts
  from the Supabase dashboard.

A green run updates `BUILD_STATUS.md` only if all acceptance criteria in
`LOAD_TEST_PLAN.md` hold and the numbers are attached.