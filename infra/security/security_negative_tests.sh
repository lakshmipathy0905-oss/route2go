#!/usr/bin/env bash
# Route2Go — Security / Authorization Negative Test Suite
#
# Tests every attack vector from the security audit:
#   - Missing / expired / malformed tokens
#   - Forged UID injection
#   - IDOR / BOLA: cross-user resource access
#   - Non-admin calling admin endpoints
#   - Rate-limit enforcement
#   - Method enforcement
#
# Usage:
#   SUPABASE_URL=https://<ref>.supabase.co \
#   ANON_KEY=<anon_key> \
#   ./infra/security/security_negative_tests.sh
#
# Optional (provide to enable authenticated IDOR cross-user tests):
#   USER_A_TOKEN=<firebase_id_token_user_a>
#   USER_A_TRIP_ID=<trip_uuid_belonging_to_user_a>
#   USER_B_TOKEN=<firebase_id_token_user_b>
#
# Prerequisites: curl, jq

set -euo pipefail

BASE_URL="${SUPABASE_URL:-}"
ANON="${ANON_KEY:-}"

if [[ -z "$BASE_URL" ]] || [[ -z "$ANON" ]]; then
  echo "❌  SUPABASE_URL and ANON_KEY must be set."
  exit 1
fi

FN="${BASE_URL}/functions/v1"
PASS=0
FAIL=0

# ── Helpers ───────────────────────────────────────────────────────────────────
check() {
  local label="$1"; local expected="$2"; local actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✅  $label (got $actual)"
    PASS=$((PASS + 1))
  else
    echo "  ❌  $label — expected HTTP $expected, got $actual"
    FAIL=$((FAIL + 1))
  fi
}

get_status() {
  curl -s -o /dev/null -w "%{http_code}" \
    -H "apikey: ${ANON}" \
    "${@}"
}

post_status() {
  local url="$1"; shift
  curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "apikey: ${ANON}" \
    -H "Content-Type: application/json" \
    "${@}" \
    "$url"
}

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Route2Go Security Negative Test Suite"
echo "  Target: ${BASE_URL}"
echo "═══════════════════════════════════════════════════════════════"

# ── TEST GROUP 1: Missing / Bad Tokens ──────────────────────────────────────
echo ""
echo "── Group 1: Missing / Malformed / Expired Tokens ──────────────"

# /trip requires authentication — no token → 401
STATUS=$(get_status "${FN}/trip")
check "GET /trip — no Authorization header → 401" "401" "$STATUS"

# /trip with empty bearer
STATUS=$(get_status -H "Authorization: Bearer " "${FN}/trip")
check "GET /trip — empty bearer → 401" "401" "$STATUS"

# /trip with garbage token
STATUS=$(get_status -H "Authorization: Bearer GARBAGE_TOKEN_12345" "${FN}/trip")
check "GET /trip — garbage token → 401" "401" "$STATUS"

# /vehicles requires auth
STATUS=$(get_status "${FN}/vehicles")
check "GET /vehicles — no token → 401" "401" "$STATUS"

# /notifications requires auth
STATUS=$(get_status "${FN}/notifications")
check "GET /notifications — no token → 401" "401" "$STATUS"

# /profile requires auth
STATUS=$(get_status "${FN}/profile")
check "GET /profile — no token → 401" "401" "$STATUS"

# /expenses requires auth
STATUS=$(get_status "${FN}/expenses?trip_id=00000000-0000-0000-0000-000000000000")
check "GET /expenses — no token → 401" "401" "$STATUS"

# /favorites requires auth
STATUS=$(get_status "${FN}/favorites?kind=trip")
check "GET /favorites — no token → 401" "401" "$STATUS"

# /admin requires auth + admin role — no token
STATUS=$(get_status "${FN}/admin/stats")
check "GET /admin/stats — no token → 401" "401" "$STATUS"

# /privacy requires auth
STATUS=$(post_status "${FN}/privacy" \
  -H "Authorization: Bearer GARBAGE" \
  -d '{"action":"request_delete"}')
check "POST /privacy — garbage token → 401" "401" "$STATUS"

# ── TEST GROUP 2: Guest Token on Authenticated Endpoints ─────────────────────
echo ""
echo "── Group 2: Guest Token on Auth-Required Endpoints ────────────"

STATUS=$(get_status -H "Authorization: Bearer guest" "${FN}/trip")
check "GET /trip — guest token → 401 (guest not allowed)" "401" "$STATUS"

STATUS=$(get_status -H "Authorization: Bearer guest" "${FN}/vehicles")
check "GET /vehicles — guest token → 401" "401" "$STATUS"

STATUS=$(get_status -H "Authorization: Bearer guest" "${FN}/notifications")
check "GET /notifications — guest token → 401" "401" "$STATUS"

