#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="multiple_users_isolated_deletion_operations"
CAROL_COOKIE_JAR="/tmp/${TEST_ID}_carol_cookies_${CASE_SUFFIX}.txt"
DAVE_COOKIE_JAR="/tmp/${TEST_ID}_dave_cookies_${CASE_SUFFIX}.txt"
CAROL_LOGIN_HEADERS="/tmp/${TEST_ID}_carol_login_headers_${CASE_SUFFIX}.txt"
CAROL_LOGIN_BODY="/tmp/${TEST_ID}_carol_login_body_${CASE_SUFFIX}.txt"
DAVE_LOGIN_HEADERS="/tmp/${TEST_ID}_dave_login_headers_${CASE_SUFFIX}.txt"
DAVE_LOGIN_BODY="/tmp/${TEST_ID}_dave_login_body_${CASE_SUFFIX}.txt"
CAROL_CREATE_HEADERS="/tmp/${TEST_ID}_carol_create_headers_${CASE_SUFFIX}.txt"
CAROL_CREATE_BODY="/tmp/${TEST_ID}_carol_create_body_${CASE_SUFFIX}.txt"
DAVE_CREATE_HEADERS="/tmp/${TEST_ID}_dave_create_headers_${CASE_SUFFIX}.txt"
DAVE_CREATE_BODY="/tmp/${TEST_ID}_dave_create_body_${CASE_SUFFIX}.txt"
CAROL_DELETE_HEADERS="/tmp/${TEST_ID}_carol_delete_headers_${CASE_SUFFIX}.txt"
CAROL_DELETE_BODY="/tmp/${TEST_ID}_carol_delete_body_${CASE_SUFFIX}.txt"
DAVE_DELETE_HEADERS="/tmp/${TEST_ID}_dave_delete_headers_${CASE_SUFFIX}.txt"
DAVE_DELETE_BODY="/tmp/${TEST_ID}_dave_delete_body_${CASE_SUFFIX}.txt"
CAROL_LIST_HEADERS="/tmp/${TEST_ID}_carol_list_headers_${CASE_SUFFIX}.txt"
CAROL_LIST_BODY="/tmp/${TEST_ID}_carol_list_body_${CASE_SUFFIX}.txt"
DAVE_LIST_HEADERS="/tmp/${TEST_ID}_dave_list_headers_${CASE_SUFFIX}.txt"
DAVE_LIST_BODY="/tmp/${TEST_ID}_dave_list_body_${CASE_SUFFIX}.txt"
CAROL_TITLE="Carol private todo ${CASE_SUFFIX}"
DAVE_TITLE="Dave private todo ${CASE_SUFFIX}"

