#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/authenticated_access_to_todos_succeeds_cookie_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/authenticated_access_to_todos_succeeds_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/authenticated_access_to_todos_succeeds_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — require a valid authenticated session cookie for alice"
ALICE_COOKIE="${ALICE_COOKIE:-}"
[ -n "$ALICE_COOKIE" ] || { echo "ASSERTION_FAILED: ALICE_COOKIE environment variable is required for this authenticated test"; exit 1; }
: > "$COOKIE_JAR"
printf '%s\n' "$ALICE_COOKIE" > "$COOKIE_JAR"
echo "PREREQ: wrote provided ALICE_COOKIE to cookie jar"

echo "STEP: When — request authenticated todo listing via public API"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR" -c "$COOKIE_JAR" "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo
echo "RESPONSE_STATUS: $status"

echo "STEP: Then — verify authenticated access succeeds and returns alice todo data"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
BODY_CONTENT="$(cat "$BODY_FILE")"
printf '%s' "$BODY_CONTENT" | grep -F 'Buy groceries' >/dev/null 2>&1 || {
  echo "ASSERTION_FAILED: expected response to include alice todo title 'Buy groceries'"
  exit 1
}
if command -v jq >/dev/null 2>&1; then
  jq -e 'type == "array"' "$BODY_FILE" >/dev/null 2>&1 || {
    echo "ASSERTION_FAILED: expected /api/todos response body to be a JSON array"
    exit 1
  }
fi

echo "STEP: Cleanup — remove temporary files only"
echo "CODEVALID_TEST_ASSERTION_OK:authenticated_access_to_todos_succeeds"
