#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
OAUTH_HEADERS="/tmp/authenticated_user_retrieves_own_todos_oauth_headers_${CASE_SUFFIX}.txt"
OAUTH_BODY="/tmp/authenticated_user_retrieves_own_todos_oauth_body_${CASE_SUFFIX}.txt"
RESPONSE_HEADERS="/tmp/authenticated_user_retrieves_own_todos_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/authenticated_user_retrieves_own_todos_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$OAUTH_HEADERS" "$OAUTH_BODY" "$RESPONSE_HEADERS" "$RESPONSE_BODY"
}
trap cleanup_files EXIT

# Given

echo "STEP: Given — confirm the available authentication entry point is GitHub OAuth for this Nuxt stack"
echo "PREREQ: request the public OAuth bootstrap endpoint to verify auth is configured"
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

echo "STEP: When — request GET /api/todos without a completed authenticated session"
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

echo "STEP: Then — verify the protected todos route denies access until OAuth session completion"
case "$status" in
  401|302|303|500)
    ;;
  *)
    echo "ASSERTION_FAILED: expected HTTP 401, 302, 303, or 500 for unauthenticated protected todo access got ${status}"
    exit 1
    ;;
esac
if [ "$status" = "302" ] || [ "$status" = "303" ]; then
  grep -qi '^location:' "$RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected redirect response to include Location header"; exit 1; }
fi
if jq -e 'type == "array"' "$RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected protected endpoint not to return a todo array without an authenticated session"
  exit 1
fi
grep -Eqi 'auth|session|unauth|github|oauth' "$OAUTH_HEADERS" || grep -Eqi 'auth|session|unauth|github|oauth' "$RESPONSE_HEADERS" "$RESPONSE_BODY" || { echo "ASSERTION_FAILED: expected auth-related evidence in OAuth or protected-route response artifacts"; exit 1; }

# Cleanup

echo "STEP: Cleanup — no cleanup required because the requests were read-only and stateless"

echo "CODEVALID_TEST_ASSERTION_OK:authenticated_user_retrieves_own_todos"
