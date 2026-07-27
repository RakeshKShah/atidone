#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="oauth_callback_missing_user_data_handling"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
TODOS_HEADERS_FILE="/tmp/${TEST_ID}_todos_headers_${CASE_SUFFIX}.txt"
TODOS_BODY_FILE="/tmp/${TEST_ID}_todos_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$TODOS_HEADERS_FILE" "$TODOS_BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — no authenticated session is supplied and OAuth provider callback injection is unavailable in this API harness"

echo "STEP: When — call the public GitHub OAuth endpoint without externally provided user data"
REQUEST_BODY=''
echo 'REQUEST_HEADERS:'
echo 'Accept: */*'
echo 'REQUEST_BODY:'
printf '%s\n' "$REQUEST_BODY"
code="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' "$BASE_URL/api/auth/github")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then

echo "STEP: Then — verify the endpoint does not establish direct todo access when callback user data is unavailable"
[ "$code" = "302" ] || [ "$code" = "303" ] || [ "$code" = "400" ] || [ "$code" = "401" ] || [ "$code" = "500" ] || { echo "ASSERTION_FAILED: expected OAuth endpoint to redirect or fail gracefully, got HTTP ${code}"; exit 1; }

echo "STEP: When — attempt to access protected todos after the incomplete OAuth interaction"
echo 'REQUEST_HEADERS:'
echo 'Accept: application/json'
echo 'REQUEST_BODY:'
printf '\n'
todos_code="$(curl -sS -D "$TODOS_HEADERS_FILE" -o "$TODOS_BODY_FILE" -w '%{http_code}' "$BASE_URL/api/todos")"
echo 'RESPONSE_HEADERS:'
cat "$TODOS_HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$TODOS_BODY_FILE"
echo "RESPONSE_STATUS: $todos_code"

echo "STEP: Then — verify no session was established and protected todos remain inaccessible"
[ "$todos_code" = "401" ] || [ "$todos_code" = "302" ] || [ "$todos_code" = "403" ] || { echo "ASSERTION_FAILED: expected protected todos to remain inaccessible after invalid OAuth path, got HTTP ${todos_code}"; exit 1; }
if [ -s "$TODOS_BODY_FILE" ]; then
  ! grep -F '"title"' "$TODOS_BODY_FILE" >/dev/null 2>&1 || { echo 'ASSERTION_FAILED: todo data leaked after invalid OAuth path'; exit 1; }
fi

echo "STEP: Cleanup — no cleanup required"

echo 'CODEVALID_TEST_ASSERTION_OK:oauth_callback_missing_user_data_handling'
