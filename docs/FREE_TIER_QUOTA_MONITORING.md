# Free-Tier Quota Monitoring Guide

To ensure Route2Go operates safely within its ₹0/month constraints, you must monitor the following metrics across provider dashboards.

## 1. Supabase Dashboard
Monitor weekly at `https://supabase.com/dashboard/project/_/settings/billing`
*   **Database Size**: Warning threshold: 400 MB (Limit: 500 MB).
    *   *Action*: Truncate old unused itineraries or orphan POI caches.
*   **Edge Function Invocations**: Warning threshold: 400,000 (Limit: 500,000/mo).
*   **Egress**: Warning threshold: 4 GB (Limit: 5 GB/mo).

## 2. Firebase Console
Monitor at `https://console.firebase.google.com/`
*   **Authentication Usage**: Verify daily active users (DAU) against Spark plan limits.
*   **Crashlytics Non-Fatals**: Set up alerts for surges in HTTP 429 (Rate Limit) errors originating from Edge Functions. This indicates public API starvation.

## 3. Graceful Degradation Monitoring
Our Edge Functions (`geocodingProvider.ts`, `poiProvider.ts`) are built to fail-closed safely.
*   If Overpass rate-limits our Edge Functions, the client will receive an empty POI list, but the map and routing will remain functional.
*   If Valhalla fails, a controlled error banner is displayed.
*   **Action**: If user reports indicate frequent "Routing Unavailable" or empty searches, the concurrent limit of 15 VUs has been breached.
