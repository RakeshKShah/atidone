#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="unauthenticated_user_blocked_from_update"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
PATCH_REQUEST_BODY="/tmp/${TEST_ID}_patch_request_${CASE_SUFFIX}.json"
TODO_ID="todo-789"

cleanup_files() {
  rm -f "$PATCH_HEADERS" "$PATCH_BODY" "$PATCH_REQUEST_BODY"
}
trap cleanup_files EXIT

cat > "$PATCH_REQUEST_BODY" <<JSON
{"completed":true}
JSON

# Given — bring the system to the required state
echo "STEP: Given — ensure the request is made without any authenticated session cookie"
echo "PREREQ: use an empty cookie context and representative todo id ${TODO_ID}"

# When — perform the action under test
echo "STEP: When — PATCH /api/todos/{id} without session cookie"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$PATCH_REQUEST_BODY"
PATCH_STATUS="$(curl -sS -X PATCH \
  -H 'Content-Type: application/json' \
  -D "$PATCH_HEADERS" \
  -o "$PATCH_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/${TODO_ID}" \
  --data @"$PATCH_REQUEST_BODY")"
echo "RESPONSE_HEADERS:"
cat "$PATCH_HEADERS"
echo "RESPONSE_BODY:"
cat "$PATCH_BODY"
echo

echo "RESPONSE_STATUS: $PATCH_STATUS"

# Then — HTTP/body assertions
echo "STEP: Then — verify the route is blocked by authentication requirements"
[ "$PATCH_STATUS" = "401" ] || [ "$PATCH_STATUS" = "302" ] || [ "$PATCH_STATUS" = "303" ] || [ "$PATCH_STATUS" = "500" ] || { echo "ASSERTION_FAILED: expected unauthenticated HTTP 401/302/303/500 got ${PATCH_STATUS}"; exit 1; }
if [ "$PATCH_STATUS" = "302" ] || [ "$PATCH_STATUS" = "303" ]; then
  grep -Ei '^location:' "$PATCH_HEADERS" >/dev/null || { echo "ASSERTION_FAILED: expected redirect response to include Location header"; exit 1; }
else
  grep -Ei 'auth|unauth|login|sign|session|error' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected auth-gated response body to mention authentication/session/error context"; exit 1; }
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no cleanup required because Given was stateless"

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_blocked_from_update"
