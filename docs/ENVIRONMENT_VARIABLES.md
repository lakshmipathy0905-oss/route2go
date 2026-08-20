# Environment Variables

## Client Build Variables (`--dart-define`)
- `MAP_TILE_URL_TEMPLATE`: The URL template for map tiles. MUST be set for production builds. (e.g., `https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png`)
- `SUPABASE_URL`: The URL for the Supabase project.
- `SUPABASE_ANON_KEY`: The anonymous public key for the Supabase project.

## Supabase Edge Function Secrets
- `VALHALLA_BASE_URL`: The base URL for the production Valhalla routing engine. MUST be set in production to prevent failing closed.
- `SUPABASE_SERVICE_ROLE_KEY`: Automatically provided by the Supabase environment. Used for bypassing RLS in secure server-side operations.

## Local `.env` (Development Only)
See `.env.example` for the required local development variables used by `supabase start`.
