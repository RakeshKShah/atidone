#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"

RESPONSE_HEADERS="/tmp/unauthenticated_access_blocked_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/unauthenticated_access_blocked_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare an unauthenticated request context"
echo "PREREQ: no Cookie header and no Authorization header will be sent"

# When
echo "STEP: When — call GET /api/todos without authentication"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
status="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $status"

# Then
echo "STEP: Then — verify authentication is required and no todo data is exposed"
[ "$status" = "401" ] || { echo "ASSERTION_FAILED: expected HTTP 401 got ${status}"; exit 1; }
if grep -F 'title' "$RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: response body unexpectedly appears to contain todo data"
  exit 1
fi
if grep -F 'userId' "$RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: response body unexpectedly appears to contain user todo ownership data"
  exit 1
fi

# Cleanup
echo "STEP: Cleanup — no side effects to remove"

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_access_blocked"
