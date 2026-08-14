# BUILD_STATUS.md

Generated: 2026-08-14. This document is deliberately honest about scope — per the
project's own rule: "do not fake unavailable functionality."

## What's implemented (real, reviewed code)

| Area | Status |
|---|---|
| Firebase config: `firebase_options.dart` has real values for project `route2go-da5c3` (Android + iOS `com.route2go.route2go`); `google-services.json` present | Done |
| Google Sign-In (real OAuth): `google_sign_in` wired in `AuthRepository.signInWithGoogle()`; SHA-1 debug fingerprint registered in the Firebase console; verified live (account picker + 2-Step completed by user) | Done |
| Supabase linked to correct project `ginurkwywgqpcvzpfaop`; all 6 migrations pushed; all 18 Edge Functions deployed | Done |
| `route-nav` verify_jwt fixed to `false` (Supabase gateway was rejecting Firebase tokens) | Done |
| Secrets set: `FIREBASE_PROJECT_ID`, `ROUTING_PROVIDER_BASE_URL` (OSRM), `GEOCODING_PROVIDER_KEY=nominatim`, `USE_LIVE_FUEL_PRICES=true`, `USE_LIVE_TOLL_DATA=true` | Done |
| Live providers verified: OSRM routing (18.1 km SF→Oakland route), Nominatim geocoding (forward + reverse), fuel/toll flags on | Done |
| Map tiles verified rendering on emulator (OSM; real cause of blank map was emulator DNS — fixed with `-dns-server 8.8.8.8`) | Done |
| `flutter analyze` clean; `flutter test` green (**63 tests**: original 18 + auth/back-nav/router suites + 2 new critical-path E2E tests) | Done |
| Critical-path E2E integration test (`apps/mobile/test/critical_path_integration_test.dart`): calculate → compare (selectRoute) → places → stays → itinerary → save via real repositories + fake ApiClient, 2 tests | Done |
| `dart format` — repo was never format-clean (106 files); formatted so CI's `--set-exit-if-changed` gate passes; fixed 2 latent `curly_braces` lints the formatter surfaced | Done |
| Deno: `deno check` clean across all 18 functions + shared modules; **16 unit tests** pass (10 itinerary scheduler + 6 new fuel-cost engine) | Done |
| Database CI validated locally: `supabase start` → `db reset` (6 migrations apply) → pgTAP RLS suite **10/10** pass | Done |
| CI workflows (`mobile_ci`, `functions_ci`, `database_ci`, `release`) — fixed gaps (functions_ci now typechecks `route-nav` + tests fuel engine); each validated locally; not yet executed in GitHub Actions | Written, locally validated |
| iOS ATT runtime prompt: `TrackingPermissionService` requests tracking authorization at first launch and disables analytics unless authorized (no-op on Android; conservative disabled-on-failure) | Done |
| Android release signing: `build.gradle.kts` reads `android/key.properties` when present, falls back to debug keystore otherwise; `key.properties.template` with keystore generation steps (gitignored) | Done |
| Legal docs: Privacy Policy + Terms of Service rewritten comprehensively (DPDP Act 2023, IT Act 2000 + Intermediary Rules, Consumer Protection Act 2019, BNS framing) with real contact details — **Together (Lakshmipathy and Team)**, route2go1@gmail.com, JP Nagar Kothanuru Dinne, Bengaluru 560076 | Done (draft, needs legal review) |
| Phase 2 EV/CNG cost paths: `computeFuelCost` extracted to `_shared/fuelCostEngine.ts` (pure, unit-tested); `trip-calculate` reads `phase2_ev`/`phase2_cng` flags live; EV cost = kWh × ₹/kWh, CNG cost = kg × ₹/kg; gated + honest (null/unavailable when off); live-verified flag off→unavailable, on→₹182.53 | Done |
| App EV/CNG wiring: `trip_repository` sends `ev_efficiency_kwh_per_km`/`cng_mileage_km_per_kg` instead of `mileage_kmpl`; `ev_price_per_kwh` passed through; plan screen labels adapt (kWh/km, km/kg, per-kWh) | Done |
| Supabase schema (29 tables), RLS, pgTAP RLS suite (`rls_trips.sql` + `rls_audit.sql`), 17+1 Edge Functions, Firebase token verification, itinerary scheduler | Done (from prior phase) |
| Flutter app surface: onboarding, home, plan trip, route results, budget tracker, places/stays/itinerary/confirm/live trip, vehicle garage, expenses (group-split shell), notifications+FCM, profile/settings/privacy/terms/help/delete-account, favorites/search, admin dashboard (server-gated RBAC) | Done |
| Phase-2 gates: `Phase2Gate` widget gated on `/feature-flags`; group-split, offline cache, weather are gated shells | Done (shells) |

