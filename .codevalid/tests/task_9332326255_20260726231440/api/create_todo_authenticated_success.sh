#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_authenticated_success"
COOKIE_FILE="${COOKIE_FILE:-${AUTH_COOKIE_FILE:-}}"
TITLE="Buy groceries for the week"
HEADERS_FILE="/tmp/${TEST_ID}_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/${TEST_ID}_body_${CASE_SUFFIX}.txt"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"
DELETE_HEADERS_FILE="/tmp/${TEST_ID}_delete_headers_${CASE_SUFFIX}.txt"
DELETE_BODY_FILE="/tmp/${TEST_ID}_delete_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$REQUEST_BODY_FILE" "$DELETE_HEADERS_FILE" "$DELETE_BODY_FILE"
}
trap cleanup_files EXIT

CREATED_TODO_ID=""

printf '{"title":"%s"}' "$TITLE" > "$REQUEST_BODY_FILE"

# Given — bring the system to the required state
SHORT_GIVEN="authenticated user session is available"
echo "STEP: Given — ${SHORT_GIVEN}"
echo "PREREQ: verify authenticated cookie file is provided"
[ -n "$COOKIE_FILE" ] || { echo "ASSERTION_FAILED: expected COOKIE_FILE or AUTH_COOKIE_FILE for authenticated request"; exit 1; }
[ -f "$COOKIE_FILE" ] || { echo "ASSERTION_FAILED: cookie file not found at $COOKIE_FILE"; exit 1; }

# When — perform the action under test
SHORT_WHEN="create todo via POST /api/todos"
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
SHORT_THEN="response indicates todo created for authenticated user"
echo "STEP: Then — ${SHORT_THEN}"
[ "$code" = "200" ] || [ "$code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 200 or 201 got ${code}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  CREATED_TODO_ID="$(jq -r '.id' "$BODY_FILE")"
  [ "$CREATED_TODO_ID" != "null" ] && [ -n "$CREATED_TODO_ID" ] || { echo "ASSERTION_FAILED: expected response id"; exit 1; }
  RESPONSE_TITLE="$(jq -r '.title' "$BODY_FILE")"
  [ "$RESPONSE_TITLE" = "$TITLE" ] || { echo "ASSERTION_FAILED: expected title '$TITLE' got '$RESPONSE_TITLE'"; exit 1; }
  RESPONSE_USER_ID="$(jq -r '.userId' "$BODY_FILE")"
  [ "$RESPONSE_USER_ID" = "user-123" ] || { echo "ASSERTION_FAILED: expected userId 'user-123' got '$RESPONSE_USER_ID'"; exit 1; }
  CREATED_AT="$(jq -r '.createdAt' "$BODY_FILE")"
  [ "$CREATED_AT" != "null" ] && [ -n "$CREATED_AT" ] || { echo "ASSERTION_FAILED: expected createdAt to be present"; exit 1; }
else
  grep -F '"title":"Buy groceries for the week"' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain todo title"; exit 1; }
  grep -F '"userId":"user-123"' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected response body to contain userId user-123"; exit 1; }
  CREATED_TODO_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$BODY_FILE" | head -n 1)"
  [ -n "$CREATED_TODO_ID" ] || { echo "ASSERTION_FAILED: expected response body to contain id"; exit 1; }
fi

# Cleanup — undo Given side effects
SHORT_CLEANUP="delete created todo via API"
echo "STEP: Cleanup — ${SHORT_CLEANUP}"
if [ -n "$CREATED_TODO_ID" ]; then
  echo "PREREQ: deleting created todo id $CREATED_TODO_ID"
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

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_authenticated_success"
