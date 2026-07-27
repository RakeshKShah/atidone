#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_isolated_per_user"
ALICE_COOKIE_FILE="${ALICE_COOKIE_FILE:-${AUTH_COOKIE_FILE_ALICE:-}}"
BOB_COOKIE_FILE="${BOB_COOKIE_FILE:-${AUTH_COOKIE_FILE_BOB:-}}"
ALICE_REQUEST_BODY_FILE="/tmp/${TEST_ID}_alice_request_${CASE_SUFFIX}.json"
BOB_REQUEST_BODY_FILE="/tmp/${TEST_ID}_bob_request_${CASE_SUFFIX}.json"
ALICE_HEADERS_FILE="/tmp/${TEST_ID}_alice_headers_${CASE_SUFFIX}.txt"
ALICE_BODY_FILE="/tmp/${TEST_ID}_alice_body_${CASE_SUFFIX}.txt"
BOB_HEADERS_FILE="/tmp/${TEST_ID}_bob_headers_${CASE_SUFFIX}.txt"
BOB_BODY_FILE="/tmp/${TEST_ID}_bob_body_${CASE_SUFFIX}.txt"
ALICE_CLEANUP_HEADERS_FILE="/tmp/${TEST_ID}_alice_cleanup_headers_${CASE_SUFFIX}.txt"
ALICE_CLEANUP_BODY_FILE="/tmp/${TEST_ID}_alice_cleanup_body_${CASE_SUFFIX}.txt"
BOB_CLEANUP_HEADERS_FILE="/tmp/${TEST_ID}_bob_cleanup_headers_${CASE_SUFFIX}.txt"
BOB_CLEANUP_BODY_FILE="/tmp/${TEST_ID}_bob_cleanup_body_${CASE_SUFFIX}.txt"
ALICE_TITLE="Alice task ${CASE_SUFFIX}"
BOB_TITLE="Bob task ${CASE_SUFFIX}"
ALICE_ID=""
BOB_ID=""
ALICE_USER_ID=""
BOB_USER_ID=""

cleanup_files() {
  rm -f "$ALICE_REQUEST_BODY_FILE" "$BOB_REQUEST_BODY_FILE" "$ALICE_HEADERS_FILE" "$ALICE_BODY_FILE" "$BOB_HEADERS_FILE" "$BOB_BODY_FILE" "$ALICE_CLEANUP_HEADERS_FILE" "$ALICE_CLEANUP_BODY_FILE" "$BOB_CLEANUP_HEADERS_FILE" "$BOB_CLEANUP_BODY_FILE"
}
trap cleanup_files EXIT

printf '{"title":"%s"}' "$ALICE_TITLE" > "$ALICE_REQUEST_BODY_FILE"
printf '{"title":"%s"}' "$BOB_TITLE" > "$BOB_REQUEST_BODY_FILE"

# Given — bring the system to the required state
echo "STEP: Given — ensure two distinct authenticated session cookie files are available"
echo "PREREQ: validate ALICE_COOKIE_FILE or AUTH_COOKIE_FILE_ALICE points to an existing authenticated cookie jar"
[ -n "$ALICE_COOKIE_FILE" ] || { echo "ASSERTION_FAILED: expected ALICE_COOKIE_FILE or AUTH_COOKIE_FILE_ALICE"; exit 1; }
[ -f "$ALICE_COOKIE_FILE" ] || { echo "ASSERTION_FAILED: alice cookie file not found at $ALICE_COOKIE_FILE"; exit 1; }
echo "PREREQ: validate BOB_COOKIE_FILE or AUTH_COOKIE_FILE_BOB points to an existing authenticated cookie jar"
[ -n "$BOB_COOKIE_FILE" ] || { echo "ASSERTION_FAILED: expected BOB_COOKIE_FILE or AUTH_COOKIE_FILE_BOB"; exit 1; }
[ -f "$BOB_COOKIE_FILE" ] || { echo "ASSERTION_FAILED: bob cookie file not found at $BOB_COOKIE_FILE"; exit 1; }

# When — perform the action under test
echo "STEP: When — each authenticated user creates a todo"
echo "REQUEST_HEADERS: Content-Type: application/json; Alice cookie jar from $ALICE_COOKIE_FILE"
echo "REQUEST_BODY:"
cat "$ALICE_REQUEST_BODY_FILE"
alice_code="$(curl -sS -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -b "$ALICE_COOKIE_FILE" \
  -D "$ALICE_HEADERS_FILE" \
  -o "$ALICE_BODY_FILE" \
  -w '%{http_code}' \
  --data @"$ALICE_REQUEST_BODY_FILE" || true)"
echo "RESPONSE_HEADERS:"
cat "$ALICE_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$ALICE_BODY_FILE"
echo "RESPONSE_STATUS: $alice_code"

echo "REQUEST_HEADERS: Content-Type: application/json; Bob cookie jar from $BOB_COOKIE_FILE"
echo "REQUEST_BODY:"
cat "$BOB_REQUEST_BODY_FILE"
bob_code="$(curl -sS -X POST "$BASE_URL/api/todos" \
  -H 'Content-Type: application/json' \
  -b "$BOB_COOKIE_FILE" \
  -D "$BOB_HEADERS_FILE" \
  -o "$BOB_BODY_FILE" \
  -w '%{http_code}' \
  --data @"$BOB_REQUEST_BODY_FILE" || true)"
