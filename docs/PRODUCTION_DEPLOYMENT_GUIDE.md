# Route2Go Production Deployment Guide

## 1. Firebase Configuration
- Ensure `google-services.json` and `GoogleService-Info.plist` are updated for the production environment (`route2go-da5c3`).
- Add the SHA-1 fingerprint (`9E:64:6A:B8:93:7F:FC:C3:E0:31:AD:C9:74:FB:F2:3E:63:7B:E1:F3`) to the Firebase Console to enable Google Sign-In and App Check.

## 2. Supabase Configuration
- Upgrade to Supabase Pro before onboarding public traffic to prevent Edge Function timeouts.
- Set production secrets in Supabase:
  - `VALHALLA_BASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`

## 3. Flutter Build
Build the Android App Bundle (AAB):
```bash
flutter build appbundle --release \
  --dart-define=MAP_TILE_URL_TEMPLATE='https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png' \
  --dart-define=VALHALLA_BASE_URL='https://valhalla.production.endpoint'
```

## 4. App Store Upload
- **Android**: Upload `build/app/outputs/bundle/release/app-release.aab` to Google Play Console (Internal Testing Track).
- **iOS**: Archive via Xcode and upload to App Store Connect via Transporter.
