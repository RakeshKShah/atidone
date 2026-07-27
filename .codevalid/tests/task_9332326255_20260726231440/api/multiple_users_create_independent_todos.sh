#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="multiple_users_create_independent_todos"
FIRST_COOKIE_FILE="${FIRST_COOKIE_FILE:-${USER_FIRST_COOKIE_FILE:-}}"
SECOND_COOKIE_FILE="${SECOND_COOKIE_FILE:-${USER_SECOND_COOKIE_FILE:-}}"
FIRST_TITLE="First user's task"
SECOND_TITLE="Second user's task"
FIRST_HEADERS_FILE="/tmp/${TEST_ID}_first_headers_${CASE_SUFFIX}.txt"
FIRST_BODY_FILE="/tmp/${TEST_ID}_first_body_${CASE_SUFFIX}.txt"
FIRST_REQUEST_BODY_FILE="/tmp/${TEST_ID}_first_request_${CASE_SUFFIX}.json"
SECOND_HEADERS_FILE="/tmp/${TEST_ID}_second_headers_${CASE_SUFFIX}.txt"
SECOND_BODY_FILE="/tmp/${TEST_ID}_second_body_${CASE_SUFFIX}.txt"
SECOND_REQUEST_BODY_FILE="/tmp/${TEST_ID}_second_request_${CASE_SUFFIX}.json"
FIRST_LIST_HEADERS_FILE="/tmp/${TEST_ID}_first_list_headers_${CASE_SUFFIX}.txt"
FIRST_LIST_BODY_FILE="/tmp/${TEST_ID}_first_list_body_${CASE_SUFFIX}.txt"
SECOND_LIST_HEADERS_FILE="/tmp/${TEST_ID}_second_list_headers_${CASE_SUFFIX}.txt"
SECOND_LIST_BODY_FILE="/tmp/${TEST_ID}_second_list_body_${CASE_SUFFIX}.txt"
FIRST_DELETE_HEADERS_FILE="/tmp/${TEST_ID}_first_delete_headers_${CASE_SUFFIX}.txt"
FIRST_DELETE_BODY_FILE="/tmp/${TEST_ID}_first_delete_body_${CASE_SUFFIX}.txt"
SECOND_DELETE_HEADERS_FILE="/tmp/${TEST_ID}_second_delete_headers_${CASE_SUFFIX}.txt"
SECOND_DELETE_BODY_FILE="/tmp/${TEST_ID}_second_delete_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$FIRST_HEADERS_FILE" "$FIRST_BODY_FILE" "$FIRST_REQUEST_BODY_FILE" \
        "$SECOND_HEADERS_FILE" "$SECOND_BODY_FILE" "$SECOND_REQUEST_BODY_FILE" \
        "$FIRST_LIST_HEADERS_FILE" "$FIRST_LIST_BODY_FILE" "$SECOND_LIST_HEADERS_FILE" "$SECOND_LIST_BODY_FILE" \
        "$FIRST_DELETE_HEADERS_FILE" "$FIRST_DELETE_BODY_FILE" "$SECOND_DELETE_HEADERS_FILE" "$SECOND_DELETE_BODY_FILE"
}
trap cleanup_files EXIT

FIRST_TODO_ID=""
SECOND_TODO_ID=""
printf '{"title":"%s"}' "$FIRST_TITLE" > "$FIRST_REQUEST_BODY_FILE"
printf '{"title":"%s"}' "$SECOND_TITLE" > "$SECOND_REQUEST_BODY_FILE"

# Given — bring the system to the required state
SHORT_GIVEN="two independent authenticated sessions are available"
echo "STEP: Given — ${SHORT_GIVEN}"
echo "PREREQ: verify first user cookie file is provided"
[ -n "$FIRST_COOKIE_FILE" ] || { echo "ASSERTION_FAILED: expected FIRST_COOKIE_FILE or USER_FIRST_COOKIE_FILE"; exit 1; }
[ -f "$FIRST_COOKIE_FILE" ] || { echo "ASSERTION_FAILED: first user cookie file not found at $FIRST_COOKIE_FILE"; exit 1; }
echo "PREREQ: verify second user cookie file is provided"
[ -n "$SECOND_COOKIE_FILE" ] || { echo "ASSERTION_FAILED: expected SECOND_COOKIE_FILE or USER_SECOND_COOKIE_FILE"; exit 1; }
[ -f "$SECOND_COOKIE_FILE" ] || { echo "ASSERTION_FAILED: second user cookie file not found at $SECOND_COOKIE_FILE"; exit 1; }

