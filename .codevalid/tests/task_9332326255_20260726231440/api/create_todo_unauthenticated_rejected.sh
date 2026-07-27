#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_unauthenticated_rejected"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"
RESPONSE_HEADERS_FILE="/tmp/${TEST_ID}_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY_FILE="/tmp/${TEST_ID}_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$REQUEST_BODY_FILE" "$RESPONSE_HEADERS_FILE" "$RESPONSE_BODY_FILE"
}
trap cleanup_files EXIT

cat > "$REQUEST_BODY_FILE" <<EOF
{"title":"Should not be created ${CASE_SUFFIX}"}
EOF

# Given — bring the system to the required state
echo "STEP: Given — ensure no authentication cookie or token is sent"
echo "PREREQ: execute request without Cookie or Authorization headers"

# When — perform the action under test
echo "STEP: When — POST unauthenticated create todo request"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
code="$(curl -sS -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -D "$RESPONSE_HEADERS_FILE" \
  -o "$RESPONSE_BODY_FILE" \
  -w '%{http_code}' \
  --data @"$REQUEST_BODY_FILE" || true)"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — unauthenticated request is rejected before todo creation"
case "$code" in
  401|302|303|500) ;;
  *) echo "ASSERTION_FAILED: expected HTTP 401, 302, 303, or 500 for Nuxt requireUserSession got ${code}"; exit 1 ;;
esac
if [ "$code" = "302" ] || [ "$code" = "303" ]; then
  grep -Ei '^location:' "$RESPONSE_HEADERS_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected redirect Location header for unauthenticated response"; exit 1; }
else
  grep -Ei 'auth|unauthor|session|login|signin|sign-in' "$RESPONSE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected auth-related response body for unauthenticated rejection"; exit 1; }
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no cleanup required because request must be rejected"

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_unauthenticated_rejected"