echo "RESPONSE_HEADERS:"
cat "$BOB_HEADERS_FILE"
echo "RESPONSE_BODY:"
cat "$BOB_BODY_FILE"
echo "RESPONSE_STATUS: $bob_code"

# Then — HTTP/body assertions
echo "STEP: Then — each created todo is associated only with its requesting user"
[ "$alice_code" = "200" ] || [ "$alice_code" = "201" ] || { echo "ASSERTION_FAILED: expected Alice create HTTP 200 or 201 got ${alice_code}"; exit 1; }
[ "$bob_code" = "200" ] || [ "$bob_code" = "201" ] || { echo "ASSERTION_FAILED: expected Bob create HTTP 200 or 201 got ${bob_code}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  ALICE_ID="$(jq -r '.id' "$ALICE_BODY_FILE")"
  BOB_ID="$(jq -r '.id' "$BOB_BODY_FILE")"
  [ "$ALICE_ID" != "null" ] && [ -n "$ALICE_ID" ] || { echo "ASSERTION_FAILED: expected Alice response id"; exit 1; }
  [ "$BOB_ID" != "null" ] && [ -n "$BOB_ID" ] || { echo "ASSERTION_FAILED: expected Bob response id"; exit 1; }
  ALICE_USER_ID="$(jq -r '.userId' "$ALICE_BODY_FILE")"
  BOB_USER_ID="$(jq -r '.userId' "$BOB_BODY_FILE")"
  [ "$ALICE_USER_ID" != "null" ] && [ -n "$ALICE_USER_ID" ] || { echo "ASSERTION_FAILED: expected Alice userId field"; exit 1; }
  [ "$BOB_USER_ID" != "null" ] && [ -n "$BOB_USER_ID" ] || { echo "ASSERTION_FAILED: expected Bob userId field"; exit 1; }
  [ "$ALICE_USER_ID" != "$BOB_USER_ID" ] || { echo "ASSERTION_FAILED: expected different userId values for Alice and Bob responses"; exit 1; }
  [ "$(jq -r '.title' "$ALICE_BODY_FILE")" = "$ALICE_TITLE" ] || { echo "ASSERTION_FAILED: expected Alice title '$ALICE_TITLE'"; exit 1; }
  [ "$(jq -r '.title' "$BOB_BODY_FILE")" = "$BOB_TITLE" ] || { echo "ASSERTION_FAILED: expected Bob title '$BOB_TITLE'"; exit 1; }
else
  grep -F "$ALICE_TITLE" "$ALICE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected Alice response to contain created title"; exit 1; }
  grep -F "$BOB_TITLE" "$BOB_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected Bob response to contain created title"; exit 1; }
  ALICE_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$ALICE_BODY_FILE" | head -n 1)"
  BOB_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$BOB_BODY_FILE" | head -n 1)"
  [ -n "$ALICE_ID" ] || { echo "ASSERTION_FAILED: expected Alice response id"; exit 1; }
  [ -n "$BOB_ID" ] || { echo "ASSERTION_FAILED: expected Bob response id"; exit 1; }
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — delete todos created by each user"
if [ -n "$ALICE_ID" ]; then
  echo "PREREQ: deleting Alice todo id $ALICE_ID"
  alice_cleanup_code="$(curl -sS -X DELETE "$BASE_URL/api/todos/$ALICE_ID" \
    -b "$ALICE_COOKIE_FILE" \
    -D "$ALICE_CLEANUP_HEADERS_FILE" \
    -o "$ALICE_CLEANUP_BODY_FILE" \
    -w '%{http_code}' || true)"
  echo "RESPONSE_HEADERS:"
  cat "$ALICE_CLEANUP_HEADERS_FILE"
  echo "RESPONSE_BODY:"
  cat "$ALICE_CLEANUP_BODY_FILE"
  echo "RESPONSE_STATUS: $alice_cleanup_code"
  [ "$alice_cleanup_code" = "200" ] || { echo "ASSERTION_FAILED: expected Alice cleanup HTTP 200 got ${alice_cleanup_code}"; exit 1; }
fi
if [ -n "$BOB_ID" ]; then
  echo "PREREQ: deleting Bob todo id $BOB_ID"
  bob_cleanup_code="$(curl -sS -X DELETE "$BASE_URL/api/todos/$BOB_ID" \
    -b "$BOB_COOKIE_FILE" \
    -D "$BOB_CLEANUP_HEADERS_FILE" \
    -o "$BOB_CLEANUP_BODY_FILE" \
    -w '%{http_code}' || true)"
  echo "RESPONSE_HEADERS:"
  cat "$BOB_CLEANUP_HEADERS_FILE"
  echo "RESPONSE_BODY:"
  cat "$BOB_CLEANUP_BODY_FILE"
  echo "RESPONSE_STATUS: $bob_cleanup_code"
  [ "$bob_cleanup_code" = "200" ] || { echo "ASSERTION_FAILED: expected Bob cleanup HTTP 200 got ${bob_cleanup_code}"; exit 1; }
fi

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_isolated_per_user"