# When — perform the action under test
SHORT_WHEN="each authenticated user creates a todo in separate sessions"
echo "STEP: When — ${SHORT_WHEN}"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$FIRST_REQUEST_BODY_FILE"
first_code="$({
  curl -sS -X POST "$BASE_URL/api/todos" \
    -H 'Content-Type: application/json' \
    -b "$FIRST_COOKIE_FILE" \
    -D "$FIRST_HEADERS_FILE" \
    -o "$FIRST_BODY_FILE" \
    -w '%{http_code}' \
    --data @"$FIRST_REQUEST_BODY_FILE"
} || true)"
echo "RESPONSE_HEADERS:"
cat "$FIRST_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$FIRST_BODY_FILE"
echo "RESPONSE_STATUS: $first_code"

[ "$first_code" = "200" ] || [ "$first_code" = "201" ] || { echo "ASSERTION_FAILED: expected first create HTTP 200 or 201 got ${first_code}"; exit 1; }

echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$SECOND_REQUEST_BODY_FILE"
second_code="$({
  curl -sS -X POST "$BASE_URL/api/todos" \
    -H 'Content-Type: application/json' \
    -b "$SECOND_COOKIE_FILE" \
    -D "$SECOND_HEADERS_FILE" \
    -o "$SECOND_BODY_FILE" \
    -w '%{http_code}' \
    --data @"$SECOND_REQUEST_BODY_FILE"
} || true)"
echo "RESPONSE_HEADERS:"
cat "$SECOND_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$SECOND_BODY_FILE"
echo "RESPONSE_STATUS: $second_code"

# Then — HTTP/body assertions
SHORT_THEN="each todo is associated only with its respective authenticated user"
echo "STEP: Then — ${SHORT_THEN}"
[ "$second_code" = "200" ] || [ "$second_code" = "201" ] || { echo "ASSERTION_FAILED: expected second create HTTP 200 or 201 got ${second_code}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  FIRST_TODO_ID="$(jq -r '.id' "$FIRST_BODY_FILE")"
  SECOND_TODO_ID="$(jq -r '.id' "$SECOND_BODY_FILE")"
  [ "$FIRST_TODO_ID" != "null" ] && [ -n "$FIRST_TODO_ID" ] || { echo "ASSERTION_FAILED: expected first response id"; exit 1; }
  [ "$SECOND_TODO_ID" != "null" ] && [ -n "$SECOND_TODO_ID" ] || { echo "ASSERTION_FAILED: expected second response id"; exit 1; }
  [ "$FIRST_TODO_ID" != "$SECOND_TODO_ID" ] || { echo "ASSERTION_FAILED: expected distinct todo ids for different users"; exit 1; }
  [ "$(jq -r '.userId' "$FIRST_BODY_FILE")" = "user-first" ] || { echo "ASSERTION_FAILED: expected first response userId user-first"; exit 1; }
  [ "$(jq -r '.userId' "$SECOND_BODY_FILE")" = "user-second" ] || { echo "ASSERTION_FAILED: expected second response userId user-second"; exit 1; }
  [ "$(jq -r '.title' "$FIRST_BODY_FILE")" = "$FIRST_TITLE" ] || { echo "ASSERTION_FAILED: expected first title '$FIRST_TITLE'"; exit 1; }
  [ "$(jq -r '.title' "$SECOND_BODY_FILE")" = "$SECOND_TITLE" ] || { echo "ASSERTION_FAILED: expected second title '$SECOND_TITLE'"; exit 1; }
else
  grep -F '"userId":"user-first"' "$FIRST_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected first response userId user-first"; exit 1; }
  grep -F '"userId":"user-second"' "$SECOND_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected second response userId user-second"; exit 1; }
  grep -F "$FIRST_TITLE" "$FIRST_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected first response title"; exit 1; }
  grep -F "$SECOND_TITLE" "$SECOND_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected second response title"; exit 1; }
  FIRST_TODO_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$FIRST_BODY_FILE" | head -n 1)"
  SECOND_TODO_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$SECOND_BODY_FILE" | head -n 1)"
  [ -n "$FIRST_TODO_ID" ] || { echo "ASSERTION_FAILED: expected first response id"; exit 1; }
  [ -n "$SECOND_TODO_ID" ] || { echo "ASSERTION_FAILED: expected second response id"; exit 1; }
  [ "$FIRST_TODO_ID" != "$SECOND_TODO_ID" ] || { echo "ASSERTION_FAILED: expected distinct todo ids for different users"; exit 1; }
