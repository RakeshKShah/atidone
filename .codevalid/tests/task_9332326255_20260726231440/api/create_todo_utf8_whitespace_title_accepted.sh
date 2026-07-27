#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_utf8_whitespace_title_accepted"
COOKIE_FILE="${COOKIE_FILE:-${AUTH_COOKIE_FILE:-}}"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"
RESPONSE_HEADERS_FILE="/tmp/${TEST_ID}_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY_FILE="/tmp/${TEST_ID}_response_body_${CASE_SUFFIX}.txt"
CLEANUP_HEADERS_FILE="/tmp/${TEST_ID}_cleanup_headers_${CASE_SUFFIX}.txt"
CLEANUP_BODY_FILE="/tmp/${TEST_ID}_cleanup_body_${CASE_SUFFIX}.txt"
TITLE="   Buy 超市 groceries 🥑 ${CASE_SUFFIX}  "
CREATED_ID=""

cleanup_files() {
  rm -f "$REQUEST_BODY_FILE" "$RESPONSE_HEADERS_FILE" "$RESPONSE_BODY_FILE" "$CLEANUP_HEADERS_FILE" "$CLEANUP_BODY_FILE"
}
trap cleanup_files EXIT

printf '{"title":"%s"}' "$TITLE" > "$REQUEST_BODY_FILE"

# Given — bring the system to the required state
echo "STEP: Given — ensure authenticated session cookie file is available"
echo "PREREQ: validate COOKIE_FILE or AUTH_COOKIE_FILE points to an existing authenticated cookie jar"
[ -n "$COOKIE_FILE" ] || { echo "ASSERTION_FAILED: expected COOKIE_FILE or AUTH_COOKIE_FILE for authenticated request"; exit 1; }
[ -f "$COOKIE_FILE" ] || { echo "ASSERTION_FAILED: cookie file not found at $COOKIE_FILE"; exit 1; }

# When — perform the action under test
echo "STEP: When — POST create todo request with UTF-8 and surrounding whitespace in title"
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
echo "STEP: Then — response preserves the exact title string"
[ "$code" = "200" ] || [ "$code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 200 or 201 got ${code}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  CREATED_ID="$(jq -r '.id' "$RESPONSE_BODY_FILE")"
  [ "$CREATED_ID" != "null" ] && [ -n "$CREATED_ID" ] || { echo "ASSERTION_FAILED: expected response id"; exit 1; }
  RESPONSE_TITLE="$(jq -r '.title' "$RESPONSE_BODY_FILE")"
  [ "$RESPONSE_TITLE" = "$TITLE" ] || { echo "ASSERTION_FAILED: expected exact title preservation got '$RESPONSE_TITLE'"; exit 1; }
else
  grep -F "$TITLE" "$RESPONSE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain exact UTF-8 title"; exit 1; }
  CREATED_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$RESPONSE_BODY_FILE" | head -n 1)"
  [ -n "$CREATED_ID" ] || { echo "ASSERTION_FAILED: expected response body to contain id"; exit 1; }
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — delete the created todo"
if [ -n "$CREATED_ID" ]; then
  echo "PREREQ: deleting todo id $CREATED_ID created by this test"
  cleanup_code="$(curl -sS -X DELETE "$BASE_URL/api/todos/$CREATED_ID" \
    -b "$COOKIE_FILE" \
    -D "$CLEANUP_HEADERS_FILE" \
    -o "$CLEANUP_BODY_FILE" \
    -w '%{http_code}' || true)"
  echo "RESPONSE_HEADERS:"
  cat "$CLEANUP_HEADERS_FILE"
  echo "RESPONSE_BODY:"
  cat "$CLEANUP_BODY_FILE"
  echo "RESPONSE_STATUS: $cleanup_code"
  [ "$cleanup_code" = "200" ] || { echo "ASSERTION_FAILED: expected cleanup HTTP 200 got ${cleanup_code}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_utf8_whitespace_title_accepted"
