# CREDENTIALS_REQUIRED.md

Accurate credential inventory for Route2Go, based on an audit of the actual
code (frontend, Edge Functions, migrations, `.env.example`) — **not** on an
assumed "three API keys" requirement.

> Bottom line: **No API keys are required to build or run the app today.**
> The app runs on open/free services (OpenStreetMap tiles, Nominatim,
> OSRM-style routing, mock fuel/toll) plus two **projects** you create in
> Firebase and Supabase. Only **email notifications** need a real credential,
> and only if/when you wire a live email provider.

---

## Actual credentials required: **2 projects + 1 optional email key**

| # | Credential | Type | Required? | Free? | Purpose |
|---|-----------|------|-----------|-------|---------|
| 1 | **Firebase project** | project config (NOT an API key) | YES | Yes (Spark plan) | Google + email/password + phone auth, FCM, Crashlytics, Analytics |
| 2 | **Supabase project** | project config + anon key (public) + service-role key (server-only secret) | YES | Yes (free tier) | Postgres + RLS, Edge Functions, tables |
| 3 | **Email provider key** | API key (server-side only) | NO — only when email notifications are enabled | Resend 3,000/mo free; Brevo 300/day free | Welcome/trip emails via Edge Function |

Everything else (map tiles, geocoding, routing, fuel, toll) needs **no key** —
see per-service table below.

---

## Per-service breakdown (accurate to current code)

### GOOGLE AUTHENTICATION
- **Credential required:** NO API key. Requires **Firebase project + Google OAuth client configuration**.
- **Type:** OAuth client ID / Web client config — *configuration*, not a secret key.
- **Free:** Yes. **Setup:** In Firebase console → Authentication → Sign-in method → Google.
- **Code status:** UI button exists (`login_screen.dart`); `_handleGoogleSignIn` is a **stub** (shows an error). The `google_sign_in` package is **not** in `pubspec.yaml`. Needs wiring + the package + Firebase config before it works.
- **Security:** OAuth client IDs are public (safe in the app). Any secret stays server-side.

### PHONE AUTHENTICATION
- **Credential required:** NO API key for the prototype.
- **Type:** Firebase Auth phone verification (uses Google's SMS infrastructure).
- **Free:** Yes on Firebase Spark, but subject to **SMS verification quotas** set by Google (check current console limit; it is not unlimited).
- **Code status:** `AuthRepository.startPhoneVerification`/`confirmOtp` exist but are **unused by any screen** (no OTP UI). Requires enabling Phone in Firebase → Authentication.
- **Production warning:** Bulk phone-auth usage can incur cost; treat quotas as finite.

### EMAIL / GMAIL NOTIFICATIONS
- **Credential required:** YES — one **email provider API key**, server-side only.
- **Type:** API key (SMTP password or HTTP API key depending on provider).
- **Free:** Resend free tier ~3,000 emails/mo (no card); Brevo ~300/day; Supabase Auth built-in emails are free for auth flows.
- **Code status:** **Not implemented.** No email function or template exists yet. Must be added as an Edge Function; never put the key in Flutter.
- **Gmail note:** You do **not** need the Gmail API. A transactional provider is simpler and safer. Do **not** use a Gmail account password anywhere.

### WORLDWIDE MAP (tiles)
- **Credential required:** NO.
- **Free:** Yes. **Provider:** OpenStreetMap public tile server.
- **Limit:** Public tile server is for light/dev use — **no heavy or production traffic**. Requires attribution "© OpenStreetMap contributors". Add a tile abstraction so a paid provider can be swapped in for production.
- **Code status:** Wired in `location_picker_screen.dart` (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`). No abstraction yet.

### WORLDWIDE SEARCH + REVERSE GEOCODING
- **Credential required:** NO.
- **Free:** Yes. **Provider:** Nominatim (OpenStreetMap).
- **Limit:** **Strict** usage policy — max ~1 req/sec, must send a valid `User-Agent`, no heavy/bulk use. 403 = policy/rate issue.
- **Code status:** Live Nominatim adapter exists (`geocodingProvider.ts`), activated by setting `GEOCODING_PROVIDER_KEY` (any non-empty value — the key itself is not used). Mock provider is the default.
- **Production warning:** For production load, use a hosted geocoding service or self-host Nominatim/Photon.

### ROUTING
- **Credential required:** NO.
- **Free:** Yes. **Provider:** any OSRM-compatible host (e.g., OSRM public demo ~50k req/day, or self-hosted OSRM).
- **Limit:** Varies by host; OSRM public demo is non-commercial. Do not hammer.
- **Code status:** `HttpRoutingProvider` in `routingProvider.ts`, active when `ROUTING_PROVIDER_BASE_URL` is set. Default is a deterministic mock.

### TRAFFIC
- **Credential required:** NO (and none should be added blindly).
- **Code status:** **Not implemented. No fake traffic.** Any live-traffic integration requires a provider with real traffic data; until then the app must label traffic as unavailable/estimated.

### FUEL PRICE
- **Credential required:** NO.
- **Code status:** Mock prices by default; live mode reads the `fuel_prices` table when `USE_LIVE_FUEL_PRICES=true`. EV/CNG cost paths are phase-gated and return `unavailable`.

### TOLL
- **Credential required:** NO.
- **Code status:** Mock by default; live mode reads `toll_plazas` when `USE_LIVE_TOLL_DATA=true`.

### PUSH NOTIFICATIONS (FCM)
- **Credential required:** NO key in the app. FCM config comes from the Firebase project.
- **Code status:** token registration only; no server push-send code exists yet.

### PLACES / HOTELS / STAYS / AFFILIATE / OCR / WEATHER
- **Places:** DB-backed (`places`, `hotels` tables); **no external key**. (`PLACES_PROVIDER_KEY` is declared in `.env.example` but **read by no code** — do not create a fake key for it.)
- **Weather / EV / OCR:** not implemented or phase-gated shells; **no keys required**.
- **Affiliate:** `HOTEL_AFFILIATE_*` vars declared but unused — ignore until implemented.

---

## Key security rules

1. **`SUPABASE_SERVICE_ROLE_KEY` is a server-only secret.** It must live in
   Supabase function secrets and `.env.example` must stay empty. Never put it
   in Flutter.
2. **Email provider keys live only in Edge Function secrets**, never Flutter.
3. **Firebase client config** (apiKey, appId, projectId in `firebase_options.dart`)
   is public by design — safe to commit. Only OAuth *secrets* are protected.
4. **Never commit a filled `.env` file.** `.gitignore` already blocks `.env`,
   `google-services.json`, `GoogleService-Info.plist`, `*.jks`, `*.keystore`,
   `key.properties`. A real `google-services.json` exists on disk but is
   correctly ignored.
5. `SUPABASE_FUNCTIONS_URL` has a placeholder default in
   `api_client.dart:136` (`https://YOUR_PROJECT_REF.supabase.co/...`) — must be
   replaced via `--dart-define` at build time; never hardcode your project ref.

---

## "Three keys" investigation result

The original assumption of "exactly three API keys" does **not** match the
architecture. Verified count:

- **0 API keys** are needed to run the current app (open providers + mocks).
- **2 project configurations** are needed for real deployment: Firebase
  (auth/push/analytics) and Supabase (DB/functions).
- **1 optional email API key** if you enable transactional email.

Credentials are **projects + configuration**, not API keys. Do not create keys
for unused vars (`PLACES_PROVIDER_KEY`, `HOTEL_AFFILIATE_API_KEY`,
`FCM_SERVER_KEY`, `ANALYTICS_WRITE_KEY`) — no code reads them.