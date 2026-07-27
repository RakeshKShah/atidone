#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="delete_todo_happy_path"
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
TODO_TITLE="delete-happy-${CASE_SUFFIX}"
TODO_ID=""

cleanup_files() {
  rm -f "$COOKIE_JAR" "$AUTH_HEADERS" "$AUTH_BODY" "$LIST_HEADERS" "$LIST_BODY" "$CREATE_HEADERS" "$CREATE_BODY" "$WHEN_HEADERS" "$WHEN_BODY" "$VERIFY_HEADERS" "$VERIFY_BODY"
}
trap cleanup_files EXIT

extract_first_id() {
  body_file="$1"
  title="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg title "$title" 'if type=="array" then map(select(.title == $title)) | .[0].id // empty else empty end' "$body_file"
  else
    sed -n 's/.*"id":"\([^"]*\)".*"title":"'"$title"'".*/\1/p' "$body_file" | head -n 1
  fi
}

# Given — bring the system to the required state
echo "STEP: Given — discover auth behavior and create an owned todo when authenticated"
echo "PREREQ: probing authenticated todo list requirement"
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

echo "PREREQ: checking whether this environment already has an authenticated cookie jar"
echo "REQUEST_HEADERS: Cookie jar from probe"
echo "REQUEST_BODY:"
list_code=$(curl -sS -D "$LIST_HEADERS" -o "$LIST_BODY" -w '%{http_code}' \n  -X GET "$BASE_URL/api/todos" \n  -b "$COOKIE_JAR" -c "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$LIST_HEADERS"
echo "RESPONSE_BODY:"
cat "$LIST_BODY"
echo "RESPONSE_STATUS: $list_code"

if [ "$list_code" = "200" ]; then
  echo "PREREQ: creating todo through authenticated public API"
  CREATE_PAYLOAD=$(printf '{"title":"%s"}' "$TODO_TITLE")
  echo "REQUEST_HEADERS: Content-Type: application/json"
  echo "REQUEST_BODY: $CREATE_PAYLOAD"
  create_code=$(curl -sS -D "$CREATE_HEADERS" -o "$CREATE_BODY" -w '%{http_code}' \n    -X POST "$BASE_URL/api/todos" \n    -H 'Content-Type: application/json' \n    -b "$COOKIE_JAR" -c "$COOKIE_JAR" \n    --data "$CREATE_PAYLOAD")
  echo "RESPONSE_HEADERS:"
  cat "$CREATE_HEADERS"
  echo "RESPONSE_BODY:"
  cat "$CREATE_BODY"
  echo "RESPONSE_STATUS: $create_code"
  [ "$create_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 creating owned todo got ${create_code}"; exit 1; }

  if command -v jq >/dev/null 2>&1; then
    TODO_ID=$(jq -r '.id // empty' "$CREATE_BODY")
  else
    TODO_ID=$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$CREATE_BODY" | head -n 1)
  fi
  [ -n "$TODO_ID" ] || { echo "ASSERTION_FAILED: expected created todo id in response"; exit 1; }
else
  echo "ASSERTION_FAILED: unable to bootstrap authenticated session via public API only; GET /api/todos with cookie jar returned ${list_code}. This repo requires a real session bootstrap seam for authenticated delete tests." 
  exit 1
fi

# When — perform the action under test
echo "STEP: When — delete the authenticated user's own todo"
echo "REQUEST_HEADERS: Cookie jar from authenticated setup"
echo "REQUEST_BODY:"
code=$(curl -sS -D "$WHEN_HEADERS" -o "$WHEN_BODY" -w '%{http_code}' \n  -X DELETE "$BASE_URL/api/todos/$TODO_ID" \n  -b "$COOKIE_JAR" -c "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$WHEN_HEADERS"
echo "RESPONSE_BODY:"
cat "$WHEN_BODY"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — deleted todo is returned and removed from the user's list"
[ "$code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 got ${code}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  jq -e --arg id "$TODO_ID" --arg title "$TODO_TITLE" '.id == $id and .title == $title' "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected deleted todo payload to contain matching id and title"; exit 1; }
else
  grep -F ""id":"$TODO_ID"" "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain deleted todo id"; exit 1; }
  grep -F ""title":"$TODO_TITLE"" "$WHEN_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain deleted todo title"; exit 1; }
fi

echo "REQUEST_HEADERS: Cookie jar from authenticated setup"
echo "REQUEST_BODY:"
verify_code=$(curl -sS -D "$VERIFY_HEADERS" -o "$VERIFY_BODY" -w '%{http_code}' \n  -X GET "$BASE_URL/api/todos" \n  -b "$COOKIE_JAR" -c "$COOKIE_JAR")
echo "RESPONSE_HEADERS:"
cat "$VERIFY_HEADERS"
echo "RESPONSE_BODY:"
cat "$VERIFY_BODY"
echo "RESPONSE_STATUS: $verify_code"
[ "$verify_code" = "200" ] || { echo "ASSERTION_FAILED: expected HTTP 200 listing todos after deletion got ${verify_code}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  jq -e --arg id "$TODO_ID" 'map(select(.id == $id)) | length == 0' "$VERIFY_BODY" >/dev/null || { echo "ASSERTION_FAILED: expected deleted todo to be absent from todo list"; exit 1; }
else
  if grep -F ""id":"$TODO_ID"" "$VERIFY_BODY" >/dev/null; then
    echo "ASSERTION_FAILED: expected deleted todo to be absent from todo list"
    exit 1
  fi
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — best effort delete in case previous assertion failed after create"
if [ -n "$TODO_ID" ]; then
  cleanup_code=$(curl -sS -D /dev/null -o /dev/null -w '%{http_code}' \n    -X DELETE "$BASE_URL/api/todos/$TODO_ID" \n    -b "$COOKIE_JAR" -c "$COOKIE_JAR" || true)
  case "$cleanup_code" in
    200|404|401|302|303|500|000) : ;;
    *) echo "ASSERTION_FAILED: unexpected cleanup HTTP status ${cleanup_code}"; exit 1 ;;
  esac
fi

echo "CODEVALID_TEST_ASSERTION_OK:delete_todo_happy_path"
