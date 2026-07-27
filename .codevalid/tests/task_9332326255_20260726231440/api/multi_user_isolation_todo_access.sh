#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
ALICE_EMAIL="alice-${CASE_SUFFIX}@example.com"
ALICE_PASSWORD="AlicePass-${CASE_SUFFIX}!"
ALICE_TITLE="Alice task ${CASE_SUFFIX}"
BOB_EMAIL="bob-${CASE_SUFFIX}@example.com"
BOB_PASSWORD="BobPass-${CASE_SUFFIX}!"
BOB_TITLE="Bob task ${CASE_SUFFIX}"

ALICE_COOKIE_JAR="/tmp/multi_user_isolation_todo_access_alice_cookie_${CASE_SUFFIX}.txt"
BOB_COOKIE_JAR="/tmp/multi_user_isolation_todo_access_bob_cookie_${CASE_SUFFIX}.txt"
ALICE_SIGNUP_HEADERS="/tmp/multi_user_isolation_todo_access_alice_signup_headers_${CASE_SUFFIX}.txt"
ALICE_SIGNUP_BODY="/tmp/multi_user_isolation_todo_access_alice_signup_body_${CASE_SUFFIX}.txt"
ALICE_LOGIN_HEADERS="/tmp/multi_user_isolation_todo_access_alice_login_headers_${CASE_SUFFIX}.txt"
ALICE_LOGIN_BODY="/tmp/multi_user_isolation_todo_access_alice_login_body_${CASE_SUFFIX}.txt"
ALICE_CREATE_HEADERS="/tmp/multi_user_isolation_todo_access_alice_create_headers_${CASE_SUFFIX}.txt"
ALICE_CREATE_BODY="/tmp/multi_user_isolation_todo_access_alice_create_body_${CASE_SUFFIX}.txt"
BOB_SIGNUP_HEADERS="/tmp/multi_user_isolation_todo_access_bob_signup_headers_${CASE_SUFFIX}.txt"
BOB_SIGNUP_BODY="/tmp/multi_user_isolation_todo_access_bob_signup_body_${CASE_SUFFIX}.txt"
BOB_LOGIN_HEADERS="/tmp/multi_user_isolation_todo_access_bob_login_headers_${CASE_SUFFIX}.txt"
BOB_LOGIN_BODY="/tmp/multi_user_isolation_todo_access_bob_login_body_${CASE_SUFFIX}.txt"
BOB_CREATE_HEADERS="/tmp/multi_user_isolation_todo_access_bob_create_headers_${CASE_SUFFIX}.txt"
BOB_CREATE_BODY="/tmp/multi_user_isolation_todo_access_bob_create_body_${CASE_SUFFIX}.txt"
ALICE_RESPONSE_HEADERS="/tmp/multi_user_isolation_todo_access_alice_response_headers_${CASE_SUFFIX}.txt"
ALICE_RESPONSE_BODY="/tmp/multi_user_isolation_todo_access_alice_response_body_${CASE_SUFFIX}.txt"
BOB_RESPONSE_HEADERS="/tmp/multi_user_isolation_todo_access_bob_response_headers_${CASE_SUFFIX}.txt"
BOB_RESPONSE_BODY="/tmp/multi_user_isolation_todo_access_bob_response_body_${CASE_SUFFIX}.txt"
ALICE_DELETE_HEADERS="/tmp/multi_user_isolation_todo_access_alice_delete_headers_${CASE_SUFFIX}.txt"
ALICE_DELETE_BODY="/tmp/multi_user_isolation_todo_access_alice_delete_body_${CASE_SUFFIX}.txt"
BOB_DELETE_HEADERS="/tmp/multi_user_isolation_todo_access_bob_delete_headers_${CASE_SUFFIX}.txt"
BOB_DELETE_BODY="/tmp/multi_user_isolation_todo_access_bob_delete_body_${CASE_SUFFIX}.txt"

ALICE_TODO_ID=""
BOB_TODO_ID=""

