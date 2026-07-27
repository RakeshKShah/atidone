#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="unauthenticated_user_cannot_delete_todo"
OWNER_COOKIE_JAR="/tmp/${TEST_ID}_owner_cookies_${CASE_SUFFIX}.txt"
OWNER_LOGIN_HEADERS="/tmp/${TEST_ID}_owner_login_headers_${CASE_SUFFIX}.txt"
OWNER_LOGIN_BODY="/tmp/${TEST_ID}_owner_login_body_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"
LIST_HEADERS="/tmp/${TEST_ID}_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY="/tmp/${TEST_ID}_list_body_${CASE_SUFFIX}.txt"
TITLE="Protected todo ${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$OWNER_COOKIE_JAR" "$OWNER_LOGIN_HEADERS" "$OWNER_LOGIN_BODY" "$CREATE_HEADERS" "$CREATE_BODY" "$DELETE_HEADERS" "$DELETE_BODY" "$LIST_HEADERS" "$LIST_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — create a todo for one user and make no authenticated session for the delete request"
echo "PREREQ: log in as the todo owner"
LOGIN_REQUEST='{"userId":"user-456","name":"User 456"}'
echo "REQUEST_HEADERS:"
printf 'Content-Type: application/json\n'
echo "REQUEST_BODY:"
printf '%s\n' "$LOGIN_REQUEST"
owner_login_code="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -c "$OWNER_COOKIE_JAR" \
  -D "$OWNER_LOGIN_HEADERS" \
  -o "$OWNER_LOGIN_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/test-auth/login" \
  --data "$LOGIN_REQUEST")"
echo "RESPONSE_HEADERS:"
cat "$OWNER_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$OWNER_LOGIN_BODY"
echo "RESPONSE_STATUS: $owner_login_code"
[ "$owner_login_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${owner_login_code}"; exit 1; }

echo "PREREQ: create a todo that should remain undeleted"
CREATE_REQUEST="{\"title\":\"$TITLE\"}"
echo "REQUEST_HEADERS:"
printf 'Content-Type: application/json\n'
printf 'Cookie jar: %s\n' "$OWNER_COOKIE_JAR"
echo "REQUEST_BODY:"
printf '%s\n' "$CREATE_REQUEST"
create_code="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -b "$OWNER_COOKIE_JAR" \
  -c "$OWNER_COOKIE_JAR" \
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
echo "STEP: When — send delete request without any session cookie"
echo "REQUEST_HEADERS:"
printf 'Cookie: \n'
echo "REQUEST_BODY:"
printf '\n'
delete_code="$(curl -sS -X DELETE \
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
echo "STEP: Then — unauthenticated delete is rejected and the todo remains in the owner's list"
[ "$delete_code" = "401" ] || [ "$delete_code" = "302" ] || [ "$delete_code" = "303" ] || [ "$delete_code" = "500" ] || { echo "ASSERTION_FAILED: expected HTTP 401, 302, 303, or 500 got ${delete_code}"; exit 1; }

list_code="$(curl -sS -X GET \
  -b "$OWNER_COOKIE_JAR" \
  -D "$LIST_HEADERS" \
  -o "$LIST_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$LIST_BODY"
echo "RESPONSE_STATUS: $list_code"
[ "$list_code" = "200" ] || { echo "ASSERTION_FAILED: expected owner list HTTP 200 got ${list_code}"; exit 1; }
grep -F '"id":"'"$TODO_ID"'"' "$LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected todo $TODO_ID to remain in owner list"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — delete the seeded todo with the owner session and clear owner session"
curl -sS -X DELETE \
  -b "$OWNER_COOKIE_JAR" \
  -o /dev/null \
  "$BASE_URL/api/todos/$TODO_ID" >/dev/null 2>&1 || true
curl -sS -X POST \
  -b "$OWNER_COOKIE_JAR" \
  -o /dev/null \
  "$BASE_URL/api/test-auth/logout" >/dev/null 2>&1 || true

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_cannot_delete_todo"
