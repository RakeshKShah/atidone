#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
CHARLIE_EMAIL="charlie-${CASE_SUFFIX}@example.com"
CHARLIE_PASSWORD="CodevalidCharlie-${CASE_SUFFIX}!"
DIANA_EMAIL="diana-${CASE_SUFFIX}@example.com"
DIANA_PASSWORD="CodevalidDiana-${CASE_SUFFIX}!"
CHARLIE_TITLE="Charlie todo A ${CASE_SUFFIX}"
DIANA_TITLE_ONE="Diana todo B ${CASE_SUFFIX}"
DIANA_TITLE_TWO="Diana todo C ${CASE_SUFFIX}"

CHARLIE_COOKIE_JAR="/tmp/multiple_users_separate_todo_lists_charlie_cookie_${CASE_SUFFIX}.txt"
DIANA_COOKIE_JAR="/tmp/multiple_users_separate_todo_lists_diana_cookie_${CASE_SUFFIX}.txt"
CHARLIE_SIGNUP_HEADERS="/tmp/multiple_users_separate_todo_lists_charlie_signup_headers_${CASE_SUFFIX}.txt"
CHARLIE_SIGNUP_BODY="/tmp/multiple_users_separate_todo_lists_charlie_signup_body_${CASE_SUFFIX}.txt"
CHARLIE_LOGIN_HEADERS="/tmp/multiple_users_separate_todo_lists_charlie_login_headers_${CASE_SUFFIX}.txt"
CHARLIE_LOGIN_BODY="/tmp/multiple_users_separate_todo_lists_charlie_login_body_${CASE_SUFFIX}.txt"
DIANA_SIGNUP_HEADERS="/tmp/multiple_users_separate_todo_lists_diana_signup_headers_${CASE_SUFFIX}.txt"
DIANA_SIGNUP_BODY="/tmp/multiple_users_separate_todo_lists_diana_signup_body_${CASE_SUFFIX}.txt"
DIANA_LOGIN_HEADERS="/tmp/multiple_users_separate_todo_lists_diana_login_headers_${CASE_SUFFIX}.txt"
DIANA_LOGIN_BODY="/tmp/multiple_users_separate_todo_lists_diana_login_body_${CASE_SUFFIX}.txt"
CHARLIE_CREATE_HEADERS="/tmp/multiple_users_separate_todo_lists_charlie_create_headers_${CASE_SUFFIX}.txt"
CHARLIE_CREATE_BODY="/tmp/multiple_users_separate_todo_lists_charlie_create_body_${CASE_SUFFIX}.txt"
DIANA_CREATE1_HEADERS="/tmp/multiple_users_separate_todo_lists_diana_create1_headers_${CASE_SUFFIX}.txt"
DIANA_CREATE1_BODY="/tmp/multiple_users_separate_todo_lists_diana_create1_body_${CASE_SUFFIX}.txt"
DIANA_CREATE2_HEADERS="/tmp/multiple_users_separate_todo_lists_diana_create2_headers_${CASE_SUFFIX}.txt"
DIANA_CREATE2_BODY="/tmp/multiple_users_separate_todo_lists_diana_create2_body_${CASE_SUFFIX}.txt"
CHARLIE_PATCH_HEADERS="/tmp/multiple_users_separate_todo_lists_charlie_patch_headers_${CASE_SUFFIX}.txt"
CHARLIE_PATCH_BODY="/tmp/multiple_users_separate_todo_lists_charlie_patch_body_${CASE_SUFFIX}.txt"
DIANA_PATCH2_HEADERS="/tmp/multiple_users_separate_todo_lists_diana_patch2_headers_${CASE_SUFFIX}.txt"
DIANA_PATCH2_BODY="/tmp/multiple_users_separate_todo_lists_diana_patch2_body_${CASE_SUFFIX}.txt"
CHARLIE_RESPONSE_HEADERS="/tmp/multiple_users_separate_todo_lists_charlie_response_headers_${CASE_SUFFIX}.txt"
CHARLIE_RESPONSE_BODY="/tmp/multiple_users_separate_todo_lists_charlie_response_body_${CASE_SUFFIX}.txt"
DIANA_RESPONSE_HEADERS="/tmp/multiple_users_separate_todo_lists_diana_response_headers_${CASE_SUFFIX}.txt"
DIANA_RESPONSE_BODY="/tmp/multiple_users_separate_todo_lists_diana_response_body_${CASE_SUFFIX}.txt"
CHARLIE_DELETE_HEADERS="/tmp/multiple_users_separate_todo_lists_charlie_delete_headers_${CASE_SUFFIX}.txt"
CHARLIE_DELETE_BODY="/tmp/multiple_users_separate_todo_lists_charlie_delete_body_${CASE_SUFFIX}.txt"
DIANA_DELETE1_HEADERS="/tmp/multiple_users_separate_todo_lists_diana_delete1_headers_${CASE_SUFFIX}.txt"
DIANA_DELETE1_BODY="/tmp/multiple_users_separate_todo_lists_diana_delete1_body_${CASE_SUFFIX}.txt"
DIANA_DELETE2_HEADERS="/tmp/multiple_users_separate_todo_lists_diana_delete2_headers_${CASE_SUFFIX}.txt"
DIANA_DELETE2_BODY="/tmp/multiple_users_separate_todo_lists_diana_delete2_body_${CASE_SUFFIX}.txt"

