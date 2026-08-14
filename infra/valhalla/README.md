# Self-hosted Valhalla

Route2Go routes with [Valhalla](https://github.com/valhalla/valhalla). For
production you run your own instance and point the edge functions at it; the
public demo endpoints (`valhalla.openstreetmap.de`, `valhalla1.openstreetmap.de`)
are dev/test only, rate-limited and unsupported.

## Quick start

```bash
cd infra/valhalla
export OSM_EXTRACT_URL=https://download.geofabrik.de/asia/india-latest.osm.pbf
docker compose up -d --build
```

Smoke test:

```bash
curl http://localhost:8002/status          # health: {"version":"3.x", ...}
curl http://localhost:8002/route \
  -H 'Content-Type: application/json' \
  -d '{"locations":[{"lat":12.9716,"lon":77.5946},{"lat":12.3052,"lon":76.6552}],"costing":"auto"}'
```

Then wire Route2Go:

```bash
supabase secrets set VALHALLA_BASE_URL=http://<host>:8002
```

`getRoutingProvider()` prefers `VALHALLA_BASE_URL` and falls back to the legacy
`ROUTING_PROVIDER_BASE_URL`; with neither set it uses the deterministic mock
(labelled `mock-dev-fixture`) — fine for tests/CI, never for production traffic.

## Deployment model

The compose file gives you a **reproducible, persistent** instance:

- `valhalla-data` volume holds the extract, admin DB, tiles and config — a
  container replacement keeps all built data.
- The entrypoint builds admin db + tiles + tile extract **once** (marker
  skipped on restart), so restarts are fast.
- A **healthcheck** polls `GET /status`; `restart: unless-stopped` brings a
  crashed container back.
- `deploy.resources` sets conservative memory/CPU limits and reservations —
  tune them to your extract, not the other way round.
- Logs are capped (`json-file`, 10 MB x 3) so a busy instance doesn't fill
  the disk.

## Region options and realistic infrastructure

Valhalla itself is free software; the **server is not free**. Pick the smallest
extract that covers your market and size the host honestly. These are
orders of magnitude (verify on your own hardware before promising capacity):

| Option | Extract (Geofabrik) | OSM PBF size | RAM (build) | RAM (serve) | Disk (tiles) | Suitability |
|---|---|---|---|---|---|---|
| **A. India-only** | `asia/india-latest.osm.pbf` | ~700 MB | 8-12 GB | 2-4 GB | 10-30 GB | Good for an India-first launch; fastest to build/update |
| **B. Regional** | e.g. `europe/great-britain-latest.osm.pbf` | ~1 GB | 12-16 GB | 4-8 GB | 20-60 GB | Multi-country corridor (e.g. Western Europe, US states) |
| **C. Larger / worldwide** | `planet-latest.osm.pbf` (or continent extracts) | 80+ GB | 128+ GB | 32-64 GB | 400 GB-1 TB+ | Multi-region worldwide production - serious box, staging, monitoring; multi-hour/day tile builds |

Never default to the planet. For a typical early production launch, **Option A
(India) or a tight regional extract** is the right starting point; you can
later switch to a wider extract (see Update process — it is a rebuild, not an
incremental patch).

**Capacity reality check:** one modest VM cannot serve an unlimited number of
concurrent drivers. Rough planning figure: a single instance handles on the
order of a few requests/second of routing. If you need more, scale by adding
instances behind a load balancer (each serving the same tile set) rather than
by over-provisioning one box. The app keeps routing traffic low by design
(see `apps/mobile/lib/core/navigation/reroute_policy.dart`: 20 s cooldown,
in-flight dedupe, exponential backoff).

## Operational notes

- **Updates.** Valhalla does not do incremental OSM updates; to refresh tiles
  you re-build from a fresh extract:
  1. `docker compose down`
  2. `docker volume rm infra-valhalla_valhalla-data` (or delete the
     `.tiles-built` marker inside `/data` and replace the PBF)
  3. `docker compose up -d --build` with the updated `OSM_EXTRACT_URL`
- **Tuning.** `VALHALLA_CONCURRENCY` parallelises the tile build (default 1).
  Raise it during the initial build on a multi-core host, lower it at runtime.
  `VALHALLA_MEM_LIMIT` / `VALHALLA_CPU_LIMIT` override the resource limits.
- **Auth.** If reachable over the public internet, front it with a reverse
  proxy (TLS + IP allow-list). The edge functions send an optional Bearer
  token from `ROUTING_PROVIDER_KEY`; add a middleware that checks it.
- **Backups.** `valhalla-data` is rebuildable from the extract — back up the
  volume only if you want to avoid a rebuild after host loss.
- **Monitoring.** The `/status` healthcheck is a starting point; also watch
  response latency on `/route` and 5xx counts (the edge function already maps
  those to a clean `502 ROUTE_PROVIDER_UNAVAILABLE`).