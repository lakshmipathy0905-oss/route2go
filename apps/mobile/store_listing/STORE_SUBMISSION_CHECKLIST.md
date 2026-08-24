# Route2Go — Store Submission Checklist

**Last updated:** 2026-08-24
**Target stores:** Google Play Store, Apple App Store

---

## 1. Brand Assets

- [x] App icon (512×512 PNG, adaptive icon for Android)
- [x] App splash screen with logo and slogan
- [x] Feature graphic (1024×500) — **NEEDED**
- [ ] App preview video (optional, 30s–2min)

## 2. Store Listing

### Google Play Store
- [x] App name: Route2Go
- [x] Short description (80 chars)
- [x] Full description
- [x] Category: Travel & Local
- [x] Tags/keywords
- [x] Contact email: route2go1@gmail.com
- [x] Privacy policy URL — **NEEDED** (hosted URL)
- [x] Screenshots (5 minimum, 1080×2340)
- [ ] Feature graphic (1024×500) — **NEEDED**

### Apple App Store
- [x] App name: Route2Go
- [x] Subtitle (30 chars)
- [x] Description
- [x] Keywords (100 chars)
- [x] Category: Travel
- [x] Support URL — **NEEDED**
- [x] Privacy policy URL — **NEEDED**
- [ ] Screenshots (iPhone 6.7", 6.5", 5.5"; iPad 12.9") — **NEEDED**
- [ ] App preview video (optional)

## 3. Legal & Compliance

- [x] Privacy Policy document (draft complete)
- [x] Terms of Service document (draft complete)
- [ ] Legal review by qualified professional — **NEEDED before launch**
- [x] Account deletion reachable from app
- [x] Data Safety form answers prepared
- [x] Privacy nutrition labels prepared

## 4. Permissions

- [x] ACCESS_FINE_LOCATION / ACCESS_COARSE_LOCATION
- [x] ACCESS_BACKGROUND_LOCATION (requested only at Live Trip start)
- [x] POST_NOTIFICATIONS (Android 13+)
- [x] NSLocationWhenInUseUsageDescription (iOS)
- [x] NSLocationAlwaysAndWhenInUseUsageDescription (iOS)
- [x] NSUserTrackingUsageDescription (iOS)
- [x] In-app permission explainer before system prompt

## 5. Security

- [x] Row Level Security (RLS) on all user tables
- [x] Server-side validation
- [x] Rate limiting on public endpoints
- [x] No API secrets in mobile app
- [x] Firebase token verification
- [x] Audit logs for admin actions
- [x] Secure account deletion flow

## 6. Technical Readiness

- [x] `flutter analyze` clean
- [x] `flutter test` 106/106 pass
- [x] `dart format` clean
- [x] Mobile CI passing on GitHub Actions
- [x] Functions CI passing
- [x] Database CI passing
- [x] Release build (APK) succeeds
- [x] Web build succeeds

## 7. Content Rating

- [x] Content rating questionnaire prepared
- [x] Target: Everyone / 4+

## 8. Monetization

- [x] No ads in MVP
- [x] Affiliate/sponsored labels implemented
- [x] Clear disclosure for partner links

## 9. Testing

- [x] Unit tests for calculations
- [x] Widget tests for screen states
- [x] Integration tests for critical path
- [x] RLS policy tests (10/10 pass)
- [ ] Physical device testing (Live Trip GPS) — **RECOMMENDED**
- [ ] Closed beta testing — **RECOMMENDED**

## 10. Pre-Launch Actions Required

### Must Complete Before Submission
1. **Generate Android release keystore** + `key.properties`
2. **Set iOS DEVELOPMENT_TEAM** in Xcode
3. **Host Privacy Policy** at a public URL
4. **Host Terms of Service** at a public URL
5. **Capture iOS screenshots** at required resolutions
6. **Create feature graphic** (1024×500)
7. **Legal review** of privacy policy and terms

### Recommended Before Launch
1. Physical device Live Trip testing
2. Closed beta with real users
3. App preview video
4. Load testing on owned infrastructure

---

## File Locations

| Asset | Path |
|-------|------|
| Android screenshots | `apps/mobile/store_listing/screenshots/android/` |
| Play Store listing | `apps/mobile/store_listing/play_store_listing.md` |
| App Store listing | `apps/mobile/store_listing/app_store_listing.md` |
| App flow documentation | `apps/mobile/store_listing/APP_FLOW_DOCUMENTATION.md` |
| Privacy Policy | `docs/PRIVACY_POLICY.md` |
| Terms of Service | `docs/TERMS_OF_SERVICE.md` |
| Compliance checklist | `docs/STORE_COMPLIANCE.md` |
| Gap analysis | `docs/GAP_ANALYSIS.md` |
| Key properties template | `apps/mobile/android/key.properties.template` |

---

## Store Submission Status

| Item | Status |
|------|--------|
| Android APK (debug) | ✅ Built |
| Android App Bundle (release) | 🟡 Needs keystore |
| iOS build (debug) | 🟡 Needs DEVELOPMENT_TEAM |
| Screenshots (Android) | ✅ 5 captured |
| Screenshots (iOS) | ❌ Not captured |
| Feature graphic | ❌ Not created |
| Privacy policy URL | ❌ Not hosted |
| Terms URL | ❌ Not hosted |
| Legal review | ❌ Not completed |