cleanup_files() {
  rm -f "$CAROL_COOKIE_JAR" "$DAVE_COOKIE_JAR" "$CAROL_LOGIN_HEADERS" "$CAROL_LOGIN_BODY" "$DAVE_LOGIN_HEADERS" "$DAVE_LOGIN_BODY" "$CAROL_CREATE_HEADERS" "$CAROL_CREATE_BODY" "$DAVE_CREATE_HEADERS" "$DAVE_CREATE_BODY" "$CAROL_DELETE_HEADERS" "$CAROL_DELETE_BODY" "$DAVE_DELETE_HEADERS" "$DAVE_DELETE_BODY" "$CAROL_LIST_HEADERS" "$CAROL_LIST_BODY" "$DAVE_LIST_HEADERS" "$DAVE_LIST_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — establish Carol and Dave sessions and create one todo for each user"
echo "PREREQ: log in as Carol"
CAROL_LOGIN_REQUEST='{"userId":"user-carol","name":"Carol"}'
echo "REQUEST_HEADERS:"
printf 'Content-Type: application/json\n'
echo "REQUEST_BODY:"
printf '%s\n' "$CAROL_LOGIN_REQUEST"
carol_login_code="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -c "$CAROL_COOKIE_JAR" \
  -D "$CAROL_LOGIN_HEADERS" \
  -o "$CAROL_LOGIN_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/test-auth/login" \
  --data "$CAROL_LOGIN_REQUEST")"
echo "RESPONSE_HEADERS:"
cat "$CAROL_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$CAROL_LOGIN_BODY"
echo "RESPONSE_STATUS: $carol_login_code"
[ "$carol_login_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${carol_login_code}"; exit 1; }

echo "PREREQ: log in as Dave"
DAVE_LOGIN_REQUEST='{"userId":"user-dave","name":"Dave"}'
echo "REQUEST_HEADERS:"
printf 'Content-Type: application/json\n'
echo "REQUEST_BODY:"
printf '%s\n' "$DAVE_LOGIN_REQUEST"
dave_login_code="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -c "$DAVE_COOKIE_JAR" \
  -D "$DAVE_LOGIN_HEADERS" \
  -o "$DAVE_LOGIN_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/test-auth/login" \
  --data "$DAVE_LOGIN_REQUEST")"
echo "RESPONSE_HEADERS:"
cat "$DAVE_LOGIN_HEADERS"
echo "RESPONSE_BODY:"
cat "$DAVE_LOGIN_BODY"
echo "RESPONSE_STATUS: $dave_login_code"
[ "$dave_login_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${dave_login_code}"; exit 1; }

echo "PREREQ: create Carol-owned todo"
CAROL_CREATE_REQUEST="{\"title\":\"$CAROL_TITLE\"}"
echo "REQUEST_HEADERS:"
printf 'Content-Type: application/json\n'
printf 'Cookie jar: %s\n' "$CAROL_COOKIE_JAR"
echo "REQUEST_BODY:"
printf '%s\n' "$CAROL_CREATE_REQUEST"
carol_create_code="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -b "$CAROL_COOKIE_JAR" \
  -c "$CAROL_COOKIE_JAR" \
  -D "$CAROL_CREATE_HEADERS" \
  -o "$CAROL_CREATE_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos" \
  --data "$CAROL_CREATE_REQUEST")"
echo "RESPONSE_HEADERS:"
cat "$CAROL_CREATE_HEADERS"
echo "RESPONSE_BODY:"
cat "$CAROL_CREATE_BODY"
echo "RESPONSE_STATUS: $carol_create_code"
[ "$carol_create_code" = "200" ] || [ "$carol_create_code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 200 or 201 got ${carol_create_code}"; exit 1; }
CAROL_TODO_ID="$(jq -r '.id // empty' "$CAROL_CREATE_BODY")"
[ -n "$CAROL_TODO_ID" ] || { echo "ASSERTION_FAILED: expected Carol todo id in response body"; exit 1; }

echo "PREREQ: create Dave-owned todo"
DAVE_CREATE_REQUEST="{\"title\":\"$DAVE_TITLE\"}"
echo "REQUEST_HEADERS:"
printf 'Content-Type: application/json\n'
printf 'Cookie jar: %s\n' "$DAVE_COOKIE_JAR"
echo "REQUEST_BODY:"
printf '%s\n' "$DAVE_CREATE_REQUEST"
dave_create_code="$(curl -sS -X POST \
  -H 'Content-Type: application/json' \
  -b "$DAVE_COOKIE_JAR" \
  -c "$DAVE_COOKIE_JAR" \
  -D "$DAVE_CREATE_HEADERS" \
  -o "$DAVE_CREATE_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos" \
  --data "$DAVE_CREATE_REQUEST")"
echo "RESPONSE_HEADERS:"
cat "$DAVE_CREATE_HEADERS"
echo "RESPONSE_BODY:"
cat "$DAVE_CREATE_BODY"
echo "RESPONSE_STATUS: $dave_create_code"
[ "$dave_create_code" = "200" ] || [ "$dave_create_code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 200 or 201 got ${dave_create_code}"; exit 1; }
DAVE_TODO_ID="$(jq -r '.id // empty' "$DAVE_CREATE_BODY")"
[ -n "$DAVE_TODO_ID" ] || { echo "ASSERTION_FAILED: expected Dave todo id in response body"; exit 1; }

# When — perform the action under test
echo "STEP: When — Carol deletes her own todo"
echo "REQUEST_HEADERS:"
printf 'Cookie jar: %s\n' "$CAROL_COOKIE_JAR"
echo "REQUEST_BODY:"
printf '\n'
carol_delete_code="$(curl -sS -X DELETE \
  -b "$CAROL_COOKIE_JAR" \
  -D "$CAROL_DELETE_HEADERS" \
  -o "$CAROL_DELETE_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/$CAROL_TODO_ID")"
echo "RESPONSE_HEADERS:"
cat "$CAROL_DELETE_HEADERS"
echo "RESPONSE_BODY:"
cat "$CAROL_DELETE_BODY"
echo "RESPONSE_STATUS: $carol_delete_code"

echo "STEP: When — Dave deletes his own todo"
echo "REQUEST_HEADERS:"
printf 'Cookie jar: %s\n' "$DAVE_COOKIE_JAR"
echo "REQUEST_BODY:"
printf '\n'
dave_delete_code="$(curl -sS -X DELETE \
  -b "$DAVE_COOKIE_JAR" \
  -D "$DAVE_DELETE_HEADERS" \
  -o "$DAVE_DELETE_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos/$DAVE_TODO_ID")"
echo "RESPONSE_HEADERS:"
cat "$DAVE_DELETE_HEADERS"
echo "RESPONSE_BODY:"
cat "$DAVE_DELETE_BODY"
echo "RESPONSE_STATUS: $dave_delete_code"

# Then — HTTP/body assertions
echo "STEP: Then — both users delete only their own todos and each list no longer contains the deleted item"
[ "$carol_delete_code" = "200" ] || { echo "ASSERTION_FAILED: expected Carol delete HTTP 200 got ${carol_delete_code}"; exit 1; }
[ "$dave_delete_code" = "200" ] || { echo "ASSERTION_FAILED: expected Dave delete HTTP 200 got ${dave_delete_code}"; exit 1; }
grep -F '"id":"'"$CAROL_TODO_ID"'"' "$CAROL_DELETE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Carol delete response to contain todo id $CAROL_TODO_ID"; exit 1; }
grep -F '"title":"'"$CAROL_TITLE"'"' "$CAROL_DELETE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Carol delete response to contain title $CAROL_TITLE"; exit 1; }
grep -F '"id":"'"$DAVE_TODO_ID"'"' "$DAVE_DELETE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Dave delete response to contain todo id $DAVE_TODO_ID"; exit 1; }
grep -F '"title":"'"$DAVE_TITLE"'"' "$DAVE_DELETE_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected Dave delete response to contain title $DAVE_TITLE"; exit 1; }

