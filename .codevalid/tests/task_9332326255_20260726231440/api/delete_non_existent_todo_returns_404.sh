#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_non_existent_todo_returns_404"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
LOGIN_HEADERS="/tmp/${TEST_ID}_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY="/tmp/${TEST_ID}_login_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"
LIST_HEADERS="/tmp/${TEST_ID}_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY="/tmp/${TEST_ID}_list_body_${CASE_SUFFIX}.txt"
NONEXISTENT_ID="nonexistent-todo-999-${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$LOGIN_HEADERS" "$LOGIN_BODY" "$DELETE_HEADERS" "$DELETE_BODY" "$LIST_HEADERS" "$LIST_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — establish authenticated session and use a guaranteed-unique nonexistent todo id"
echo "PREREQ: log in as the test user"
LOGIN_REQUEST='{"userId":"user-test","name":"User Test"}'
echo "REQUEST_HEADERS:"
printf 'Content-Type: application/json\n'
echo "REQUEST_BODY:"
printf '%s\n' "$LOGIN_REQUEST"
login_code="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -c "$COOKIE_JAR" \
  -D "$LOGIN_HEADERS" \
  -o "$LOGIN_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/test-auth/login" \
  --data "$LOGIN_REQUEST")"
echo "RESPONSE_HEADERS:"
cat "$LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$LOGIN_BODY"
echo "RESPONSE_STATUS: $login_code"
[ "$login_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${login_code}"; exit 1; }

# When — perform the action under test
echo "STEP: When — delete a todo id that does not exist"
echo "REQUEST_HEADERS:"
printf 'Cookie jar: %s\n' "$COOKIE_JAR"
echo "REQUEST_BODY:"
printf '\n'
delete_code="$(curl -sS -X DELETE \
  -b "$COOKIE_JAR" \
  -D "$DELETE_HEADERS" \
  -o "$DELETE_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/$NONEXISTENT_ID")"
echo "RESPONSE_HEADERS:"
cat "$DELETE_HEADERS"
echo "RESPONSE_BODY:"
cat "$DELETE_BODY"
echo "RESPONSE_STATUS: $delete_code"

# Then — HTTP/body assertions
echo "STEP: Then — not found is returned for the nonexistent todo id"
[ "$delete_code" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${delete_code}"; exit 1; }
grep -F 'Todo not found' "$DELETE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Todo not found message in response body"; exit 1; }

list_code="$(curl -sS -X GET \
  -b "$COOKIE_JAR" \
  -D "$LIST_HEADERS" \
  -o "$LIST_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$LIST_BODY"
echo "RESPONSE_STATUS: $list_code"
[ "$list_code" = "200" ] || { echo "ASSERTION_FAILED: expected list HTTP 200 got ${list_code}"; exit 1; }
if grep -F '"id":"'"$NONEXISTENT_ID"'"' "$LIST_BODY" >/dev/null; then
  echo "ASSERTION_FAILED: expected nonexistent todo id $NONEXISTENT_ID to remain absent from list"
  exit 1
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — clear authenticated session"
curl -sS -X POST \
  -b "$COOKIE_JAR" \
  -o /dev/null \
  "$BASE_URL/api/test-auth/logout" >/dev/null 2>&1 || true

echo "CODEVALID_TEST_ASSERTION_OK:delete_non_existent_todo_returns_404"
