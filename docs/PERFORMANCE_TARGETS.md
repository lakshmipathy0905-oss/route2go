# Performance Targets

> These are **targets to engineer toward**, not claims about the current build.
> Route2Go publishes no performance numbers anywhere in-app; any number that
> appears here must first be measured on the owned production infrastructure
> (Supabase project `ginurkwywgqpcvzpfaop`, self-hosted Valhalla) using the
> procedure in [`LOAD_TEST_PLAN.md`](../LOAD_TEST_PLAN.md).

## Client targets (measured on-device, debug-free build)

| Surface | Target | Definition |
|---|---|---|
| Map first frame | **< 1 s** | From tapping the Map tab to the first rendered map frame on a mid-range device (OnePlus CPH2375 / equivalent) on a warm cache. Includes tile layer setup but not the first tile's network latency. |
| Search | **p50 < 400 ms** | End-to-end: last keystroke → debounce (300 ms) → `/search` round-trip → result list rendered. Measured from a representative Indian city with the location reference set. |
| Route calculation | **p95 < 2 s** | `/trip-calculate` (Valhalla + cost engine) from request to the route-comparison screen for a typical inter-city trip. p95 is used because a single Valhalla attempt is bounded by a 10 s abort. |

How to measure: instrument with `Stopwatch`/`performance` traces on a release
build on the reference device; report p50/p95 over ≥ 30 samples; state the
device, network, and server region alongside every result.

## Server targets (load-tested, owned infra only)

See `LOAD_TEST_PLAN.md` for scenarios, thresholds and acceptance criteria.
Nothing here is considered met until a controlled run records it.

## Exclusions (honest, by design)

- **No live-traffic/ETA claims** — Route2Go has no traffic data feed.
- **No latency claims for public providers** (Photon, Overpass, OSM tiles) —
  these are shared, best-effort upstreams; the app degrades gracefully
  (`nearbyDegraded`, styled→OSM tile fallback).
- **The 3K-concurrent-users claim is unverified** — it is a capacity-planning
  target only, gated on the load test.
