#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_invalid_title_type_rejected"
COOKIE_FILE="${COOKIE_FILE:-${AUTH_COOKIE_FILE:-}}"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"
RESPONSE_HEADERS_FILE="/tmp/${TEST_ID}_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY_FILE="/tmp/${TEST_ID}_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$REQUEST_BODY_FILE" "$RESPONSE_HEADERS_FILE" "$RESPONSE_BODY_FILE"
}
trap cleanup_files EXIT

cat > "$REQUEST_BODY_FILE" <<'JSON'
{"title":12345}
JSON

# Given — bring the system to the required state
echo "STEP: Given — ensure authenticated session cookie file is available"
echo "PREREQ: validate COOKIE_FILE or AUTH_COOKIE_FILE points to an existing authenticated cookie jar"
[ -n "$COOKIE_FILE" ] || { echo "ASSERTION_FAILED: expected COOKIE_FILE or AUTH_COOKIE_FILE for authenticated request"; exit 1; }
[ -f "$COOKIE_FILE" ] || { echo "ASSERTION_FAILED: cookie file not found at $COOKIE_FILE"; exit 1; }

# When — perform the action under test
echo "STEP: When — POST create todo request with non-string title"
echo "REQUEST_HEADERS: Content-Type: application/json; Cookie jar from $COOKIE_FILE"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
code="$(curl -sS -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -b "$COOKIE_FILE" \
  -D "$RESPONSE_HEADERS_FILE" \
  -o "$RESPONSE_BODY_FILE" \
  -w '%{http_code}' \
  --data @"$REQUEST_BODY_FILE" || true)"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — request is rejected for invalid title type"
[ "$code" = "400" ] || [ "$code" = "422" ] || { echo "ASSERTION_FAILED: expected HTTP 400 or 422 got ${code}"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no cleanup required because invalid request should not create data"

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_invalid_title_type_rejected"