CHARLIE_TODO_ID=""
DIANA_TODO_ID_ONE=""
DIANA_TODO_ID_TWO=""

cleanup_files() {
  rm -f "$CHARLIE_COOKIE_JAR" "$DIANA_COOKIE_JAR" \
    "$CHARLIE_SIGNUP_HEADERS" "$CHARLIE_SIGNUP_BODY" "$CHARLIE_LOGIN_HEADERS" "$CHARLIE_LOGIN_BODY" \
    "$DIANA_SIGNUP_HEADERS" "$DIANA_SIGNUP_BODY" "$DIANA_LOGIN_HEADERS" "$DIANA_LOGIN_BODY" \
    "$CHARLIE_CREATE_HEADERS" "$CHARLIE_CREATE_BODY" "$DIANA_CREATE1_HEADERS" "$DIANA_CREATE1_BODY" \
    "$DIANA_CREATE2_HEADERS" "$DIANA_CREATE2_BODY" "$CHARLIE_PATCH_HEADERS" "$CHARLIE_PATCH_BODY" \
    "$DIANA_PATCH2_HEADERS" "$DIANA_PATCH2_BODY" "$CHARLIE_RESPONSE_HEADERS" "$CHARLIE_RESPONSE_BODY" \
    "$DIANA_RESPONSE_HEADERS" "$DIANA_RESPONSE_BODY" \
    "$CHARLIE_DELETE_HEADERS" "$CHARLIE_DELETE_BODY" "$DIANA_DELETE1_HEADERS" "$DIANA_DELETE1_BODY" \
    "$DIANA_DELETE2_HEADERS" "$DIANA_DELETE2_BODY"
}
trap cleanup_files EXIT

# Given

echo "STEP: Given — create separate Charlie and Diana sessions and seed isolated todo lists"
echo "PREREQ: sign up Charlie through the public authentication API"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${CHARLIE_EMAIL}\",\"password\":\"***\"}"
charlie_signup_status="$(curl -sS -c "$CHARLIE_COOKIE_JAR" -D "$CHARLIE_SIGNUP_HEADERS" -o "$CHARLIE_SIGNUP_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${CHARLIE_EMAIL}\",\"password\":\"${CHARLIE_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-up")"
echo "RESPONSE_HEADERS:"
cat "$CHARLIE_SIGNUP_HEADERS"
echo "RESPONSE_BODY:"
cat "$CHARLIE_SIGNUP_BODY"
echo
echo "RESPONSE_STATUS: $charlie_signup_status"
[ "$charlie_signup_status" = "200" ] || [ "$charlie_signup_status" = "201" ] || { echo "ASSERTION_FAILED: expected Charlie sign-up HTTP 200 or 201 got ${charlie_signup_status}"; exit 1; }

