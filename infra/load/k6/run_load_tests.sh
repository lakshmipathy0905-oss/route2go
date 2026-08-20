#!/usr/bin/env bash
# Route2Go — k6 load-test runner
#
# Usage:
#   ./infra/load/k6/run_load_tests.sh [scenario] [vus] [profile]
#
# Examples:
#   ./run_load_tests.sh full_suite 10 baseline    # 10 VU smoke test
#   ./run_load_tests.sh full_suite 50 baseline    # 50 VU baseline
#   ./run_load_tests.sh full_suite 100 baseline   # 100 VU baseline
#   ./run_load_tests.sh full_suite 500 plan       # 500 VU sustained plan
#   ./run_load_tests.sh full_suite 1000 plan      # 1000 VU stress test
#
# Required environment variables:
#   K6_SUPABASE_URL        — https://<ref>.supabase.co
#   K6_SUPABASE_ANON_KEY   — anon/public key from Supabase dashboard
#
# Optional:
#   K6_FIREBASE_TOKEN      — valid Firebase ID token for authenticated endpoints
#
# Prerequisites:
#   brew install k6   OR   https://k6.io/docs/get-started/installation/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Arguments ────────────────────────────────────────────────────────────────
SCENARIO="${1:-full_suite}"
VUS="${2:-10}"
PROFILE="${3:-baseline}"

# ── Validate environment ──────────────────────────────────────────────────────
if [[ -z "${K6_SUPABASE_URL:-}" ]]; then
  echo "❌  K6_SUPABASE_URL is not set. Export it before running."
  echo "    export K6_SUPABASE_URL=https://<ref>.supabase.co"
  exit 1
fi

if [[ -z "${K6_SUPABASE_ANON_KEY:-}" ]]; then
  echo "❌  K6_SUPABASE_ANON_KEY is not set. Export it before running."
  echo "    export K6_SUPABASE_ANON_KEY=<your_anon_key>"
  exit 1
fi

if ! command -v k6 &>/dev/null; then
  echo "❌  k6 is not installed. Install it:"
  echo "    brew install k6   (macOS)"
  echo "    https://k6.io/docs/get-started/installation/ (other)"
  exit 1
fi

# ── Output directory ──────────────────────────────────────────────────────────
RESULTS_DIR="${SCRIPT_DIR}/results"
mkdir -p "${RESULTS_DIR}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RESULT_FILE="${RESULTS_DIR}/${SCENARIO}_vus${VUS}_${PROFILE}_${TIMESTAMP}.json"
SUMMARY_FILE="${RESULTS_DIR}/${SCENARIO}_vus${VUS}_${PROFILE}_${TIMESTAMP}_summary.txt"

echo ""
echo "┌─────────────────────────────────────────────────┐"
echo "│  Route2Go Load Test                             │"
echo "├─────────────────────────────────────────────────┤"
echo "│  Scenario : ${SCENARIO}"
echo "│  VUs      : ${VUS}"
echo "│  Profile  : ${PROFILE}"
echo "│  Target   : ${K6_SUPABASE_URL}"
echo "│  Results  : ${RESULT_FILE}"
echo "└─────────────────────────────────────────────────┘"
echo ""

# ── Run k6 ───────────────────────────────────────────────────────────────────
k6 run \
  --out "json=${RESULT_FILE}" \
  --summary-trend-stats "avg,min,med,max,p(50),p(90),p(95),p(99),p(99.9),count" \
  -e "K6_SUPABASE_URL=${K6_SUPABASE_URL}" \
  -e "K6_SUPABASE_ANON_KEY=${K6_SUPABASE_ANON_KEY}" \
  -e "K6_FIREBASE_TOKEN=${K6_FIREBASE_TOKEN:-}" \
  -e "K6_TARGET_VUS=${VUS}" \
  -e "K6_PROFILE=${PROFILE}" \
  "${SCRIPT_DIR}/scenarios/${SCENARIO}.js" 2>&1 | tee "${SUMMARY_FILE}"

EXIT_CODE=$?

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "✅  Load test PASSED — all thresholds met."
else
  echo "❌  Load test FAILED — one or more thresholds breached. Check ${SUMMARY_FILE}"
fi

echo "    Results JSON: ${RESULT_FILE}"
echo "    Summary txt : ${SUMMARY_FILE}"
exit $EXIT_CODE