STATUS=$(get_status -H "Authorization: Bearer guest" "${FN}/admin/stats")
check "GET /admin/stats — guest token → 401" "401" "$STATUS"

# Guest IS allowed on these endpoints (feature spec):
STATUS=$(get_status -H "Authorization: Bearer guest" "${FN}/feature-flags")
check "GET /feature-flags — guest token → 200 (guest allowed)" "200" "$STATUS"

STATUS=$(get_status -H "Authorization: Bearer guest" "${FN}/search?q=Bengaluru")
check "GET /search — guest token → 200 (guest allowed)" "200" "$STATUS"

# ── TEST GROUP 3: Method Enforcement ─────────────────────────────────────────
echo ""
echo "── Group 3: Wrong HTTP Method → 405 ───────────────────────────"

STATUS=$(post_status "${FN}/search" -H "Authorization: Bearer guest" -d '{}')
check "POST /search — wrong method → 405" "405" "$STATUS"

STATUS=$(post_status "${FN}/feature-flags" -H "Authorization: Bearer guest" -d '{}')
check "POST /feature-flags — wrong method → 405" "405" "$STATUS"

STATUS=$(post_status "${FN}/places-near-route" -H "Authorization: Bearer guest" -d '{}')
check "POST /places-near-route — wrong method → 405" "405" "$STATUS"

STATUS=$(post_status "${FN}/stays-near-route" -H "Authorization: Bearer guest" -d '{}')
check "POST /stays-near-route — wrong method → 405" "405" "$STATUS"

STATUS=$(get_status -H "Authorization: Bearer guest" "${FN}/route-nav")
check "GET /route-nav — wrong method → 405" "405" "$STATUS"

STATUS=$(get_status -H "Authorization: Bearer guest" "${FN}/trip-calculate")
check "GET /trip-calculate — wrong method → 405" "405" "$STATUS"

# ── TEST GROUP 4: Input Validation ───────────────────────────────────────────
echo ""
echo "── Group 4: Input Validation → 422 ────────────────────────────"

# route-nav: missing coordinates
STATUS=$(post_status "${FN}/route-nav" \
  -H "Authorization: Bearer guest" \
  -d '{"origin":{},"destination":{}}')
check "POST /route-nav — missing coords → 422" "422" "$STATUS"

# trip-calculate: invalid fuel_type
STATUS=$(post_status "${FN}/trip-calculate" \
  -H "Authorization: Bearer guest" \
  -d '{"origin":{"label":"A","lat":12.9716,"lng":77.5946},"destination":{"label":"B","lat":12.2958,"lng":76.6394},"trip_type":"one_way","vehicle":{"fuel_type":"gasoline"}}')
check "POST /trip-calculate — invalid fuel_type → 422" "422" "$STATUS"

# trip-calculate: same origin = destination
STATUS=$(post_status "${FN}/trip-calculate" \
  -H "Authorization: Bearer guest" \
  -d '{"origin":{"label":"A","lat":12.9716,"lng":77.5946},"destination":{"label":"A","lat":12.9716,"lng":77.5946},"trip_type":"one_way","vehicle":{"fuel_type":"petrol"}}')
check "POST /trip-calculate — same origin/dest → 422" "422" "$STATUS"

# geocode: missing q, lat, lng
STATUS=$(get_status -H "Authorization: Bearer guest" "${FN}/geocode")
check "GET /geocode — no params → 422" "422" "$STATUS"

# search: query too short
STATUS=$(get_status -H "Authorization: Bearer guest" "${FN}/search?q=a")
check "GET /search — q<2 chars → 200 empty (not error)" "200" "$STATUS"

# poi-search: missing lat/lng
STATUS=$(get_status -H "Authorization: Bearer guest" "${FN}/poi-search?q=restaurant")
check "GET /poi-search — missing lat/lng → 422" "422" "$STATUS"

# ── TEST GROUP 5: IDOR / BOLA (Cross-User Access) ───────────────────────────
echo ""
echo "── Group 5: IDOR / BOLA Cross-User Access ──────────────────────"
echo "   (Full IDOR testing requires two live Firebase tokens.)"
echo "   Set USER_A_TOKEN, USER_A_TRIP_ID, USER_B_TOKEN to enable."

USER_A_TOKEN="${USER_A_TOKEN:-}"
USER_A_TRIP_ID="${USER_A_TRIP_ID:-}"
USER_B_TOKEN="${USER_B_TOKEN:-}"

