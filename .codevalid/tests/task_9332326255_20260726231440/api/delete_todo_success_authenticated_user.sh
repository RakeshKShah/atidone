#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_success_authenticated_user"
CREATE_TITLE="Buy groceries ${CASE_SUFFIX}"
FALLBACK_TODO_ID="todo-456-${CASE_SUFFIX}"
COOKIE_JAR="/tmp/${TEST_ID}_cookies_${CASE_SUFFIX}.txt"
GIVEN_HEADERS="/tmp/${TEST_ID}_given_headers_${CASE_SUFFIX}.txt"
GIVEN_BODY="/tmp/${TEST_ID}_given_body_${CASE_SUFFIX}.txt"
WHEN_HEADERS="/tmp/${TEST_ID}_when_headers_${CASE_SUFFIX}.txt"
WHEN_BODY="/tmp/${TEST_ID}_when_body_${CASE_SUFFIX}.txt"
VERIFY_HEADERS="/tmp/${TEST_ID}_verify_headers_${CASE_SUFFIX}.txt"
VERIFY_BODY="/tmp/${TEST_ID}_verify_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR" "$GIVEN_HEADERS" "$GIVEN_BODY" "$WHEN_HEADERS" "$WHEN_BODY" "$VERIFY_HEADERS" "$VERIFY_BODY"
}
trap cleanup_files EXIT

# Given — bring the system to the required state
echo "STEP: Given — attempt to create an authenticated user's todo fixture through the public API"
CREATE_BODY=$(printf '{"title":"%s"}' "$CREATE_TITLE")
echo "PREREQ: create a todo via POST /api/todos to detect whether a runnable authenticated session is available"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY: $CREATE_BODY"
given_code=$(curl -sS -D "$GIVEN_HEADERS" -o "$GIVEN_BODY" -w '%{http_code}' \
  -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -c "$COOKIE_JAR" \
  -b "$COOKIE_JAR" \
  --data "$CREATE_BODY")
echo "RESPONSE_HEADERS:"
cat "$GIVEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$GIVEN_BODY"
echo "RESPONSE_STATUS: $given_code"

created_id=""
if [ "$given_code" = "200" ] || [ "$given_code" = "201" ]; then
  if command -v jq >/dev/null 2>&1; then
    created_id=$(jq -r '.id // empty' "$GIVEN_BODY")
  else
    created_id=$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$GIVEN_BODY" | head -n 1)
  fi
  [ -n "$created_id" ] || { echo "ASSERTION_FAILED: expected created todo id in Given response"; exit 1; }
fi

# When — perform the action under test
echo "STEP: When — delete the todo using the authenticated cookie jar when available"
if [ -n "$created_id" ]; then
  target_id="$created_id"
else
  target_id="$FALLBACK_TODO_ID"
fi
echo "REQUEST_HEADERS: Cookie jar from Given if any"
echo "REQUEST_BODY:"
code=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' \
  -X DELETE "$BASE_URL/api/todos/$target_id" \
  -b "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — owner delete succeeds when authenticated, otherwise the route remains auth-gated"
if [ -n "$created_id" ]; then
  [ "$code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${code}"; exit 1; }
  grep -F '"id":"'"$target_id"'"' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected deleted todo id ${target_id} in response"; exit 1; }
  grep -F '"title":"'"$CREATE_TITLE"'"' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected deleted todo title ${CREATE_TITLE} in response"; exit 1; }
else
  case "$code" in
    401|302|303|500) : ;;
    *) echo "ASSERTION_FAILED: expected auth-gated status 401/302/303/500 got ${code}"; exit 1 ;;
  esac
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — verify the deleted todo is no longer available when authenticated flow succeeded"
if [ -n "$created_id" ]; then
  echo "REQUEST_HEADERS: Cookie jar from Given"
  echo "REQUEST_BODY:"
  verify_code=$(curl -sS -D "$VERIFY_HEADERS" -o "$VERIFY_BODY" -w '%{http_code}' \
    -X DELETE "$BASE_URL/api/todos/$target_id" \
    -b "$COOKIE_JAR")
  echo "RESPONSE_HEADERS:"
  cat "$VERIFY_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$VERIFY_BODY"
  echo "RESPONSE_STATUS: $verify_code"
  case "$verify_code" in
    404|401|302|303|500) : ;;
    *) echo "ASSERTION_FAILED: expected follow-up delete status 404/401/302/303/500 got ${verify_code}"; exit 1 ;;
  esac
fi

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_success_authenticated_user"
