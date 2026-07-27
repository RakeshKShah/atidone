#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
ALICE_EMAIL="codevalid-alice-${CASE_SUFFIX}@example.com"
ALICE_PASSWORD="CodevalidAlice-${CASE_SUFFIX}!"
BOB_EMAIL="codevalid-bob-${CASE_SUFFIX}@example.com"
BOB_PASSWORD="CodevalidBob-${CASE_SUFFIX}!"
ALICE_TITLE_ONE="alice-todo-1-${CASE_SUFFIX}"
ALICE_TITLE_TWO="alice-todo-2-${CASE_SUFFIX}"
BOB_TITLE_ONE="bob-todo-1-${CASE_SUFFIX}"
BOB_TITLE_TWO="bob-todo-2-${CASE_SUFFIX}"

ALICE_COOKIE_JAR="/tmp/multi_user_isolation_enforced_alice_cookie_${CASE_SUFFIX}.txt"
BOB_COOKIE_JAR="/tmp/multi_user_isolation_enforced_bob_cookie_${CASE_SUFFIX}.txt"
ALICE_SIGNUP_HEADERS="/tmp/multi_user_isolation_enforced_alice_signup_headers_${CASE_SUFFIX}.txt"
ALICE_SIGNUP_BODY="/tmp/multi_user_isolation_enforced_alice_signup_body_${CASE_SUFFIX}.txt"
ALICE_LOGIN_HEADERS="/tmp/multi_user_isolation_enforced_alice_login_headers_${CASE_SUFFIX}.txt"
ALICE_LOGIN_BODY="/tmp/multi_user_isolation_enforced_alice_login_body_${CASE_SUFFIX}.txt"
BOB_SIGNUP_HEADERS="/tmp/multi_user_isolation_enforced_bob_signup_headers_${CASE_SUFFIX}.txt"
BOB_SIGNUP_BODY="/tmp/multi_user_isolation_enforced_bob_signup_body_${CASE_SUFFIX}.txt"
BOB_LOGIN_HEADERS="/tmp/multi_user_isolation_enforced_bob_login_headers_${CASE_SUFFIX}.txt"
BOB_LOGIN_BODY="/tmp/multi_user_isolation_enforced_bob_login_body_${CASE_SUFFIX}.txt"
ALICE_CREATE1_HEADERS="/tmp/multi_user_isolation_enforced_alice_create1_headers_${CASE_SUFFIX}.txt"
ALICE_CREATE1_BODY="/tmp/multi_user_isolation_enforced_alice_create1_body_${CASE_SUFFIX}.txt"
ALICE_CREATE2_HEADERS="/tmp/multi_user_isolation_enforced_alice_create2_headers_${CASE_SUFFIX}.txt"
ALICE_CREATE2_BODY="/tmp/multi_user_isolation_enforced_alice_create2_body_${CASE_SUFFIX}.txt"
BOB_CREATE1_HEADERS="/tmp/multi_user_isolation_enforced_bob_create1_headers_${CASE_SUFFIX}.txt"
BOB_CREATE1_BODY="/tmp/multi_user_isolation_enforced_bob_create1_body_${CASE_SUFFIX}.txt"
BOB_CREATE2_HEADERS="/tmp/multi_user_isolation_enforced_bob_create2_headers_${CASE_SUFFIX}.txt"
BOB_CREATE2_BODY="/tmp/multi_user_isolation_enforced_bob_create2_body_${CASE_SUFFIX}.txt"
ALICE_LIST_HEADERS="/tmp/multi_user_isolation_enforced_alice_list_headers_${CASE_SUFFIX}.txt"
ALICE_LIST_BODY="/tmp/multi_user_isolation_enforced_alice_list_body_${CASE_SUFFIX}.txt"
BOB_LIST_HEADERS="/tmp/multi_user_isolation_enforced_bob_list_headers_${CASE_SUFFIX}.txt"
BOB_LIST_BODY="/tmp/multi_user_isolation_enforced_bob_list_body_${CASE_SUFFIX}.txt"
ALICE_DELETE1_HEADERS="/tmp/multi_user_isolation_enforced_alice_delete1_headers_${CASE_SUFFIX}.txt"
ALICE_DELETE1_BODY="/tmp/multi_user_isolation_enforced_alice_delete1_body_${CASE_SUFFIX}.txt"
ALICE_DELETE2_HEADERS="/tmp/multi_user_isolation_enforced_alice_delete2_headers_${CASE_SUFFIX}.txt"
ALICE_DELETE2_BODY="/tmp/multi_user_isolation_enforced_alice_delete2_body_${CASE_SUFFIX}.txt"
BOB_DELETE1_HEADERS="/tmp/multi_user_isolation_enforced_bob_delete1_headers_${CASE_SUFFIX}.txt"
BOB_DELETE1_BODY="/tmp/multi_user_isolation_enforced_bob_delete1_body_${CASE_SUFFIX}.txt"
BOB_DELETE2_HEADERS="/tmp/multi_user_isolation_enforced_bob_delete2_headers_${CASE_SUFFIX}.txt"
BOB_DELETE2_BODY="/tmp/multi_user_isolation_enforced_bob_delete2_body_${CASE_SUFFIX}.txt"

