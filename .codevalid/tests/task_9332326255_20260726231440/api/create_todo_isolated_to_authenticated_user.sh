#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_isolated_to_authenticated_user"
COOKIE_FILE="${COOKIE_FILE:-${AUTH_COOKIE_FILE:-}}"
TITLE="Alice's personal task"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"
LIST_HEADERS_FILE="/tmp/${TEST_ID}_list_headers_${CASE_SUFFIX}.txt"
LIST_BODY_FILE="/tmp/${TEST_ID}_list_body_${CASE_SUFFIX}.txt"
DELETE_HEADERS_FILE="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY_FILE="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_FILE" "$LIST_HEADERS_FILE" "$LIST_BODY_FILE" "$DELETE_HEADERS_FILE" "$DELETE_BODY_FILE"
}
trap cleanup_files EXIT

CREATED_TODO_ID=""
printf '{"title":"%s"}' "$TITLE" > "$REQUEST_BODY_FILE"

# Given — bring the system to the required state
SHORT_GIVEN="authenticated session for Alice is available"
echo "STEP: Given — ${SHORT_GIVEN}"
echo "PREREQ: verify authenticated cookie file is provided"
[ -n "$COOKIE_FILE" ] || { echo "ASSERTION_FAILED: expected COOKIE_FILE or AUTH_COOKIE_FILE for authenticated request"; exit 1; }
[ -f "$COOKIE_FILE" ] || { echo "ASSERTION_FAILED: cookie file not found at $COOKIE_FILE"; exit 1; }

# When — perform the action under test
SHORT_WHEN="create todo as Alice"
echo "STEP: When — ${SHORT_WHEN}"
echo "REQUEST_HEADERS: Content-Type: application/json"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
code="$({
  curl -sS -X POST "$BASE_URL/api/todos" \
    -H 'Content-Type: application/json' \
    -b "$COOKIE_FILE" \
    -D "$HEADERS_FILE" \
    -o "$BODY_FILE" \
    -w '%{http_code}' \
    --data @"$REQUEST_BODY_FILE"
} || true)"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
SHORT_THEN="created todo is tied to authenticated user only"
echo "STEP: Then — ${SHORT_THEN}"
[ "$code" = "200" ] || [ "$code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 200 or 201 got ${code}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  CREATED_TODO_ID="$(jq -r '.id' "$BODY_FILE")"
  [ "$CREATED_TODO_ID" != "null" ] && [ -n "$CREATED_TODO_ID" ] || { echo "ASSERTION_FAILED: expected response id"; exit 1; }
  RESPONSE_USER_ID="$(jq -r '.userId' "$BODY_FILE")"
  [ "$RESPONSE_USER_ID" = "user-alice" ] || { echo "ASSERTION_FAILED: expected userId 'user-alice' got '$RESPONSE_USER_ID'"; exit 1; }
  RESPONSE_TITLE="$(jq -r '.title' "$BODY_FILE")"
  [ "$RESPONSE_TITLE" = "$TITLE" ] || { echo "ASSERTION_FAILED: expected title '$TITLE' got '$RESPONSE_TITLE'"; exit 1; }
else
  grep -F '"userId":"user-alice"' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected response body userId user-alice"; exit 1; }
  grep -F '"title":"Alice' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected response body title for Alice"; exit 1; }
  CREATED_TODO_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$BODY_FILE" | head -n 1)"
  [ -n "$CREATED_TODO_ID" ] || { echo "ASSERTION_FAILED: expected response body to contain id"; exit 1; }
fi

echo "PREREQ: list todos for same authenticated user to confirm visibility in own collection"
list_code="$({
  curl -sS -X GET "$BASE_URL/api/todos" \
    -b "$COOKIE_FILE" \
    -D "$LIST_HEADERS_FILE" \
    -o "$LIST_BODY_FILE" \
    -w '%{http_code}'
} || true)"
echo "RESPONSE_HEADERS:"
cat "$LIST_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$LIST_BODY_FILE"
echo "RESPONSE_STATUS: $list_code"
[ "$list_code" = "200" ] || { echo "ASSERTION_FAILED: expected list HTTP 200 got ${list_code}"; exit 1; }
grep -F "$TITLE" "$LIST_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected authenticated user's todo list to contain created title"; exit 1; }
! grep -F 'user-bob' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: response body unexpectedly references user-bob"; exit 1; }

# Cleanup — undo Given side effects
SHORT_CLEANUP="delete Alice's created todo"
echo "STEP: Cleanup — ${SHORT_CLEANUP}"
if [ -n "$CREATED_TODO_ID" ]; then
  delete_code="$({
    curl -sS -X DELETE "$BASE_URL/api/todos/$CREATED_TODO_ID" \
      -b "$COOKIE_FILE" \
      -D "$DELETE_HEADERS_FILE" \
      -o "$DELETE_BODY_FILE" \
      -w '%{http_code}'
  } || true)"
  echo "RESPONSE_HEADERS:"
  cat "$DELETE_HEADERS_FILE"
  echo "RESPONSE_BODY:"
  cat "$DELETE_BODY_FILE"
  echo "RESPONSE_STATUS: $delete_code"
  [ "$delete_code" = "200" ] || { echo "ASSERTION_FAILED: expected cleanup HTTP 200 got ${delete_code}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_isolated_to_authenticated_user"
