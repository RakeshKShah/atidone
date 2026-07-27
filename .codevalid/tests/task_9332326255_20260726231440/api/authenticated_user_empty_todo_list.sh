#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
USER_EMAIL="empty-user-${CASE_SUFFIX}@example.com"
USER_PASSWORD="CodevalidEmpty-${CASE_SUFFIX}!"
OTHER_EMAIL="other-user-${CASE_SUFFIX}@example.com"
OTHER_PASSWORD="CodevalidOther-${CASE_SUFFIX}!"
OTHER_TITLE="Other user seeded todo ${CASE_SUFFIX}"

COOKIE_JAR="/tmp/authenticated_user_empty_todo_list_cookie_${CASE_SUFFIX}.txt"
OTHER_COOKIE_JAR="/tmp/authenticated_user_empty_todo_list_other_cookie_${CASE_SUFFIX}.txt"
SIGNUP_HEADERS="/tmp/authenticated_user_empty_todo_list_signup_headers_${CASE_SUFFIX}.txt"
SIGNUP_BODY="/tmp/authenticated_user_empty_todo_list_signup_body_${CASE_SUFFIX}.txt"
LOGIN_HEADERS="/tmp/authenticated_user_empty_todo_list_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY="/tmp/authenticated_user_empty_todo_list_login_body_${CASE_SUFFIX}.txt"
OTHER_SIGNUP_HEADERS="/tmp/authenticated_user_empty_todo_list_other_signup_headers_${CASE_SUFFIX}.txt"
OTHER_SIGNUP_BODY="/tmp/authenticated_user_empty_todo_list_other_signup_body_${CASE_SUFFIX}.txt"
OTHER_LOGIN_HEADERS="/tmp/authenticated_user_empty_todo_list_other_login_headers_${CASE_SUFFIX}.txt"
OTHER_LOGIN_BODY="/tmp/authenticated_user_empty_todo_list_other_login_body_${CASE_SUFFIX}.txt"
OTHER_CREATE_HEADERS="/tmp/authenticated_user_empty_todo_list_other_create_headers_${CASE_SUFFIX}.txt"
OTHER_CREATE_BODY="/tmp/authenticated_user_empty_todo_list_other_create_body_${CASE_SUFFIX}.txt"
RESPONSE_HEADERS="/tmp/authenticated_user_empty_todo_list_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/authenticated_user_empty_todo_list_response_body_${CASE_SUFFIX}.txt"
OTHER_DELETE_HEADERS="/tmp/authenticated_user_empty_todo_list_other_delete_headers_${CASE_SUFFIX}.txt"
OTHER_DELETE_BODY="/tmp/authenticated_user_empty_todo_list_other_delete_body_${CASE_SUFFIX}.txt"

OTHER_TODO_ID=""

cleanup_files() {
  rm -f "$COOKIE_JAR" "$OTHER_COOKIE_JAR" \
    "$SIGNUP_HEADERS" "$SIGNUP_BODY" "$LOGIN_HEADERS" "$LOGIN_BODY" \
    "$OTHER_SIGNUP_HEADERS" "$OTHER_SIGNUP_BODY" "$OTHER_LOGIN_HEADERS" "$OTHER_LOGIN_BODY" \
    "$OTHER_CREATE_HEADERS" "$OTHER_CREATE_BODY" "$RESPONSE_HEADERS" "$RESPONSE_BODY" \
    "$OTHER_DELETE_HEADERS" "$OTHER_DELETE_BODY"
}
trap cleanup_files EXIT

# Given

echo "STEP: Given — create an authenticated user with no todos and a different user who owns one todo"
echo "PREREQ: sign up the empty-list user through the public authentication API"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${USER_EMAIL}\",\"password\":\"***\"}"
signup_status="$(curl -sS -c "$COOKIE_JAR" -D "$SIGNUP_HEADERS" -o "$SIGNUP_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${USER_EMAIL}\",\"password\":\"${USER_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-up")"
echo "RESPONSE_HEADERS:"
cat "$SIGNUP_HEADERS"
echo "RESPONSE_BODY:"
cat "$SIGNUP_BODY"
echo
echo "RESPONSE_STATUS: $signup_status"
[ "$signup_status" = "200" ] || [ "$signup_status" = "201" ] || { echo "ASSERTION_FAILED: expected empty-list user sign-up HTTP 200 or 201 got ${signup_status}"; exit 1; }

