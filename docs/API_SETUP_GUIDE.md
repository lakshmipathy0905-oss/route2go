# API_SETUP_GUIDE.md

A step-by-step guide for someone who has **zero** experience with API keys,
projects, or cloud consoles. Everything here is derived from the actual
Route2Go code — nothing is invented.

**Before you start, know this:** Route2Go does **not** need "API keys" to run.
It needs **two free projects** (Firebase and Supabase) and optional email.
This guide walks you through creating them.

---

## What you will end up with

| Step | What you create | Free? | Needed for |
|------|-----------------|-------|-----------|
| 1 | Firebase project | Yes | Login (Google/email/phone), push, analytics, crash reports |
| 2 | Supabase project | Yes | Database, security rules (RLS), backend functions |
| 3 | (optional) Email provider | Yes | Welcome / notification emails |
| 4 | (optional) Routing URL | Yes | Real worldwide routes instead of mock routes |

No credit card is required for the free tiers below.

---

## Terminology (read this once)

- **API key** — a long secret string an external service gives you to identify
  your app. Not all services use them.
- **Project** — a container you create in a cloud console. Firebase and
  Supabase both use projects, not keys.
- **Anon key** — Supabase's *public* key. Safe to put in the app. It is NOT
  secret.
- **Service-role key** — Supabase's *private* master key. **NEVER** put it in
  the app. Server only.
- **`--dart-define`** — how you pass values to the Flutter app at build time:
  `flutter run --dart-define=NAME=value`.
- **Edge Function** — a small backend function that runs on Supabase. Email
  and other secret-key logic lives here, never in the app.

---

## STEP 1 — Create a Firebase project

**Purpose:** authentication (Google, email, phone) and device services.

1. Open **https://console.firebase.google.com** in your browser.
2. Click **Create a project** (or **Add project**).
3. Type a project name, e.g. `route2go`.
4. Google Analytics can be **disabled** (not required). Click **Create project**.
5. Wait for the spinner to finish, click **Continue**.
6. In the left menu go to **Build → Authentication → Get started**.
7. On the **Sign-in method** tab, enable:
   - **Email/Password** (always enable — used for email login)
   - **Google** (click Enable, then Save)
   - **Phone** (click Enable; set a test number if prompted — phone SMS
     verification is quota-limited, not unlimited)
8. Go to **Project settings** (gear icon) → **Your apps** → add an Android app
   and an iOS app using your package/bundle id: `com.route2go.route2go`
   (Android) and `com.route2go.app` (iOS). Download the config files Google
   offers.
9. Install the Flutter Firebase tooling so the app can read this project:

   ```
   cd apps/mobile
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Log in when prompted, pick your Firebase project, and accept the default
   platforms. This writes `lib/firebase_options.dart` with real values
   (public config — safe to commit).

### If it fails
- `flutterfire configure` says no project found → you are logged into the
  wrong Google account or the project wasn't created. Re-run and pick the
  right project.
- Build error about Firebase → make sure `flutter pub get` ran and
  `google-services.json` / `GoogleService-Info.plist` are in place (these are
  gitignored on purpose — they contain real config).

---

## STEP 2 — Create a Supabase project

**Purpose:** database, security rules (RLS), backend Edge Functions.

1. Open **https://supabase.com** → **Start your project** (free tier).
2. Sign in with GitHub. Pick a region close to your users (e.g., Singapore or
   `ap-south-1` for India). Create the project. Free tier needs no card.
3. After it spins up, note your **Project URL** (looks like
   `https://abcdefgh.supabase.co`) and your **anon key** (in
   **Settings → API keys**). You will need both.
4. Apply the database schema from the repo:

   ```
   # from repo root
   npm install -g supabase
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   ```

   (`YOUR_PROJECT_REF` is the short id in your project URL, e.g. `abcdefgh`.)

5. Deploy the backend functions:

   ```
   supabase functions deploy
   ```

   This uploads all functions in `supabase/functions/`.

6. Set the server-only secrets the functions require:

   ```
   supabase secrets set FIREBASE_PROJECT_ID=route2go
   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
   ```

   Find the service-role key in **Settings → API keys**. It is the **secret**
   one. Store it in a password manager. **Never** put it in the app or in git.

### If it fails
- `supabase db push` fails → make sure you are linked to the right project
  and have run `supabase login`.