ALICE_TODO_ID_1=""
ALICE_TODO_ID_2=""
BOB_TODO_ID_1=""
BOB_TODO_ID_2=""

cleanup_files() {
  rm -f "$ALICE_COOKIE_JAR" "$BOB_COOKIE_JAR" \
    "$ALICE_SIGNUP_HEADERS" "$ALICE_SIGNUP_BODY" "$ALICE_LOGIN_HEADERS" "$ALICE_LOGIN_BODY" \
    "$BOB_SIGNUP_HEADERS" "$BOB_SIGNUP_BODY" "$BOB_LOGIN_HEADERS" "$BOB_LOGIN_BODY" \
    "$ALICE_CREATE1_HEADERS" "$ALICE_CREATE1_BODY" "$ALICE_CREATE2_HEADERS" "$ALICE_CREATE2_BODY" \
    "$BOB_CREATE1_HEADERS" "$BOB_CREATE1_BODY" "$BOB_CREATE2_HEADERS" "$BOB_CREATE2_BODY" \
    "$ALICE_LIST_HEADERS" "$ALICE_LIST_BODY" "$BOB_LIST_HEADERS" "$BOB_LIST_BODY" \
    "$ALICE_DELETE1_HEADERS" "$ALICE_DELETE1_BODY" "$ALICE_DELETE2_HEADERS" "$ALICE_DELETE2_BODY" \
    "$BOB_DELETE1_HEADERS" "$BOB_DELETE1_BODY" "$BOB_DELETE2_HEADERS" "$BOB_DELETE2_BODY"
}
trap cleanup_files EXIT

# Given

echo "STEP: Given — create two separate authenticated users and seed isolated todos through public APIs"
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

echo "PREREQ: sign in Alice to establish a session"
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

echo "PREREQ: sign in Bob to establish a separate session"
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

echo "PREREQ: create Alice todo #1"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${ALICE_TITLE_ONE}\"}"
alice_create1_code="$(curl -sS -b "$ALICE_COOKIE_JAR" -D "$ALICE_CREATE1_HEADERS" -o "$ALICE_CREATE1_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${ALICE_TITLE_ONE}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$ALICE_CREATE1_HEADERS"
echo "RESPONSE_BODY:"
cat "$ALICE_CREATE1_BODY"
echo
echo "RESPONSE_STATUS: $alice_create1_code"
[ "$alice_create1_code" = "200" ] || [ "$alice_create1_code" = "201" ] || { echo "ASSERTION_FAILED: expected Alice create todo #1 HTTP 200 or 201 got ${alice_create1_code}"; exit 1; }
ALICE_TODO_ID_1="$(jq -r '.id // empty' "$ALICE_CREATE1_BODY")"
[ -n "$ALICE_TODO_ID_1" ] || { echo "ASSERTION_FAILED: expected Alice create todo #1 response to contain id"; exit 1; }

echo "PREREQ: create Alice todo #2"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${ALICE_TITLE_TWO}\"}"
alice_create2_code="$(curl -sS -b "$ALICE_COOKIE_JAR" -D "$ALICE_CREATE2_HEADERS" -o "$ALICE_CREATE2_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${ALICE_TITLE_TWO}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$ALICE_CREATE2_HEADERS"
echo "RESPONSE_BODY:"
cat "$ALICE_CREATE2_BODY"
echo
echo "RESPONSE_STATUS: $alice_create2_code"
[ "$alice_create2_code" = "200" ] || [ "$alice_create2_code" = "201" ] || { echo "ASSERTION_FAILED: expected Alice create todo #2 HTTP 200 or 201 got ${alice_create2_code}"; exit 1; }
ALICE_TODO_ID_2="$(jq -r '.id // empty' "$ALICE_CREATE2_BODY")"
[ -n "$ALICE_TODO_ID_2" ] || { echo "ASSERTION_FAILED: expected Alice create todo #2 response to contain id"; exit 1; }