echo "PREREQ: sign in the empty-list user to establish the session under test"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${USER_EMAIL}\",\"password\":\"***\"}"
login_status="$(curl -sS -b "$COOKIE_JAR" -c "$COOKIE_JAR" -D "$LOGIN_HEADERS" -o "$LOGIN_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${USER_EMAIL}\",\"password\":\"${USER_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$LOGIN_BODY"
echo
echo "RESPONSE_STATUS: $login_status"
[ "$login_status" = "200" ] || { echo "ASSERTION_FAILED: expected empty-list user sign-in HTTP 200 got ${login_status}"; exit 1; }

echo "PREREQ: sign up another user to verify other users' todos are filtered out"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${OTHER_EMAIL}\",\"password\":\"***\"}"
other_signup_status="$(curl -sS -c "$OTHER_COOKIE_JAR" -D "$OTHER_SIGNUP_HEADERS" -o "$OTHER_SIGNUP_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${OTHER_EMAIL}\",\"password\":\"${OTHER_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-up")"
echo "RESPONSE_HEADERS:"
cat "$OTHER_SIGNUP_HEADERS"
echo "RESPONSE_BODY:"
cat "$OTHER_SIGNUP_BODY"
echo
echo "RESPONSE_STATUS: $other_signup_status"
[ "$other_signup_status" = "200" ] || [ "$other_signup_status" = "201" ] || { echo "ASSERTION_FAILED: expected other user sign-up HTTP 200 or 201 got ${other_signup_status}"; exit 1; }

echo "PREREQ: sign in the other user to create an isolated todo in a separate session"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"email\":\"${OTHER_EMAIL}\",\"password\":\"***\"}"
other_login_status="$(curl -sS -b "$OTHER_COOKIE_JAR" -c "$OTHER_COOKIE_JAR" -D "$OTHER_LOGIN_HEADERS" -o "$OTHER_LOGIN_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"${OTHER_EMAIL}\",\"password\":\"${OTHER_PASSWORD}\"}" \
  "$BASE_URL/api/auth/sign-in")"
echo "RESPONSE_HEADERS:"
cat "$OTHER_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$OTHER_LOGIN_BODY"
echo
echo "RESPONSE_STATUS: $other_login_status"
[ "$other_login_status" = "200" ] || { echo "ASSERTION_FAILED: expected other user sign-in HTTP 200 got ${other_login_status}"; exit 1; }

echo "PREREQ: create one todo for the other user only"
echo "REQUEST_HEADERS:"
echo "Content-Type: application/json"
echo "REQUEST_BODY: {\"title\":\"${OTHER_TITLE}\"}"
other_create_status="$(curl -sS -b "$OTHER_COOKIE_JAR" -D "$OTHER_CREATE_HEADERS" -o "$OTHER_CREATE_BODY" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"title\":\"${OTHER_TITLE}\"}" \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$OTHER_CREATE_HEADERS"
echo "RESPONSE_BODY:"
cat "$OTHER_CREATE_BODY"
echo
echo "RESPONSE_STATUS: $other_create_status"
[ "$other_create_status" = "200" ] || [ "$other_create_status" = "201" ] || { echo "ASSERTION_FAILED: expected other user create todo HTTP 200 or 201 got ${other_create_status}"; exit 1; }
OTHER_TODO_ID="$(jq -r '.id // empty' "$OTHER_CREATE_BODY")"
[ -n "$OTHER_TODO_ID" ] || { echo "ASSERTION_FAILED: expected other user create todo response to contain id"; exit 1; }

# When

echo "STEP: When — request the todo list for the authenticated user who owns no todos"
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

echo "STEP: Then — verify the authenticated user receives an empty array instead of another user's todo"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
jq -e 'type == "array" and length == 0' "$RESPONSE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected empty todo array [] for authenticated user with no todos"; exit 1; }

# Cleanup

echo "STEP: Cleanup — delete the other user's setup todo"
if [ -n "$OTHER_TODO_ID" ]; then
  echo "PREREQ: delete other user todo ${OTHER_TODO_ID}"
  other_delete_status="$(curl -sS -b "$OTHER_COOKIE_JAR" -D "$OTHER_DELETE_HEADERS" -o "$OTHER_DELETE_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$OTHER_TODO_ID")"
  echo "RESPONSE_HEADERS:"
  cat "$OTHER_DELETE_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$OTHER_DELETE_BODY"
  echo
  echo "RESPONSE_STATUS: $other_delete_status"
  [ "$other_delete_status" = "200" ] || [ "$other_delete_status" = "404" ] || { echo "ASSERTION_FAILED: expected other user delete HTTP 200 or 404 got ${other_delete_status}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:authenticated_user_empty_todo_list"
