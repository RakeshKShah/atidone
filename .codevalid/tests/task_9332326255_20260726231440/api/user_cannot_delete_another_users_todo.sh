#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="user_cannot_delete_another_users_todo"
ALICE_COOKIE_JAR="/tmp/${TEST_ID}_alice_cookies_${CASE_SUFFIX}.txt"
BOB_COOKIE_JAR="/tmp/${TEST_ID}_bob_cookies_${CASE_SUFFIX}.txt"
ALICE_LOGIN_HEADERS="/tmp/${TEST_ID}_alice_login_headers_${CASE_SUFFIX}.txt"
ALICE_LOGIN_BODY="/tmp/${TEST_ID}_alice_login_body_${CASE_SUFFIX}.txt"
BOB_LOGIN_HEADERS="/tmp/${TEST_ID}_bob_login_headers_${CASE_SUFFIX}.txt"
BOB_LOGIN_BODY="/tmp/${TEST_ID}_bob_login_body_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"
BOB_LIST_HEADERS="/tmp/${TEST_ID}_bob_list_headers_${CASE_SUFFIX}.txt"
BOB_LIST_BODY="/tmp/${TEST_ID}_bob_list_body_${CASE_SUFFIX}.txt"
TITLE="Bob private todo ${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$ALICE_COOKIE_JAR" "$BOB_COOKIE_JAR" "$ALICE_LOGIN_HEADERS" "$ALICE_LOGIN_BODY" "$BOB_LOGIN_HEADERS" "$BOB_LOGIN_BODY" "$CREATE_HEADERS" "$CREATE_BODY" "$DELETE_HEADERS" "$DELETE_BODY" "$BOB_LIST_HEADERS" "$BOB_LIST_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — establish Alice and Bob sessions and create a Bob-owned todo"
echo "PREREQ: log in as Alice"
ALICE_LOGIN_REQUEST='{"userId":"user-alice","name":"Alice"}'
echo "REQUEST_HEADERS:"
printf 'Content-Type: application/json\n'
echo "REQUEST_BODY:"
printf '%s\n' "$ALICE_LOGIN_REQUEST"
alice_login_code="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -c "$ALICE_COOKIE_JAR" \
  -D "$ALICE_LOGIN_HEADERS" \
  -o "$ALICE_LOGIN_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/test-auth/login" \
  --data "$ALICE_LOGIN_REQUEST")"
echo "RESPONSE_HEADERS:"
cat "$ALICE_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$ALICE_LOGIN_BODY"
echo "RESPONSE_STATUS: $alice_login_code"
[ "$alice_login_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${alice_login_code}"; exit 1; }

echo "PREREQ: log in as Bob"
BOB_LOGIN_REQUEST='{"userId":"user-bob","name":"Bob"}'
echo "REQUEST_HEADERS:"
printf 'Content-Type: application/json\n'
echo "REQUEST_BODY:"
printf '%s\n' "$BOB_LOGIN_REQUEST"
bob_login_code="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -c "$BOB_COOKIE_JAR" \
  -D "$BOB_LOGIN_HEADERS" \
  -o "$BOB_LOGIN_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/test-auth/login" \
  --data "$BOB_LOGIN_REQUEST")"
echo "RESPONSE_HEADERS:"
cat "$BOB_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$BOB_LOGIN_BODY"
echo "RESPONSE_STATUS: $bob_login_code"
[ "$bob_login_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${bob_login_code}"; exit 1; }

echo "PREREQ: create Bob-owned todo through Bob session"
CREATE_REQUEST="{\"title\":\"$TITLE\"}"
echo "REQUEST_HEADERS:"
printf 'Content-Type: application/json\n'
printf 'Cookie jar: %s\n' "$BOB_COOKIE_JAR"
echo "REQUEST_BODY:"
printf '%s\n' "$CREATE_REQUEST"
create_code="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -b "$BOB_COOKIE_JAR" \
  -c "$BOB_COOKIE_JAR" \
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
[ -n "$TODO_ID" ] || { echo "ASSERTION_FAILED: expected Bob-created todo id in response body"; exit 1; }

# When — perform the action under test
echo "STEP: When — Alice attempts to delete Bob's todo"
echo "REQUEST_HEADERS:"
printf 'Cookie jar: %s\n' "$ALICE_COOKIE_JAR"
echo "REQUEST_BODY:"
printf '\n'
delete_code="$(curl -sS -X DELETE \
  -b "$ALICE_COOKIE_JAR" \
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
echo "STEP: Then — Alice receives not found and Bob's todo remains visible to Bob"
[ "$delete_code" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${delete_code}"; exit 1; }
grep -F 'Todo not found' "$DELETE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Todo not found message in response body"; exit 1; }

bob_list_code="$(curl -sS -X GET \
  -b "$BOB_COOKIE_JAR" \
  -D "$BOB_LIST_HEADERS" \
  -o "$BOB_LIST_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$BOB_LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$BOB_LIST_BODY"
echo "RESPONSE_STATUS: $bob_list_code"
[ "$bob_list_code" = "200" ] || { echo "ASSERTION_FAILED: expected Bob list HTTP 200 got ${bob_list_code}"; exit 1; }
grep -F '"id":"'"$TODO_ID"'"' "$BOB_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Bob todo $TODO_ID to remain after Alice delete attempt"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — delete Bob's seeded todo and clear both sessions"
curl -sS -X DELETE \
  -b "$BOB_COOKIE_JAR" \
  -o /dev/null \
  "$BASE_URL/api/todos/$TODO_ID" >/dev/null 2>&1 || true
curl -sS -X POST -b "$ALICE_COOKIE_JAR" -o /dev/null "$BASE_URL/api/test-auth/logout" >/dev/null 2>&1 || true
curl -sS -X POST -b "$BOB_COOKIE_JAR" -o /dev/null "$BASE_URL/api/test-auth/logout" >/dev/null 2>&1 || true

echo "CODEVALID_TEST_ASSERTION_OK:user_cannot_delete_another_users_todo"
