#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="unauthenticated_user_rejected_from_update"
OWNER_COOKIE_JAR="/tmp/${TEST_ID}_owner_cookies_${CASE_SUFFIX}.txt"
OWNER_LOGIN_HEADERS="/tmp/${TEST_ID}_owner_login_headers_${CASE_SUFFIX}.txt"
OWNER_LOGIN_BODY="/tmp/${TEST_ID}_owner_login_body_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
OWNER_LIST_HEADERS="/tmp/${TEST_ID}_owner_list_headers_${CASE_SUFFIX}.txt"
OWNER_LIST_BODY="/tmp/${TEST_ID}_owner_list_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"
OWNER_LOGIN_REQUEST_BODY="/tmp/${TEST_ID}_owner_login_request_${CASE_SUFFIX}.json"
CREATE_REQUEST_BODY="/tmp/${TEST_ID}_create_request_${CASE_SUFFIX}.json"
PATCH_REQUEST_BODY="/tmp/${TEST_ID}_patch_request_${CASE_SUFFIX}.json"
TODO_TITLE="todo-${TEST_ID}-${CASE_SUFFIX}"
TODO_ID=""

cleanup_files() {
  rm -f "$OWNER_COOKIE_JAR" "$OWNER_LOGIN_HEADERS" "$OWNER_LOGIN_BODY" "$CREATE_HEADERS" "$CREATE_BODY" "$PATCH_HEADERS" "$PATCH_BODY" "$OWNER_LIST_HEADERS" "$OWNER_LIST_BODY" "$DELETE_HEADERS" "$DELETE_BODY" "$OWNER_LOGIN_REQUEST_BODY" "$CREATE_REQUEST_BODY" "$PATCH_REQUEST_BODY"
}
trap cleanup_files EXIT

cat > "$OWNER_LOGIN_REQUEST_BODY" <<JSON
{"username":"codevalid-owner-${TEST_ID}-${CASE_SUFFIX}","userId":"owner-${TEST_ID}-${CASE_SUFFIX}"}
JSON

cat > "$CREATE_REQUEST_BODY" <<JSON
{"title":"${TODO_TITLE}"}
JSON

cat > "$PATCH_REQUEST_BODY" <<JSON
{"completed":true}
JSON

echo "STEP: Given — create a todo owned by another user while the primary request stays unauthenticated"
echo "PREREQ: sign in owner user through a repo-provided auth test seam"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$OWNER_LOGIN_REQUEST_BODY"
OWNER_LOGIN_CODE="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -c "$OWNER_COOKIE_JAR" \
  -D "$OWNER_LOGIN_HEADERS" \
  -o "$OWNER_LOGIN_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/test/session" \
  --data @"$OWNER_LOGIN_REQUEST_BODY")"
echo "RESPONSE_HEADERS:"
cat "$OWNER_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$OWNER_LOGIN_BODY"
echo "RESPONSE_STATUS: ${OWNER_LOGIN_CODE}"
[ "$OWNER_LOGIN_CODE" = "200" ] || [ "$OWNER_LOGIN_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 200 or 201 from session bootstrap got ${OWNER_LOGIN_CODE}"; exit 1; }

echo "PREREQ: create a todo to target later"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_HEADERS: Cookie jar ${OWNER_COOKIE_JAR}"
echo "REQUEST_BODY:"
cat "$CREATE_REQUEST_BODY"
CREATE_CODE="$(curl -sS -X POST \
  -b "$OWNER_COOKIE_JAR" \
  -c "$OWNER_COOKIE_JAR" \
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

echo "STEP: When — send PATCH without authentication cookies or session"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$PATCH_REQUEST_BODY"
PATCH_CODE="$(curl -sS -X PATCH \
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

echo "STEP: Then — assert unauthenticated access is rejected and owner data remains unchanged"
[ "$PATCH_CODE" = "401" ] || [ "$PATCH_CODE" = "302" ] || [ "$PATCH_CODE" = "303" ] || { echo "ASSERTION_FAILED: expected HTTP 401, 302, or 303 got ${PATCH_CODE}"; exit 1; }
if [ "$PATCH_CODE" = "401" ]; then
  grep -Ei 'unauth|auth|login|sign' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected 401 response body to indicate authentication is required"; exit 1; }
fi

OWNER_LIST_CODE="$(curl -sS \
  -b "$OWNER_COOKIE_JAR" \
  -c "$OWNER_COOKIE_JAR" \
  -D "$OWNER_LIST_HEADERS" \
  -o "$OWNER_LIST_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$OWNER_LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$OWNER_LIST_BODY"
echo "RESPONSE_STATUS: ${OWNER_LIST_CODE}"
[ "$OWNER_LIST_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 from owner list got ${OWNER_LIST_CODE}"; exit 1; }
grep -F '"id":"'"${TODO_ID}"'"' "$OWNER_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected owner list to contain todo id ${TODO_ID}"; exit 1; }
grep -F '"completed":false' "$OWNER_LIST_BODY" >/dev/null || grep -F '"completed":0' "$OWNER_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected owner's todo to remain not completed after unauthenticated patch attempt"; exit 1; }

echo "STEP: Cleanup — delete the todo created during Given"
if [ -n "$TODO_ID" ]; then
  DELETE_CODE="$(curl -sS -X DELETE \
    -b "$OWNER_COOKIE_JAR" \
    -c "$OWNER_COOKIE_JAR" \
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

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_user_rejected_from_update"
