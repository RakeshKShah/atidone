#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR_EMPTY="/tmp/missing_or_invalid_session_prevents_todo_access_empty_cookie_${CASE_SUFFIX}.txt"
COOKIE_JAR_INVALID="/tmp/missing_or_invalid_session_prevents_todo_access_invalid_cookie_${CASE_SUFFIX}.txt"
HEADERS_EMPTY="/tmp/missing_or_invalid_session_prevents_todo_access_empty_headers_${CASE_SUFFIX}.txt"
BODY_EMPTY="/tmp/missing_or_invalid_session_prevents_todo_access_empty_body_${CASE_SUFFIX}.txt"
HEADERS_INVALID="/tmp/missing_or_invalid_session_prevents_todo_access_invalid_headers_${CASE_SUFFIX}.txt"
BODY_INVALID="/tmp/missing_or_invalid_session_prevents_todo_access_invalid_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR_EMPTY" "$COOKIE_JAR_INVALID" "$HEADERS_EMPTY" "$BODY_EMPTY" "$HEADERS_INVALID" "$BODY_INVALID"
}
trap cleanup_files EXIT

echo "STEP: Given — prepare missing-session and invalid-session client contexts"
: > "$COOKIE_JAR_EMPTY"
printf '# Netscape HTTP Cookie File\napp\tFALSE\t/\tFALSE\t0\tsession\tinvalid-session-%s\n' "$CASE_SUFFIX" > "$COOKIE_JAR_INVALID"
echo "PREREQ: created empty cookie jar and explicit invalid session cookie jar"

echo "STEP: When — request protected todo API without any session cookie"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
status_empty="$(curl -sS -D "$HEADERS_EMPTY" -o "$BODY_EMPTY" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR_EMPTY" -c "$COOKIE_JAR_EMPTY" "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_EMPTY"
echo "RESPONSE_BODY:"
cat "$BODY_EMPTY"
echo
echo "RESPONSE_STATUS: $status_empty"

echo "STEP: When — request protected todo API with an invalid session cookie"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
status_invalid="$(curl -sS -D "$HEADERS_INVALID" -o "$BODY_INVALID" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR_INVALID" -c "$COOKIE_JAR_INVALID" "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_INVALID"
echo "RESPONSE_BODY:"
cat "$BODY_INVALID"
echo
echo "RESPONSE_STATUS: $status_invalid"

echo "STEP: Then — verify neither missing nor invalid sessions gain todo access"
case "$status_empty" in
  302|303|307|308|401|500) ;;
  *)
    echo "ASSERTION_FAILED: expected missing session request to return 3xx, 401, or 500 got ${status_empty}"
    exit 1
    ;;
esac
case "$status_invalid" in
  302|303|307|308|401|500) ;;
  *)
    echo "ASSERTION_FAILED: expected invalid session request to return 3xx, 401, or 500 got ${status_invalid}"
    exit 1
    ;;
esac
[ "$status_empty" != "200" ] || { echo "ASSERTION_FAILED: missing session unexpectedly returned HTTP 200"; exit 1; }
[ "$status_invalid" != "200" ] || { echo "ASSERTION_FAILED: invalid session unexpectedly returned HTTP 200"; exit 1; }
empty_location="$(awk 'BEGIN{IGNORECASE=1} /^location:/ {sub(/\r$/, "", $2); print $2}' "$HEADERS_EMPTY" | tail -n 1)"
invalid_location="$(awk 'BEGIN{IGNORECASE=1} /^location:/ {sub(/\r$/, "", $2); print $2}' "$HEADERS_INVALID" | tail -n 1)"
if [ "$status_empty" = "401" ] || [ "$status_empty" = "500" ]; then
  grep -Ei 'auth|session|unauth|login|sign|oauth' "$BODY_EMPTY" >/dev/null 2>&1 || {
    echo "ASSERTION_FAILED: expected missing-session body to mention authentication or session handling"
    exit 1
  }
else
  printf '%s' "$empty_location" | grep -E '/api/auth/github|/auth|login|sign' >/dev/null 2>&1 || {
    echo "ASSERTION_FAILED: expected missing-session redirect to auth flow, got ${empty_location}"
    exit 1
  }
fi
if [ "$status_invalid" = "401" ] || [ "$status_invalid" = "500" ]; then
  grep -Ei 'auth|session|unauth|login|sign|oauth' "$BODY_INVALID" >/dev/null 2>&1 || {
    echo "ASSERTION_FAILED: expected invalid-session body to mention authentication or session handling"
    exit 1
  }
else
  printf '%s' "$invalid_location" | grep -E '/api/auth/github|/auth|login|sign' >/dev/null 2>&1 || {
    echo "ASSERTION_FAILED: expected invalid-session redirect to auth flow, got ${invalid_location}"
    exit 1
  }
fi

echo "STEP: Cleanup — remove temporary files only"
echo "CODEVALID_TEST_ASSERTION_OK:missing_or_invalid_session_prevents_todo_access"