fi

echo "PREREQ: verify first user's list contains only first title and not second title"
first_list_code="$({
  curl -sS -X GET "$BASE_URL/api/todos" \
    -b "$FIRST_COOKIE_FILE" \
    -D "$FIRST_LIST_HEADERS_FILE" \
    -o "$FIRST_LIST_BODY_FILE" \
    -w '%{http_code}'
} || true)"
echo "RESPONSE_HEADERS:"
cat "$FIRST_LIST_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$FIRST_LIST_BODY_FILE"
echo "RESPONSE_STATUS: $first_list_code"
[ "$first_list_code" = "200" ] || { echo "ASSERTION_FAILED: expected first list HTTP 200 got ${first_list_code}"; exit 1; }
grep -F "$FIRST_TITLE" "$FIRST_LIST_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected first user's list to contain first title"; exit 1; }
! grep -F "$SECOND_TITLE" "$FIRST_LIST_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: first user's list unexpectedly contains second user's title"; exit 1; }

echo "PREREQ: verify second user's list contains only second title and not first title"
second_list_code="$({
  curl -sS -X GET "$BASE_URL/api/todos" \
    -b "$SECOND_COOKIE_FILE" \
    -D "$SECOND_LIST_HEADERS_FILE" \
    -o "$SECOND_LIST_BODY_FILE" \
    -w '%{http_code}'
} || true)"
echo "RESPONSE_HEADERS:"
cat "$SECOND_LIST_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$SECOND_LIST_BODY_FILE"
echo "RESPONSE_STATUS: $second_list_code"
[ "$second_list_code" = "200" ] || { echo "ASSERTION_FAILED: expected second list HTTP 200 got ${second_list_code}"; exit 1; }
grep -F "$SECOND_TITLE" "$SECOND_LIST_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected second user's list to contain second title"; exit 1; }
! grep -F "$FIRST_TITLE" "$SECOND_LIST_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: second user's list unexpectedly contains first user's title"; exit 1; }

# Cleanup — undo Given side effects
SHORT_CLEANUP="delete both created todos using their respective sessions"
echo "STEP: Cleanup — ${SHORT_CLEANUP}"
if [ -n "$FIRST_TODO_ID" ]; then
  first_delete_code="$({
    curl -sS -X DELETE "$BASE_URL/api/todos/$FIRST_TODO_ID" \
      -b "$FIRST_COOKIE_FILE" \
      -D "$FIRST_DELETE_HEADERS_FILE" \
      -o "$FIRST_DELETE_BODY_FILE" \
      -w '%{http_code}'
  } || true)"
  echo "RESPONSE_HEADERS:"
  cat "$FIRST_DELETE_HEADERS_FILE"
  echo "RESPONSE_BODY:"
  cat "$FIRST_DELETE_BODY_FILE"
  echo "RESPONSE_STATUS: $first_delete_code"
  [ "$first_delete_code" = "200" ] || { echo "ASSERTION_FAILED: expected first cleanup HTTP 200 got ${first_delete_code}"; exit 1; }
fi
if [ -n "$SECOND_TODO_ID" ]; then
  second_delete_code="$({
    curl -sS -X DELETE "$BASE_URL/api/todos/$SECOND_TODO_ID" \
      -b "$SECOND_COOKIE_FILE" \
      -D "$SECOND_DELETE_HEADERS_FILE" \
      -o "$SECOND_DELETE_BODY_FILE" \
      -w '%{http_code}'
  } || true)"
  echo "RESPONSE_HEADERS:"
  cat "$SECOND_DELETE_HEADERS_FILE"
  echo "RESPONSE_BODY:"
  cat "$SECOND_DELETE_BODY_FILE"
  echo "RESPONSE_STATUS: $second_delete_code"
  [ "$second_delete_code" = "200" ] || { echo "ASSERTION_FAILED: expected second cleanup HTTP 200 got ${second_delete_code}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:multiple_users_create_independent_todos"
