# BUILD_STATUS.md

Generated: 2026-08-13. This document is deliberately honest about scope — per the
project's own rule: "do not fake unavailable functionality."

## What's implemented (real, reviewed code)

| Area | Status |
|---|---|
| Supabase schema: `0001_core_schema.sql` (29 tables, verified healthy: 418 lines, 29 CREATE TABLE, no duplicate lines) | Done |
| `0002_row_level_security.sql` — RLS on all user-owned tables (Firebase-identity-based) | Done |
| `0003_edge_function_support.sql` — `notification_prefs`, `affiliate_clicks`, `hotels` columns, `itinerary_items.name`, RLS for new tables | Done |
| `0004_enable_pgtap.sql` — pgTAP extension in `extensions` schema | Done |
| `0005_table_grants.sql` — anon/authenticated/service_role grants (mirrors production Supabase) | Done |
| `0006_rls_helper_security_definer.sql` — `current_app_user_id()`/`current_admin_role()` are SECURITY DEFINER (fixes RLS recursion under `authenticated`) | Done |
| pgTAP RLS suite (`supabase/tests/database/rls_trips.sql`): 6 assertions, all pass; verified NOT a false positive (fails 4/6 when policies are deliberately broken) | Done |
| 17 Edge Functions + shared modules, all `deno check` clean (Deno 2.9.5) | Done |
| Firebase token verification (`_shared/firebaseAuth.ts` via `node:crypto` `X509Certificate` — placeholder removed) | Done |
| Auth ordering: token validated before Supabase client creation; typed `AuthError` for missing/guest/garbage tokens | Done |
| `_shared/auth.ts` — `authRequest`/`requireUser`/`requireAdmin`/`auditLog`, guest mode | Done |
| Provider adapters (Mock + Nominatim geocoding) behind `_shared/providers/` | Done |
| Itinerary scheduler (`_shared/itineraryScheduler.ts`) with 10 passing tests | Done |
| Edge Functions: `geocode`, `vehicles`, `trip` (save/list/rename/duplicate/delete), `expenses`, `notifications` (incl. register_token), `profile`, `privacy`, `favorites`, `affiliate`, `support`, `search`, `feature-flags`, `places-near-route`, `stays-near-route`, `itinerary-generate`, `admin`, `trip-calculate` | Done |
| `supabase/config.toml` — all functions `verify_jwt = false` (self-authenticate vs Firebase, accept literal `guest` token) | Done |
| Flutter app: theme, go_router, Firebase Auth (Google/email/guest mode); phone-OTP still implemented at the repository level but **not exposed in the UI** (dropped from login for launch) | Done |
| Screens: Splash, Onboarding, Login, Home, Plan Trip, Route Results (comparison), Budget Tracker, Places, Place Detail, Stays, Itinerary, Confirm, Live Trip | Done, with loading/error/empty states |
| Vehicle garage + form (with mileage-range validation) | Done |
| Trip detail + expense tracker (group-split shell behind Phase2Gate) | Done |
| Notifications screen + prefs + FCM service (permission → token → register_token) | Done |
| Profile / settings / privacy / terms / help / delete-account screens | Done |
| Favorites + search screens | Done |
| Admin dashboard (`/admin` route group): stats, feature flags, audit log, support, affiliate, users — server-gated RBAC | Done |
| Admin role consistency: `admin_users.role` CHECK uses `super_admin`; EF + Flutter gate on `super_admin` (fixed from a never-valid `'super'`) | Done |
| Phase-2 gates: `Phase2Gate` widget gated on `/feature-flags`; wired weather + offline-cache shells | Done |
| Section 3: Android/iOS permission strings, ATT usage description, analytics opt-out enforced against Firebase SDK | Done |
| Tests: `flutter analyze` clean; `flutter test` green (18 tests: design tokens, vehicles, budget aggregation, Phase2Gate widget) | Done |
| CI/CD: `.github/workflows/` — `mobile_ci`, `functions_ci`, `database_ci`, `release` | Written (not yet executed in CI) |

## Tests run in this session

- `flutter analyze` → No issues found.
- `flutter test` → 18/18 pass.
- `deno check` on all functions + shared modules → clean.
- `_shared/itinerary_scheduler_test.ts` → 10/10 pass.
- Auth smoke: missing token → 401 `UNAUTHENTICATED`; guest on non-guest endpoint → `GUEST_NOT_ALLOWED`.
- `supabase db reset` → all 6 migrations apply cleanly.
- `supabase test db` → `rls_trips.sql` 6/6 pass. Sanity-checked: deliberately permissive
  trips SELECT/UPDATE policies make the suite fail 4/6, proving RLS enforcement is real.

### 2.15 Testing — RLS/integration (previously open gap, now closed)
- `supabase/tests/database/rls_trips.sql`: 6 pgTAP assertions covering
  cross-user select/update/delete isolation and the "no session var = zero
  visibility" case. Verified non-trivial via deliberate break/fix round-trip
  (permissive policy → 4/6 fail as expected → reverted → 6/6 pass).
