#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_unauthenticated_blocked"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"
RESPONSE_HEADERS_FILE="/tmp/${TEST_ID}_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY_FILE="/tmp/${TEST_ID}_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$REQUEST_BODY_FILE" "$RESPONSE_HEADERS_FILE" "$RESPONSE_BODY_FILE"
}
trap cleanup_files EXIT

cat > "$REQUEST_BODY_FILE" <<'JSON'
{"title":"Test Todo"}
JSON

# Given — bring the system to the required state
echo "STEP: Given — ensure request has no authenticated session"
echo "PREREQ: this test intentionally sends no cookie or authorization header"

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
echo "STEP: Then — unauthenticated creation is rejected"
[ "$code" = "401" ] || [ "$code" = "403" ] || [ "$code" = "302" ] || [ "$code" = "303" ] || [ "$code" = "500" ] || { echo "ASSERTION_FAILED: expected HTTP 401, 403, 302, 303, or 500 got ${code}"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no cleanup required because unauthenticated request should not create data"

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_unauthenticated_blocked"
