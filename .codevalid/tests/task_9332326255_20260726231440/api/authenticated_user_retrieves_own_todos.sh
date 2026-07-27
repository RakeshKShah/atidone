#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
USER_EMAIL="codevalid-authenticated-user-${CASE_SUFFIX}@example.com"
USER_PASSWORD="CodevalidPass-${CASE_SUFFIX}!"
TITLE_ONE="Buy groceries ${CASE_SUFFIX}"
TITLE_TWO="Walk dog ${CASE_SUFFIX}"
OTHER_EMAIL="codevalid-other-user-${CASE_SUFFIX}@example.com"
OTHER_PASSWORD="CodevalidOther-${CASE_SUFFIX}!"
OTHER_TITLE="Different user todo ${CASE_SUFFIX}"

COOKIE_JAR="/tmp/authenticated_user_retrieves_own_todos_cookie_${CASE_SUFFIX}.txt"
OTHER_COOKIE_JAR="/tmp/authenticated_user_retrieves_own_todos_other_cookie_${CASE_SUFFIX}.txt"
SIGNUP_HEADERS="/tmp/authenticated_user_retrieves_own_todos_signup_headers_${CASE_SUFFIX}.txt"
SIGNUP_BODY="/tmp/authenticated_user_retrieves_own_todos_signup_body_${CASE_SUFFIX}.txt"
LOGIN_HEADERS="/tmp/authenticated_user_retrieves_own_todos_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY="/tmp/authenticated_user_retrieves_own_todos_login_body_${CASE_SUFFIX}.txt"
CREATE1_HEADERS="/tmp/authenticated_user_retrieves_own_todos_create1_headers_${CASE_SUFFIX}.txt"
CREATE1_BODY="/tmp/authenticated_user_retrieves_own_todos_create1_body_${CASE_SUFFIX}.txt"
CREATE2_HEADERS="/tmp/authenticated_user_retrieves_own_todos_create2_headers_${CASE_SUFFIX}.txt"
CREATE2_BODY="/tmp/authenticated_user_retrieves_own_todos_create2_body_${CASE_SUFFIX}.txt"
PATCH2_HEADERS="/tmp/authenticated_user_retrieves_own_todos_patch2_headers_${CASE_SUFFIX}.txt"
PATCH2_BODY="/tmp/authenticated_user_retrieves_own_todos_patch2_body_${CASE_SUFFIX}.txt"
OTHER_SIGNUP_HEADERS="/tmp/authenticated_user_retrieves_own_todos_other_signup_headers_${CASE_SUFFIX}.txt"
OTHER_SIGNUP_BODY="/tmp/authenticated_user_retrieves_own_todos_other_signup_body_${CASE_SUFFIX}.txt"
OTHER_LOGIN_HEADERS="/tmp/authenticated_user_retrieves_own_todos_other_login_headers_${CASE_SUFFIX}.txt"
OTHER_LOGIN_BODY="/tmp/authenticated_user_retrieves_own_todos_other_login_body_${CASE_SUFFIX}.txt"
OTHER_CREATE_HEADERS="/tmp/authenticated_user_retrieves_own_todos_other_create_headers_${CASE_SUFFIX}.txt"
OTHER_CREATE_BODY="/tmp/authenticated_user_retrieves_own_todos_other_create_body_${CASE_SUFFIX}.txt"
RESPONSE_HEADERS="/tmp/authenticated_user_retrieves_own_todos_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/authenticated_user_retrieves_own_todos_response_body_${CASE_SUFFIX}.txt"
DELETE1_HEADERS="/tmp/authenticated_user_retrieves_own_todos_delete1_headers_${CASE_SUFFIX}.txt"
DELETE1_BODY="/tmp/authenticated_user_retrieves_own_todos_delete1_body_${CASE_SUFFIX}.txt"
DELETE2_HEADERS="/tmp/authenticated_user_retrieves_own_todos_delete2_headers_${CASE_SUFFIX}.txt"
DELETE2_BODY="/tmp/authenticated_user_retrieves_own_todos_delete2_body_${CASE_SUFFIX}.txt"
OTHER_DELETE_HEADERS="/tmp/authenticated_user_retrieves_own_todos_other_delete_headers_${CASE_SUFFIX}.txt"
OTHER_DELETE_BODY="/tmp/authenticated_user_retrieves_own_todos_other_delete_body_${CASE_SUFFIX}.txt"

