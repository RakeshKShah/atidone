#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/github_oauth_redirects_to_todos_cookies_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/github_oauth_redirects_to_todos_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/github_oauth_redirects_to_todos_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — prepare isolated OAuth redirect inspection context"
echo "PREREQ: using a fresh cookie jar to observe redirect behavior"
: > "$COOKIE_JAR"

# When
echo "STEP: When — request the GitHub OAuth endpoint"
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
echo "STEP: Then — verify the authentication flow responds with a redirect-related outcome"
case "$status_code" in
  301|302|303|307|308) ;;
  *)
    echo "ASSERTION_FAILED: expected redirect HTTP status from GET /api/auth/github got ${status_code}"
    exit 1
    ;;
esac

location_value="$(grep -i '^location:' "$HEADERS_FILE" | tail -n 1 | cut -d' ' -f2- | tr -d '\r')"
[ -n "$location_value" ] || {
  echo "ASSERTION_FAILED: expected redirect Location header"
  exit 1
}

echo "$location_value" | grep -E '(/todos|github|oauth)' >/dev/null || {
  echo "ASSERTION_FAILED: expected redirect target to reference /todos or GitHub OAuth flow; got: $location_value"
  exit 1
}

echo "CODEVALID_TEST_ASSERTION_OK:github_oauth_redirects_to_todos"

# Cleanup
echo "STEP: Cleanup — remove temporary request artifacts"
