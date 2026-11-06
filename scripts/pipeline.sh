#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:-citybike:v1}"
TEST_PORT=4174
PROD_PORT=4173
TARGET_URL="http://localhost:${TEST_PORT}"
CONTAINER="citybike-pipeline"
PROD_API_KEY="${PROD_API_KEY:-citybike-lab-secret}"

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

run_stage() {
  local stage="$1"
  local gate="$2"
  local env_name="$3"

  echo
  echo "========== ${stage} =========="
  cleanup

  docker run -d --name "$CONTAINER" \
    -p "${TEST_PORT}:4173" \
    -e "APP_ENV=${env_name}" \
    -e "PROD_API_KEY=${PROD_API_KEY}" \
    "$IMAGE" >/dev/null

  sleep 2

  TARGET_URL="$TARGET_URL" IMAGE_NAME="$IMAGE" \
    bash "scripts/${gate}"

  cleanup
  echo "========== ${stage} PASSED =========="
}

echo "Pipeline image: $IMAGE"

run_stage "STAGING" "test-staging.sh" "staging"
run_stage "UAT" "test-uat.sh" "uat"
run_stage "OAT" "test-oat.sh" "oat"
run_stage "PRE-PRODUCTION" "test-preprod.sh" "preprod"

echo
echo "========== PRODUCTION DEPLOYMENT =========="
docker rm -f citybike-v1 >/dev/null 2>&1 || true

docker run -d --name citybike-v1 \
  -p "${PROD_PORT}:4173" \
  -e APP_ENV=production \
  -e "PROD_API_KEY=${PROD_API_KEY}" \
  "$IMAGE"

TARGET_URL="http://localhost:${PROD_PORT}" \
  bash scripts/test-prod.sh

echo
echo "SUCCESS: All five quality gates passed."
echo "Production container: citybike-v1"
