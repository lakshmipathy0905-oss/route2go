# Route2Go — Starter Repository

This is a **real, working starting codebase** for Route2Go — not a mockup and not a
document describing what to build. It implements one complete, working vertical
slice end-to-end (Plan Trip → Route Calculation → Fuel/Toll Cost → Budget Meter),
built the same way the full app should be built out: Flutter + Riverpod + go_router
on the client, Supabase Postgres + RLS + Edge Functions on the backend, Firebase for
identity.

See `BUILD_STATUS.md` for exactly what is implemented vs. what is scaffolded/pending,
and `CONTINUATION_PROMPT.md` for a ready-to-run prompt that hands the remaining
screens/features to Claude Code, following the same patterns already in this repo.

## What's actually working right now

- Supabase schema + RLS (`supabase/migrations/`) for the full MVP data model
- A real Firebase-token-verifying Edge Function (`supabase/functions/trip-calculate/`)
  implementing the exact fuel/toll/budget formulas from the spec
- Swappable provider interfaces (routing/fuel-price/toll) with deterministic mock
  adapters, so the app runs and returns real numbers before you have live provider keys
- A Flutter app shell: theme/design system, go_router navigation, Firebase Auth
  (Google/email/phone OTP), guest mode
- One complete working screen flow: Home → Plan Trip → Route Results → Budget Tracker,
  with loading/error/empty states and human-readable error messages throughout

## What still needs real credentials before it will run end-to-end

1. A Firebase project (Auth providers enabled: Google, Email/Password, Phone)
2. A Supabase project (Postgres + Edge Functions)
3. Optionally, a real routing provider (OSRM-compatible host, or Google/Mapbox) —
   the app works with the deterministic mock provider until you add one

## Setup — exact commands

```bash
# 1. Install Flutter dependencies
cd apps/mobile
flutter pub get

# 2. Wire up your real Firebase project (replaces lib/firebase_options.dart)
dart pub global activate flutterfire_cli
flutterfire configure

# 3. Set up Supabase (from repo root)
npm install -g supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push                      # applies supabase/migrations/*.sql
supabase functions deploy trip-calculate

# 4. Set required secrets on the deployed function
supabase secrets set FIREBASE_PROJECT_ID=your-project-id
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
# ROUTING_PROVIDER_BASE_URL / ROUTING_PROVIDER_KEY optional — mock adapter used if unset

# 5. Run the app, pointing it at your deployed function + Supabase project
cd apps/mobile
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=SUPABASE_FUNCTIONS_URL=https://YOUR_PROJECT_REF.supabase.co/functions/v1

# 6. Run tests
flutter test

# 7. Build
flutter build apk        # Android
flutter build ios        # iOS (macOS + Xcode required)
```

## One thing to fix before production (flagged intentionally, not hidden)

`supabase/functions/_shared/firebaseAuth.ts` verifies Firebase tokens using
Deno's `node:crypto` `X509Certificate` against Google's published certificates
(Google account keys + per-project signing keys). It is wired up correctly now —
but re-run `deno check` after any change and confirm the two live cert URLs you
allowlist still resolve before deploying.

## Repository layout

```
route2go/
  apps/mobile/          Flutter app (Android/iOS)
  supabase/
    migrations/          SQL schema + RLS policies
    functions/            Edge Functions (17 functions + shared provider adapters)
  docs/                  Privacy policy, terms, compliance checklist, spec reference
  .env*.example          Environment variable templates — never commit real secrets
```

## Full scope reference

The complete product/technical specification and original 46-screen build brief are
preserved in `docs/ORIGINAL_SPEC_REFERENCE.md`. `CONTINUATION_PROMPT.md` is what to
feed an agent (Claude Code) to build out the remaining screens/features using the
same architecture already established here.
