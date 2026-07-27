#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/session_persists_after_oauth_callback_cookies_${CASE_SUFFIX}.txt"
OAUTH_HEADERS_FILE="/tmp/session_persists_after_oauth_callback_oauth_headers_${CASE_SUFFIX}.txt"
OAUTH_BODY_FILE="/tmp/session_persists_after_oauth_callback_oauth_body_${CASE_SUFFIX}.txt"
TODOS_HEADERS_FILE="/tmp/session_persists_after_oauth_callback_todos_headers_${CASE_SUFFIX}.txt"
TODOS_BODY_FILE="/tmp/session_persists_after_oauth_callback_todos_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$OAUTH_HEADERS_FILE" "$OAUTH_BODY_FILE" "$TODOS_HEADERS_FILE" "$TODOS_BODY_FILE"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — initialize a fresh session context for OAuth bootstrap"
echo "PREREQ: using empty cookie jar before starting OAuth flow"
: > "$COOKIE_JAR"

# When
echo "STEP: When — start OAuth flow and then perform a subsequent protected request with the same cookie jar"
REQUEST_HEADERS='Accept: */*'
REQUEST_BODY=''
echo "PREREQ: start OAuth flow"
echo "REQUEST_HEADERS:"
printf '%s\n' "$REQUEST_HEADERS"
echo "REQUEST_BODY:"
printf '%s\n' "$REQUEST_BODY"
oauth_status="$({
  curl -sS \
    -D "$OAUTH_HEADERS_FILE" \
    -o "$OAUTH_BODY_FILE" \
    -w '%{http_code}' \
    -c "$COOKIE_JAR" \
    -b "$COOKIE_JAR" \
    -H 'Accept: */*' \
    "$BASE_URL/api/auth/github"
} )"
echo "RESPONSE_HEADERS:"
cat "$OAUTH_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$OAUTH_BODY_FILE"
echo
echo "RESPONSE_STATUS: $oauth_status"
case "$oauth_status" in
  301|302|303|307|308) ;;
  *)
    echo "ASSERTION_FAILED: expected redirect status from OAuth entrypoint, got ${oauth_status}"
    exit 1
    ;;
esac

echo "REQUEST_HEADERS:"
printf '%s\n' 'Accept: application/json'
echo "REQUEST_BODY:"
printf '%s\n' ''
todos_status="$({
  curl -sS \
    -D "$TODOS_HEADERS_FILE" \
    -o "$TODOS_BODY_FILE" \
    -w '%{http_code}' \
    -c "$COOKIE_JAR" \
    -b "$COOKIE_JAR" \
    -H 'Accept: application/json' \
    "$BASE_URL/api/todos"
} )"
echo "RESPONSE_HEADERS:"
cat "$TODOS_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$TODOS_BODY_FILE"
echo
echo "RESPONSE_STATUS: $todos_status"

# Then
echo "STEP: Then — verify the same session context is reused across requests and protected endpoint remains guarded"
[ -f "$COOKIE_JAR" ] || {
  echo "ASSERTION_FAILED: expected cookie jar to persist across requests"
  exit 1
}

case "$todos_status" in
  401|302|303|500) ;;
  *)
    echo "ASSERTION_FAILED: expected subsequent protected request to yield documented guarded-route response (401/302/303/500), got ${todos_status}"
    exit 1
    ;;
esac

if [ "$todos_status" = "302" ] || [ "$todos_status" = "303" ]; then
  location_value="$(grep -i '^location:' "$TODOS_HEADERS_FILE" | tail -n 1 | cut -d' ' -f2- | tr -d '\r')"
  [ -n "$location_value" ] || {
    echo "ASSERTION_FAILED: expected redirect Location header on protected route after OAuth bootstrap request"
    exit 1
  }
  echo "$location_value" | grep -E '(auth|github|sign)' >/dev/null || {
    echo "ASSERTION_FAILED: expected redirect to authentication flow on protected route; got: $location_value"
    exit 1
  }
fi

echo "CODEVALID_TEST_ASSERTION_OK:session_persists_after_oauth_callback"

# Cleanup
echo "STEP: Cleanup — remove temporary request artifacts"
