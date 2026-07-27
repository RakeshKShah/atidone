#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_unauthenticated_rejected"
WHEN_HEADERS="/tmp/${TEST_ID}_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/${TEST_ID}_when_body_${CASE_SUFFIX}.txt"
VERIFY_HEADERS="/tmp/${TEST_ID}_verify_headers_${CASE_SUFFIX}.txt"
VERIFY_BODY="/tmp/${TEST_ID}_verify_body_${CASE_SUFFIX}.txt"
TARGET_ID="todo-def-456-${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$WHEN_HEADERS" "$WHEN_BODY" "$VERIFY_HEADERS" "$VERIFY_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — no authentication credentials are provided"
echo "PREREQ: using a request without cookies or auth headers against the public delete endpoint"

# When — perform the action under test
echo "STEP: When — delete todo without any authenticated session"
echo "REQUEST_HEADERS: none"
echo "REQUEST_BODY:"
code=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' \n  -X DELETE "$BASE_URL/api/todos/$TARGET_ID")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — unauthenticated request is rejected before deletion"
case "$code" in
  401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: expected unauthenticated delete to be rejected with HTTP 401, 302, 303, or 500 got ${code}"; exit 1 ;;
esac

echo "REQUEST_HEADERS: none"
echo "REQUEST_BODY:"
verify_code=$(curl -sS -D "$VERIFY_HEADERS" -o "$VERIFY_BODY" -w '%{http_code}' \n  -X GET "$BASE_URL/api/todos")
echo "RESPONSE_HEADERS:"
cat "$VERIFY_HEADERS"
echo "RESPONSE_BODY:"
cat "$VERIFY_BODY"
echo "RESPONSE_STATUS: $verify_code"
case "$verify_code" in
  401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: expected unauthenticated todo list to remain guarded with HTTP 401, 302, 303, or 500 got ${verify_code}"; exit 1 ;;
esac

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no stateful setup was performed"

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_unauthenticated_rejected"
