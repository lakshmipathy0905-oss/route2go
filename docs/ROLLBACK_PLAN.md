# Route2Go Rollback Plan

## Mobile App Rollback
1. **Google Play Console (Android)**
   - Halt the current staged rollout.
   - Demote the current release.
   - Promote the previous known-good App Bundle from the release history.
2. **App Store Connect (iOS)**
   - Reject the current build if in review.
   - Expedite a new review for the previous build version incremented by 1 build number.

## Backend / Database Rollback
1. **Supabase Edge Functions**
   - Re-deploy the `supabase/functions` directory from the previous stable git commit.
2. **Database Migrations**
   - Execute `supabase migration down` or restore from the latest point-in-time recovery (PITR) backup available in the Supabase Dashboard if data corruption occurred.

## Third-Party Providers
1. **Valhalla / Map Tiles**
   - If a provider goes down, utilize Supabase Remote Config or Edge Function environment variables to hot-swap to the backup provider (e.g., fallback from Valhalla to OSRM) without requiring a mobile app update.
