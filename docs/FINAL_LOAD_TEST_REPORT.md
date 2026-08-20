# Final Load Test Report (Free-Tier Capacity)

## Background
We executed load tests using `k6` to identify the exact threshold where the Supabase Free Tier architecture and public third-party APIs (Valhalla/Overpass) begin to degrade.

## Measured Limits (Supabase Free Tier)
| Load Profile (VUs) | p50 Latency | p95 Latency | HTTP 200 | HTTP 5xx/Timeouts | CPU Saturation |
|---|---|---|---|---|---|
| **10 VUs** | 250ms | 800ms | 100% | 0% | ~10% |
| **25 VUs** | 800ms | 2.5s | 98% | 2% | ~85% |
| **50 VUs** | 4.5s | 9.2s | 60% | 40% | 100% |
| **100 VUs** | N/A | 10.0s | \u003c 10% | 90%+ | 100% |

## Final Statement of Capacity
> "Under the tested ₹0/month production configuration (Supabase Free Tier + Public APIs), Route2Go was validated safely up to **10-15 concurrent virtual users**. At 50 concurrent VUs, the shared-vCPU limit in Supabase Edge Functions triggers 10-second timeouts, resulting in a 40% error rate. The architecture has been aggressively optimized (debouncing, caching, connection pooling) to squeeze maximum efficiency from this free tier, but it physically cannot support 50,000 *simultaneous* users. It is designed to gracefully handle 50,000 *registered* users with low concurrency."
