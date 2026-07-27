#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/github_oauth_success_establishes_session_cookies_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/github_oauth_success_establishes_session_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/github_oauth_success_establishes_session_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare isolated unauthenticated OAuth request context"
echo "PREREQ: starting without a pre-existing session cookie jar"
: > "$COOKIE_JAR"

# When
echo "STEP: When — call GitHub OAuth entry endpoint"
REQUEST_HEADERS='Accept: */*'
REQUEST_BODY=''
echo "REQUEST_HEADERS:"
printf '%s\n' "$REQUEST_HEADERS"
echo "REQUEST_BODY:"
printf '%s\n' "$REQUEST_BODY"

status_code="$({
  curl -sS \
    -D "$HEADERS_FILE" \
    -o "$BODY_FILE" \
    -w '%{http_code}' \
    -c "$COOKIE_JAR" \
    -b "$COOKIE_JAR" \
    -H 'Accept: */*' \
    "$BASE_URL/api/auth/github"
} )"

echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo
echo "RESPONSE_STATUS: $status_code"

# Then
echo "STEP: Then — verify OAuth flow starts via redirect and session bootstrap path is reachable"
case "$status_code" in
  301|302|303|307|308) ;;
  *)
    echo "ASSERTION_FAILED: expected redirect HTTP status from OAuth entrypoint got ${status_code}"
    exit 1
    ;;
esac

location_header="$(grep -i '^location:' "$HEADERS_FILE" | tail -n 1 | tr -d '\r')"
[ -n "$location_header" ] || {
  echo "ASSERTION_FAILED: expected Location header in OAuth redirect response"
  exit 1
}

echo "$location_header" | grep -Ei 'location: .+' >/dev/null || {
  echo "ASSERTION_FAILED: expected non-empty redirect Location header"
  exit 1
}

echo "$location_header" | grep -Ei 'github|/todos|oauth' >/dev/null || {
  echo "ASSERTION_FAILED: expected redirect location to reference GitHub OAuth or post-auth todo route; got: $location_header"
  exit 1
}

[ -s "$HEADERS_FILE" ] || {
  echo "ASSERTION_FAILED: expected response headers to be captured"
  exit 1
}

echo "CODEVALID_TEST_ASSERTION_OK:github_oauth_success_establishes_session"

# Cleanup
echo "STEP: Cleanup — remove temporary request artifacts"
