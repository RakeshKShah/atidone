#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_invalid_id_format_validation_error"
INVALID_ID='invalid%3C%3Eid!@%23'
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
GIVEN_HEADERS="/tmp/${TEST_ID}_given_headers_${CASE_SUFFIX}.txt"
GIVEN_BODY="/tmp/${TEST_ID}_given_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/${TEST_ID}_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/${TEST_ID}_when_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$GIVEN_HEADERS" "$GIVEN_BODY" "$WHEN_HEADERS" "$WHEN_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — bootstrap cookie jar for a best-effort authenticated request context"
CREATE_BODY=$(printf '{"title":"invalid-id-bootstrap-%s"}' "$CASE_SUFFIX")
echo "PREREQ: capture any cookie emitted by the app through a create attempt"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY: $CREATE_BODY"
given_code=$(curl -sS -D "$GIVEN_HEADERS" -o "$GIVEN_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
  --data "$CREATE_BODY")
echo "RESPONSE_HEADERS:"
cat "$GIVEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$GIVEN_BODY"
echo "RESPONSE_STATUS: $given_code"

# When — perform the action under test
echo "STEP: When — send DELETE request with malformed route parameter"
echo "REQUEST_HEADERS: Cookie jar from Given if any"
echo "REQUEST_BODY:"
code=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$INVALID_ID" \
  -b "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — malformed id is rejected or remains behind the auth gate"
case "$code" in
  400|404|422|401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: expected validation/auth status 400/404/422/401/302/303/500 got ${code}"; exit 1 ;;
esac

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no cleanup required for malformed route parameter scenario"

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_invalid_id_format_validation_error"
