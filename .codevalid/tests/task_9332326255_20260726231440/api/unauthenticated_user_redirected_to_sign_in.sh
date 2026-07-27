#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="unauthenticated_user_redirected_to_sign_in"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
OAUTH_HEADERS_FILE="/tmp/${TEST_ID}_oauth_headers_${CASE_SUFFIX}.txt"
OAUTH_BODY_FILE="/tmp/${TEST_ID}_oauth_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$OAUTH_HEADERS_FILE" "$OAUTH_BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — act as an unauthenticated client with no cookies"

echo "STEP: When — request the authenticated todo API without a session"
REQUEST_BODY=''
echo 'REQUEST_HEADERS:'
echo 'Accept: application/json'
echo 'REQUEST_BODY:'
printf '%s\n' "$REQUEST_BODY"
code="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' "$BASE_URL/api/todos")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then

echo "STEP: Then — verify unauthenticated access is rejected and no todo data is exposed"
[ "$code" = "401" ] || [ "$code" = "302" ] || [ "$code" = "403" ] || { echo "ASSERTION_FAILED: expected HTTP 401, 302, or 403 for unauthenticated todo access got ${code}"; exit 1; }
if [ -s "$BODY_FILE" ]; then
  ! grep -F '"title"' "$BODY_FILE" >/dev/null 2>&1 || { echo 'ASSERTION_FAILED: unexpected todo title data exposed to unauthenticated client'; exit 1; }
fi

echo "STEP: When — initiate authentication through the public GitHub OAuth endpoint"
echo 'REQUEST_HEADERS:'
echo 'Accept: */*'
echo 'REQUEST_BODY:'
printf '\n'
oauth_code="$(curl -sS -D "$OAUTH_HEADERS_FILE" -o "$OAUTH_BODY_FILE" -w '%{http_code}' "$BASE_URL/api/auth/github")"
echo 'RESPONSE_HEADERS:'
cat "$OAUTH_HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$OAUTH_BODY_FILE"
echo "RESPONSE_STATUS: $oauth_code"


echo "STEP: Then — verify authentication flow starts with a redirect"
oauth_location="$(awk 'BEGIN{IGNORECASE=1} /^Location:/ {sub(/\r$/, "", $2); print $2}' "$OAUTH_HEADERS_FILE" | tail -n 1)"
[ "$oauth_code" = "302" ] || [ "$oauth_code" = "303" ] || { echo "ASSERTION_FAILED: expected HTTP 302 or 303 from OAuth initiation got ${oauth_code}"; exit 1; }
[ -n "$oauth_location" ] || { echo 'ASSERTION_FAILED: expected OAuth initiation redirect Location header'; exit 1; }

echo "STEP: Cleanup — no cleanup required for unauthenticated redirect test"

echo 'CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_redirected_to_sign_in'
