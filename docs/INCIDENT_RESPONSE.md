# Incident Response Plan

## Monitoring & Alerts
- **Crashlytics**: Fatal and non-fatal errors in the Flutter client.
- **Supabase Dashboard**: Database CPU, Memory, and Edge Function invocation errors.
- **Firebase Performance Monitoring**: Network request latency and success rates.

## Escalation Matrix
1. **Severity 1 (App Down / Data Loss / Auth Broken)**
   - Acknowledge within 15 minutes.
   - Immediately check Supabase status page and Edge Function logs.
   - Initiate Database PITR restore if data loss is confirmed.
2. **Severity 2 (Core Feature Broken - e.g. Routing Fails)**
   - Acknowledge within 1 hour.
   - Validate Valhalla provider status.
   - Hot-swap `VALHALLA_BASE_URL` in Supabase to a fallback provider if primary is down.
3. **Severity 3 (Non-critical Bug / UI Glitch)**
   - Triaged for the next sprint.

## Communication
- Post updates to the status page (if available).
- For critical Auth issues, send a Firebase Cloud Messaging (FCM) broadcast to affected users.
