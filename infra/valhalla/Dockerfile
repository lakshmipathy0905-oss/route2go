# Self-hosted Valhalla for Route2Go production routing.
#
# Builds a tiles extract from an OSM PBF on first start, then serves the
# Valhalla routing API on :8002. Point Route2Go's functions at it with:
#
#   supabase secrets set VALHALLA_BASE_URL=http://<host>:8002
#
# Dev/test must NOT use the public demo endpoints (valhalla1.openstreetmap.de)
# for production load — they are rate-limited and unsupported. Self-host instead.

FROM ghcr.io/valhalla/valhalla:latest

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /work

COPY scripts/entrypoint.sh /scripts/entrypoint.sh
RUN chmod +x /scripts/entrypoint.sh

EXPOSE 8002

ENTRYPOINT ["/bin/sh", "/scripts/entrypoint.sh"]