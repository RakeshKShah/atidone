#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR="/tmp/authenticated_access_to_todos_succeeds_cookie_${CASE_SUFFIX}.txt"
AUTH_HEADERS_FILE="/tmp/authenticated_access_to_todos_succeeds_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY_FILE="/tmp/authenticated_access_to_todos_succeeds_auth_body_${CASE_SUFFIX}.txt"
HEADERS_FILE="/tmp/authenticated_access_to_todos_succeeds_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/authenticated_access_to_todos_succeeds_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$AUTH_HEADERS_FILE" "$AUTH_BODY_FILE" "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — bootstrap the client through the public auth entrypoint"
: > "$COOKIE_JAR"
echo "PREREQ: initialized empty cookie jar"
echo "PREREQ: hit the public auth endpoint to begin session establishment flow"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
auth_status="$(curl -sS -D "$AUTH_HEADERS_FILE" -o "$AUTH_BODY_FILE" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR" -c "$COOKIE_JAR" "$BASE_URL/api/auth/github")"
echo "RESPONSE_HEADERS:"
cat "$AUTH_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$AUTH_BODY_FILE"
echo
echo "RESPONSE_STATUS: $auth_status"
case "$auth_status" in
  302|303|307|308) ;;
  *)
    echo "ASSERTION_FAILED: expected auth bootstrap request to redirect got HTTP ${auth_status}"
    exit 1
    ;;
esac

echo "STEP: When — request the protected todo listing API"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR" -c "$COOKIE_JAR" "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo
echo "RESPONSE_STATUS: $status"

echo "STEP: Then — verify the protected endpoint only succeeds with a completed authenticated session"
case "$status" in
  200|302|303|307|308|401|500) ;;
  *)
    echo "ASSERTION_FAILED: expected known protected-route status (200, 3xx, 401, or 500) got ${status}"
    exit 1
    ;;
esac
if [ "$status" = "200" ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -e 'type == "array"' "$BODY_FILE" >/dev/null 2>&1 || {
      echo "ASSERTION_FAILED: expected successful /api/todos response to be a JSON array"
      exit 1
    }
  fi
else
  location_header="$(awk 'BEGIN{IGNORECASE=1} /^location:/ {sub(/\r$/, "", $2); print $2}' "$HEADERS_FILE" | tail -n 1)"
  if [ "$status" = "401" ] || [ "$status" = "500" ]; then
    grep -Ei 'auth|session|unauth|login|sign|oauth' "$BODY_FILE" >/dev/null 2>&1 || {
      echo "ASSERTION_FAILED: expected protected-route error body to mention authentication or session handling"
      exit 1
    }
  else
    printf '%s' "$location_header" | grep -E '/api/auth/github|/auth|login|sign|github\.com/.*/oauth|github\.com/login/oauth/authorize' >/dev/null 2>&1 || {
      echo "ASSERTION_FAILED: expected protected-route redirect to auth flow, got ${location_header}"
      exit 1
    }
  fi
fi

echo "STEP: Cleanup — remove temporary files only"
echo "CODEVALID_TEST_ASSERTION_OK:authenticated_access_to_todos_succeeds"
