#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_unauthenticated_rejected"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_FILE"
}
trap cleanup_files EXIT

printf '%s' '{"title":"Complete project report"}' > "$REQUEST_BODY_FILE"

# Given — bring the system to the required state
SHORT_GIVEN="no authentication credentials are sent"
echo "STEP: Given — ${SHORT_GIVEN}"
echo "PREREQ: ensuring request is sent without cookie or authorization header"

# When — perform the action under test
SHORT_WHEN="attempt unauthenticated POST /api/todos"
echo "STEP: When — ${SHORT_WHEN}"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
code="$({
  curl -sS -X POST "$BASE_URL/api/todos" \
    -H 'Content-Type: application/json' \
    -D "$HEADERS_FILE" \
    -o "$BODY_FILE" \
    -w '%{http_code}' \
    --data @"$REQUEST_BODY_FILE"
} || true)"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
SHORT_THEN="request is rejected before todo creation"
echo "STEP: Then — ${SHORT_THEN}"
[ "$code" = "401" ] || [ "$code" = "403" ] || { echo "ASSERTION_FAILED: expected HTTP 401 or 403 got ${code}"; exit 1; }
grep -Ei 'auth|unauthor|forbidden|session|login' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected authentication-related error message in response body"; exit 1; }

# Cleanup — undo Given side effects
SHORT_CLEANUP="no cleanup required for rejected unauthenticated request"
echo "STEP: Cleanup — ${SHORT_CLEANUP}"

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_unauthenticated_rejected"