TODO_ID_1=""
TODO_ID_2=""
OTHER_TODO_ID=""

cleanup_files() {
  rm -f "$COOKIE_JAR" "$OTHER_COOKIE_JAR" \
    "$SIGNUP_HEADERS" "$SIGNUP_BODY" "$LOGIN_HEADERS" "$LOGIN_BODY" \
    "$CREATE1_HEADERS" "$CREATE1_BODY" "$CREATE2_HEADERS" "$CREATE2_BODY" \
    "$PATCH2_HEADERS" "$PATCH2_BODY" \
    "$OTHER_SIGNUP_HEADERS" "$OTHER_SIGNUP_BODY" "$OTHER_LOGIN_HEADERS" "$OTHER_LOGIN_BODY" \
    "$OTHER_CREATE_HEADERS" "$OTHER_CREATE_BODY" "$RESPONSE_HEADERS" "$RESPONSE_BODY" \
    "$DELETE1_HEADERS" "$DELETE1_BODY" "$DELETE2_HEADERS" "$DELETE2_BODY" \
    "$OTHER_DELETE_HEADERS" "$OTHER_DELETE_BODY"
}
trap cleanup_files EXIT

# Given

echo "STEP: Given — create two authenticated users and seed isolated todos via public APIs"
echo "PREREQ: sign up the primary user through the authentication API"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${USER_EMAIL}\",\"password\":\"***\"}"
signup_code="$(curl -sS -c "$COOKIE_JAR" -D "$SIGNUP_HEADERS" -o "$SIGNUP_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${USER_EMAIL}\",\"password\":\"${USER_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-up")"
echo "RESPONSE_HEADERS:"
cat "$SIGNUP_HEADERS"
echo "RESPONSE_BODY:"
cat "$SIGNUP_BODY"
echo
echo "RESPONSE_STATUS: $signup_code"
[ "$signup_code" = "200" ] || [ "$signup_code" = "201" ] || { echo "ASSERTION_FAILED: expected primary sign-up HTTP 200 or 201 got ${signup_code}"; exit 1; }

echo "PREREQ: sign in the primary user to establish a real session cookie"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${USER_EMAIL}\",\"password\":\"***\"}"
login_code="$(curl -sS -b "$COOKIE_JAR" -c "$COOKIE_JAR" -D "$LOGIN_HEADERS" -o "$LOGIN_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${USER_EMAIL}\",\"password\":\"${USER_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$LOGIN_BODY"
echo
echo "RESPONSE_STATUS: $login_code"
[ "$login_code" = "200" ] || { echo "ASSERTION_FAILED: expected primary sign-in HTTP 200 got ${login_code}"; exit 1; }

echo "PREREQ: create the first todo for the authenticated primary user"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${TITLE_ONE}\"}"
create1_code="$(curl -sS -b "$COOKIE_JAR" -D "$CREATE1_HEADERS" -o "$CREATE1_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${TITLE_ONE}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$CREATE1_HEADERS"
echo "RESPONSE_BODY:"
cat "$CREATE1_BODY"
echo
echo "RESPONSE_STATUS: $create1_code"
[ "$create1_code" = "200" ] || [ "$create1_code" = "201" ] || { echo "ASSERTION_FAILED: expected create todo #1 HTTP 200 or 201 got ${create1_code}"; exit 1; }
TODO_ID_1="$(jq -r '.id // empty' "$CREATE1_BODY")"
[ -n "$TODO_ID_1" ] || { echo "ASSERTION_FAILED: expected create todo #1 response to contain id"; exit 1; }

