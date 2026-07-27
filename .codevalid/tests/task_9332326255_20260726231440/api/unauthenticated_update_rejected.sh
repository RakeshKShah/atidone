#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="unauthenticated_update_rejected"
OWNER_COOKIE_JAR="/tmp/${TEST_ID}_owner_cookie_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
OWNER_LIST_HEADERS="/tmp/${TEST_ID}_owner_list_headers_${CASE_SUFFIX}.txt"
OWNER_LIST_BODY="/tmp/${TEST_ID}_owner_list_body_${CASE_SUFFIX}.txt"
CREATE_REQ_BODY="/tmp/${TEST_ID}_create_req_${CASE_SUFFIX}.json"
PATCH_REQ_BODY="/tmp/${TEST_ID}_patch_req_${CASE_SUFFIX}.json"
CLEANUP_HEADERS="/tmp/${TEST_ID}_cleanup_headers_${CASE_SUFFIX}.txt"
CLEANUP_BODY="/tmp/${TEST_ID}_cleanup_body_${CASE_SUFFIX}.txt"
TODO_TITLE="todo-${TEST_ID}-${CASE_SUFFIX}"
TODO_ID=""

cleanup_files() {
  rm -f "$OWNER_COOKIE_JAR" "$CREATE_HEADERS" "$CREATE_BODY" "$PATCH_HEADERS" "$PATCH_BODY" "$OWNER_LIST_HEADERS" "$OWNER_LIST_BODY" "$CREATE_REQ_BODY" "$PATCH_REQ_BODY" "$CLEANUP_HEADERS" "$CLEANUP_BODY"
}
trap cleanup_files EXIT

printf '{"title":"%s"}' "$TODO_TITLE" > "$CREATE_REQ_BODY"
printf '{"completed":true}' > "$PATCH_REQ_BODY"

# Given — bring the system to the required state
echo "STEP: Given — create an authenticated owner's todo and use no session for the update"
echo "PREREQ: bootstrap owner session"
AUTH_TEST_USER="owner-${CASE_SUFFIX}" ./tests/task_9332326255_20260726231440/api/_auth_session_helper.sh "$TEST_ID-owner" "$CASE_SUFFIX" "$OWNER_COOKIE_JAR"
echo "PREREQ: owner creates a todo"
echo "REQUEST_HEADERS:"
echo 'Content-Type: application/json'
echo "REQUEST_BODY: $(cat "$CREATE_REQ_BODY")"
create_status="$(curl -sS -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -b "$OWNER_COOKIE_JAR" -c "$OWNER_COOKIE_JAR" \
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
echo "STEP: When — send PATCH /api/todos/{id} without a valid session"
echo "REQUEST_HEADERS:"
echo 'Content-Type: application/json'
echo "REQUEST_BODY: $(cat "$PATCH_REQ_BODY")"
patch_status="$(curl -sS -X PATCH "$BASE_URL/api/todos/$TODO_ID" \
  -H 'Content-Type: application/json' \
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
echo "STEP: Then — verify the unauthenticated update is rejected and data is unchanged"
case "$patch_status" in
  401|302|303|500) ;;
  *) echo "ASSERTION_FAILED: expected unauthenticated status 401/302/303/500 got ${patch_status}"; exit 1 ;;
esac
owner_list_status="$(curl -sS "$BASE_URL/api/todos" \
  -b "$OWNER_COOKIE_JAR" -c "$OWNER_COOKIE_JAR" \
  -D "$OWNER_LIST_HEADERS" \
  -o "$OWNER_LIST_BODY" \
  -w '%{http_code}')"
echo "RESPONSE_HEADERS:"
cat "$OWNER_LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$OWNER_LIST_BODY"
echo
echo "RESPONSE_STATUS: $owner_list_status"
[ "$owner_list_status" = "200" ] || { echo "ASSERTION_FAILED: expected owner list HTTP 200 got ${owner_list_status}"; exit 1; }
jq -e --arg id "$TODO_ID" 'map(select(.id == $id and (.completed == false or .completed == 0))) | length == 1' "$OWNER_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected todo ${TODO_ID} to remain unchanged after unauthenticated PATCH"; exit 1; }

# Cleanup — undo Given side effects
echo "STEP: Cleanup — delete the owner's created todo"
if [ -n "$TODO_ID" ]; then
  cleanup_status="$(curl -sS -X DELETE "$BASE_URL/api/todos/$TODO_ID" \
    -b "$OWNER_COOKIE_JAR" -c "$OWNER_COOKIE_JAR" \
    -D "$CLEANUP_HEADERS" \
    -o "$CLEANUP_BODY" \
    -w '%{http_code}' || true)"
  [ "$cleanup_status" = "200" ] || [ "$cleanup_status" = "404" ] || { echo "ASSERTION_FAILED: expected cleanup HTTP 200/404 got ${cleanup_status}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_update_rejected"
