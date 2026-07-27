#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="authenticated_user_updates_own_todo_to_not_completed"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
LOGIN_HEADERS="/tmp/${TEST_ID}_login_headers_${CASE_SUFFIX}.txt"
LOGIN_BODY="/tmp/${TEST_ID}_login_body_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
PATCH1_HEADERS="/tmp/${TEST_ID}_patch1_headers_${CASE_SUFFIX}.txt"
PATCH1_BODY="/tmp/${TEST_ID}_patch1_body_${CASE_SUFFIX}.txt"
PATCH2_HEADERS="/tmp/${TEST_ID}_patch2_headers_${CASE_SUFFIX}.txt"
PATCH2_BODY="/tmp/${TEST_ID}_patch2_body_${CASE_SUFFIX}.txt"
LIST_HEADERS="/tmp/${TEST_ID}_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY="/tmp/${TEST_ID}_list_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"
LOGIN_REQUEST_BODY="/tmp/${TEST_ID}_login_request_${CASE_SUFFIX}.json"
CREATE_REQUEST_BODY="/tmp/${TEST_ID}_create_request_${CASE_SUFFIX}.json"
PATCH_TRUE_REQUEST_BODY="/tmp/${TEST_ID}_patch_true_request_${CASE_SUFFIX}.json"
PATCH_FALSE_REQUEST_BODY="/tmp/${TEST_ID}_patch_false_request_${CASE_SUFFIX}.json"
TODO_TITLE="todo-${TEST_ID}-${CASE_SUFFIX}"
TODO_ID=""

cleanup_files() {
  rm -f "$COOKIE_JAR" "$LOGIN_HEADERS" "$LOGIN_BODY" "$CREATE_HEADERS" "$CREATE_BODY" "$PATCH1_HEADERS" "$PATCH1_BODY" "$PATCH2_HEADERS" "$PATCH2_BODY" "$LIST_HEADERS" "$LIST_BODY" "$DELETE_HEADERS" "$DELETE_BODY" "$LOGIN_REQUEST_BODY" "$CREATE_REQUEST_BODY" "$PATCH_TRUE_REQUEST_BODY" "$PATCH_FALSE_REQUEST_BODY"
}
trap cleanup_files EXIT

cat > "$LOGIN_REQUEST_BODY" <<JSON
{"username":"codevalid-${TEST_ID}-${CASE_SUFFIX}","userId":"user-${TEST_ID}-${CASE_SUFFIX}"}
JSON

cat > "$CREATE_REQUEST_BODY" <<JSON
{"title":"${TODO_TITLE}"}
JSON

cat > "$PATCH_TRUE_REQUEST_BODY" <<JSON
{"completed":true}
JSON

cat > "$PATCH_FALSE_REQUEST_BODY" <<JSON
{"completed":false}
JSON

echo "STEP: Given — bootstrap authenticated session, create a todo, and set it completed=true"
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

echo "PREREQ: create a todo for the authenticated user"
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

echo "PREREQ: mark the created todo completed=true before the primary action"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_HEADERS: Cookie jar ${COOKIE_JAR}"
echo "REQUEST_BODY:"
cat "$PATCH_TRUE_REQUEST_BODY"
PATCH1_CODE="$(curl -sS -X PATCH \
  -b "$COOKIE_JAR" \
  -c "$COOKIE_JAR" \
  -H 'Content-Type: application/json' \
  -D "$PATCH1_HEADERS" \
  -o "$PATCH1_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/${TODO_ID}" \
  --data @"$PATCH_TRUE_REQUEST_BODY")"
echo "RESPONSE_HEADERS:"
cat "$PATCH1_HEADERS"
echo "RESPONSE_BODY:"
cat "$PATCH1_BODY"
echo "RESPONSE_STATUS: ${PATCH1_CODE}"
[ "$PATCH1_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 from precondition patch got ${PATCH1_CODE}"; exit 1; }
grep -F '"completed":true' "$PATCH1_BODY" >/dev/null || grep -F '"completed":1' "$PATCH1_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected precondition patch response to show completed=true"; exit 1; }

echo "STEP: When — update the authenticated user's own todo to completed=false"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_HEADERS: Cookie jar ${COOKIE_JAR}"
echo "REQUEST_BODY:"
cat "$PATCH_FALSE_REQUEST_BODY"
PATCH2_CODE="$(curl -sS -X PATCH \
  -b "$COOKIE_JAR" \
  -c "$COOKIE_JAR" \
  -H 'Content-Type: application/json' \
  -D "$PATCH2_HEADERS" \
  -o "$PATCH2_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/${TODO_ID}" \
  --data @"$PATCH_FALSE_REQUEST_BODY")"
echo "RESPONSE_HEADERS:"
cat "$PATCH2_HEADERS"
echo "RESPONSE_BODY:"
cat "$PATCH2_BODY"
echo "RESPONSE_STATUS: ${PATCH2_CODE}"

echo "STEP: Then — assert 200 response and persisted completed=false in the user's todo list"
[ "$PATCH2_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${PATCH2_CODE}"; exit 1; }
grep -F '"id":"'"${TODO_ID}"'"' "$PATCH2_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain todo id ${TODO_ID}"; exit 1; }
grep -F '"completed":false' "$PATCH2_BODY" >/dev/null || grep -F '"completed":0' "$PATCH2_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to show completed=false"; exit 1; }

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
grep -F '"completed":false' "$LIST_BODY" >/dev/null || grep -F '"completed":0' "$LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected persisted todo to remain completed=false"; exit 1; }

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

echo "CODEVALID_TEST_ASSERTION_OK:authenticated_user_updates_own_todo_to_not_completed"