cleanup_files() {
  rm -f "$ALICE_COOKIE_JAR" "$BOB_COOKIE_JAR" \
    "$ALICE_SIGNUP_HEADERS" "$ALICE_SIGNUP_BODY" "$ALICE_LOGIN_HEADERS" "$ALICE_LOGIN_BODY" \
    "$ALICE_CREATE_HEADERS" "$ALICE_CREATE_BODY" "$BOB_SIGNUP_HEADERS" "$BOB_SIGNUP_BODY" \
    "$BOB_LOGIN_HEADERS" "$BOB_LOGIN_BODY" "$BOB_CREATE_HEADERS" "$BOB_CREATE_BODY" \
    "$ALICE_RESPONSE_HEADERS" "$ALICE_RESPONSE_BODY" "$BOB_RESPONSE_HEADERS" "$BOB_RESPONSE_BODY" \
    "$ALICE_DELETE_HEADERS" "$ALICE_DELETE_BODY" "$BOB_DELETE_HEADERS" "$BOB_DELETE_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — create two separate authenticated sessions and one todo per user"
echo "PREREQ: sign up Alice through the authentication API"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${ALICE_EMAIL}\",\"password\":\"***\"}"
alice_signup_code="$(curl -sS -c "$ALICE_COOKIE_JAR" -D "$ALICE_SIGNUP_HEADERS" -o "$ALICE_SIGNUP_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${ALICE_EMAIL}\",\"password\":\"${ALICE_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-up")"
echo "RESPONSE_HEADERS:"
cat "$ALICE_SIGNUP_HEADERS"
echo "RESPONSE_BODY:"
cat "$ALICE_SIGNUP_BODY"
echo
echo "RESPONSE_STATUS: $alice_signup_code"
[ "$alice_signup_code" = "200" ] || [ "$alice_signup_code" = "201" ] || { echo "ASSERTION_FAILED: expected Alice sign-up HTTP 200 or 201 got ${alice_signup_code}"; exit 1; }

echo "PREREQ: sign in Alice to establish a real session"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${ALICE_EMAIL}\",\"password\":\"***\"}"
alice_login_code="$(curl -sS -b "$ALICE_COOKIE_JAR" -c "$ALICE_COOKIE_JAR" -D "$ALICE_LOGIN_HEADERS" -o "$ALICE_LOGIN_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${ALICE_EMAIL}\",\"password\":\"${ALICE_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$ALICE_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$ALICE_LOGIN_BODY"
echo
echo "RESPONSE_STATUS: $alice_login_code"
[ "$alice_login_code" = "200" ] || { echo "ASSERTION_FAILED: expected Alice sign-in HTTP 200 got ${alice_login_code}"; exit 1; }

echo "PREREQ: create Alice's todo through the public API"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${ALICE_TITLE}\"}"
alice_create_code="$(curl -sS -b "$ALICE_COOKIE_JAR" -D "$ALICE_CREATE_HEADERS" -o "$ALICE_CREATE_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${ALICE_TITLE}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$ALICE_CREATE_HEADERS"
echo "RESPONSE_BODY:"
cat "$ALICE_CREATE_BODY"
echo
echo "RESPONSE_STATUS: $alice_create_code"
[ "$alice_create_code" = "200" ] || [ "$alice_create_code" = "201" ] || { echo "ASSERTION_FAILED: expected Alice create todo HTTP 200 or 201 got ${alice_create_code}"; exit 1; }
ALICE_TODO_ID="$(jq -r '.id // empty' "$ALICE_CREATE_BODY")"
[ -n "$ALICE_TODO_ID" ] || { echo "ASSERTION_FAILED: expected Alice create todo response to contain id"; exit 1; }

echo "PREREQ: sign up Bob through the authentication API"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${BOB_EMAIL}\",\"password\":\"***\"}"
bob_signup_code="$(curl -sS -c "$BOB_COOKIE_JAR" -D "$BOB_SIGNUP_HEADERS" -o "$BOB_SIGNUP_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${BOB_EMAIL}\",\"password\":\"${BOB_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-up")"
echo "RESPONSE_HEADERS:"
cat "$BOB_SIGNUP_HEADERS"
echo "RESPONSE_BODY:"
cat "$BOB_SIGNUP_BODY"
echo
echo "RESPONSE_STATUS: $bob_signup_code"
[ "$bob_signup_code" = "200" ] || [ "$bob_signup_code" = "201" ] || { echo "ASSERTION_FAILED: expected Bob sign-up HTTP 200 or 201 got ${bob_signup_code}"; exit 1; }

echo "PREREQ: sign in Bob to establish an independent session"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${BOB_EMAIL}\",\"password\":\"***\"}"
bob_login_code="$(curl -sS -b "$BOB_COOKIE_JAR" -c "$BOB_COOKIE_JAR" -D "$BOB_LOGIN_HEADERS" -o "$BOB_LOGIN_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${BOB_EMAIL}\",\"password\":\"${BOB_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$BOB_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$BOB_LOGIN_BODY"
echo
echo "RESPONSE_STATUS: $bob_login_code"
[ "$bob_login_code" = "200" ] || { echo "ASSERTION_FAILED: expected Bob sign-in HTTP 200 got ${bob_login_code}"; exit 1; }

