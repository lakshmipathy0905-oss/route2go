# Route2Go — Continuation Prompt for Claude Code

Paste this into Claude Code, running inside this repository, once you've completed
the Setup steps in README.md and confirmed the existing Plan Trip → Route Results →
Budget Tracker flow runs on your machine.

---

You are continuing an existing Route2Go repository. Do NOT restart the architecture —
inspect `apps/mobile/lib/` and `supabase/` first and follow the exact patterns already
established there:

- Riverpod providers in `presentation/providers/`, one file per feature domain
- Repositories in `data/repositories/` calling `ApiClient` (never Dio directly from a screen)
- Every external data source goes behind a provider interface in
  `supabase/functions/_shared/providers/` with a deterministic mock adapter,
  exactly like `routingProvider.ts` / `fuelPriceProvider.ts` / `tollProvider.ts`
- Every screen implements loading/success/empty/error/offline states using
  `AppLoadingState` / `AppErrorState` / `AppEmptyState` / `OfflineBanner` from
  `presentation/widgets/app_widgets.dart`
- Every Edge Function verifies the Firebase token via `_shared/firebaseAuth.ts`
  and never trusts a client-supplied user id
- Every user-owned table gets an RLS policy following the pattern in
  `supabase/migrations/0002_row_level_security.sql` (ownership resolved via
  `current_app_user_id()`, never a client-supplied column)
- Every screen's costs/estimates show a `ConfidenceBadge` — never present
  estimated/mock data as if it were live

Build in this order, and after each numbered item: run `flutter analyze`, run
`flutter test`, fix anything broken, then move to the next item. Do not batch
everything to the end.

1. **Vehicle Garage**: `vehicles` CRUD screens + repository (table already exists:
   `public.vehicles`). Add/edit/delete, default vehicle flag, mileage validation
   (reject unrealistic values with guidance, don't silently clamp).
2. **Location Picker**: replace the manual lat/lng fields in `PlanTripScreen` with a
   real map-pin + search screen using `flutter_map`, backed by a `GeocodingProvider`
   interface (mock adapter first, matching the pattern in `routingProvider.ts`).
3. **Route Comparison**: extend `RouteResultsScreen` into a side-by-side comparison
   view (spec Section 5.6) showing cost/time deltas vs. the recommended route.
4. **Places Along Route**: new `places-near-route` Edge Function (bounding-box or
   PostGIS query against `public.places`), category filters, detour-impact display
   (spec Section 5.8 — always show the explicit cost/time delta of adding a place).
5. **Stay Discovery**: `stays-near-route` Edge Function against `public.hotels`,
   provider disclosure + sponsored labelling per spec Section 23.2.
6. **Itinerary Generator**: `itinerary-generate` Edge Function implementing the
   day-by-day scheduling algorithm with the configurable max-driving-hours safety
   cap (spec Section 18) — this is a safety-relevant algorithm, write tests for the
   edge cases in spec Section 17 before considering it done.
7. **Expense Tracker + Save/Share Trip**: `trip/save`, `expenses` CRUD, saved trips list.
8. **Notifications**: FCM wiring + `notifications` table read/mark-read screens.
9. **Profile / Settings / Privacy / Terms / Delete Account**: delete account flow
   must call a `/privacy/request-delete` function BEFORE calling Firebase
   `user.delete()`, so Supabase-owned data isn't orphaned.
10. **Admin web dashboard**: separate Flutter web target or isolated route group,
    RBAC per spec Section 18 (Super Admin/Content Manager/Support/Moderator/Finance),
    every write goes to `public.audit_logs`.
11. **Feature-flagged Phase 2 shells**: EV/CNG cost paths (already stubbed as
    `unavailable` in `computeFuelCost` in `trip-calculate/index.ts` — wire them up
    for real only when `phase2_ev`/`phase2_cng` flags are true), group split,
    offline cache, weather alerts.
12. **Tests**: unit tests for every calculation function, widget tests for every
    screen state, RLS policy tests, integration test for the critical E2E path
    (plan → calculate → compare → places → stays → itinerary → confirm → save).
13. **CI/CD**: `.github/workflows/` — format check, analyze, test, secret scan,
    build Android/iOS/web, staged deploy.
14. **Legal documents**: draft `docs/PRIVACY_POLICY.md` and `docs/TERMS_OF_SERVICE.md`
    per the checklist in the original spec (Section 23), clearly labelled as drafts
    requiring qualified legal review before publication — do not present them as
    final legal text.

After each phase, update `BUILD_STATUS.md` with what changed, what was tested, and
what's still outstanding — keep it honest, the same way the current version is.

The full original product/technical specification is in
`docs/ORIGINAL_SPEC_REFERENCE.md` for detailed requirements on any screen above.

START WITH ITEM 1.
