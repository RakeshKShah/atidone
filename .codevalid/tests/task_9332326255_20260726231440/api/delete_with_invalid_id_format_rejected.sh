#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_with_invalid_id_format_rejected"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
LOGIN_HEADERS="/tmp/${TEST_ID}_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY="/tmp/${TEST_ID}_login_body_${CASE_SUFFIX}.txt"
LIST_BEFORE_HEADERS="/tmp/${TEST_ID}_list_before_headers_${CASE_SUFFIX}.txt"
LIST_BEFORE_BODY="/tmp/${TEST_ID}_list_before_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"
LIST_AFTER_HEADERS="/tmp/${TEST_ID}_list_after_headers_${CASE_SUFFIX}.txt"
LIST_AFTER_BODY="/tmp/${TEST_ID}_list_after_body_${CASE_SUFFIX}.txt"
INVALID_ID='%20'

cleanup_files() {
  rm -f "$COOKIE_JAR" "$LOGIN_HEADERS" "$LOGIN_BODY" "$LIST_BEFORE_HEADERS" "$LIST_BEFORE_BODY" "$DELETE_HEADERS" "$DELETE_BODY" "$LIST_AFTER_HEADERS" "$LIST_AFTER_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — establish authenticated session for invalid id validation scenario"
echo "PREREQ: log in as a valid user"
LOGIN_REQUEST='{"userId":"user-valid","name":"User Valid"}'
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

before_code="$(curl -sS -X GET \
  -b "$COOKIE_JAR" \
  -D "$LIST_BEFORE_HEADERS" \
  -o "$LIST_BEFORE_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$LIST_BEFORE_HEADERS"
echo "RESPONSE_BODY:"
cat "$LIST_BEFORE_BODY"
echo "RESPONSE_STATUS: $before_code"
[ "$before_code" = "200" ] || { echo "ASSERTION_FAILED: expected before-list HTTP 200 got ${before_code}"; exit 1; }
before_count="$(jq 'length' "$LIST_BEFORE_BODY")"

# When — perform the action under test
echo "STEP: When — send delete request with invalid id format"
echo "REQUEST_HEADERS:"
printf 'Cookie jar: %s\n' "$COOKIE_JAR"
echo "REQUEST_BODY:"
printf '\n'
delete_code="$(curl -sS -X DELETE \
  -b "$COOKIE_JAR" \
  -D "$DELETE_HEADERS" \
  -o "$DELETE_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/$INVALID_ID")"
echo "RESPONSE_HEADERS:"
cat "$DELETE_HEADERS"
echo "RESPONSE_BODY:"
cat "$DELETE_BODY"
echo "RESPONSE_STATUS: $delete_code"

# Then — HTTP/body assertions
echo "STEP: Then — request is rejected as an invalid id and no todo list change occurs"
[ "$delete_code" = "400" ] || [ "$delete_code" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 400 or 404 got ${delete_code}"; exit 1; }
grep -F 'id' "$DELETE_BODY" >/dev/null || grep -F 'validation' "$DELETE_BODY" >/dev/null || grep -F 'not found' "$DELETE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected validation or invalid id details in response body"; exit 1; }

after_code="$(curl -sS -X GET \
  -b "$COOKIE_JAR" \
  -D "$LIST_AFTER_HEADERS" \
  -o "$LIST_AFTER_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$LIST_AFTER_HEADERS"
echo "RESPONSE_BODY:"
cat "$LIST_AFTER_BODY"
echo "RESPONSE_STATUS: $after_code"
[ "$after_code" = "200" ] || { echo "ASSERTION_FAILED: expected after-list HTTP 200 got ${after_code}"; exit 1; }
after_count="$(jq 'length' "$LIST_AFTER_BODY")"
[ "$after_count" = "$before_count" ] || { echo "ASSERTION_FAILED: expected todo count unchanged, before=${before_count} after=${after_count}"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — clear authenticated session"
curl -sS -X POST \
  -b "$COOKIE_JAR" \
  -o /dev/null \
  "$BASE_URL/api/test-auth/logout" >/dev/null 2>&1 || true

echo "CODEVALID_TEST_ASSERTION_OK:delete_with_invalid_id_format_rejected"
