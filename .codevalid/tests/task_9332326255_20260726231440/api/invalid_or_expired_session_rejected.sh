#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
RESPONSE_HEADERS="/tmp/invalid_or_expired_session_rejected_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/invalid_or_expired_session_rejected_response_body_${CASE_SUFFIX}.txt"
INVALID_COOKIE_JAR="/tmp/invalid_or_expired_session_rejected_cookie_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$RESPONSE_HEADERS" "$RESPONSE_BODY" "$INVALID_COOKIE_JAR"
}
trap cleanup_files EXIT

# Given

echo "STEP: Given — prepare a malformed and tampered session cookie to simulate an invalid or expired session"
echo "PREREQ: write a fake session cookie into an isolated cookie jar"
cat > "$INVALID_COOKIE_JAR" <<EOF
# Netscape HTTP Cookie File
app\tFALSE\t/\tFALSE\t2147483647\tnuxt-session\tinvalid-session-${CASE_SUFFIX}
EOF

# When

echo "STEP: When — send GET /api/todos with the invalid session cookie"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "Cookie: nuxt-session=invalid-session-${CASE_SUFFIX}"
echo "REQUEST_BODY: <empty>"
status="$(curl -sS -b "$INVALID_COOKIE_JAR" -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $status"

# Then

echo "STEP: Then — verify the invalid or expired session is rejected and no todo data is disclosed"
case "$status" in
  401|302|303|500) ;;
  *) echo "ASSERTION_FAILED: expected HTTP 401, 302, 303, or 500 for invalid session got ${status}"; exit 1 ;;
esac
if jq -e 'type == "array" and length >= 0' "$RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected no todo array payload for invalid session"
  exit 1
fi
grep -Eq 'signin|sign-in|login|auth|unauth|error|redirect|session' "$RESPONSE_BODY" "$RESPONSE_HEADERS" || {
  echo "ASSERTION_FAILED: expected authentication/session failure signal in headers or body"
  exit 1
}

# Cleanup

echo "STEP: Cleanup — no cleanup required because only temporary files and a fake cookie jar were created"

echo "CODEVALID_TEST_ASSERTION_OK:invalid_or_expired_session_rejected"