## Tests run in this session

- `flutter analyze` → No issues found.
- `flutter test` → **63/63** pass.
- `deno check` on all 18 functions + shared modules → clean.
- `deno test` → itinerary scheduler **10/10**, fuel-cost engine **6/6**.
- Database CI (local): `supabase start` + `db reset` (6 migrations) + `supabase test db` → **10/10** (rls_trips 6 + rls_audit 4).
- Live provider smoke: route-nav real route (18.1 km / 20 min); geocode Nominatim returned "Bengaluru, ..."; trip-calculate auth + validation verified.
- Live EV gating: `phase2_ev` off → `fuel_cost: null` / `unavailable`; on → `fuel_cost: 182.53` / `calculated`; restored to off.

## Known gaps to close before this is production-safe

1. **Service-role key** was pasted into chat during setup (user kept the old
   key; **must rotate before go-live**). The key is only used server-side
   (Supabase injects `SUPABASE_SERVICE_ROLE_KEY` into Edge Functions) and is
   never in the app or committed.
2. **iOS `DEVELOPMENT_TEAM` not set** in the Xcode project — add the Apple Team
   ID before `flutter build ipa` (release blocker).
3. **Android release keystore** — `key.properties` does not exist yet; release
   builds fall back to debug signing (rejected by Play Console). Generate a
   keystore and fill `android/key.properties` (see template).
4. **Legal docs are comprehensive drafts** with real contact details; still need
   a qualified legal review before store submission.
5. **CI workflows not yet executed in GitHub Actions** — validated locally; run
   them once on a real push/PR to confirm the runner environment (deno version,
   Docker for database_ci).
6. **DB-backed tables empty** — `places`, `hotels`, `fuel_prices`, `stays` have
   no data (licensed feeds/API keys not in repo); DB-backed functions return
   honest empty/unavailable results via ConfidenceBadge until feeds are wired.
7. **Phase 2 bodies** (group split, offline cache, weather) remain gated shells
   behind `phase2_*` flags; EV/CNG cost paths are now implemented.
8. **Physical-device testing** of the full Live Trip flow (background location)
   still recommended; currently verified on emulator.
9. **Google 2-Step** — real-device sign-in needs the user's phone approval
   (completed on emulator).

## Required external credentials (cannot be created for you)

- Firebase project (done: route2go-da5c3, Auth providers enabled, SHA-1 added)
- Supabase project (done: ginurkwywgqpcvzpfaop, linked + deployed)
- Apple Developer account + signing certificate + **Team ID** (for iOS release)
- Google Play Console account + **release keystore** (for Android release)
- Hotel/affiliate partner account(s) for the Stays flow (optional for launch)

## Realistic next steps for "go live"

1. Rotate the Supabase service-role key before publishing.
2. Execute the CI workflows once in GitHub Actions and fix anything that
   surfaces on the runner.
3. Create the Android release keystore + `key.properties`; add the iOS
   `DEVELOPMENT_TEAM`; build and sign release artifacts.
4. Have the legal drafts reviewed and approved; fill the "Last updated" dates.
5. Capture store screenshots and fill Play/App Store metadata (checklist:
   `docs/STORE_COMPLIANCE.md`).
6. Test the full Live Trip flow on a physical device.