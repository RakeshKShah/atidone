#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="user_updates_nonexistent_todo_returns_404"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
LOGIN_HEADERS="/tmp/${TEST_ID}_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY="/tmp/${TEST_ID}_login_body_${CASE_SUFFIX}.txt"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
LIST_HEADERS="/tmp/${TEST_ID}_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY="/tmp/${TEST_ID}_list_body_${CASE_SUFFIX}.txt"
LOGIN_REQUEST_BODY="/tmp/${TEST_ID}_login_request_${CASE_SUFFIX}.json"
PATCH_REQUEST_BODY="/tmp/${TEST_ID}_patch_request_${CASE_SUFFIX}.json"
TODO_ID="todo-nonexistent-${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$LOGIN_HEADERS" "$LOGIN_BODY" "$PATCH_HEADERS" "$PATCH_BODY" "$LIST_HEADERS" "$LIST_BODY" "$LOGIN_REQUEST_BODY" "$PATCH_REQUEST_BODY"
}
trap cleanup_files EXIT

cat > "$LOGIN_REQUEST_BODY" <<JSON
{"username":"codevalid-${TEST_ID}-${CASE_SUFFIX}","userId":"user-${TEST_ID}-${CASE_SUFFIX}"}
JSON

cat > "$PATCH_REQUEST_BODY" <<JSON
{"completed":true}
JSON

echo "STEP: Given — bootstrap authenticated session and use a todo id that should not exist"
echo "PREREQ: sign in test user through a repo-provided auth test seam"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$LOGIN_REQUEST_BODY"
LOGIN_CODE="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -c "$COOKIE_JAR" \
  -D "$LOGIN_HEADERS" \
  -o "$LOGIN_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/test/session" \
  --data @"$LOGIN_REQUEST_BODY")"
echo "RESPONSE_HEADERS:"
cat "$LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$LOGIN_BODY"
echo "RESPONSE_STATUS: ${LOGIN_CODE}"
[ "$LOGIN_CODE" = "200" ] || [ "$LOGIN_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 200 or 201 from session bootstrap got ${LOGIN_CODE}"; exit 1; }

echo "STEP: When — PATCH a non-existent todo id"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_HEADERS: Cookie jar ${COOKIE_JAR}"
echo "REQUEST_BODY:"
cat "$PATCH_REQUEST_BODY"
PATCH_CODE="$(curl -sS -X PATCH \
  -b "$COOKIE_JAR" \
  -c "$COOKIE_JAR" \
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
echo "RESPONSE_STATUS: ${PATCH_CODE}"

echo "STEP: Then — assert 404 is returned and no such todo appears in the user's list"
[ "$PATCH_CODE" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${PATCH_CODE}"; exit 1; }
grep -F 'Todo not found' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain Todo not found"; exit 1; }

LIST_CODE="$(curl -sS \
  -b "$COOKIE_JAR" \
  -c "$COOKIE_JAR" \
  -D "$LIST_HEADERS" \
  -o "$LIST_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$LIST_BODY"
echo "RESPONSE_STATUS: ${LIST_CODE}"
[ "$LIST_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 from list got ${LIST_CODE}"; exit 1; }
if grep -F '"id":"'"${TODO_ID}"'"' "$LIST_BODY" >/dev/null; then
  echo "ASSERTION_FAILED: expected nonexistent todo id ${TODO_ID} to be absent from list response"
  exit 1
fi

echo "STEP: Cleanup — no cleanup needed because no todo was created in Given"
echo "CODEVALID_TEST_ASSERTION_OK:user_updates_nonexistent_todo_returns_404"
