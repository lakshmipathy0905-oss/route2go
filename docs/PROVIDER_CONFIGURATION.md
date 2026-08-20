# Provider Configuration

## 1. Authentication
- **Provider**: Firebase Authentication
- **Methods**: Google, Email/Password, Phone OTP, Anonymous (Guest)
- **Configuration**: Managed via `google-services.json` and `GoogleService-Info.plist`

## 2. Database & API Gateway
- **Provider**: Supabase
- **Configuration**: Postgres Database with Row Level Security (RLS). Edge functions handle business logic.

## 3. Map Tiles
- **Provider**: Configurable (e.g., Carto, Mapbox, Stadia)
- **Production URL**: Passed at compile time via `--dart-define=MAP_TILE_URL_TEMPLATE`
- **Fallback**: Fails closed if missing.

## 4. Routing Engine
- **Provider**: Valhalla (or equivalent OSRM/GraphHopper)
- **Configuration**: Edge Function secret `VALHALLA_BASE_URL`.
- **Fallback**: Fails closed if missing.

## 5. Crash Reporting & Analytics
- **Provider**: Firebase Crashlytics & Analytics
- **Configuration**: Initialized automatically via Firebase Core.
