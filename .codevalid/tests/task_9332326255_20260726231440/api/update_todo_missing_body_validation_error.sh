#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="update_todo_missing_body_validation_error"
COOKIE_JAR="/tmp/${TEST_ID}_cookie_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
LIST_HEADERS="/tmp/${TEST_ID}_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY="/tmp/${TEST_ID}_list_body_${CASE_SUFFIX}.txt"
CREATE_REQ_BODY="/tmp/${TEST_ID}_create_req_${CASE_SUFFIX}.json"
PATCH_REQ_BODY="/tmp/${TEST_ID}_patch_req_${CASE_SUFFIX}.json"
CLEANUP_HEADERS="/tmp/${TEST_ID}_cleanup_headers_${CASE_SUFFIX}.txt"
CLEANUP_BODY="/tmp/${TEST_ID}_cleanup_body_${CASE_SUFFIX}.txt"
TODO_TITLE="todo-${TEST_ID}-${CASE_SUFFIX}"
TODO_ID=""

cleanup_files() {
  rm -f "$COOKIE_JAR" "$CREATE_HEADERS" "$CREATE_BODY" "$PATCH_HEADERS" "$PATCH_BODY" "$LIST_HEADERS" "$LIST_BODY" "$CREATE_REQ_BODY" "$PATCH_REQ_BODY" "$CLEANUP_HEADERS" "$CLEANUP_BODY"
}
trap cleanup_files EXIT

printf '{"title":"%s"}' "$TODO_TITLE" > "$CREATE_REQ_BODY"
printf '{}' > "$PATCH_REQ_BODY"

# Given — bring the system to the required state
echo "STEP: Given — create an authenticated user-owned todo"
echo "PREREQ: bootstrap authenticated session via test auth helper"
./tests/task_9332326255_20260726231440/api/_auth_session_helper.sh "$TEST_ID" "$CASE_SUFFIX" "$COOKIE_JAR"
echo "PREREQ: create a todo before sending invalid PATCH body"
echo "REQUEST_HEADERS:"
echo 'Content-Type: application/json'
echo "REQUEST_BODY: $(cat "$CREATE_REQ_BODY")"
create_status="$(curl -sS -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  --data @"$CREATE_REQ_BODY" \
  -D "$CREATE_HEADERS" \
  -o "$CREATE_BODY" \
  -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$CREATE_HEADERS"
echo "RESPONSE_BODY:"
cat "$CREATE_BODY"
echo
echo "RESPONSE_STATUS: $create_status"
[ "$create_status" = "200" ] || { echo "ASSERTION_FAILED: expected Given create HTTP 200 got ${create_status}"; exit 1; }
TODO_ID="$(jq -r '.id // empty' "$CREATE_BODY")"
[ -n "$TODO_ID" ] || { echo "ASSERTION_FAILED: expected created todo id in Given response"; exit 1; }

# When — perform the action under test
echo "STEP: When — PATCH /api/todos/{id} with missing completed field"
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
echo "STEP: Then — verify validation error is returned and the todo remains unchanged"
[ "$patch_status" = "400" ] || { echo "ASSERTION_FAILED: expected HTTP 400 got ${patch_status}"; exit 1; }
grep -E 'completed|validation|required|invalid' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected validation message mentioning completed/validation/required"; exit 1; }
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
jq -e --arg id "$TODO_ID" 'map(select(.id == $id and (.completed == false or .completed == 0))) | length == 1' "$LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected todo ${TODO_ID} to remain incomplete after invalid PATCH"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — delete the created todo"
if [ -n "$TODO_ID" ]; then
  cleanup_status="$(curl -sS -X DELETE "$BASE_URL/api/todos/$TODO_ID" \
    -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -D "$CLEANUP_HEADERS" \
    -o "$CLEANUP_BODY" \
    -w '%{http_code}' || true)"
  [ "$cleanup_status" = "200" ] || [ "$cleanup_status" = "404" ] || { echo "ASSERTION_FAILED: expected cleanup HTTP 200/404 got ${cleanup_status}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:update_todo_missing_body_validation_error"
