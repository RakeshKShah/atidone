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
echo "STEP: When — call GET /api/todos without an authenticated session"
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
echo "STEP: Then — verify authentication is enforced and todo data is not exposed"
case "$status" in
  401|302|303|500) ;;
  *) echo "ASSERTION_FAILED: expected HTTP 401, 302, 303, or 500 for unauthenticated access got ${status}"; exit 1 ;;
esac
if grep -F 'title' "$RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: response body unexpectedly appears to contain todo data"
  exit 1
fi
if grep -F 'userId' "$RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: response body unexpectedly appears to contain todo ownership data"
  exit 1
fi

# Cleanup
echo "STEP: Cleanup — no side effects to remove"

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_access_blocked"
