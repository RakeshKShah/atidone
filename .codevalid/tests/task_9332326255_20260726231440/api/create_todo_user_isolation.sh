#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
TEST_ID="create_todo_user_isolation"
AUTH_COOKIE="${AUTH_COOKIE:-}"
REQUEST_BODY_FILE="/tmp/${TEST_ID}_request_${CASE_SUFFIX}.json"
RESPONSE_HEADERS_FILE="/tmp/${TEST_ID}_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY_FILE="/tmp/${TEST_ID}_response_body_${CASE_SUFFIX}.txt"
CLEANUP_HEADERS_FILE="/tmp/${TEST_ID}_cleanup_headers_${CASE_SUFFIX}.txt"
CLEANUP_BODY_FILE="/tmp/${TEST_ID}_cleanup_body_${CASE_SUFFIX}.txt"
TITLE="Alpha's private task ${CASE_SUFFIX}"
CREATED_ID=""

cleanup_files() {
  rm -f "$REQUEST_BODY_FILE" "$RESPONSE_HEADERS_FILE" "$RESPONSE_BODY_FILE" "$CLEANUP_HEADERS_FILE" "$CLEANUP_BODY_FILE"
}
trap cleanup_files EXIT

cat > "$REQUEST_BODY_FILE" <<EOF
{"title":"$TITLE","userId":"user-beta"}
EOF

# Given — bring the system to the required state
echo "STEP: Given — authenticated session belongs to user-alpha while request attempts to smuggle user-beta"
echo "PREREQ: mint authenticated session for user-alpha and pass it in AUTH_COOKIE"
[ -n "$AUTH_COOKIE" ] || { echo "ASSERTION_FAILED: expected AUTH_COOKIE env var containing a valid authenticated session cookie"; exit 1; }
printf '%s\n' "$AUTH_COOKIE" | grep -F 'nuxt-session=' >/dev/null || { echo "ASSERTION_FAILED: expected AUTH_COOKIE to contain nuxt-session cookie"; exit 1; }

# When — perform the action under test
echo "STEP: When — POST /api/todos while attempting client-controlled userId override"
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
echo "STEP: Then — created todo is associated with authenticated user only"
[ "$code" = "200" ] || [ "$code" = "201" ] || { echo "ASSERTION_FAILED: expected HTTP 200 or 201 got ${code}"; exit 1; }
if command -v jq >/dev/null 2>&1; then
  CREATED_ID="$(jq -r '.id' "$RESPONSE_BODY_FILE")"
  [ -n "$CREATED_ID" ] && [ "$CREATED_ID" != "null" ] || { echo "ASSERTION_FAILED: expected created id"; exit 1; }
  RESPONSE_TITLE="$(jq -r '.title' "$RESPONSE_BODY_FILE")"
  [ "$RESPONSE_TITLE" = "$TITLE" ] || { echo "ASSERTION_FAILED: expected title '$TITLE' got '$RESPONSE_TITLE'"; exit 1; }
  RESPONSE_USER_ID="$(jq -r '.userId' "$RESPONSE_BODY_FILE")"
  [ "$RESPONSE_USER_ID" = "user-alpha" ] || { echo "ASSERTION_FAILED: expected server-controlled userId user-alpha got '$RESPONSE_USER_ID'"; exit 1; }
  [ "$RESPONSE_USER_ID" != "user-beta" ] || { echo "ASSERTION_FAILED: expected userId not to be user-beta"; exit 1; }
else
  grep -F "$TITLE" "$RESPONSE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected response to contain created title"; exit 1; }
  grep -F '"userId":"user-alpha"' "$RESPONSE_BODY_FILE" >/dev/null || { echo "ASSERTION_FAILED: expected userId user-alpha in response"; exit 1; }
  CREATED_ID="$(sed -n 's/.*"id":"\([^"]*\)".*/\1/p' "$RESPONSE_BODY_FILE" | head -n 1)"
  [ -n "$CREATED_ID" ] || { echo "ASSERTION_FAILED: expected to parse created id from response"; exit 1; }
fi

# Cleanup — undo Given side effects
echo "STEP: Cleanup — delete the isolated todo through the public API"
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

echo "CODEVALID_TEST_ASSERTION_OK:create_todo_user_isolation"