echo "PREREQ: create the second todo for the authenticated primary user"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${TITLE_TWO}\"}"
create2_code="$(curl -sS -b "$COOKIE_JAR" -D "$CREATE2_HEADERS" -o "$CREATE2_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${TITLE_TWO}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$CREATE2_HEADERS"
echo "RESPONSE_BODY:"
cat "$CREATE2_BODY"
echo
echo "RESPONSE_STATUS: $create2_code"
[ "$create2_code" = "200" ] || [ "$create2_code" = "201" ] || { echo "ASSERTION_FAILED: expected create todo #2 HTTP 200 or 201 got ${create2_code}"; exit 1; }
TODO_ID_2="$(jq -r '.id // empty' "$CREATE2_BODY")"
[ -n "$TODO_ID_2" ] || { echo "ASSERTION_FAILED: expected create todo #2 response to contain id"; exit 1; }

echo "PREREQ: mark the second todo completed via PATCH /api/todos/{id} so the list contains mixed completion states"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"completed\":true}"
patch2_code="$(curl -sS -b "$COOKIE_JAR" -D "$PATCH2_HEADERS" -o "$PATCH2_BODY" -w '%{http_code}' \
  -X PATCH \
  -H 'Content-Type: application/json' \
  -d '{"completed":true}' \
  "$BASE_URL/api/todos/$TODO_ID_2")"
echo "RESPONSE_HEADERS:"
cat "$PATCH2_HEADERS"
echo "RESPONSE_BODY:"
cat "$PATCH2_BODY"
echo
echo "RESPONSE_STATUS: $patch2_code"
[ "$patch2_code" = "200" ] || { echo "ASSERTION_FAILED: expected patch todo #2 HTTP 200 got ${patch2_code}"; exit 1; }

echo "PREREQ: sign up the secondary user through the authentication API"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${OTHER_EMAIL}\",\"password\":\"***\"}"
other_signup_code="$(curl -sS -c "$OTHER_COOKIE_JAR" -D "$OTHER_SIGNUP_HEADERS" -o "$OTHER_SIGNUP_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${OTHER_EMAIL}\",\"password\":\"${OTHER_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-up")"
echo "RESPONSE_HEADERS:"
cat "$OTHER_SIGNUP_HEADERS"
echo "RESPONSE_BODY:"
cat "$OTHER_SIGNUP_BODY"
echo
echo "RESPONSE_STATUS: $other_signup_code"
[ "$other_signup_code" = "200" ] || [ "$other_signup_code" = "201" ] || { echo "ASSERTION_FAILED: expected secondary sign-up HTTP 200 or 201 got ${other_signup_code}"; exit 1; }

echo "PREREQ: sign in the secondary user to establish an isolated session cookie"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${OTHER_EMAIL}\",\"password\":\"***\"}"
other_login_code="$(curl -sS -b "$OTHER_COOKIE_JAR" -c "$OTHER_COOKIE_JAR" -D "$OTHER_LOGIN_HEADERS" -o "$OTHER_LOGIN_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${OTHER_EMAIL}\",\"password\":\"${OTHER_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$OTHER_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$OTHER_LOGIN_BODY"
echo
echo "RESPONSE_STATUS: $other_login_code"
[ "$other_login_code" = "200" ] || { echo "ASSERTION_FAILED: expected secondary sign-in HTTP 200 got ${other_login_code}"; exit 1; }

echo "PREREQ: create a todo for the secondary user so ownership filtering can be verified"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${OTHER_TITLE}\"}"
other_create_code="$(curl -sS -b "$OTHER_COOKIE_JAR" -D "$OTHER_CREATE_HEADERS" -o "$OTHER_CREATE_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${OTHER_TITLE}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$OTHER_CREATE_HEADERS"
echo "RESPONSE_BODY:"
cat "$OTHER_CREATE_BODY"
echo
echo "RESPONSE_STATUS: $other_create_code"
[ "$other_create_code" = "200" ] || [ "$other_create_code" = "201" ] || { echo "ASSERTION_FAILED: expected secondary create todo HTTP 200 or 201 got ${other_create_code}"; exit 1; }
OTHER_TODO_ID="$(jq -r '.id // empty' "$OTHER_CREATE_BODY")"
[ -n "$OTHER_TODO_ID" ] || { echo "ASSERTION_FAILED: expected secondary create todo response to contain id"; exit 1; }

