#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_very_long_title"
AUTH_COOKIE="${AUTH_COOKIE:-}"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"
RESPONSE_HEADERS_FILE="/tmp/${TEST_ID}_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY_FILE="/tmp/${TEST_ID}_response_body_${CASE_SUFFIX}.txt"
CLEANUP_HEADERS_FILE="/tmp/${TEST_ID}_cleanup_headers_${CASE_SUFFIX}.txt"
CLEANUP_BODY_FILE="/tmp/${TEST_ID}_cleanup_body_${CASE_SUFFIX}.txt"
LONG_TITLE="1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
CREATED_ID=""

cleanup_files() {
  rm -f "$REQUEST_BODY_FILE" "$RESPONSE_HEADERS_FILE" "$RESPONSE_BODY_FILE" "$CLEANUP_HEADERS_FILE" "$CLEANUP_BODY_FILE"
}
trap cleanup_files EXIT

printf '{"title":"%s"}\n' "$LONG_TITLE" > "$REQUEST_BODY_FILE"

# Given — bring the system to the required state
echo "STEP: Given — prepare authenticated session for long-title boundary test"
echo "PREREQ: mint authenticated session for user-length and pass it in AUTH_COOKIE"
[ -n "$AUTH_COOKIE" ] || { echo "ASSERTION_FAILED: expected AUTH_COOKIE env var containing a valid authenticated session cookie"; exit 1; }
printf '%s\n' "$AUTH_COOKIE" | grep -F 'nuxt-session=' >/dev/null || { echo "ASSERTION_FAILED: expected AUTH_COOKIE to contain nuxt-session cookie"; exit 1; }

# When — perform the action under test
echo "STEP: When — POST /api/todos with a very long title"
echo "REQUEST_HEADERS: Content-Type: application/json; Cookie: $AUTH_COOKIE"
echo "REQUEST_BODY:"
cat "$REQUEST_BODY_FILE"
code="$(curl -sS -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -H "Cookie: $AUTH_COOKIE" \
  -D "$RESPONSE_HEADERS_FILE" \
  -o "$RESPONSE_BODY_FILE" \
  -w '%{http_code}' \
  --data @"$REQUEST_BODY_FILE" || true)"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY_FILE"
echo "RESPONSE_STATUS: $code"

# Then — HTTP/body assertions
echo "STEP: Then — endpoint either accepts or validation-rejects the boundary title consistently"
case "$code" in
  200|201)
    if command -v jq >/dev/null 2>&1; then
      CREATED_ID="$(jq -r '.id' "$RESPONSE_BODY_FILE")"
      [ -n "$CREATED_ID" ] && [ "$CREATED_ID" != "null" ] || { echo "ASSERTION_FAILED: expected created id for accepted long title"; exit 1; }
      RESPONSE_TITLE="$(jq -r '.title' "$RESPONSE_BODY_FILE")"
      [ "$RESPONSE_TITLE" = "$LONG_TITLE" ] || { echo "ASSERTION_FAILED: expected accepted long title to round-trip exactly"; exit 1; }
    else
      grep -F "$LONG_TITLE" "$RESPONSE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected accepted long title in response body"; exit 1; }
      CREATED_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$RESPONSE_BODY_FILE" | head -n 1)"
      [ -n "$CREATED_ID" ] || { echo "ASSERTION_FAILED: expected created id when long title is accepted"; exit 1; }
    fi
    ;;
  400)
    grep -Ei 'title|validation|length|max|too long|invalid' "$RESPONSE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected validation message when long title is rejected"; exit 1; }
    ;;
  *)
    echo "ASSERTION_FAILED: expected HTTP 200, 201, or 400 got ${code}"; exit 1 ;;
esac

# Cleanup — undo Given side effects
echo "STEP: Cleanup — delete created todo only when long title was accepted"
if [ -n "$CREATED_ID" ]; then
  echo "PREREQ: delete todo id $CREATED_ID created by this test"
  cleanup_code="$(curl -sS -X DELETE "$BASE_URL/api/todos/$CREATED_ID" \
    -H "Cookie: $AUTH_COOKIE" \
    -D "$CLEANUP_HEADERS_FILE" \
    -o "$CLEANUP_BODY_FILE" \
    -w '%{http_code}' || true)"
  echo "REQUEST_HEADERS: Cookie: $AUTH_COOKIE"
  echo "REQUEST_BODY:"
  printf '\n'
  echo "RESPONSE_HEADERS:"
  cat "$CLEANUP_HEADERS_FILE"
  echo "RESPONSE_BODY:"
  cat "$CLEANUP_BODY_FILE"
  echo "RESPONSE_STATUS: $cleanup_code"
  [ "$cleanup_code" = "200" ] || { echo "ASSERTION_FAILED: expected cleanup HTTP 200 got ${cleanup_code}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_very_long_title"
