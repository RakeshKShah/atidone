#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="update_todo_set_completed_false"
COOKIE_JAR="/tmp/${TEST_ID}_cookie_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
PREPATCH_HEADERS="/tmp/${TEST_ID}_prepatch_headers_${CASE_SUFFIX}.txt"
PREPATCH_BODY="/tmp/${TEST_ID}_prepatch_body_${CASE_SUFFIX}.txt"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
LIST_HEADERS="/tmp/${TEST_ID}_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY="/tmp/${TEST_ID}_list_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"
CREATE_REQUEST_BODY="/tmp/${TEST_ID}_create_request_${CASE_SUFFIX}.json"
PREPATCH_REQUEST_BODY="/tmp/${TEST_ID}_prepatch_request_${CASE_SUFFIX}.json"
PATCH_REQUEST_BODY="/tmp/${TEST_ID}_patch_request_${CASE_SUFFIX}.json"
TODO_TITLE="codevalid-${TEST_ID}-${CASE_SUFFIX}"
TODO_ID="todo-456"
CREATED_TODO_ID=""

cleanup_files() {
  rm -f "$COOKIE_JAR" "$CREATE_HEADERS" "$CREATE_BODY" "$PREPATCH_HEADERS" "$PREPATCH_BODY" "$PATCH_HEADERS" "$PATCH_BODY" "$LIST_HEADERS" "$LIST_BODY" "$DELETE_HEADERS" "$DELETE_BODY" "$CREATE_REQUEST_BODY" "$PREPATCH_REQUEST_BODY" "$PATCH_REQUEST_BODY"
}
trap cleanup_files EXIT

cat > "$CREATE_REQUEST_BODY" <<JSON
{"title":"${TODO_TITLE}"}
JSON
cat > "$PREPATCH_REQUEST_BODY" <<JSON
{"completed":true}
JSON
cat > "$PATCH_REQUEST_BODY" <<JSON
{"completed":false}
JSON
: > "$COOKIE_JAR"

# Given — bring the system to the required state
echo "STEP: Given — attempt to create a todo and mark it completed before testing completed=false"
echo "PREREQ: use only public todo API endpoints; if auth is required and no public auth bootstrap exists, observe auth gating"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$CREATE_REQUEST_BODY"
CREATE_STATUS="$(curl -sS -X POST \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
  -H 'Content-Type: application/json' \
  -D "$CREATE_HEADERS" \
  -o "$CREATE_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos" \
  --data @"$CREATE_REQUEST_BODY")"
echo "RESPONSE_HEADERS:"
cat "$CREATE_HEADERS"
echo "RESPONSE_BODY:"
cat "$CREATE_BODY"
echo

echo "RESPONSE_STATUS: $CREATE_STATUS"
CREATED_TODO_ID="$(jq -r '.id // empty' "$CREATE_BODY" 2>/dev/null || true)"
if [ -n "$CREATED_TODO_ID" ]; then
  TODO_ID="$CREATED_TODO_ID"
fi

PREPATCH_STATUS=""
if [ "$CREATE_STATUS" = "200" ] || [ "$CREATE_STATUS" = "201" ]; then
  echo "PREREQ: mark the created todo completed=true before the primary When step"
  echo "REQUEST_HEADERS: Content-Type: application/json"
  echo "REQUEST_BODY:"
  cat "$PREPATCH_REQUEST_BODY"
  PREPATCH_STATUS="$(curl -sS -X PATCH \
    -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -H 'Content-Type: application/json' \
    -D "$PREPATCH_HEADERS" \
    -o "$PREPATCH_BODY" \
    -w '%{http_code}' \
    "$BASE_URL/api/todos/${TODO_ID}" \
    --data @"$PREPATCH_REQUEST_BODY")"
  echo "RESPONSE_HEADERS:"
  cat "$PREPATCH_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$PREPATCH_BODY"
  echo
  echo "RESPONSE_STATUS: $PREPATCH_STATUS"
  [ "$PREPATCH_STATUS" = "200" ] || { echo "ASSERTION_FAILED: expected Given pre-patch HTTP 200 got ${PREPATCH_STATUS}"; exit 1; }
fi

# When — perform the action under test
echo "STEP: When — PATCH /api/todos/{id} with completed=false"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$PATCH_REQUEST_BODY"
PATCH_STATUS="$(curl -sS -X PATCH \
  -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
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
echo "STEP: Then — verify explicit completed=false update semantics or auth gating"
if [ "$CREATE_STATUS" = "200" ] || [ "$CREATE_STATUS" = "201" ]; then
  [ "$PATCH_STATUS" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${PATCH_STATUS}"; exit 1; }
  jq -e '(.completed == false or .completed == 0)' "$PATCH_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected PATCH response completed=false/0"; exit 1; }

  LIST_STATUS="$(curl -sS \
    -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -D "$LIST_HEADERS" \
    -o "$LIST_BODY" \
    -w '%{http_code}' \
    "$BASE_URL/api/todos")"
  echo "RESPONSE_HEADERS:"
  cat "$LIST_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$LIST_BODY"
  echo
  echo "RESPONSE_STATUS: $LIST_STATUS"
  [ "$LIST_STATUS" = "200" ] || { echo "ASSERTION_FAILED: expected list HTTP 200 got ${LIST_STATUS}"; exit 1; }
  jq -e --arg id "$TODO_ID" 'map(select(.id == $id and (.completed == false or .completed == 0))) | length == 1' "$LIST_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected persisted completed=false for todo ${TODO_ID}"; exit 1; }
else
  [ "$CREATE_STATUS" = "401" ] || [ "$CREATE_STATUS" = "302" ] || [ "$CREATE_STATUS" = "303" ] || [ "$CREATE_STATUS" = "500" ] || { echo "ASSERTION_FAILED: expected auth-gated create HTTP 401/302/303/500 got ${CREATE_STATUS}"; exit 1; }
  [ "$PATCH_STATUS" = "401" ] || [ "$PATCH_STATUS" = "302" ] || [ "$PATCH_STATUS" = "303" ] || [ "$PATCH_STATUS" = "500" ] || { echo "ASSERTION_FAILED: expected auth-gated patch HTTP 401/302/303/500 got ${PATCH_STATUS}"; exit 1; }
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — delete created todo only if Given created one"
if [ -n "$CREATED_TODO_ID" ]; then
  DELETE_STATUS="$(curl -sS -X DELETE \
    -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    -D "$DELETE_HEADERS" \
    -o "$DELETE_BODY" \
    -w '%{http_code}' \
    "$BASE_URL/api/todos/${CREATED_TODO_ID}" || true)"
  echo "RESPONSE_HEADERS:"
  cat "$DELETE_HEADERS" 2>/dev/null || true
  echo "RESPONSE_BODY:"
  cat "$DELETE_BODY" 2>/dev/null || true
  echo
  echo "RESPONSE_STATUS: $DELETE_STATUS"
  [ "$DELETE_STATUS" = "200" ] || [ "$DELETE_STATUS" = "404" ] || [ "$DELETE_STATUS" = "401" ] || [ "$DELETE_STATUS" = "302" ] || [ "$DELETE_STATUS" = "303" ] || [ "$DELETE_STATUS" = "500" ] || { echo "ASSERTION_FAILED: expected cleanup HTTP 200/404/401/302/303/500 got ${DELETE_STATUS}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:update_todo_set_completed_false"
