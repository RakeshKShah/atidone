#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="user_cannot_update_another_users_todo"
OWNER_COOKIE_JAR="/tmp/${TEST_ID}_owner_cookies_${CASE_SUFFIX}.txt"
ATTACKER_COOKIE_JAR="/tmp/${TEST_ID}_attacker_cookies_${CASE_SUFFIX}.txt"
OWNER_LOGIN_HEADERS="/tmp/${TEST_ID}_owner_login_headers_${CASE_SUFFIX}.txt"
OWNER_LOGIN_BODY="/tmp/${TEST_ID}_owner_login_body_${CASE_SUFFIX}.txt"
ATTACKER_LOGIN_HEADERS="/tmp/${TEST_ID}_attacker_login_headers_${CASE_SUFFIX}.txt"
ATTACKER_LOGIN_BODY="/tmp/${TEST_ID}_attacker_login_body_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
PATCH_HEADERS="/tmp/${TEST_ID}_patch_headers_${CASE_SUFFIX}.txt"
PATCH_BODY="/tmp/${TEST_ID}_patch_body_${CASE_SUFFIX}.txt"
OWNER_LIST_HEADERS="/tmp/${TEST_ID}_owner_list_headers_${CASE_SUFFIX}.txt"
OWNER_LIST_BODY="/tmp/${TEST_ID}_owner_list_body_${CASE_SUFFIX}.txt"
ATTACKER_LIST_HEADERS="/tmp/${TEST_ID}_attacker_list_headers_${CASE_SUFFIX}.txt"
ATTACKER_LIST_BODY="/tmp/${TEST_ID}_attacker_list_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"
OWNER_LOGIN_REQUEST_BODY="/tmp/${TEST_ID}_owner_login_request_${CASE_SUFFIX}.json"
ATTACKER_LOGIN_REQUEST_BODY="/tmp/${TEST_ID}_attacker_login_request_${CASE_SUFFIX}.json"
CREATE_REQUEST_BODY="/tmp/${TEST_ID}_create_request_${CASE_SUFFIX}.json"
PATCH_REQUEST_BODY="/tmp/${TEST_ID}_patch_request_${CASE_SUFFIX}.json"
TODO_TITLE="todo-${TEST_ID}-${CASE_SUFFIX}"
TODO_ID=""

cleanup_files() {
  rm -f "$OWNER_COOKIE_JAR" "$ATTACKER_COOKIE_JAR" "$OWNER_LOGIN_HEADERS" "$OWNER_LOGIN_BODY" "$ATTACKER_LOGIN_HEADERS" "$ATTACKER_LOGIN_BODY" "$CREATE_HEADERS" "$CREATE_BODY" "$PATCH_HEADERS" "$PATCH_BODY" "$OWNER_LIST_HEADERS" "$OWNER_LIST_BODY" "$ATTACKER_LIST_HEADERS" "$ATTACKER_LIST_BODY" "$DELETE_HEADERS" "$DELETE_BODY" "$OWNER_LOGIN_REQUEST_BODY" "$ATTACKER_LOGIN_REQUEST_BODY" "$CREATE_REQUEST_BODY" "$PATCH_REQUEST_BODY"
}
trap cleanup_files EXIT

cat > "$OWNER_LOGIN_REQUEST_BODY" <<JSON
{"username":"codevalid-owner-${TEST_ID}-${CASE_SUFFIX}","userId":"owner-${TEST_ID}-${CASE_SUFFIX}"}
JSON

cat > "$ATTACKER_LOGIN_REQUEST_BODY" <<JSON
{"username":"codevalid-attacker-${TEST_ID}-${CASE_SUFFIX}","userId":"attacker-${TEST_ID}-${CASE_SUFFIX}"}
JSON

cat > "$CREATE_REQUEST_BODY" <<JSON
{"title":"${TODO_TITLE}"}
JSON

cat > "$PATCH_REQUEST_BODY" <<JSON
{"completed":true}
JSON

echo "STEP: Given — authenticate two users and create a todo for the owner only"
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
[ "$OWNER_LOGIN_CODE" = "200" ] || [ "$OWNER_LOGIN_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 200 or 201 from owner session bootstrap got ${OWNER_LOGIN_CODE}"; exit 1; }

echo "PREREQ: sign in attacker user through a repo-provided auth test seam"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$ATTACKER_LOGIN_REQUEST_BODY"
ATTACKER_LOGIN_CODE="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -c "$ATTACKER_COOKIE_JAR" \
  -D "$ATTACKER_LOGIN_HEADERS" \
  -o "$ATTACKER_LOGIN_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/test/session" \
  --data @"$ATTACKER_LOGIN_REQUEST_BODY")"
echo "RESPONSE_HEADERS:"
cat "$ATTACKER_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$ATTACKER_LOGIN_BODY"
echo "RESPONSE_STATUS: ${ATTACKER_LOGIN_CODE}"
[ "$ATTACKER_LOGIN_CODE" = "200" ] || [ "$ATTACKER_LOGIN_CODE" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 200 or 201 from attacker session bootstrap got ${ATTACKER_LOGIN_CODE}"; exit 1; }

echo "PREREQ: create a todo owned by the owner user"
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

echo "STEP: When — attacker attempts to PATCH another user's todo"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_HEADERS: Cookie jar ${ATTACKER_COOKIE_JAR}"
echo "REQUEST_BODY:"
cat "$PATCH_REQUEST_BODY"
PATCH_CODE="$(curl -sS -X PATCH \
  -b "$ATTACKER_COOKIE_JAR" \
  -c "$ATTACKER_COOKIE_JAR" \
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

echo "STEP: Then — assert 404 is returned and user isolation is preserved"
[ "$PATCH_CODE" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${PATCH_CODE}"; exit 1; }
grep -F 'Todo not found' "$PATCH_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain Todo not found"; exit 1; }

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
grep -F '"completed":false' "$OWNER_LIST_BODY" >/dev/null || grep -F '"completed":0' "$OWNER_LIST_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected owner's todo to remain not completed after attacker patch attempt"; exit 1; }

ATTACKER_LIST_CODE="$(curl -sS \
  -b "$ATTACKER_COOKIE_JAR" \
  -c "$ATTACKER_COOKIE_JAR" \
  -D "$ATTACKER_LIST_HEADERS" \
  -o "$ATTACKER_LIST_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$ATTACKER_LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$ATTACKER_LIST_BODY"
echo "RESPONSE_STATUS: ${ATTACKER_LIST_CODE}"
[ "$ATTACKER_LIST_CODE" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 from attacker list got ${ATTACKER_LIST_CODE}"; exit 1; }
if grep -F '"id":"'"${TODO_ID}"'"' "$ATTACKER_LIST_BODY" >/dev/null; then
  echo "ASSERTION_FAILED: attacker should not see owner todo ${TODO_ID} in their list"
  exit 1
fi

echo "STEP: Cleanup — delete the owner todo created during Given"
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

echo "CODEVALID_TEST_ASSERTION_OK:user_cannot_update_another_users_todo"
