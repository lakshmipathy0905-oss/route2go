# Route2Go — Store & Compliance Checklist (Section 3)

Draft working checklist for Play / App Store submission. **Not legal advice** —
have a qualified reviewer confirm each item before publishing. All placeholders
(`YOUR_*`, `route2go.example`) must be replaced with production values.

Status legend: ✅ done in code · 🟡 needs a manual/store-side action · 🔶 draft only

---

## 1. Permissions declared in the app

| Platform | Key | String | Status |
| --- | --- | --- | --- |
| Android | `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | Used for route planning, the location picker, and live-trip deviation checks | ✅ |
| Android | `ACCESS_BACKGROUND_LOCATION` | Live-trip deviation detection only; requested **after** the in-app explainer, never at launch | ✅ |
| Android | `POST_NOTIFICATIONS` | Push notifications (Android 13+), spec 2.10 | ✅ |
| iOS | `NSLocationWhenInUseUsageDescription` | Route planning, location picker, live trip | ✅ |
| iOS | `NSLocationAlwaysAndWhenInUseUsageDescription` | Live-trip background deviation detection (explainer before prompt) | ✅ |
| iOS | `NSUserTrackingUsageDescription` | Analytics/measurement (see ATT below) | ✅ |

Files: `apps/mobile/android/app/src/main/AndroidManifest.xml`,
`apps/mobile/ios/Runner/Info.plist`.

Runtime behaviour: every OS permission prompt is preceded by the in-app
`PermissionExplainer` (`lib/presentation/widgets/permission_explainer.dart`).
Background location is requested only from Live Trip entry (`confirm_trip_screen.dart`),
matching Section 3.3.

---

## 2. Analytics & ATT

- Firebase Analytics is the only analytics SDK. `firebase_analytics` is linked.
- **ATT**: iOS builds using the IDFA must call
  `requestTrackingAuthorization` before any analytics collection, with the
  `NSUserTrackingUsageDescription` string above. ✅ `TrackingPermissionService`
  (`lib/core/notifications/tracking_permission_service.dart`) requests ATT at
  first launch and disables analytics unless the user authorizes tracking
  (no-op on Android). The ATT prompt now runs at runtime before TestFlight
  build.
- **Analytics opt-out is enforced in code**: `ProfileNotifier` calls
  `FirebaseAnalytics.setAnalyticsCollectionEnabled(false)` the moment the user
  toggles it in Settings, and re-applies the persisted value at app start
  (`lib/presentation/providers/profile_provider.dart`). Opting out never blocks
  trip planning.
- No precise location is ever logged to analytics. Crashlytics is configured to
  exclude tokens/auth headers/location (`lib/main.dart`).

---

## 3. Play Console — Data Safety (Android)

Answers to the Play Data Safety form. 🟡 Fill these in the Play Console.

| Question | Answer |
| --- | --- |
| Data collected | Device or other identifiers (Firebase/analytics), approximate and precise location (only while planning/live trip), user contacts? No. Personal info: name/phone/photo (only if user provides) |
| Data shared | None with third parties; analytics/IDFA collected but not sold |
| Data encrypted in transit | Yes (HTTPS to Supabase/Firebase) |
| Deletion requested by user | Yes — in-app Delete Account + privacy request endpoint |
| Ads | None |
| Child-directed | No |

---

## 4. App Store — Privacy Nutrition Labels

🟡 Enter in App Connect.

- **Location**: used for app functionality (route planning, live-trip deviation).
- **Identifiers**: device ID / analytics.
- **User content**: profile name/photo if provided.
- **Contact info**: phone collected only if the user provides it. Phone/OTP sign-in is implemented at the repository level but is **not exposed in the UI** for launch (email/password, Google, and guest only) — so phone collection won't occur through the current sign-in flow.
- **Data not linked to identity**: analytics events.

---

## 5. Store listing draft (both stores)

- **Short description**: Plan road trips with real fuel, toll and budget costs —
  then add places, stays and a day-by-day itinerary.
- **Full description**: (write from current feature set, see BUILD_STATUS.md for
  the honest feature list.) Include: route & fuel-cost calculation, budget
  tracker (green/yellow/red), places & stays near route, itinerary scheduler,
  expense tracker, live-trip deviation warnings, push notifications, affiliate
  partner disclosure, full account deletion + data privacy controls.
- **Screenshots** 🔶: capture Plan Trip → Route Results → Budget → Itinerary →
  Live Trip at 1080×1920 (Android) / 1290×2796 (iOS).
- **App name**: Route2Go. **Application id**: `com.route2go.route2go` (Android),
  iOS bundle id per your team.

---

## 6. Pre-submission doc

🟡 Fill in before submitting:

1. Production Firebase project id (secrets on every deployed Edge Function).
2. Production Supabase project + `supabase db push` applied.
3. Real routing provider (or keep the mock provider off for release).
4. Legal docs finalised (replace `route2go.example` placeholders in
   `apps/mobile/assets/docs/*.md` and re-run the build so the in-app links match).
   ✅ Contact/address now filled (route2go1@gmail.com, Bengaluru 560076);
   🟡 still needs a qualified legal review of the final drafts.
5. Terms + Privacy linked in-app (Settings screen) and store.
6. Release signing: `android/app/build.gradle.kts` reads `android/key.properties`
   when present and falls back to debug keys otherwise. 🟡 Generate a real
   keystore + key.properties before publishing (see
   `apps/mobile/android/key.properties.template`).
7. `flutter analyze` clean, `flutter test` green, plus the RLS + EF test suites.
8. iOS `DEVELOPMENT_TEAM`: not yet set in the Xcode project — add your Apple
   Team ID before `flutter build ipa` (release blocker).

---

## 6b. Credentials & keys — what's actually required (verified against code)

The app runs on two hard requirements (Firebase + Supabase) plus a small set of
optional provider keys. Everything below was verified against the codebase.

### Required — the app will not run without these

| Credential | How to get it | Where it goes |
| --- | --- | --- |
| Firebase project + `firebase_options.dart` | console.firebase.google.com → create project → **Add app** (Android `com.route2go.route2go`, iOS `com.route2go.route2go`); download `google-services.json` → `apps/mobile/android/app/`, `GoogleService-Info.plist` → `apps/mobile/ios/Runner/`; then `flutterfire configure` | regenerates `apps/mobile/lib/firebase_options.dart` (currently a placeholder) |
| `SUPABASE_URL` + `SUPABASE_ANON_KEY` | supabase.com → project → **Project Settings → API** | `flutter run --dart-define=...` |
| `SUPABASE_SERVICE_ROLE_KEY` | same page, the **service_role** key | **server-only**: `supabase secrets set` on deployed functions; never in the app, never committed |
| `FIREBASE_PROJECT_ID` | Firebase project settings | `supabase secrets set` on every deployed function |

### Optional — mock/dev providers work without them

| Key | Status |
| --- | --- |
| `ROUTING_PROVIDER_BASE_URL` / `ROUTING_PROVIDER_KEY` | Optional — routing falls back to deterministic mock |
| `GEOCODING_PROVIDER_KEY` | Not needed — geocoder falls back to free Nominatim (OSM) |
| `PLACES_PROVIDER_KEY` | Optional — only if wiring a real places API |
| `HOTEL_AFFILIATE_API_KEY` | Optional — only after signing a real affiliate deal |
| `FCM_SERVER_KEY` | **Not currently used.** The `/notifications` EF only *registers* FCM tokens; no push-sending code exists yet. If/when a push sender is built, use **Firebase Console → Project Settings → Cloud Messaging** (legacy key or HTTP v1 service-account JSON) — Supabase does not issue FCM keys. |
| `ANALYTICS_WRITE_KEY` | Optional — only if plugging a separate analytics backend |

### Reviewer/admin account (create before submission)

```sql
-- 1. Create a Firebase user (console.firebase.google.com → Authentication → Add user)
-- 2. Copy that user's UID
-- 3. Run in Supabase → SQL Editor:
insert into admin_users (firebase_uid, role) values ('THE_UID_FROM_STEP_2', 'super_admin');
```

**Note:** `admin_users.role` is CHECK-constrained to
`('super_admin','content_manager','support','moderator','finance')` — there is no
`'super'` value. Use `'super_admin'`. The `/admin` Edge Function and the Flutter
admin screens both gate privileged writes on `'super_admin'` (fixed to match).

---

## 7. Known gaps (honest)

- ✅ ATT prompt now invoked at runtime (gates analytics on user choice).
- 🟡 Release signing falls back to debug keys until `android/key.properties`
  exists; iOS `DEVELOPMENT_TEAM` unset — both are store-submission blockers.
- 🟡 Legal docs are comprehensive drafts with real contact details but still
  require a qualified legal review.
- Store screenshots and metadata not yet produced.
- Background-location runtime handling verified in code; device testing of the
  full Live Trip flow still recommended on a physical device.