- Fixed two real bugs surfaced while writing this suite:
  - `0005_table_grants.sql`: local DB was missing DML grants to `authenticated`,
    so RLS was never actually being exercised (queries failed before RLS was
    consulted, not because of it).
  - `0006_rls_helper_security_definer.sql`: `current_app_user_id()` caused
    infinite recursion under `authenticated` role; fixed with `SECURITY DEFINER`
    (standard Supabase pattern — safe here since the function only resolves
    firebase_uid → user id, exposes nothing else).
- Wired into CI: `database_ci.yml` runs `supabase test db` on any change under
  `supabase/tests/**`.
- RLS audit pass (`supabase/tests/database/rls_audit.sql`, 4 assertions): the
  same-table recursion class exists only on `users`/`admin_users` (both fixed by
  0006's SECURITY DEFINER helpers); `via_trip`/`via_expense` policies query
  different tables, so they are safe. `anon` grants confirmed: SELECT only on
  the seven public-read catalog tables, zero DML on any app table. The audit is
  a permanent pgTAP test, so CI guards both failure classes automatically.

### Fix pass — auth surface, back navigation, overflow, UI polish

- **Phone/OTP login removed from the UI.** `LoginScreen` now offers only
  Continue with Google, Continue with Email, and Skip for now. The repository
  layer (`AuthRepository.startPhoneVerification` / `confirmOtp`) is untouched and
  could be re-exposed behind a feature flag later; this affects what the
  Firebase/Play Console privacy forms declare (phone is now collected only if the
  user provides it elsewhere — see `docs/STORE_COMPLIANCE.md`).
- **System back button fixed.** Audited every `context.go(...)` call. `go()` is
  now reserved for auth redirects (login success/skip, onboarding finish, splash,
  error reset, end-trip), tab-level switches, and intentional stack resets. All
  forward navigation in the Plan Trip flow now uses `context.push(...)`:
  Home → Plan Trip, guest-banner/login/profile "Sign in" → Login, guest-gate →
  Login, itinerary → Places/Stays, Budget → Stays. Back now pops one screen at a
  time instead of quitting the app.
- **RenderFlex overflow hardening.** Wrapped variable-length text in
  `Expanded`/`Flexible` + `TextOverflow.ellipsis` across budget rows, live-trip
  from/to rows, confirm-trip rows, trip-detail summary + destination label,
  itinerary item subtitle, stay price rows, expense totals, and home trip titles.
- **UI/UX polish (no rebrand — palette, type scale, and component names
  unchanged):** subtle fade/slide page transitions for the Plan Trip flow; the
  `BudgetMeter` bar now animates its fill; the Home Plan-a-Trip CTA carries a
  soft shadow so it reads as the singular next action; selected place/stay cards
  get a soft shadow + check indicator (spec 15.4 shadow-on-selected rule);
  mixed filled icons normalized to the outline set (`directions_car_outlined`,
  `person_outline`, `route_outlined`); stray hardcoded spacings replaced with
  `AppSpacing` tokens.

## Known gaps to close before this is production-safe

1. **`firebase_options.dart` is a placeholder** — run `flutterfire configure` against
   your real project.
2. **No live routing/toll/fuel-price/geocoding provider is wired** — mock adapters
   return clearly-labelled dev fixtures until you add keys. This is by design.
3. **DB-backed Edge Functions not exercised against a live stack** — `supabase
   functions serve`/smoke tests need env vars (`SUPABASE_URL`,
   `SUPABASE_SERVICE_ROLE_KEY`, `FIREBASE_PROJECT_ID`) or a local `supabase start`.
4. **CI workflows not yet executed in CI** — run `database_ci` against a local
   Supabase stack and fix any issues before relying on them.
5. **Google Sign-In button** — verify against a real OAuth client setup.
6. **RLS / integration tests** — RLS suite now exists and is proven non-trivial
   (`supabase/tests/database/rls_trips.sql`, 6/6 pass). The critical E2E path
   (plan → calculate → compare → places → stays → itinerary → confirm → save)
   integration test remains to be written.
7. **Release signing** — `android/app/build.gradle.kts` signs release with debug
   keys; replace with a real keystore before publishing.
8. **Legal documents are drafts** with `route2go.example` placeholders — require
   qualified legal review before launch (see `docs/STORE_COMPLIANCE.md`).
9. **ATT prompt declared but not yet invoked at runtime**; store metadata/screenshots
   not produced (see `docs/STORE_COMPLIANCE.md`).
10. **Feature-flagged Phase 2 bodies** (weather, offline cache, EV/CNG in live cost
    engine) are gated shells — the flags are read from the backend but the real
    implementations are the next vertical slices.

## Required external credentials (cannot be created for you)

- Firebase project (Auth providers enabled)
- Supabase project
- Apple Developer account + signing certificate (for iOS build/release)
- Google Play Console account + signing key (for Android release)
- A commercial or self-hosted routing provider, once you're past mock data
- Hotel/affiliate partner account(s) for the Stays flow

## Realistic next steps for "go live"

1. Run Setup in README.md with real Firebase/Supabase credentials; run `supabase db
   push` and deploy all functions; set secrets.
2. Execute the CI workflows once and fix anything that surfaces.
3. Write RLS + integration tests; run on a physical device for the Live Trip flow.
4. Finalize signing, legal docs, ATT, and store listing (checklist:
   `docs/STORE_COMPLIANCE.md`).