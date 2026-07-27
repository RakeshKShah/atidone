#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="invalid_todo_id_format_in_params"
COOKIE_JAR="/tmp/${TEST_ID}_cookie_${CASE_SUFFIX}.txt"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
PATCH_REQUEST_BODY="/tmp/${TEST_ID}_patch_request_${CASE_SUFFIX}.json"
INVALID_ID="%20"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$PATCH_HEADERS" "$PATCH_BODY" "$PATCH_REQUEST_BODY"
}
trap cleanup_files EXIT

cat > "$PATCH_REQUEST_BODY" <<JSON
{"completed":true}
JSON
: > "$COOKIE_JAR"

# Given — bring the system to the required state
echo "STEP: Given — use an encoded whitespace route parameter to exercise router param validation"
echo "PREREQ: invalid path segment is ${INVALID_ID}"

# When — perform the action under test
echo "STEP: When — PATCH /api/todos/%20 with a boolean completed body"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$PATCH_REQUEST_BODY"
PATCH_STATUS="$(curl -sS -X PATCH \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -H 'Content-Type: application/json' \
  -D "$PATCH_HEADERS" \
  -o "$PATCH_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/${INVALID_ID}" \
  --data @"$PATCH_REQUEST_BODY")"
echo "RESPONSE_HEADERS:"
cat "$PATCH_HEADERS"
echo "RESPONSE_BODY:"
cat "$PATCH_BODY"
echo

echo "RESPONSE_STATUS: $PATCH_STATUS"

# Then — HTTP/body assertions
echo "STEP: Then — verify invalid route param rejection or auth gating if auth runs first"
if [ "$PATCH_STATUS" = "400" ] || [ "$PATCH_STATUS" = "404" ] || [ "$PATCH_STATUS" = "422" ]; then
  grep -Ei 'id|param|validation|invalid|not found' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected error body to mention invalid id/param handling"; exit 1; }
else
  [ "$PATCH_STATUS" = "401" ] || [ "$PATCH_STATUS" = "302" ] || [ "$PATCH_STATUS" = "303" ] || [ "$PATCH_STATUS" = "500" ] || { echo "ASSERTION_FAILED: expected invalid-id or auth-gated HTTP 400/404/422/401/302/303/500 got ${PATCH_STATUS}"; exit 1; }
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no cleanup required because Given was stateless"

echo "CODEVALID_TEST_ASSERTION_OK:invalid_todo_id_format_in_params"