# When

echo "STEP: When — retrieve the authenticated primary user's todo list"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
status="$(curl -sS -b "$COOKIE_JAR" -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $status"

# Then

echo "STEP: Then — verify only the authenticated user's own todos are returned"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
jq -e --arg title "$TITLE_ONE" 'map(select(.title == $title)) | length == 1' "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected exactly one todo with title ${TITLE_ONE}"; exit 1; }
jq -e --arg title "$TITLE_TWO" 'map(select(.title == $title)) | length == 1' "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected exactly one todo with title ${TITLE_TWO}"; exit 1; }
jq -e --arg id "$TODO_ID_1" 'map(select((.id|tostring) == $id)) | length == 1' "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response to include todo id ${TODO_ID_1}"; exit 1; }
jq -e --arg id "$TODO_ID_2" 'map(select((.id|tostring) == $id)) | length == 1' "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response to include todo id ${TODO_ID_2}"; exit 1; }
jq -e --arg title "$TITLE_ONE" 'map(select(.title == $title and ((.completed == false) or (.completed == 0)))) | length == 1' "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected first todo to be incomplete"; exit 1; }
jq -e --arg title "$TITLE_TWO" 'map(select(.title == $title and ((.completed == true) or (.completed == 1)))) | length == 1' "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected second todo to be completed"; exit 1; }
jq -e --arg title "$OTHER_TITLE" 'map(select(.title == $title)) | length == 0' "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: response unexpectedly included another user's todo title ${OTHER_TITLE}"; exit 1; }
jq -e --arg id "$OTHER_TODO_ID" 'map(select((.id|tostring) == $id)) | length == 0' "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: response unexpectedly included another user's todo id ${OTHER_TODO_ID}"; exit 1; }

# Cleanup

echo "STEP: Cleanup — delete all todos created during setup"
if [ -n "$TODO_ID_1" ]; then
  echo "PREREQ: delete primary user todo ${TODO_ID_1}"
  delete1_code="$(curl -sS -b "$COOKIE_JAR" -D "$DELETE1_HEADERS" -o "$DELETE1_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$TODO_ID_1")"
  echo "RESPONSE_HEADERS:"
  cat "$DELETE1_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$DELETE1_BODY"
  echo
  echo "RESPONSE_STATUS: $delete1_code"
  [ "$delete1_code" = "200" ] || [ "$delete1_code" = "404" ] || { echo "ASSERTION_FAILED: expected delete todo #1 HTTP 200 or 404 got ${delete1_code}"; exit 1; }
fi
if [ -n "$TODO_ID_2" ]; then
  echo "PREREQ: delete primary user todo ${TODO_ID_2}"
  delete2_code="$(curl -sS -b "$COOKIE_JAR" -D "$DELETE2_HEADERS" -o "$DELETE2_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$TODO_ID_2")"
  echo "RESPONSE_HEADERS:"
  cat "$DELETE2_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$DELETE2_BODY"
  echo
  echo "RESPONSE_STATUS: $delete2_code"
  [ "$delete2_code" = "200" ] || [ "$delete2_code" = "404" ] || { echo "ASSERTION_FAILED: expected delete todo #2 HTTP 200 or 404 got ${delete2_code}"; exit 1; }
fi
if [ -n "$OTHER_TODO_ID" ]; then
  echo "PREREQ: delete secondary user todo ${OTHER_TODO_ID}"
  other_delete_code="$(curl -sS -b "$OTHER_COOKIE_JAR" -D "$OTHER_DELETE_HEADERS" -o "$OTHER_DELETE_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$OTHER_TODO_ID")"
  echo "RESPONSE_HEADERS:"
  cat "$OTHER_DELETE_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$OTHER_DELETE_BODY"
  echo
  echo "RESPONSE_STATUS: $other_delete_code"
  [ "$other_delete_code" = "200" ] || [ "$other_delete_code" = "404" ] || { echo "ASSERTION_FAILED: expected secondary delete todo HTTP 200 or 404 got ${other_delete_code}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:authenticated_user_retrieves_own_todos"
