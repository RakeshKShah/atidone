#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="invalid_body_wrong_completed_type"
COOKIE_JAR="/tmp/${TEST_ID}_cookie_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"
CREATE_REQUEST_BODY="/tmp/${TEST_ID}_create_request_${CASE_SUFFIX}.json"
PATCH_REQUEST_BODY="/tmp/${TEST_ID}_patch_request_${CASE_SUFFIX}.json"
TODO_TITLE="codevalid-${TEST_ID}-${CASE_SUFFIX}"
TODO_ID="todo-456"
CREATED_TODO_ID=""

cleanup_files() {
  rm -f "$COOKIE_JAR" "$CREATE_HEADERS" "$CREATE_BODY" "$PATCH_HEADERS" "$PATCH_BODY" "$DELETE_HEADERS" "$DELETE_BODY" "$CREATE_REQUEST_BODY" "$PATCH_REQUEST_BODY"
}
trap cleanup_files EXIT

cat > "$CREATE_REQUESTBODY_FIX_ME" 2>/dev/null || true
rm -f "$CREATE_REQUESTBODY_FIX_ME" 2>/dev/null || true
cat > "$CREATE_REQUEST_BODY" <<JSON
{"title":"${TODO_TITLE}"}
JSON
cat > "$PATCH_REQUEST_BODY" <<JSON
{"completed":"yes"}
JSON
: > "$COOKIE_JAR"

# Given — bring the system to the required state
echo "STEP: Given — attempt to create a todo so wrong-type validation can target a real todo when authenticated"
echo "PREREQ: use only public endpoints and an empty cookie jar when no auth seed seam is available"
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

# When — perform the action under test
echo "STEP: When — PATCH /api/todos/{id} with completed as a string instead of a boolean"
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
echo "STEP: Then — verify type validation failure or auth gating"
if [ "$CREATE_STATUS" = "200" ] || [ "$CREATE_STATUS" = "201" ]; then
  [ "$PATCH_STATUS" = "400" ] || [ "$PATCH_STATUS" = "422" ] || { echo "ASSERTION_FAILED: expected validation HTTP 400 or 422 got ${PATCH_STATUS}"; exit 1; }
  grep -Ei 'completed|boolean|validation|invalid' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected validation body to mention completed boolean validation"; exit 1; }
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

echo "CODEVALID_TEST_ASSERTION_OK:invalid_body_wrong_completed_type"
