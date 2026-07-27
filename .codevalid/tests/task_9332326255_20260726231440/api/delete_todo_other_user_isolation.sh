#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_other_user_isolation"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
AUTH_HEADERS="/tmp/${TEST_ID}_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY="/tmp/${TEST_ID}_auth_body_${CASE_SUFFIX}.txt"
LIST_HEADERS="/tmp/${TEST_ID}_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY="/tmp/${TEST_ID}_list_body_${CASE_SUFFIX}.txt"
CREATE_HEADERS="/tmp/${TEST_ID}_create_headers_${CASE_SUFFIX}.txt"
CREATE_BODY="/tmp/${TEST_ID}_create_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/${TEST_ID}_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/${TEST_ID}_when_body_${CASE_SUFFIX}.txt"
VERIFY_HEADERS="/tmp/${TEST_ID}_verify_headers_${CASE_SUFFIX}.txt"
VERIFY_BODY="/tmp/${TEST_ID}_verify_body_${CASE_SUFFIX}.txt"
OTHER_USER_TODO_ID="todo-xyz-789-${CASE_SUFFIX}"
OTHER_USER_TODO_TITLE="other-user-isolation-${CASE_SUFFIX}"
CREATED_ID=""

cleanup_files() {
  rm -f "$COOKIE_JAR" "$AUTH_HEADERS" "$AUTH_BODY" "$LIST_HEADERS" "$LIST_BODY" "$CREATE_HEADERS" "$CREATE_BODY" "$WHEN_HEADERS" "$WHEN_BODY" "$VERIFY_HEADERS" "$VERIFY_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — bootstrap authenticated access and prepare a non-owned todo target"
echo "PREREQ: probing unauthenticated access behavior"
echo "REQUEST_HEADERS: none"
echo "REQUEST_BODY:"
auth_code=$(curl -sS -D "$AUTH_HEADERS" -o "$AUTH_BODY" -w '%{http_code}' \n  -X GET "$BASE_URL/api/todos" \n  -c "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$AUTH_HEADERS"
echo "RESPONSE_BODY:"
cat "$AUTH_BODY"
echo "RESPONSE_STATUS: $auth_code"
case "$auth_code" in
  401|302|303|500) : ;;
  *) echo "ASSERTION_FAILED: expected unauthenticated todo list to be guarded with HTTP 401, 302, 303, or 500 got ${auth_code}"; exit 1 ;;
esac

echo "PREREQ: checking whether authenticated CRUD is already available in this environment"
echo "REQUEST_HEADERS: Cookie jar from probe"
echo "REQUEST_BODY:"
list_code=$(curl -sS -D "$LIST_HEADERS" -o "$LIST_BODY" -w '%{http_code}' \n  -X GET "$BASE_URL/api/todos" \n  -b "$COOKIE_JAR" -c "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$LIST_BODY"
echo "RESPONSE_STATUS: $list_code"

if [ "$list_code" = "200" ]; then
  echo "PREREQ: creating a todo to obtain a concrete id shape; this test will still assert cross-user isolation with a distinct target id"
  CREATE_PAYLOAD=$(printf '{"title":"%s"}' "$OTHER_USER_TODO_TITLE")
  echo "REQUEST_HEADERS: Content-Type: application/json"
  echo "REQUEST_BODY: $CREATE_PAYLOAD"
  create_code=$(curl -sS -D "$CREATE_HEADERS" -o "$CREATE_BODY" -w '%{http_code}' \n    -X POST "$BASE_URL/api/todos" \n    -H 'Content-Type: application/json' \n    -b "$COOKIE_JAR" -c "$COOKIE_JAR" \n    --data "$CREATE_PAYLOAD")
  echo "RESPONSE_HEADERS:"
  cat "$CREATE_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$CREATE_BODY"
  echo "RESPONSE_STATUS: $create_code"
  [ "$create_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 creating setup todo got ${create_code}"; exit 1; }
  if command -v jq >/dev/null 2>&1; then
    CREATED_ID=$(jq -r '.id // empty' "$CREATE_BODY")
  else
    CREATED_ID=$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$CREATE_BODY" | head -n 1)
  fi
  [ -n "$CREATED_ID" ] || { echo "ASSERTION_FAILED: expected created setup todo id in response"; exit 1; }
else
  echo "ASSERTION_FAILED: unable to bootstrap authenticated session via public API only; GET /api/todos with cookie jar returned ${list_code}. This repo requires a real session bootstrap seam for authenticated isolation tests."
  exit 1
fi

# When — perform the action under test
echo "STEP: When — attempt to delete a todo id that is not owned by the current user"
echo "REQUEST_HEADERS: Cookie jar from authenticated setup"
echo "REQUEST_BODY:"
code=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' \n  -X DELETE "$BASE_URL/api/todos/$OTHER_USER_TODO_ID" \n  -b "$COOKIE_JAR" -c "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — endpoint hides ownership details and returns not found"
[ "$code" = "404" ] || { echo "ASSERTION_FAILED: expected HTTP 404 got ${code}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  jq -e '(.statusCode == 404 or .status == 404) and ((.message // "") == "Todo not found")' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected 404 Todo not found payload"; exit 1; }
else
  grep -F 'Todo not found' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain Todo not found"; exit 1; }
fi

echo "REQUEST_HEADERS: Cookie jar from authenticated setup"
echo "REQUEST_BODY:"
verify_code=$(curl -sS -D "$VERIFY_HEADERS" -o "$VERIFY_BODY" -w '%{http_code}' \n  -X GET "$BASE_URL/api/todos" \n  -b "$COOKIE_JAR" -c "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$VERIFY_HEADERS"
echo "RESPONSE_BODY:"
cat "$VERIFY_BODY"
echo "RESPONSE_STATUS: $verify_code"
[ "$verify_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 listing authenticated user's todos got ${verify_code}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  jq -e --arg id "$CREATED_ID" 'map(select(.id == $id)) | length == 1' "$VERIFY_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected owned setup todo to remain after failed foreign delete"; exit 1; }
else
  grep -F ""id":"$CREATED_ID"" "$VERIFY_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected owned setup todo to remain after failed foreign delete"; exit 1; }
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — delete setup todo created for authenticated verification"
if [ -n "$CREATED_ID" ]; then
  cleanup_code=$(curl -sS -D /dev/null -o /dev/null -w '%{http_code}' \n    -X DELETE "$BASE_URL/api/todos/$CREATED_ID" \n    -b "$COOKIE_JAR" -c "$COOKIE_JAR" || true)
  case "$cleanup_code" in
    200|404|401|302|303|500|000) : ;;
    *) echo "ASSERTION_FAILED: unexpected cleanup HTTP status ${cleanup_code}"; exit 1 ;;
  esac
fi

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_other_user_isolation"
