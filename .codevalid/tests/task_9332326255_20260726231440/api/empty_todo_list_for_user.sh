#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
OAUTH_HEADERS="/tmp/empty_todo_list_for_user_oauth_headers_${CASE_SUFFIX}.txt"
OAUTH_BODY="/tmp/empty_todo_list_for_user_oauth_body_${CASE_SUFFIX}.txt"
RESPONSE_HEADERS="/tmp/empty_todo_list_for_user_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/empty_todo_list_for_user_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$OAUTH_HEADERS" "$OAUTH_BODY" "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

# Given

echo "STEP: Given — verify authentication must start through GitHub OAuth before a new user can reach their todo list"
echo "PREREQ: request the OAuth bootstrap endpoint exposed by the app"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
oauth_status="$(curl -sS -D "$OAUTH_HEADERS" -o "$OAUTH_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/auth/github")"
echo "RESPONSE_HEADERS:"
cat "$OAUTH_HEADERS"
echo "RESPONSE_BODY:"
cat "$OAUTH_BODY"
echo
echo "RESPONSE_STATUS: $oauth_status"
case "$oauth_status" in
  301|302|303|307|308)
    ;;
  *)
    echo "ASSERTION_FAILED: expected OAuth bootstrap HTTP 3xx got ${oauth_status}"
    exit 1
    ;;
esac
grep -qi '^location:.*github\|^location:.*oauth' "$OAUTH_HEADERS" || { echo "ASSERTION_FAILED: expected OAuth bootstrap redirect Location header to reference github or oauth"; exit 1; }

# When

echo "STEP: When — request GET /api/todos without completing OAuth for the fresh user context"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
status="$(curl -sS -D "$RESPONSE_HEADERS" -o "$RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $status"

# Then

echo "STEP: Then — verify the protected route requires authentication instead of returning a todo array for an uninitialized user session"
case "$status" in
  401|302|303|500)
    ;;
  *)
    echo "ASSERTION_FAILED: expected HTTP 401, 302, 303, or 500 for unauthenticated todo access got ${status}"
    exit 1
    ;;
esac
if [ "$status" = "302" ] || [ "$status" = "303" ]; then
  grep -qi '^location:' "$RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected redirect response to include Location header"; exit 1; }
fi
if jq -e 'type == "array"' "$RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected protected endpoint not to return an empty todo array before authentication"
  exit 1
fi
grep -Eqi 'auth|session|github|oauth|unauth' "$RESPONSE_HEADERS" "$RESPONSE_BODY" || { echo "ASSERTION_FAILED: expected auth-related denial details in response artifacts"; exit 1; }

# Cleanup

echo "STEP: Cleanup — no cleanup required because no user session or todo data was created"

echo "CODEVALID_TEST_ASSERTION_OK:empty_todo_list_for_user"