echo "PREREQ: create Bob's todo through the public API"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${BOB_TITLE}\"}"
bob_create_code="$(curl -sS -b "$BOB_COOKIE_JAR" -D "$BOB_CREATE_HEADERS" -o "$BOB_CREATE_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${BOB_TITLE}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$BOB_CREATE_HEADERS"
echo "RESPONSE_BODY:"
cat "$BOB_CREATE_BODY"
echo
echo "RESPONSE_STATUS: $bob_create_code"
[ "$bob_create_code" = "200" ] || [ "$bob_create_code" = "201" ] || { echo "ASSERTION_FAILED: expected Bob create todo HTTP 200 or 201 got ${bob_create_code}"; exit 1; }
BOB_TODO_ID="$(jq -r '.id // empty' "$BOB_CREATE_BODY")"
[ -n "$BOB_TODO_ID" ] || { echo "ASSERTION_FAILED: expected Bob create todo response to contain id"; exit 1; }

# When
echo "STEP: When — retrieve todos using Alice's authenticated session"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
alice_status="$(curl -sS -b "$ALICE_COOKIE_JAR" -D "$ALICE_RESPONSE_HEADERS" -o "$ALICE_RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$ALICE_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$ALICE_RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $alice_status"

echo "STEP: When — retrieve todos using Bob's authenticated session"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
bob_status="$(curl -sS -b "$BOB_COOKIE_JAR" -D "$BOB_RESPONSE_HEADERS" -o "$BOB_RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$BOB_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$BOB_RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $bob_status"

# Then
echo "STEP: Then — verify each session can only access its own todo item"
[ "$alice_status" = "200" ] || { echo "ASSERTION_FAILED: expected Alice HTTP 200 got ${alice_status}"; exit 1; }
[ "$bob_status" = "200" ] || { echo "ASSERTION_FAILED: expected Bob HTTP 200 got ${bob_status}"; exit 1; }
jq -e --arg title "$ALICE_TITLE" 'map(select(.title == $title)) | length == 1' "$ALICE_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Alice response to include Alice task"; exit 1; }
jq -e --arg id "$ALICE_TODO_ID" 'map(select((.id|tostring) == $id)) | length == 1' "$ALICE_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Alice response to include Alice todo id ${ALICE_TODO_ID}"; exit 1; }
jq -e --arg title "$BOB_TITLE" 'map(select(.title == $title)) | length == 0' "$ALICE_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: Alice response unexpectedly included Bob task"; exit 1; }
jq -e --arg id "$BOB_TODO_ID" 'map(select((.id|tostring) == $id)) | length == 0' "$ALICE_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: Alice response unexpectedly included Bob todo id ${BOB_TODO_ID}"; exit 1; }
jq -e --arg title "$BOB_TITLE" 'map(select(.title == $title)) | length == 1' "$BOB_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Bob response to include Bob task"; exit 1; }
jq -e --arg id "$BOB_TODO_ID" 'map(select((.id|tostring) == $id)) | length == 1' "$BOB_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Bob response to include Bob todo id ${BOB_TODO_ID}"; exit 1; }
jq -e --arg title "$ALICE_TITLE" 'map(select(.title == $title)) | length == 0' "$BOB_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: Bob response unexpectedly included Alice task"; exit 1; }
jq -e --arg id "$ALICE_TODO_ID" 'map(select((.id|tostring) == $id)) | length == 0' "$BOB_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: Bob response unexpectedly included Alice todo id ${ALICE_TODO_ID}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — delete the todos created for Alice and Bob"
if [ -n "$ALICE_TODO_ID" ]; then
  echo "PREREQ: delete Alice todo ${ALICE_TODO_ID}"
  alice_delete_code="$(curl -sS -b "$ALICE_COOKIE_JAR" -D "$ALICE_DELETE_HEADERS" -o "$ALICE_DELETE_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$ALICE_TODO_ID")"
  [ "$alice_delete_code" = "200" ] || [ "$alice_delete_code" = "404" ] || { echo "ASSERTION_FAILED: expected Alice delete HTTP 200 or 404 got ${alice_delete_code}"; exit 1; }
fi
if [ -n "$BOB_TODO_ID" ]; then
  echo "PREREQ: delete Bob todo ${BOB_TODO_ID}"
  bob_delete_code="$(curl -sS -b "$BOB_COOKIE_JAR" -D "$BOB_DELETE_HEADERS" -o "$BOB_DELETE_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$BOB_TODO_ID")"
  [ "$bob_delete_code" = "200" ] || [ "$bob_delete_code" = "404" ] || { echo "ASSERTION_FAILED: expected Bob delete HTTP 200 or 404 got ${bob_delete_code}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:multi_user_isolation_todo_access"
