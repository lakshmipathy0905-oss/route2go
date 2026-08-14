# VALHALLA_SETUP.md

How Route2Go performs routing (after the OSRM → Valhalla migration).

## Architecture

```
Flutter app
  └─ trip-calculate / route-nav  (Supabase Edge Function)
       └─ _shared/providers/routingProvider.ts  getRoutingProvider()
            ├─ VALHALLA_BASE_URL set      → ValhallaRoutingProvider
            ├─ ROUTING_PROVIDER_BASE_URL  → ValhallaRoutingProvider (legacy alias)
            └─ neither set                → MockRoutingProvider (deterministic dev fixture)
```

- The edge functions call `getRouteAlternatives({ origin, destination, waypoints, roundTrip })`
  and never know which provider answered. **No function changes were needed** for the
  migration.
- `ValhallaRoutingProvider` makes **two** `/route` requests per calculation:
  1. main: `costing: auto`, `use_tolls: true`, `alternates: 3`
  2. toll-free: `use_tolls: false`, `alternates: 1` (non-fatal if it fails)
- Up to **5** route options are surfaced, labeled from real metrics:
  `recommended`, `no_toll`, `fastest`, `shortest`, `cheapest`. Identical
  duplicates are collapsed.
- Round trips are genuine out-and-backs (the origin is appended as the final
  breakpoint), not a mocked return leg.

## Configuration

Set on the Supabase functions (server-side only):

```bash
supabase secrets set VALHALLA_BASE_URL=http://your-host:8002
# legacy alias, only if VALHALLA_BASE_URL is unset:
supabase secrets set ROUTING_PROVIDER_BASE_URL=...
# optional bearer token your instance enforces:
supabase secrets set ROUTING_PROVIDER_KEY=...
```

Local dev uses `supabase/functions/.env` (gitignored) with the same names.

Dev/test only (rate-limited, unsupported, **not for production**):
`https://valhalla1.openstreetmap.de`. The `valhalla.openstreetmap.de` root
serves a demo app and returns 405 for `/route`.

## Self-hosting

See [`infra/valhalla/`](../infra/valhalla/) — a Dockerfile + compose that
downloads an OSM extract, builds tiles once, and serves the routing API on
`:8002`.

```bash
cd infra/valhalla
export OSM_EXTRACT_URL=https://download.geofabrik.de/asia/india-latest.osm.pbf
docker compose up -d --build
supabase secrets set VALHALLA_BASE_URL=http://<host>:8002
```

## Behaviour & error mapping

| Valhalla outcome | Adapter behaviour | Client sees |
|---|---|---|
| `200` with `trip` | parsed into `RouteOption`s | `200` routes |
| HTTP `400` with a no-route code (`error_code` 106/150/156/158/160/161/171–183, or string code) | returns no options | `404 NO_ROUTE_FOUND` |
| any other error / non-2xx | propagates | `502 ROUTING_UNAVAILABLE` |

### Failure policy (timeout + bounded retry)

`ValhallaRoutingProvider` applies a conservative HTTP policy so a slow or sick
Valhalla never hangs the edge function and is never hammered:

- **Timeout:** 10 s per attempt (`AbortSignal.timeout`).
- **Retry:** the tolls-allowed (main) request gets **at most one retry** after a
  500 ms gap; the toll-free request does not retry (it is non-fatal anyway).
- **What retries:** network failures, timeouts, and `5xx` only. **`4xx` input
  errors are never re-issued** — including Valhalla's no-route codes, which map
  straight to `404 NO_ROUTE_FOUND`.
- After the bounded retries a failure is surfaced to the caller as
  `502 ROUTE_PROVIDER_UNAVAILABLE` (retryable).

### Production never falls back to the mock

The mock provider activates **only** when neither `VALHALLA_BASE_URL` nor
`ROUTING_PROVIDER_BASE_URL` is configured (local dev / tests / CI). In
production, once a base URL is set, a Valhalla outage produces the `502` error
above — the app **never** silently swaps in mock/fake routes. This matches the
app's honesty rule: a clear routing error, never fabricated routes.

Key response-handling notes (verified against Valhalla 3.8.3):

- The trip shape may arrive as a GeoJSON object **or** an encoded polyline6
  string depending on server/version — the adapter decodes both.
- Maneuvers carry no explicit lat/lng on some versions; step coordinates are
  taken from the decoded shape at `begin_shape_index`.
- Instructions are used **verbatim** from Valhalla (never fabricated) so the
  turn-by-turn UI shows the provider's own wording.

## Tests

```bash
cd supabase/functions
deno test --allow-import _shared/providers/valhalla_test.ts   # 22 cases
deno test --allow-import _shared/providers/routingProvider_test.ts
```

Covers request building (one-way / waypoints / round trip), encoded-polyline
decoding, both shape forms, maneuver → step / segment mapping, route
labelling/dedupe/capping, no-route error codes, and worldwide coordinates.