carol_list_code="$(curl -sS -X GET \
  -b "$CAROL_COOKIE_JAR" \
  -D "$CAROL_LIST_HEADERS" \
  -o "$CAROL_LIST_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$CAROL_LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$CAROL_LIST_BODY"
echo "RESPONSE_STATUS: $carol_list_code"
[ "$carol_list_code" = "200" ] || { echo "ASSERTION_FAILED: expected Carol list HTTP 200 got ${carol_list_code}"; exit 1; }
if grep -F '"id":"'"$CAROL_TODO_ID"'"' "$CAROL_LIST_BODY" >/dev/null; then
  echo "ASSERTION_FAILED: expected Carol list to no longer contain $CAROL_TODO_ID"
  exit 1
fi

dave_list_code="$(curl -sS -X GET \
  -b "$DAVE_COOKIE_JAR" \
  -D "$DAVE_LIST_HEADERS" \
  -o "$DAVE_LIST_BODY" \
  -w '%{http_code}' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$DAVE_LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$DAVE_LIST_BODY"
echo "RESPONSE_STATUS: $dave_list_code"
[ "$dave_list_code" = "200" ] || { echo "ASSERTION_FAILED: expected Dave list HTTP 200 got ${dave_list_code}"; exit 1; }
if grep -F '"id":"'"$DAVE_TODO_ID"'"' "$DAVE_LIST_BODY" >/dev/null; then
  echo "ASSERTION_FAILED: expected Dave list to no longer contain $DAVE_TODO_ID"
  exit 1
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — attempt idempotent deletion and clear both authenticated sessions"
curl -sS -X DELETE -b "$CAROL_COOKIE_JAR" -o /dev/null "$BASE_URL/api/todos/$CAROL_TODO_ID" >/dev/null 2>&1 || true
curl -sS -X DELETE -b "$DAVE_COOKIE_JAR" -o /dev/null "$BASE_URL/api/todos/$DAVE_TODO_ID" >/dev/null 2>&1 || true
curl -sS -X POST -b "$CAROL_COOKIE_JAR" -o /dev/null "$BASE_URL/api/test-auth/logout" >/dev/null 2>&1 || true
curl -sS -X POST -b "$DAVE_COOKIE_JAR" -o /dev/null "$BASE_URL/api/test-auth/logout" >/dev/null 2>&1 || true

echo "CODEVALID_TEST_ASSERTION_OK:multiple_users_isolated_deletion_operations"