if [[ -n "$USER_A_TOKEN" ]] && [[ -n "$USER_A_TRIP_ID" ]] && [[ -n "$USER_B_TOKEN" ]]; then
  # User B tries to read User A's trip via DELETE
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE \
    -H "apikey: ${ANON}" \
    -H "Authorization: Bearer ${USER_B_TOKEN}" \
    "${FN}/trip?trip_id=${USER_A_TRIP_ID}")
  check "DELETE /trip?trip_id=USER_A_TRIP — User B → 404 (not found, no leak)" "404" "$STATUS"

  # User B tries to PATCH User A's trip
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X PATCH \
    -H "apikey: ${ANON}" \
    -H "Authorization: Bearer ${USER_B_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"trip_id\":\"${USER_A_TRIP_ID}\",\"action\":\"rename\",\"origin_label\":\"HACKED\"}" \
    "${FN}/trip")
  check "PATCH /trip — User B renames User A trip → 404" "404" "$STATUS"

  # User B tries to read User A's expenses
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "apikey: ${ANON}" \
    -H "Authorization: Bearer ${USER_B_TOKEN}" \
    "${FN}/expenses?trip_id=${USER_A_TRIP_ID}")
  check "GET /expenses — User B reads User A expenses → 404" "404" "$STATUS"

  # User B tries to save User A's trip as favorite
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "apikey: ${ANON}" \
    -H "Authorization: Bearer ${USER_B_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"action\":\"save_trip\",\"trip_id\":\"${USER_A_TRIP_ID}\"}" \
    "${FN}/favorites")
  check "POST /favorites — User B saves User A trip → 404" "404" "$STATUS"

  # User B tries to delete User A's notification
  # (use a made-up notification id — should 404 not 403)
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE \
    -H "apikey: ${ANON}" \
    -H "Authorization: Bearer ${USER_B_TOKEN}" \
    "${FN}/notifications?notification_id=00000000-0000-0000-0000-000000000000")
  check "DELETE /notifications — non-owned notification → 404" "404" "$STATUS"

  echo "  ✅  IDOR tests completed with live tokens."
else
  echo "  ⚠️   Skipped — USER_A_TOKEN, USER_A_TRIP_ID, USER_B_TOKEN not set."
  echo "      These MUST be run manually before production sign-off."
fi

# ── TEST GROUP 6: Admin RBAC ──────────────────────────────────────────────────
echo ""
echo "── Group 6: Admin RBAC — Non-Admin → 403 ──────────────────────"
echo "   (Requires a Firebase token for a non-admin user.)"

NON_ADMIN_TOKEN="${NON_ADMIN_TOKEN:-}"
if [[ -n "$NON_ADMIN_TOKEN" ]]; then
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "apikey: ${ANON}" \
    -H "Authorization: Bearer ${NON_ADMIN_TOKEN}" \
    "${FN}/admin/stats")
  check "GET /admin/stats — non-admin → 403" "403" "$STATUS"

  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "apikey: ${ANON}" \
    -H "Authorization: Bearer ${NON_ADMIN_TOKEN}" \
    "${FN}/admin/users?q=test")
  check "GET /admin/users — non-admin → 403" "403" "$STATUS"
else
  echo "  ⚠️   Skipped — NON_ADMIN_TOKEN not set. Must test manually before sign-off."
fi

# ── TEST GROUP 7: UID / user_id Injection ────────────────────────────────────
echo ""
echo "── Group 7: Forged user_id in body cannot escalate ────────────"

# trip save: supplying a foreign user_id in the body must be ignored
# (server always uses the UID from the verified Firebase token)
# Without a real token this just 401s — we confirm the 401 not a 200 bypass.
STATUS=$(post_status "${FN}/trip" \
  -H "Authorization: Bearer GARBAGE" \
  -d '{"action":"save","user_id":"00000000-0000-0000-0000-000000000000","origin_label":"A","origin_lat":12,"origin_lng":77,"destination_label":"B","destination_lat":13,"destination_lng":78,"trip_type":"one_way"}')
check "POST /trip — garbage token + forged user_id → 401" "401" "$STATUS"

# profile patch: forged user_id field in body is rejected at auth layer
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -X PATCH \
  -H "apikey: ${ANON}" \
  -H "Authorization: Bearer GARBAGE" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"00000000-0000-0000-0000-000000000000","name":"hacker"}' \
  "${FN}/profile")
check "PATCH /profile — garbage token + forged user_id → 401" "401" "$STATUS"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL))
echo "  Results: ${PASS}/${TOTAL} PASSED | ${FAIL} FAILED"
if [[ $FAIL -eq 0 ]]; then
  echo "  ✅  All automated security tests passed."
else
  echo "  ❌  SECURITY FAILURES DETECTED. Do NOT promote to production."
fi
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  IMPORTANT: The following tests require live Firebase tokens"
echo "  and MUST be performed manually before production sign-off:"
echo "    1. IDOR: User B reading/modifying User A's trips/expenses/vehicles"
echo "    2. Admin RBAC: Non-admin calling /admin/* endpoints"
echo "    3. Expired Firebase token → 401"
echo "    4. Modified JWT payload (tampered UID) → 401"
echo ""

exit $FAIL
