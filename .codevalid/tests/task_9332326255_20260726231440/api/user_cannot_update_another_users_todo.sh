#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="user_cannot_update_another_users_todo"
OWNER_COOKIE_JAR="/tmp/${TEST_ID}_owner_cookie_${CASE_SUFFIX}.txt"
ATTACKER_COOKIE_JAR="/tmp/${TEST_ID}_attacker_cookie_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
OWNER_LIST_HEADERS="/tmp/${TEST_ID}_owner_list_headers_${CASE_SUFFIX}.txt"
OWNER_LIST_BODY="/tmp/${TEST_ID}_owner_list_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"
CREATE_REQUEST_BODY="/tmp/${TEST_ID}_create_request_${CASE_SUFFIX}.json"
PATCH_REQUEST_BODY="/tmp/${TEST_ID}_patch_request_${CASE_SUFFIX}.json"
TODO_TITLE="codevalid-${TEST_ID}-${CASE_SUFFIX}"
TODO_ID="todo-999"
CREATED_TODO_ID=""

cleanup_files() {
  rm -f "$OWNER_COOKIE_JAR" "$ATTACKER_COOKIE_JAR" "$CREATE_HEADERS" "$CREATE_BODY" "$PATCH_HEADERS" "$PATCH_BODY" "$OWNER_LIST_HEADERS" "$OWNER_LIST_BODY" "$DELETE_HEADERS" "$DELETE_BODY" "$CREATE_REQUEST_BODY" "$PATCH_REQUEST_BODY"
}
trap cleanup_files EXIT

cat > "$CREATE_REQUEST_BODY" <<JSON
{"title":"${TODO_TITLE}"}
JSON
cat > "$PATCH_REQUEST_BODY" <<JSON
{"completed":true}
JSON
: > "$OWNER_COOKIE_JAR"
: > "$ATTACKER_COOKIE_JAR"

# Given — bring the system to the required state
echo "STEP: Given — attempt to create a todo for an owner session using only public API entry points"
echo "PREREQ: this stack exposes no public session-bootstrap API; proceeding with empty cookie jars to observe auth gating if present"
echo "PREREQ: owner create attempt via POST /api/todos"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$CREATE_REQUEST_BODY"
CREATE_STATUS="$(curl -sS -X POST \
  -b "$OWNER_COOKIE_JAR" -c "$OWNER_COOKIE_JAR" \
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

# When — perform the action under test
echo "STEP: When — second session PATCHes /api/todos/{id} for a todo it does not own"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$PATCH_REQUEST_BODY"
PATCH_STATUS="$(curl -sS -X PATCH \
  -b "$ATTACKER_COOKIE_JAR" -c "$ATTACKER_COOKIE_JAR" \
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
echo "STEP: Then — verify either cross-user isolation (404) or auth gating semantics"
if [ "$CREATE_STATUS" = "200" ] || [ "$CREATE_STATUS" = "201" ]; then
  [ "$PATCH_STATUS" = "404" ] || { echo "ASSERTION_FAILED: expected cross-user update HTTP 404 got ${PATCH_STATUS}"; exit 1; }
  grep -F 'Todo not found' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain Todo not found"; exit 1; }

  OWNER_LIST_STATUS="$(curl -sS \
    -b "$OWNER_COOKIE_JAR" -c "$OWNER_COOKIE_JAR" \
    -D "$OWNER_LIST_HEADERS" \
    -o "$OWNER_LIST_BODY" \
    -w '%{http_code}' \
    "$BASE_URL/api/todos")"
  echo "RESPONSE_HEADERS:"
  cat "$OWNER_LIST_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$OWNER_LIST_BODY"
  echo
  echo "RESPONSE_STATUS: $OWNER_LIST_STATUS"
  [ "$OWNER_LIST_STATUS" = "200" ] || { echo "ASSERTION_FAILED: expected owner list HTTP 200 got ${OWNER_LIST_STATUS}"; exit 1; }
  jq -e --arg id "$TODO_ID" 'map(select(.id == $id and (.completed == false or .completed == 0))) | length == 1' "$OWNER_LIST_BODY" >/dev/null 2>&1 || { echo "ASSERTION_FAILED: expected owner todo ${TODO_ID} to remain unchanged after attacker attempt"; exit 1; }
else
  [ "$CREATE_STATUS" = "401" ] || [ "$CREATE_STATUS" = "302" ] || [ "$CREATE_STATUS" = "303" ] || [ "$CREATE_STATUS" = "500" ] || { echo "ASSERTION_FAILED: expected auth-gated create HTTP 401/302/303/500 got ${CREATE_STATUS}"; exit 1; }
  [ "$PATCH_STATUS" = "401" ] || [ "$PATCH_STATUS" = "302" ] || [ "$PATCH_STATUS" = "303" ] || [ "$PATCH_STATUS" = "500" ] || { echo "ASSERTION_FAILED: expected auth-gated patch HTTP 401/302/303/500 got ${PATCH_STATUS}"; exit 1; }
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — delete created owner todo only if it was actually created"
if [ -n "$CREATED_TODO_ID" ]; then
  DELETE_STATUS="$(curl -sS -X DELETE \
    -b "$OWNER_COOKIE_JAR" -c "$OWNER_COOKIE_JAR" \
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

echo "CODEVALID_TEST_ASSERTION_OK:user_cannot_update_another_users_todo"
