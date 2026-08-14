#!/bin/sh
# Route2Go Valhalla entrypoint: download extract (once), build tiles (once),
# then serve the routing API.
#
# Tunables (env):
#   OSM_EXTRACT_URL   mandatory — an .osm.pbf extract (Geofabrik style).
#                     Choose the smallest region that covers your market to keep
#                     tile builds fast. Examples:
#                       Asia/India: https://download.geofabrik.de/asia/india-latest.osm.pbf
#                       Europe/UK:  https://download.geofabrik.de/europe/great-britain-latest.osm.pbf
#                       North America: https://download.geofabrik.de/north-america/us/northeast-latest.osm.pbf
#   VALHALLA_CONCURRENCY  CPU threads for the tile build (default: 1).
set -eu

DATA=/data
TILES="$DATA/tiles"
ADMIN="$DATA/admin"
PBF="$DATA/extract.osm.pbf"
CONFIG="$DATA/valhalla.json"
BUILT_MARKER="$DATA/.tiles-built"

mkdir -p "$DATA" "$TILES" "$ADMIN"

# 1. Fetch the extract once.
if [ ! -f "$PBF" ]; then
  echo "[valhalla] downloading $OSM_EXTRACT_URL"
  curl -fL --retry 3 -o "$PBF" "$OSM_EXTRACT_URL"
fi

# 2. Generate the server config pointing at local tile/admin dirs.
echo "[valhalla] writing $CONFIG"
valhalla_build_config \
  --mjolnir-tile-dir "$TILES" \
  --mjolnir-admin-dir "$ADMIN" \
  --mjolnir-tile-extract "$DATA/tiles.tar" \
  > "$CONFIG"

# 3. Build tiles once. Skip on restart (container restart is fast).
if [ ! -f "$BUILT_MARKER" ]; then
  echo "[valhalla] building admin database"
  valhalla_build_admins -c "$CONFIG" "$PBF"
  echo "[valhalla] building tiles (this can take a while)"
  valhalla_build_tiles -c "$CONFIG" -j "${VALHALLA_CONCURRENCY:-1}" "$PBF"
  echo "[valhalla] building tile extract"
  valhalla_build_extract -c "$CONFIG" -e "$DATA/tiles.tar"
  touch "$BUILT_MARKER"
fi

# 4. Serve.
echo "[valhalla] serving on :8002"
exec valhalla_service "$CONFIG"