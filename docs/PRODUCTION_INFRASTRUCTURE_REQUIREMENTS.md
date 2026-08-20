# Production Infrastructure Requirements

## REQUIRED FOR LAUNCH

To support a live launch targeting 50,000 registered users with peaks of 500-1000 concurrent active users, the current Free Tier infrastructure must be upgraded.

### 1. Database & Edge Compute (Supabase)
*   **Plan**: Supabase Pro Tier (Minimum).
*   **Compute Target**: Dedicated IPv4 Add-on (to avoid shared NAT rate limits) and Custom Compute size (Small/Medium) for the Database.
*   **Edge Functions**: Pro Tier removes the strict 10s CPU-starvation limits and increases connection pools.

### 2. Routing Engine (Valhalla)
*   **Plan**: Dedicated Managed Provider (e.g., Stadia Maps, Mapbox) OR self-hosted Valhalla on AWS EC2/GCP Compute (min. 4 vCPU, 16GB RAM) to process complex trip matrices.
*   **Current State**: Relying on public endpoints violates TOS and guarantees rate-limiting under load.

### 3. Map Tile Provider
*   **Plan**: Commercial tile license (e.g., Carto commercial, Mapbox, or Stadia).
*   **Current State**: Must be configured via `MAP_TILE_URL_TEMPLATE` in production build.

---

## OPTIONAL FUTURE SCALE (1M+ Users)

*   **Read Replicas**: Deploy read-replicas for `trips` and `places` in geographically diverse regions.
*   **CDN / Redis**: Move Edge Function TTL caching to a distributed Redis cluster (e.g., Upstash) rather than relying on localized Deno memory which fragments across Edge nodes.
*   **Load Balancing**: Multi-node Valhalla deployment behind an application load balancer.
