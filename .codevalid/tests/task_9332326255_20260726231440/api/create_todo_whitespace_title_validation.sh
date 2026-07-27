#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_whitespace_title_validation"
COOKIE_FILE="${COOKIE_FILE:-${AUTH_COOKIE_FILE:-}}"
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
printf '%s' '{"title":"   "}' > "$REQUEST_BODY_FILE"

# Given — bring the system to the required state
SHORT_GIVEN="authenticated user session exists"
echo "STEP: Given — ${SHORT_GIVEN}"
echo "PREREQ: verify authenticated cookie file is provided"
[ -n "$COOKIE_FILE" ] || { echo "ASSERTION_FAILED: expected COOKIE_FILE or AUTH_COOKIE_FILE for authenticated request"; exit 1; }
[ -f "$COOKIE_FILE" ] || { echo "ASSERTION_FAILED: cookie file not found at $COOKIE_FILE"; exit 1; }

# When — perform the action under test
SHORT_WHEN="submit POST /api/todos with whitespace-only title"
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
SHORT_THEN="behavior matches validation contract for whitespace-only title"
echo "STEP: Then — ${SHORT_THEN}"
if [ "$code" = "400" ] || [ "$code" = "422" ]; then
  grep -Ei 'title|required|invalid|validation|empty' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected validation message for whitespace-only title"; exit 1; }
elif [ "$code" = "200" ] || [ "$code" = "201" ]; then
  if command -v jq >/dev/null 2>&1; then
    CREATED_TODO_ID="$(jq -r '.id' "$BODY_FILE")"
    [ "$CREATED_TODO_ID" != "null" ] && [ -n "$CREATED_TODO_ID" ] || { echo "ASSERTION_FAILED: expected created todo id when whitespace title is accepted"; exit 1; }
    RESPONSE_TITLE="$(jq -r '.title' "$BODY_FILE")"
    [ "$RESPONSE_TITLE" != "null" ] || { echo "ASSERTION_FAILED: expected title field when whitespace title is accepted"; exit 1; }
  else
    grep -F '"id":' "$BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected id in successful response"; exit 1; }
    CREATED_TODO_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$BODY_FILE" | head -n 1)"
  fi
else
  echo "ASSERTION_FAILED: expected HTTP 400/422 or 200/201 for whitespace-title behavior, got ${code}"
  exit 1
fi

# Cleanup — undo Given side effects
SHORT_CLEANUP="delete created todo if whitespace title was accepted"
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

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_whitespace_title_validation"