echo "PREREQ: sign in Charlie to establish a dedicated session cookie"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${CHARLIE_EMAIL}\",\"password\":\"***\"}"
charlie_login_status="$(curl -sS -b "$CHARLIE_COOKIE_JAR" -c "$CHARLIE_COOKIE_JAR" -D "$CHARLIE_LOGIN_HEADERS" -o "$CHARLIE_LOGIN_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${CHARLIE_EMAIL}\",\"password\":\"${CHARLIE_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$CHARLIE_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$CHARLIE_LOGIN_BODY"
echo
echo "RESPONSE_STATUS: $charlie_login_status"
[ "$charlie_login_status" = "200" ] || { echo "ASSERTION_FAILED: expected Charlie sign-in HTTP 200 got ${charlie_login_status}"; exit 1; }

echo "PREREQ: sign up Diana through the public authentication API"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${DIANA_EMAIL}\",\"password\":\"***\"}"
diana_signup_status="$(curl -sS -c "$DIANA_COOKIE_JAR" -D "$DIANA_SIGNUP_HEADERS" -o "$DIANA_SIGNUP_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${DIANA_EMAIL}\",\"password\":\"${DIANA_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-up")"
echo "RESPONSE_HEADERS:"
cat "$DIANA_SIGNUP_HEADERS"
echo "RESPONSE_BODY:"
cat "$DIANA_SIGNUP_BODY"
echo
echo "RESPONSE_STATUS: $diana_signup_status"
[ "$diana_signup_status" = "200" ] || [ "$diana_signup_status" = "201" ] || { echo "ASSERTION_FAILED: expected Diana sign-up HTTP 200 or 201 got ${diana_signup_status}"; exit 1; }

echo "PREREQ: sign in Diana to establish a second isolated session cookie"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${DIANA_EMAIL}\",\"password\":\"***\"}"
diana_login_status="$(curl -sS -b "$DIANA_COOKIE_JAR" -c "$DIANA_COOKIE_JAR" -D "$DIANA_LOGIN_HEADERS" -o "$DIANA_LOGIN_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${DIANA_EMAIL}\",\"password\":\"${DIANA_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$DIANA_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$DIANA_LOGIN_BODY"
echo
echo "RESPONSE_STATUS: $diana_login_status"
[ "$diana_login_status" = "200" ] || { echo "ASSERTION_FAILED: expected Diana sign-in HTTP 200 got ${diana_login_status}"; exit 1; }

echo "PREREQ: create Charlie's single todo via POST /api/todos"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${CHARLIE_TITLE}\"}"
charlie_create_status="$(curl -sS -b "$CHARLIE_COOKIE_JAR" -D "$CHARLIE_CREATE_HEADERS" -o "$CHARLIE_CREATE_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${CHARLIE_TITLE}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$CHARLIE_CREATE_HEADERS"
echo "RESPONSE_BODY:"
cat "$CHARLIE_CREATE_BODY"
echo
echo "RESPONSE_STATUS: $charlie_create_status"
[ "$charlie_create_status" = "200" ] || [ "$charlie_create_status" = "201" ] || { echo "ASSERTION_FAILED: expected Charlie create todo HTTP 200 or 201 got ${charlie_create_status}"; exit 1; }
CHARLIE_TODO_ID="$(jq -r '.id // empty' "$CHARLIE_CREATE_BODY")"
[ -n "$CHARLIE_TODO_ID" ] || { echo "ASSERTION_FAILED: expected Charlie create todo response to contain id"; exit 1; }

echo "PREREQ: mark Charlie's todo completed through PATCH /api/todos/{id}"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"completed\":true}"
charlie_patch_status="$(curl -sS -b "$CHARLIE_COOKIE_JAR" -D "$CHARLIE_PATCH_HEADERS" -o "$CHARLIE_PATCH_BODY" -w '%{http_code}' \
  -X PATCH \
  -H 'Content-Type: application/json' \
  -d '{"completed":true}' \
  "$BASE_URL/api/todos/$CHARLIE_TODO_ID")"
echo "RESPONSE_HEADERS:"
cat "$CHARLIE_PATCH_HEADERS"
echo "RESPONSE_BODY:"
cat "$CHARLIE_PATCH_BODY"
echo
echo "RESPONSE_STATUS: $charlie_patch_status"
[ "$charlie_patch_status" = "200" ] || { echo "ASSERTION_FAILED: expected Charlie patch HTTP 200 got ${charlie_patch_status}"; exit 1; }

