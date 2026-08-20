# Load Failure Root Cause Analysis

## Incident Summary
During the Phase 6 Load Testing execution, K6 virtual user (VU) volumes between 50 and 100 caused cascading timeouts (approaching 10 seconds) specifically isolated to Edge Functions requiring external provider integration (e.g., Valhalla, Overpass).

## Root Cause Metrics
*   **Endpoint**: `/trip-calculate` and `/places-near-route`
*   **Request Volume**: 50 - 100 requests / sec
*   **Latency p50**: 4.5 seconds
*   **Latency p95**: 9.2 seconds
*   **Latency p99**: 10.0+ seconds (Timeout)
*   **Error Rate**: 42% (at 100 VUs)
*   **Timeout Rate**: 38%
*   **Database Utilization**: ~5% CPU (Negligible impact. Database queries remained sub-10ms).
*   **Edge Function Utilization**: **100% CPU Saturation**. Free Tier Edge Functions are limited by shared-vCPU allocations (approx. 0.5 vCPU burst).
*   **External Provider Latency**: Upstream Valhalla and Overpass nodes began rate-limiting outbound connections from the shared Supabase NAT IP.

## Diagnosis
The 10-second timeout is a strict maximum execution limit imposed by the Supabase Free Tier for Edge Functions. When 50 VUs concurrently request a route, the shared CPU starves, slowing down the Node/Deno event loop. Concurrently, public external APIs rate-limit the aggressive burst. 

## Architectural Mitigations Implemented
1.  **Flutter Debouncing**: Geocoding and Search are strictly debounced by 300-350ms on the client.
2.  **In-Memory Edge TTL Caching**: Identical route requests and place searches (common in dense urban areas) are served from memory for 5 minutes, bypassing the external API.
3.  **Horizontal Scale Requirement**: The Free Tier limitation is unavoidable. Pro Tier or custom infrastructure is required to lift the CPU ceiling and execute >10 parallel requests rapidly.
