# Free-Tier Infrastructure Capacity Limits

Route2Go is deployed on a strict ₹0/month architecture. This document defines the exact boundaries between "Registered Users" and "Concurrent Users" across the independent free tiers utilized in our stack.

## 1. Supabase Free Tier
*   **Database Size**: 500 MB (Supports approx. 50,000 registered user profiles and their trip metadata, assuming aggressive cleanup of old ephemeral trip plans).
*   **Monthly Active Users (MAU)**: 50,000.
*   **Edge Function Invocations**: 500,000 / month.
*   **Egress**: 5 GB / month.
*   **Concurrent Limit (Tested)**: 10–15 concurrent Virtual Users (VUs) executing heavy Edge Function tasks (e.g., routing) simultaneously. Beyond this, Edge Functions hit 10-second timeouts due to shared-vCPU throttling.

## 2. Firebase Spark Plan (Authentication & Push)
*   **Phone Authentication**: 10k/month (SMS routing constraints apply in some regions).
*   **Email/OAuth Sign-in**: Effectively unlimited MAU for our scale (50k limit applies mainly to specific Identity Platform upgrades).
*   **Cloud Messaging (FCM)**: Unlimited.

## 3. Public APIs (Valhalla / Overpass / Photon)
*   **Overpass (POI)**: Max 10,000 requests per day per IP. If concurrent requests from Supabase exceed ~2-3/sec, the Overpass public endpoint will aggressively rate limit (HTTP 429).
*   **Photon (Geocoding)**: "Fair use" policy. Must be debounced at the client (implemented: 300-350ms).
*   **Valhalla**: Public FOSS routing endpoints do not guarantee uptime.

## Capacity Conclusions
1.  **Registered Users**: 50,000 (Easily achievable within database limits).
2.  **Monthly Active Users**: ~10,000 (Bounded by the 500,000 Edge Function invocation limit, assuming ~50 interactions per user per month).
3.  **Concurrent Users**: **15 Maximum**. The backend will gracefully degrade and time out if 50 users attempt to plan a trip at the exact same millisecond.
