#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
HEADERS_FILE="/tmp/unauthenticated_request_blocked_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/unauthenticated_request_blocked_body_${CASE_SUFFIX}.txt"
COOKIE_JAR="/tmp/unauthenticated_request_blocked_cookies_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$COOKIE_JAR"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — ensure no authenticated session is present"
: > "$COOKIE_JAR"
echo "PREREQ: using empty cookie jar and no Authorization header"

# When
echo "STEP: When — request GET /api/todos without authentication"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY:"
printf '\n'
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' \
  -H 'Accept: application/json' \
  -b "$COOKIE_JAR" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $status"

# Then
echo "STEP: Then — access is blocked and no todo data is returned"
if [ "$status" != "401" ] && [ "$status" != "302" ]; then
  echo "ASSERTION_FAILED: expected HTTP 401 or 302 got ${status}"
  exit 1
fi
! grep -F 'Buy groceries' "$BODY_FILE" || { echo "ASSERTION_FAILED: unauthenticated response exposed todo data"; exit 1; }
! grep -F 'Read book' "$BODY_FILE" || { echo "ASSERTION_FAILED: unauthenticated response exposed todo data"; exit 1; }
! grep -F 'Alice task' "$BODY_FILE" || { echo "ASSERTION_FAILED: unauthenticated response exposed todo data"; exit 1; }
! grep -F 'Charlie task' "$BODY_FILE" || { echo "ASSERTION_FAILED: unauthenticated response exposed todo data"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no stateful setup to remove"

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_request_blocked"