echo "PREREQ: create Bob todo #1"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${BOB_TITLE_ONE}\"}"
bob_create1_code="$(curl -sS -b "$BOB_COOKIE_JAR" -D "$BOB_CREATE1_HEADERS" -o "$BOB_CREATE1_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${BOB_TITLE_ONE}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$BOB_CREATE1_HEADERS"
echo "RESPONSE_BODY:"
cat "$BOB_CREATE1_BODY"
echo
echo "RESPONSE_STATUS: $bob_create1_code"
[ "$bob_create1_code" = "200" ] || [ "$bob_create1_code" = "201" ] || { echo "ASSERTION_FAILED: expected Bob create todo #1 HTTP 200 or 201 got ${bob_create1_code}"; exit 1; }
BOB_TODO_ID_1="$(jq -r '.id // empty' "$BOB_CREATE1_BODY")"
[ -n "$BOB_TODO_ID_1" ] || { echo "ASSERTION_FAILED: expected Bob create todo #1 response to contain id"; exit 1; }

echo "PREREQ: create Bob todo #2"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${BOB_TITLE_TWO}\"}"
bob_create2_code="$(curl -sS -b "$BOB_COOKIE_JAR" -D "$BOB_CREATE2_HEADERS" -o "$BOB_CREATE2_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${BOB_TITLE_TWO}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$BOB_CREATE2_HEADERS"
echo "RESPONSE_BODY:"
cat "$BOB_CREATE2_BODY"
echo
echo "RESPONSE_STATUS: $bob_create2_code"
[ "$bob_create2_code" = "200" ] || [ "$bob_create2_code" = "201" ] || { echo "ASSERTION_FAILED: expected Bob create todo #2 HTTP 200 or 201 got ${bob_create2_code}"; exit 1; }
BOB_TODO_ID_2="$(jq -r '.id // empty' "$BOB_CREATE2_BODY")"
[ -n "$BOB_TODO_ID_2" ] || { echo "ASSERTION_FAILED: expected Bob create todo #2 response to contain id"; exit 1; }

# When

echo "STEP: When — retrieve Alice and Bob todo lists in separate authenticated sessions"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
alice_status="$(curl -sS -b "$ALICE_COOKIE_JAR" -D "$ALICE_LIST_HEADERS" -o "$ALICE_LIST_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$ALICE_LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$ALICE_LIST_BODY"
echo
echo "RESPONSE_STATUS: $alice_status"

echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
bob_status="$(curl -sS -b "$BOB_COOKIE_JAR" -D "$BOB_LIST_HEADERS" -o "$BOB_LIST_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$BOB_LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$BOB_LIST_BODY"
echo
echo "RESPONSE_STATUS: $bob_status"

# Then

echo "STEP: Then — verify each authenticated user only sees their own todos and never the other user's data"
[ "$alice_status" = "200" ] || { echo "ASSERTION_FAILED: expected Alice list HTTP 200 got ${alice_status}"; exit 1; }
[ "$bob_status" = "200" ] || { echo "ASSERTION_FAILED: expected Bob list HTTP 200 got ${bob_status}"; exit 1; }
jq -e --arg title "$ALICE_TITLE_ONE" 'map(select(.title == $title)) | length == 1' "$ALICE_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Alice response to include ${ALICE_TITLE_ONE}"; exit 1; }
jq -e --arg title "$ALICE_TITLE_TWO" 'map(select(.title == $title)) | length == 1' "$ALICE_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Alice response to include ${ALICE_TITLE_TWO}"; exit 1; }
jq -e --arg title "$BOB_TITLE_ONE" 'map(select(.title == $title)) | length == 0' "$ALICE_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: Alice response unexpectedly included ${BOB_TITLE_ONE}"; exit 1; }
jq -e --arg title "$BOB_TITLE_TWO" 'map(select(.title == $title)) | length == 0' "$ALICE_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: Alice response unexpectedly included ${BOB_TITLE_TWO}"; exit 1; }
jq -e --arg title "$BOB_TITLE_ONE" 'map(select(.title == $title)) | length == 1' "$BOB_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Bob response to include ${BOB_TITLE_ONE}"; exit 1; }
jq -e --arg title "$BOB_TITLE_TWO" 'map(select(.title == $title)) | length == 1' "$BOB_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Bob response to include ${BOB_TITLE_TWO}"; exit 1; }
jq -e --arg title "$ALICE_TITLE_ONE" 'map(select(.title == $title)) | length == 0' "$BOB_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: Bob response unexpectedly included ${ALICE_TITLE_ONE}"; exit 1; }
jq -e --arg title "$ALICE_TITLE_TWO" 'map(select(.title == $title)) | length == 0' "$BOB_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: Bob response unexpectedly included ${ALICE_TITLE_TWO}"; exit 1; }

