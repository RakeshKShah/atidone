#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="update_nonexistent_todo_returns_404"
COOKIE_JAR="/tmp/${TEST_ID}_cookie_${CASE_SUFFIX}.txt"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
LIST_HEADERS="/tmp/${TEST_ID}_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY="/tmp/${TEST_ID}_list_body_${CASE_SUFFIX}.txt"
PATCH_REQ_BODY="/tmp/${TEST_ID}_patch_req_${CASE_SUFFIX}.json"
TODO_ID="nonexistent-${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$PATCH_HEADERS" "$PATCH_BODY" "$LIST_HEADERS" "$LIST_BODY" "$PATCH_REQ_BODY"
}
trap cleanup_files EXIT

printf '{"completed":true}' > "$PATCH_REQ_BODY"

# Given — bring the system to the required state
echo "STEP: Given — bootstrap an authenticated session with no todo for the target id"
echo "PREREQ: bootstrap authenticated session via test auth helper"
./tests/task_9332326255_20260726231440/api/_auth_session_helper.sh "$TEST_ID" "$CASE_SUFFIX" "$COOKIE_JAR"

# When — perform the action under test
echo "STEP: When — PATCH /api/todos/{id} for a non-existent todo id"
echo "REQUEST_HEADERS:"
echo 'Content-Type: application/json'
echo "REQUEST_BODY: $(cat "$PATCH_REQ_BODY")"
patch_status="$(curl -sS -X PATCH "$BASE_URL/api/todos/$TODO_ID" \
  -H 'Content-Type: application/json' \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  --data @"$PATCH_REQ_BODY" \
  -D "$PATCH_HEADERS" \
  -o "$PATCH_BODY" \
  -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$PATCH_HEADERS"
echo "RESPONSE_BODY:"
cat "$PATCH_BODY"
echo
echo "RESPONSE_STATUS: $patch_status"

# Then — HTTP/body assertions
echo "STEP: Then — verify 404 is returned and no todo with that id appears in the user's list"
[ "$patch_status" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${patch_status}"; exit 1; }
grep -F 'Todo not found' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain Todo not found"; exit 1; }
list_status="$(curl -sS "$BASE_URL/api/todos" \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -D "$LIST_HEADERS" \
  -o "$LIST_BODY" \
  -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$LIST_BODY"
echo
echo "RESPONSE_STATUS: $list_status"
[ "$list_status" = "200" ] || { echo "ASSERTION_FAILED: expected list HTTP 200 got ${list_status}"; exit 1; }
jq -e --arg id "$TODO_ID" 'map(select(.id == $id)) | length == 0' "$LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected no todo ${TODO_ID} in list response"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — no cleanup required because Given was session-only"

echo "CODEVALID_TEST_ASSERTION_OK:update_nonexistent_todo_returns_404"
