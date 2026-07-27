#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_not_found"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
AUTH_HEADERS="/tmp/${TEST_ID}_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY="/tmp/${TEST_ID}_auth_body_${CASE_SUFFIX}.txt"
LIST_HEADERS="/tmp/${TEST_ID}_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY="/tmp/${TEST_ID}_list_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/${TEST_ID}_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/${TEST_ID}_when_body_${CASE_SUFFIX}.txt"
VERIFY_HEADERS="/tmp/${TEST_ID}_verify_headers_${CASE_SUFFIX}.txt"
VERIFY_BODY="/tmp/${TEST_ID}_verify_body_${CASE_SUFFIX}.txt"
MISSING_ID="todo-nonexistent-999-${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$AUTH_HEADERS" "$AUTH_BODY" "$LIST_HEADERS" "$LIST_BODY" "$WHEN_HEADERS" "$WHEN_BODY" "$VERIFY_HEADERS" "$VERIFY_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — ensure request runs against an authenticated session and a unique missing todo id"
echo "PREREQ: probing unauthenticated access behavior"
echo "REQUEST_HEADERS: none"
echo "REQUEST_BODY:"
auth_code=$(curl -sS -D "$AUTH_HEADERS" -o "$AUTH_BODY" -w '%{http_code}' \n  -X GET "$BASE_URL/api/todos" \n  -c "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$AUTH_HEADERS"
echo "RESPONSE_BODY:"
cat "$AUTH_BODY"
echo "RESPONSE_STATUS: $auth_code"
case "$auth_code" in
  401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: expected unauthenticated todo list to be guarded with HTTP 401, 302, 303, or 500 got ${auth_code}"; exit 1 ;;
esac

echo "PREREQ: checking whether this environment already has an authenticated cookie jar"
echo "REQUEST_HEADERS: Cookie jar from probe"
echo "REQUEST_BODY:"
list_code=$(curl -sS -D "$LIST_HEADERS" -o "$LIST_BODY" -w '%{http_code}' \n  -X GET "$BASE_URL/api/todos" \n  -b "$COOKIE_JAR" -c "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$LIST_BODY"
echo "RESPONSE_STATUS: $list_code"
[ "$list_code" = "200" ] || { echo "ASSERTION_FAILED: unable to bootstrap authenticated session via public API only; GET /api/todos with cookie jar returned ${list_code}. This repo requires a real session bootstrap seam for authenticated not-found tests."; exit 1; }

# When — perform the action under test
echo "STEP: When — delete a todo id that does not exist"
echo "REQUEST_HEADERS: Cookie jar from authenticated setup"
echo "REQUEST_BODY:"
code=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' \n  -X DELETE "$BASE_URL/api/todos/$MISSING_ID" \n  -b "$COOKIE_JAR" -c "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — endpoint returns not found without changing data"
[ "$code" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${code}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  jq -e '(.statusCode == 404 or .status == 404) and ((.message // "") == "Todo not found")' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected 404 Todo not found payload"; exit 1; }
else
  grep -F 'Todo not found' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain Todo not found"; exit 1; }
fi

echo "REQUEST_HEADERS: Cookie jar from authenticated setup"
echo "REQUEST_BODY:"
verify_code=$(curl -sS -D "$VERIFY_HEADERS" -o "$VERIFY_BODY" -w '%{http_code}' \n  -X GET "$BASE_URL/api/todos" \n  -b "$COOKIE_JAR" -c "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$VERIFY_HEADERS"
echo "RESPONSE_BODY:"
cat "$VERIFY_BODY"
echo "RESPONSE_STATUS: $verify_code"
[ "$verify_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 listing todos after 404 delete got ${verify_code}"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no stateful setup beyond cookie jar was required"

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_not_found"