# Cleanup

echo "STEP: Cleanup — delete all todos created for both users"
if [ -n "$ALICE_TODO_ID_1" ]; then
  echo "PREREQ: delete Alice todo ${ALICE_TODO_ID_1}"
  alice_delete1_code="$(curl -sS -b "$ALICE_COOKIE_JAR" -D "$ALICE_DELETE1_HEADERS" -o "$ALICE_DELETE1_BODY" -w '%{http_code}' -X DELETE "$BASE_URL/api/todos/$ALICE_TODO_ID_1")"
  echo "RESPONSE_HEADERS:"
  cat "$ALICE_DELETE1_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$ALICE_DELETE1_BODY"
  echo
  echo "RESPONSE_STATUS: $alice_delete1_code"
  [ "$alice_delete1_code" = "200" ] || [ "$alice_delete1_code" = "404" ] || { echo "ASSERTION_FAILED: expected Alice delete #1 HTTP 200 or 404 got ${alice_delete1_code}"; exit 1; }
fi
if [ -n "$ALICE_TODO_ID_2" ]; then
  echo "PREREQ: delete Alice todo ${ALICE_TODO_ID_2}"
  alice_delete2_code="$(curl -sS -b "$ALICE_COOKIE_JAR" -D "$ALICE_DELETE2_HEADERS" -o "$ALICE_DELETE2_BODY" -w '%{http_code}' -X DELETE "$BASE_URL/api/todos/$ALICE_TODO_ID_2")"
  echo "RESPONSE_HEADERS:"
  cat "$ALICE_DELETE2_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$ALICE_DELETE2_BODY"
  echo
  echo "RESPONSE_STATUS: $alice_delete2_code"
  [ "$alice_delete2_code" = "200" ] || [ "$alice_delete2_code" = "404" ] || { echo "ASSERTION_FAILED: expected Alice delete #2 HTTP 200 or 404 got ${alice_delete2_code}"; exit 1; }
fi
if [ -n "$BOB_TODO_ID_1" ]; then
  echo "PREREQ: delete Bob todo ${BOB_TODO_ID_1}"
  bob_delete1_code="$(curl -sS -b "$BOB_COOKIE_JAR" -D "$BOB_DELETE1_HEADERS" -o "$BOB_DELETE1_BODY" -w '%{http_code}' -X DELETE "$BASE_URL/api/todos/$BOB_TODO_ID_1")"
  echo "RESPONSE_HEADERS:"
  cat "$BOB_DELETE1_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$BOB_DELETE1_BODY"
  echo
  echo "RESPONSE_STATUS: $bob_delete1_code"
  [ "$bob_delete1_code" = "200" ] || [ "$bob_delete1_code" = "404" ] || { echo "ASSERTION_FAILED: expected Bob delete #1 HTTP 200 or 404 got ${bob_delete1_code}"; exit 1; }
fi
if [ -n "$BOB_TODO_ID_2" ]; then
  echo "PREREQ: delete Bob todo ${BOB_TODO_ID_2}"
  bob_delete2_code="$(curl -sS -b "$BOB_COOKIE_JAR" -D "$BOB_DELETE2_HEADERS" -o "$BOB_DELETE2_BODY" -w '%{http_code}' -X DELETE "$BASE_URL/api/todos/$BOB_TODO_ID_2")"
  echo "RESPONSE_HEADERS:"
  cat "$BOB_DELETE2_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$BOB_DELETE2_BODY"
  echo
  echo "RESPONSE_STATUS: $bob_delete2_code"
  [ "$bob_delete2_code" = "200" ] || [ "$bob_delete2_code" = "404" ] || { echo "ASSERTION_FAILED: expected Bob delete #2 HTTP 200 or 404 got ${bob_delete2_code}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:multi_user_isolation_enforced"