echo "PREREQ: create Diana's first todo via POST /api/todos"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${DIANA_TITLE_ONE}\"}"
diana_create1_status="$(curl -sS -b "$DIANA_COOKIE_JAR" -D "$DIANA_CREATE1_HEADERS" -o "$DIANA_CREATE1_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${DIANA_TITLE_ONE}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$DIANA_CREATE1_HEADERS"
echo "RESPONSE_BODY:"
cat "$DIANA_CREATE1_BODY"
echo
echo "RESPONSE_STATUS: $diana_create1_status"
[ "$diana_create1_status" = "200" ] || [ "$diana_create1_status" = "201" ] || { echo "ASSERTION_FAILED: expected Diana create todo #1 HTTP 200 or 201 got ${diana_create1_status}"; exit 1; }
DIANA_TODO_ID_ONE="$(jq -r '.id // empty' "$DIANA_CREATE1_BODY")"
[ -n "$DIANA_TODO_ID_ONE" ] || { echo "ASSERTION_FAILED: expected Diana create todo #1 response to contain id"; exit 1; }

echo "PREREQ: create Diana's second todo via POST /api/todos"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${DIANA_TITLE_TWO}\"}"
diana_create2_status="$(curl -sS -b "$DIANA_COOKIE_JAR" -D "$DIANA_CREATE2_HEADERS" -o "$DIANA_CREATE2_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${DIANA_TITLE_TWO}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$DIANA_CREATE2_HEADERS"
echo "RESPONSE_BODY:"
cat "$DIANA_CREATE2_BODY"
echo
echo "RESPONSE_STATUS: $diana_create2_status"
[ "$diana_create2_status" = "200" ] || [ "$diana_create2_status" = "201" ] || { echo "ASSERTION_FAILED: expected Diana create todo #2 HTTP 200 or 201 got ${diana_create2_status}"; exit 1; }
DIANA_TODO_ID_TWO="$(jq -r '.id // empty' "$DIANA_CREATE2_BODY")"
[ -n "$DIANA_TODO_ID_TWO" ] || { echo "ASSERTION_FAILED: expected Diana create todo #2 response to contain id"; exit 1; }

echo "PREREQ: mark Diana's second todo completed through PATCH /api/todos/{id}"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"completed\":true}"
diana_patch2_status="$(curl -sS -b "$DIANA_COOKIE_JAR" -D "$DIANA_PATCH2_HEADERS" -o "$DIANA_PATCH2_BODY" -w '%{http_code}' \
  -X PATCH \
  -H 'Content-Type: application/json' \
  -d '{"completed":true}' \
  "$BASE_URL/api/todos/$DIANA_TODO_ID_TWO")"
echo "RESPONSE_HEADERS:"
cat "$DIANA_PATCH2_HEADERS"
echo "RESPONSE_BODY:"
cat "$DIANA_PATCH2_BODY"
echo
echo "RESPONSE_STATUS: $diana_patch2_status"
[ "$diana_patch2_status" = "200" ] || { echo "ASSERTION_FAILED: expected Diana patch #2 HTTP 200 got ${diana_patch2_status}"; exit 1; }

# When

echo "STEP: When — request Charlie and Diana todo lists in their separate authenticated sessions"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
charlie_status="$(curl -sS -b "$CHARLIE_COOKIE_JAR" -D "$CHARLIE_RESPONSE_HEADERS" -o "$CHARLIE_RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$CHARLIE_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$CHARLIE_RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $charlie_status"

echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
diana_status="$(curl -sS -b "$DIANA_COOKIE_JAR" -D "$DIANA_RESPONSE_HEADERS" -o "$DIANA_RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$DIANA_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$DIANA_RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $diana_status"

# Then

