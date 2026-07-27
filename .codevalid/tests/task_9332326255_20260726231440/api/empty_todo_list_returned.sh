#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
USER_EMAIL="empty-list-${CASE_SUFFIX}@example.com"
USER_PASSWORD="EmptyListPass-${CASE_SUFFIX}!"

COOKIE_JAR="/tmp/empty_todo_list_returned_cookie_${CASE_SUFFIX}.txt"
SIGNUP_HEADERS="/tmp/empty_todo_list_returned_signup_headers_${CASE_SUFFIX}.txt"
SIGNUP_BODY="/tmp/empty_todo_list_returned_signup_body_${CASE_SUFFIX}.txt"
LOGIN_HEADERS="/tmp/empty_todo_list_returned_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY="/tmp/empty_todo_list_returned_login_body_${CASE_SUFFIX}.txt"
RESPONSE_HEADERS="/tmp/empty_todo_list_returned_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/empty_todo_list_returned_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$SIGNUP_HEADERS" "$SIGNUP_BODY" "$LOGIN_HEADERS" "$LOGIN_BODY" "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — create an authenticated user account with no todos"
echo "PREREQ: sign up a test-specific user through the authentication API"
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
[ "$signup_code" = "200" ] || [ "$signup_code" = "201" ] || { echo "ASSERTION_FAILED: expected sign-up HTTP 200 or 201 got ${signup_code}"; exit 1; }

echo "PREREQ: sign in the user to ensure a valid session cookie is present"
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
[ "$login_code" = "200" ] || { echo "ASSERTION_FAILED: expected sign-in HTTP 200 got ${login_code}"; exit 1; }

# When
echo "STEP: When — request the authenticated user's todo list before any todos are created"
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
echo "STEP: Then — verify the API returns an empty JSON array for a user with no todos"
[ "$status" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${status}"; exit 1; }
body_compact="$(tr -d '[:space:]' < "$RESPONSE_BODY")"
[ "$body_compact" = "[]" ] || { echo "ASSERTION_FAILED: expected empty JSON array [] got ${body_compact}"; exit 1; }

# Cleanup
echo "STEP: Cleanup — no todo rows were created, so no stateful cleanup is required"

echo "CODEVALID_TEST_ASSERTION_OK:empty_todo_list_returned"
