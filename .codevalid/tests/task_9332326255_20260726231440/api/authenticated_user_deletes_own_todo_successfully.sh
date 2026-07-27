#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="authenticated_user_deletes_own_todo_successfully"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
LOGIN_HEADERS="/tmp/${TEST_ID}_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY="/tmp/${TEST_ID}_login_body_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"
LIST_HEADERS="/tmp/${TEST_ID}_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY="/tmp/${TEST_ID}_list_body_${CASE_SUFFIX}.txt"
TITLE="Buy groceries ${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$LOGIN_HEADERS" "$LOGIN_BODY" "$CREATE_HEADERS" "$CREATE_BODY" "$DELETE_HEADERS" "$DELETE_BODY" "$LIST_HEADERS" "$LIST_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — establish authenticated session and create an owned todo via public API"
echo "PREREQ: log in using the repo test auth flow"
LOGIN_REQUEST='{"userId":"user-123","name":"User 123"}'
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

CREATE_REQUEST="{\"title\":\"$TITLE\"}"
echo "PREREQ: create todo owned by the authenticated user"
echo "REQUEST_HEADERS:"
printf 'Content-Type: application/json\n'
printf 'Cookie jar: %s\n' "$COOKIE_JAR"
echo "REQUEST_BODY:"
printf '%s\n' "$CREATE_REQUEST"
create_code="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -b "$COOKIE_JAR" \
  -c "$COOKIE_JAR" \
  -D "$CREATE_HEADERS" \
  -o "$CREATE_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos" \
  --data "$CREATE_REQUEST")"
echo "RESPONSE_HEADERS:"
cat "$CREATE_HEADERS"
echo "RESPONSE_BODY:"
cat "$CREATE_BODY"
echo "RESPONSE_STATUS: $create_code"
[ "$create_code" = "200" ] || [ "$create_code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 200 or 201 got ${create_code}"; exit 1; }
TODO_ID="$(jq -r '.id // empty' "$CREATE_BODY")"
[ -n "$TODO_ID" ] || { echo "ASSERTION_FAILED: expected created todo id in response body"; exit 1; }

# When — perform the action under test
echo "STEP: When — delete the authenticated user's own todo"
echo "REQUEST_HEADERS:"
printf 'Cookie jar: %s\n' "$COOKIE_JAR"
echo "REQUEST_BODY:"
printf '\n'
delete_code="$(curl -sS -X DELETE \
  -b "$COOKIE_JAR" \
  -D "$DELETE_HEADERS" \
  -o "$DELETE_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/$TODO_ID")"
echo "RESPONSE_HEADERS:"
cat "$DELETE_HEADERS"
echo "RESPONSE_BODY:"
cat "$DELETE_BODY"
echo "RESPONSE_STATUS: $delete_code"

# Then — HTTP/body assertions
echo "STEP: Then — response returns the deleted todo and the todo is absent from subsequent listing"
[ "$delete_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${delete_code}"; exit 1; }
grep -F '"id":"'"$TODO_ID"'"' "$DELETE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected deleted response to contain todo id $TODO_ID"; exit 1; }
grep -F '"title":"'"$TITLE"'"' "$DELETE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected deleted response to contain title $TITLE"; exit 1; }

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
if grep -F '"id":"'"$TODO_ID"'"' "$LIST_BODY" >/dev/null; then
  echo "ASSERTION_FAILED: expected deleted todo $TODO_ID to be absent from todo list"
  exit 1
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — attempt idempotent delete and clear authenticated session"
curl -sS -X DELETE \
  -b "$COOKIE_JAR" \
  -o /dev/null \
  "$BASE_URL/api/todos/$TODO_ID" >/dev/null 2>&1 || true
curl -sS -X POST \
  -b "$COOKIE_JAR" \
  -o /dev/null \
  "$BASE_URL/api/test-auth/logout" >/dev/null 2>&1 || true

echo "CODEVALID_TEST_ASSERTION_OK:authenticated_user_deletes_own_todo_successfully"