echo "STEP: Then — verify each authenticated user receives only their own isolated todo list"
[ "$charlie_status" = "200" ] || { echo "ASSERTION_FAILED: expected Charlie list HTTP 200 got ${charlie_status}"; exit 1; }
[ "$diana_status" = "200" ] || { echo "ASSERTION_FAILED: expected Diana list HTTP 200 got ${diana_status}"; exit 1; }
jq -e 'type == "array" and length == 1' "$CHARLIE_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Charlie response to contain exactly 1 todo"; exit 1; }
jq -e --arg title "$CHARLIE_TITLE" 'map(select(.title == $title)) | length == 1' "$CHARLIE_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Charlie response to include title ${CHARLIE_TITLE}"; exit 1; }
jq -e --arg title "$CHARLIE_TITLE" 'map(select(.title == $title and ((.completed == true) or (.completed == 1)))) | length == 1' "$CHARLIE_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Charlie todo to be completed"; exit 1; }
jq -e --arg other1 "$DIANA_TITLE_ONE" --arg other2 "$DIANA_TITLE_TWO" 'map(select(.title == $other1 or .title == $other2)) | length == 0' "$CHARLIE_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: Charlie response unexpectedly included Diana todo titles"; exit 1; }
jq -e 'type == "array" and length == 2' "$DIANA_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Diana response to contain exactly 2 todos"; exit 1; }
jq -e --arg title "$DIANA_TITLE_ONE" 'map(select(.title == $title)) | length == 1' "$DIANA_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Diana response to include title ${DIANA_TITLE_ONE}"; exit 1; }
jq -e --arg title "$DIANA_TITLE_TWO" 'map(select(.title == $title)) | length == 1' "$DIANA_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Diana response to include title ${DIANA_TITLE_TWO}"; exit 1; }
jq -e --arg title "$DIANA_TITLE_TWO" 'map(select(.title == $title and ((.completed == true) or (.completed == 1)))) | length == 1' "$DIANA_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Diana second todo to be completed"; exit 1; }
jq -e --arg other "$CHARLIE_TITLE" 'map(select(.title == $other)) | length == 0' "$DIANA_RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: Diana response unexpectedly included Charlie title ${CHARLIE_TITLE}"; exit 1; }

# Cleanup

echo "STEP: Cleanup — delete all Charlie and Diana todos created during setup"
if [ -n "$CHARLIE_TODO_ID" ]; then
  echo "PREREQ: delete Charlie todo ${CHARLIE_TODO_ID}"
  charlie_delete_status="$(curl -sS -b "$CHARLIE_COOKIE_JAR" -D "$CHARLIE_DELETE_HEADERS" -o "$CHARLIE_DELETE_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$CHARLIE_TODO_ID")"
  echo "RESPONSE_HEADERS:"
  cat "$CHARLIE_DELETE_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$CHARLIE_DELETE_BODY"
  echo
  echo "RESPONSE_STATUS: $charlie_delete_status"
  [ "$charlie_delete_status" = "200" ] || [ "$charlie_delete_status" = "404" ] || { echo "ASSERTION_FAILED: expected Charlie delete HTTP 200 or 404 got ${charlie_delete_status}"; exit 1; }
fi
if [ -n "$DIANA_TODO_ID_ONE" ]; then
  echo "PREREQ: delete Diana todo ${DIANA_TODO_ID_ONE}"
  diana_delete1_status="$(curl -sS -b "$DIANA_COOKIE_JAR" -D "$DIANA_DELETE1_HEADERS" -o "$DIANA_DELETE1_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$DIANA_TODO_ID_ONE")"
  echo "RESPONSE_HEADERS:"
  cat "$DIANA_DELETE1_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$DIANA_DELETE1_BODY"
  echo
  echo "RESPONSE_STATUS: $diana_delete1_status"
  [ "$diana_delete1_status" = "200" ] || [ "$diana_delete1_status" = "404" ] || { echo "ASSERTION_FAILED: expected Diana delete #1 HTTP 200 or 404 got ${diana_delete1_status}"; exit 1; }
fi
if [ -n "$DIANA_TODO_ID_TWO" ]; then
  echo "PREREQ: delete Diana todo ${DIANA_TODO_ID_TWO}"
  diana_delete2_status="$(curl -sS -b "$DIANA_COOKIE_JAR" -D "$DIANA_DELETE2_HEADERS" -o "$DIANA_DELETE2_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$DIANA_TODO_ID_TWO")"
  echo "RESPONSE_HEADERS:"
  cat "$DIANA_DELETE2_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$DIANA_DELETE2_BODY"
  echo
  echo "RESPONSE_STATUS: $diana_delete2_status"
  [ "$diana_delete2_status" = "200" ] || [ "$diana_delete2_status" = "404" ] || { echo "ASSERTION_FAILED: expected Diana delete #2 HTTP 200 or 404 got ${diana_delete2_status}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:multiple_users_separate_todo_lists"
