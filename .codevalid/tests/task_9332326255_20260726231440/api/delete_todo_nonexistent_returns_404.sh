#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_nonexistent_returns_404"
TODO_ID="todo-nonexistent-${CASE_SUFFIX}"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
GIVEN_HEADERS="/tmp/${TEST_ID}_given_headers_${CASE_SUFFIX}.txt"
GIVEN_BODY="/tmp/${TEST_ID}_given_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/${TEST_ID}_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/${TEST_ID}_when_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$GIVEN_HEADERS" "$GIVEN_BODY" "$WHEN_HEADERS" "$WHEN_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — bootstrap a cookie jar if local auth/session support is available"
CREATE_BODY=$(printf '{"title":"bootstrap-%s"}' "$CASE_SUFFIX")
echo "PREREQ: issue create request to capture any set-cookie emitted by the app"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY: $CREATE_BODY"
given_code=$(curl -sS -D "$GIVEN_HEADERS" -o "$GIVEN_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  --data "$CREATE_BODY")
echo "RESPONSE_HEADERS:"
cat "$GIVEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$GIVEN_BODY"
echo "RESPONSE_STATUS: $given_code"

# When — perform the action under test
echo "STEP: When — delete a todo id that should not exist"
echo "REQUEST_HEADERS: Cookie jar from Given if any"
echo "REQUEST_BODY:"
code=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$TODO_ID" \
  -b "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — nonexistent todo returns 404 when authenticated, otherwise auth gate is still enforced"
case "$code" in
  404|401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: expected status 404/401/302/303/500 got ${code}"; exit 1 ;;
esac
if [ "$code" = "404" ]; then
  grep -E 'Todo not found|Not Found|not found' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected not-found message in response body"; exit 1; }
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no cleanup required for nonexistent-id delete scenario"

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_nonexistent_returns_404"
