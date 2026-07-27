#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="invalid_body_missing_completed_field"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
LOGIN_HEADERS="/tmp/${TEST_ID}_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY="/tmp/${TEST_ID}_login_body_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
LIST_HEADERS="/tmp/${TEST_ID}_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY="/tmp/${TEST_ID}_list_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"
LOGIN_REQUEST_BODY="/tmp/${TEST_ID}_login_request_${CASE_SUFFIX}.json"
CREATE_REQUEST_BODY="/tmp/${TEST_ID}_create_request_${CASE_SUFFIX}.json"
PATCH_REQUEST_BODY="/tmp/${TEST_ID}_patch_request_${CASE_SUFFIX}.json"
TODO_TITLE="todo-${TEST_ID}-${CASE_SUFFIX}"
TODO_ID=""

cleanup_files() {
  rm -f "$COOKIE_JAR" "$LOGIN_HEADERS" "$LOGIN_BODY" "$CREATE_HEADERS" "$CREATE_BODY" "$PATCH_HEADERS" "$PATCH_BODY" "$LIST_HEADERS" "$LIST_BODY" "$DELETE_HEADERS" "$DELETE_BODY" "$LOGIN_REQUEST_BODY" "$CREATE_REQUEST_BODY" "$PATCH_REQUEST_BODY"
}
trap cleanup_files EXIT

cat > "$LOGIN_REQUEST_BODY" <<JSON
{"username":"codevalid-${TEST_ID}-${CASE_SUFFIX}","userId":"user-${TEST_ID}-${CASE_SUFFIX}"}
JSON

cat > "$CREATE_REQUEST_BODY" <<JSON
{"title":"${TODO_TITLE}"}
JSON

cat > "$PATCH_REQUEST_BODY" <<JSON
{}
JSON

echo "STEP: Given — bootstrap authenticated session and create a todo for the validation test"
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

echo "PREREQ: create a todo owned by the authenticated user"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_HEADERS: Cookie jar ${COOKIE_JAR}"
echo "REQUEST_BODY:"
cat "$CREATE_REQUEST_BODY"
CREATE_CODE="$(curl -sS -X POST \
  -b "$COOKIE_JAR" \
  -c "$COOKIE_JAR" \
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
echo "RESPONSE_STATUS: ${CREATE_CODE}"
[ "$CREATE_CODE" = "200" ] || [ "$CREATE_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 200 or 201 from create got ${CREATE_CODE}"; exit 1; }
TODO_ID="$(jq -r '.id // empty' "$CREATE_BODY")"
[ -n "$TODO_ID" ] || { echo "ASSERTION_FAILED: expected created todo id in response"; exit 1; }

echo "STEP: When — PATCH the todo with an invalid body missing completed"
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

echo "STEP: Then — assert validation failure and unchanged todo state"
[ "$PATCH_CODE" = "400" ] || [ "$PATCH_CODE" = "422" ] || { echo "ASSERTION_FAILED: expected HTTP 400 or 422 got ${PATCH_CODE}"; exit 1; }
grep -Ei 'completed|validation|invalid|required' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected validation response body to mention completed field validation"; exit 1; }

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
grep -F '"id":"'"${TODO_ID}"'"' "$LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected list response to contain todo id ${TODO_ID}"; exit 1; }
grep -F '"completed":false' "$LIST_BODY" >/dev/null || grep -F '"completed":0' "$LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected todo to remain not completed after invalid patch body"; exit 1; }

echo "STEP: Cleanup — delete the todo created during Given"
if [ -n "$TODO_ID" ]; then
  DELETE_CODE="$(curl -sS -X DELETE \
    -b "$COOKIE_JAR" \
    -c "$COOKIE_JAR" \
    -D "$DELETE_HEADERS" \
    -o "$DELETE_BODY" \
    -w '%{http_code}' \
    "$BASE_URL/api/todos/${TODO_ID}" || true)"
  echo "RESPONSE_HEADERS:"
  cat "$DELETE_HEADERS" 2>/dev/null || true
  echo "RESPONSE_BODY:"
  cat "$DELETE_BODY" 2>/dev/null || true
  echo "RESPONSE_STATUS: ${DELETE_CODE}"
  [ "$DELETE_CODE" = "200" ] || [ "$DELETE_CODE" = "404" ] || { echo "ASSERTION_FAILED: expected cleanup HTTP 200 or 404 got ${DELETE_CODE}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:invalid_body_missing_completed_field"
