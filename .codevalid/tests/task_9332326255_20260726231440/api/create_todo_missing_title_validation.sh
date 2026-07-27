#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_missing_title_validation"
AUTH_COOKIE="${AUTH_COOKIE:-}"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"
RESPONSE_HEADERS_FILE="/tmp/${TEST_ID}_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY_FILE="/tmp/${TEST_ID}_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$REQUEST_BODY_FILE" "$RESPONSE_HEADERS_FILE" "$RESPONSE_BODY_FILE"
}
trap cleanup_files EXIT

cat > "$REQUEST_BODY_FILE" <<EOF
{}
EOF

# Given — bring the system to the required state
echo "STEP: Given — prepare authenticated request with body missing title"
echo "PREREQ: mint authenticated session for user user-456 and pass it in AUTH_COOKIE"
[ -n "$AUTH_COOKIE" ] || { echo "ASSERTION_FAILED: expected AUTH_COOKIE env var containing a valid authenticated session cookie"; exit 1; }
printf '%s\n' "$AUTH_COOKIE" | grep -F 'nuxt-session=' >/dev/null || { echo "ASSERTION_FAILED: expected AUTH_COOKIE to contain nuxt-session cookie"; exit 1; }

# When — perform the action under test
echo "STEP: When — POST /api/todos with missing title field"
echo "REQUEST_HEADERS: Content-Type: application/json; Cookie: $AUTH_COOKIE"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
code="$(curl -sS -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -H "Cookie: $AUTH_COOKIE" \
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
echo "STEP: Then — schema validation rejects the malformed body"
[ "$code" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${code}"; exit 1; }
grep -Ei 'title|validation|invalid|required' "$RESPONSE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected validation error mentioning missing title"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no cleanup required because todo must not be created"

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_missing_title_validation"
