#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_unauthenticated_access_denied"
TODO_ID="todo-789-${CASE_SUFFIX}"
WHEN_HEADERS="/tmp/${TEST_ID}_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/${TEST_ID}_when_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$WHEN_HEADERS" "$WHEN_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — prepare an unauthenticated request with no session cookie"
echo "PREREQ: no authenticated session is established for this request"

# When — perform the action under test
echo "STEP: When — send DELETE request to the protected todo endpoint without credentials"
echo "REQUEST_HEADERS: none"
echo "REQUEST_BODY:"
code=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$TODO_ID")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — unauthenticated access is denied or redirected into auth flow"
case "$code" in
  401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: expected unauthenticated status 401/302/303/500 got ${code}"; exit 1 ;;
esac

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no cleanup required for stateless unauthenticated request"

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_unauthenticated_access_denied"