- Functions return 500 at runtime → the secrets above are missing or wrong;
  re-run step 6.
- Emails / login failing → `FIREBASE_PROJECT_ID` must match your Firebase
  project id exactly.

---

## STEP 3 — (optional) Email notifications

Only do this if you want the welcome / trip-saved emails. If you skip it, the
app still works — email just stays off.

1. Create a free account at a transactional email provider. Two options with
   free tiers (current at time of writing — check the site):
   - **Resend** — ~3,000 emails/month free, no card. https://resend.com
   - **Brevo** — ~300 emails/day free. https://brevo.com
2. Create an **API key** in the provider's dashboard (e.g., Resend:
   API Keys → Create API Key).
3. This key must be stored **only** in Supabase function secrets, never in the
   app or git:
   ```
   supabase secrets set EMAIL_PROVIDER_KEY=your_key_here
   ```
4. The email function (to be implemented in `supabase/functions/email/`) reads
   this key server-side.

### If it fails
- Emails never arrive → check the key was set (step 3), check the recipient
  address, and check the provider dashboard for send errors. Free tiers do not
  send to every domain immediately (some mark new domains as spam).

---

## STEP 4 — (optional) Real worldwide routing

Route2Go ships with a mock route provider so it runs out of the box. To get
**real** worldwide routes, point it at any OSRM-compatible server.

Free options:
- **OSRM public demo** — https://router.project-osrm.org — free, ~50k
  requests/day, for development/non-commercial use only.
- **Self-hosted OSRM** — run on your own machine/server for production.

Set it via Supabase function secrets (server-side) or the app env for local:

```
supabase secrets set ROUTING_PROVIDER_BASE_URL=https://router.project-osrm.org
```

The routing function in `supabase/functions/_shared/providers/routingProvider.ts`
automatically switches from mock to live when this is set.

### If it fails
- Routes still look mock/straight-line → `ROUTING_PROVIDER_BASE_URL` is not
  set on the deployed functions (re-run the `supabase secrets set` above).
- 502 from trip-calculate → the routing URL is unreachable or returns
  non-OSRM responses.

---

## Running the app with your projects

Every `flutter run`/`flutter build` needs your Supabase project URL, anon key,
and function URL passed in. Never hardcode them; always use `--dart-define`:

```
cd apps/mobile
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=SUPABASE_FUNCTIONS_URL=https://YOUR_PROJECT_REF.supabase.co/functions/v1
```

Replace `YOUR_PROJECT_REF` and `YOUR_ANON_KEY` with the real values from
Step 2. For release builds use `flutter build apk --dart-define=...` and
`flutter build ios --dart-define=...` with the same values.

### If it fails
- App connects but screens error → anon key or project URL typo.
- Login fails with "invalid API key" → the Firebase config in
  `firebase_options.dart` is still a placeholder; redo Step 1's
  `flutterfire configure`.
- Requests hang → check your network; the app has 10s connect / 15s receive
  timeouts.

---

## Summary of where each value lives

| Value | Where to create | Where it is used | Secret? |
|-------|----------------|------------------|---------|
| Firebase project id | Firebase console | `flutterfire configure`, function secret `FIREBASE_PROJECT_ID` | No |
| Firebase client config | `flutterfire configure` | `lib/firebase_options.dart` | No (public by design) |
| Supabase project URL | Supabase console | `--dart-define=SUPABASE_URL` | No |
| Supabase anon key | Supabase console → API keys | `--dart-define=SUPABASE_ANON_KEY` | No |
| Supabase service-role key | Supabase console → API keys | function secret `SUPABASE_SERVICE_ROLE_KEY` | **YES — server only** |
| Email provider key | Resend/Brevo dashboard | function secret `EMAIL_PROVIDER_KEY` | **YES — server only** |
| Routing URL | OSRM / self-hosted | function secret `ROUTING_PROVIDER_BASE_URL` | No |

## Golden rules (never break these)

1. **Never** commit a filled `.env` file or `google-services.json` — the repo's
   `.gitignore` blocks them for a reason.
2. **Never** put `SUPABASE_SERVICE_ROLE_KEY`, email keys, or OAuth secrets in
   Flutter code.
3. **Never** hardcode your Supabase project URL in `api_client.dart` — always
   pass it with `--dart-define`.
4. Public services (OpenStreetMap tiles, Nominatim) have usage policies —
   keep traffic light in development, and plan a paid provider for production.