#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/unauthenticated_access_requires_auth_cookies_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/unauthenticated_access_requires_auth_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/unauthenticated_access_requires_auth_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

# Given
echo "STEP: Given — ensure no authenticated session is present"
echo "PREREQ: using an empty cookie jar for unauthenticated request"
: > "$COOKIE_JAR"

# When
echo "STEP: When — request protected todos API without a session"
REQUEST_HEADERS='Accept: application/json'
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
    -H 'Accept: application/json' \
    "$BASE_URL/api/todos"
} )"

echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo
echo "RESPONSE_STATUS: $status_code"

# Then
echo "STEP: Then — verify authentication is required before todo data is returned"
case "$status_code" in
  401|302|303|500) ;;
  *)
    echo "ASSERTION_FAILED: expected protected route to reject/redirect unauthenticated request with 401, 302, 303, or 500; got ${status_code}"
    exit 1
    ;;
esac

if [ "$status_code" = "302" ] || [ "$status_code" = "303" ]; then
  location_value="$(grep -i '^location:' "$HEADERS_FILE" | tail -n 1 | cut -d' ' -f2- | tr -d '\r')"
  [ -n "$location_value" ] || {
    echo "ASSERTION_FAILED: expected Location header for redirecting unauthenticated user"
    exit 1
  }
  echo "$location_value" | grep -E '(auth|github|sign)' >/dev/null || {
    echo "ASSERTION_FAILED: expected redirect location to point at authentication flow; got: $location_value"
    exit 1
  }
fi

if [ "$status_code" = "200" ]; then
  echo "ASSERTION_FAILED: unexpected HTTP 200 for unauthenticated protected route"
  exit 1
fi

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_access_requires_auth"

# Cleanup
echo "STEP: Cleanup — remove temporary request artifacts"
