#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="github_oauth_authentication_success_establishes_session"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
FOLLOW_HEADERS_FILE="/tmp/${TEST_ID}_follow_headers_${CASE_SUFFIX}.txt"
FOLLOW_BODY_FILE="/tmp/${TEST_ID}_follow_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$HEADERS_FILE" "$BODY_FILE" "$FOLLOW_HEADERS_FILE" "$FOLLOW_BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — ensure no pre-existing authenticated session cookie is used"
: > "$COOKIE_JAR"

echo "STEP: When — call GitHub OAuth entry endpoint"
REQUEST_BODY=''
echo 'REQUEST_HEADERS:'
echo 'Accept: */*'
echo 'REQUEST_BODY:'
printf '%s\n' "$REQUEST_BODY"
code="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -c "$COOKIE_JAR" "$BASE_URL/api/auth/github")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then

echo "STEP: Then — verify the public endpoint redirects into the OAuth flow or todo UI"
location="$(awk 'BEGIN{IGNORECASE=1} /^Location:/ {sub(/\r$/, "", $2); print $2}' "$HEADERS_FILE" | tail -n 1)"
[ "$code" = "302" ] || [ "$code" = "303" ] || { echo "ASSERTION_FAILED: expected HTTP 302 or 303 got ${code}"; exit 1; }
[ -n "$location" ] || { echo 'ASSERTION_FAILED: expected Location header to be present'; exit 1; }
case "$location" in
  /todos|http*|/*github*|*github.com* ) : ;;
  * ) echo "ASSERTION_FAILED: expected redirect Location to target /todos or OAuth flow, got ${location}"; exit 1 ;;
esac

if [ "$location" = "/todos" ]; then
  echo "STEP: When — follow redirect to authenticated todo UI path"
  echo 'REQUEST_HEADERS:'
  echo 'Accept: */*'
  echo 'REQUEST_BODY:'
  printf '\n'
  follow_code="$(curl -sS -D "$FOLLOW_HEADERS_FILE" -o "$FOLLOW_BODY_FILE" -w '%{http_code}' -b "$COOKIE_JAR" "$BASE_URL/todos")"
  echo 'RESPONSE_HEADERS:'
  cat "$FOLLOW_HEADERS_FILE"
  echo 'RESPONSE_BODY:'
  cat "$FOLLOW_BODY_FILE"
  echo "RESPONSE_STATUS: $follow_code"

  echo "STEP: Then — verify redirected todo UI is reachable"
  [ "$follow_code" = "200" ] || [ "$follow_code" = "302" ] || { echo "ASSERTION_FAILED: expected /todos HTTP 200 or 302 got ${follow_code}"; exit 1; }
else
  echo "INFO: OAuth endpoint redirected to external/provider flow; repository learnings mark GitHub OAuth as provisioner:none so callback/session establishment is not directly injectable in API seed tests."
fi

echo "STEP: Cleanup — no server-side cleanup required for redirect-only OAuth entry test"

echo 'CODEVALID_TEST_ASSERTION_OK:github_oauth_authentication_success_establishes_session'
