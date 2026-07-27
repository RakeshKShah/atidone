#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_empty_title_validation_error"
COOKIE_FILE="${COOKIE_FILE:-${AUTH_COOKIE_FILE:-}}"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_FILE"
}
trap cleanup_files EXIT

printf '%s' '{"title":""}' > "$REQUEST_BODY_FILE"

# Given — bring the system to the required state
SHORT_GIVEN="authenticated user session exists"
echo "STEP: Given — ${SHORT_GIVEN}"
echo "PREREQ: verify authenticated cookie file is provided"
[ -n "$COOKIE_FILE" ] || { echo "ASSERTION_FAILED: expected COOKIE_FILE or AUTH_COOKIE_FILE for authenticated request"; exit 1; }
[ -f "$COOKIE_FILE" ] || { echo "ASSERTION_FAILED: cookie file not found at $COOKIE_FILE"; exit 1; }

# When — perform the action under test
SHORT_WHEN="submit POST /api/todos with empty title"
echo "STEP: When — ${SHORT_WHEN}"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
code="$({
  curl -sS -X POST "$BASE_URL/api/todos" \
    -H 'Content-Type: application/json' \
    -b "$COOKIE_FILE" \
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
SHORT_THEN="schema validation rejects empty title"
echo "STEP: Then — ${SHORT_THEN}"
[ "$code" = "400" ] || [ "$code" = "422" ] || { echo "ASSERTION_FAILED: expected HTTP 400 or 422 got ${code}"; exit 1; }
grep -Ei 'title|required|invalid|validation|empty' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected validation message for empty title"; exit 1; }

# Cleanup — undo Given side effects
SHORT_CLEANUP="no cleanup required because creation failed"
echo "STEP: Cleanup — ${SHORT_CLEANUP}"

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_empty_title_validation_error"
