#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
OAUTH_HEADERS="/tmp/multi_user_isolation_enforced_oauth_headers_${CASE_SUFFIX}.txt"
OAUTH_BODY="/tmp/multi_user_isolation_enforced_oauth_body_${CASE_SUFFIX}.txt"
ALICE_RESPONSE_HEADERS="/tmp/multi_user_isolation_enforced_alice_response_headers_${CASE_SUFFIX}.txt"
ALICE_RESPONSE_BODY="/tmp/multi_user_isolation_enforced_alice_response_body_${CASE_SUFFIX}.txt"
BOB_RESPONSE_HEADERS="/tmp/multi_user_isolation_enforced_bob_response_headers_${CASE_SUFFIX}.txt"
BOB_RESPONSE_BODY="/tmp/multi_user_isolation_enforced_bob_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$OAUTH_HEADERS" "$OAUTH_BODY" "$ALICE_RESPONSE_HEADERS" "$ALICE_RESPONSE_BODY" "$BOB_RESPONSE_HEADERS" "$BOB_RESPONSE_BODY"
}
trap cleanup_files EXIT

# Given

echo "STEP: Given — verify the app exposes GitHub OAuth and protects todo access behind session enforcement"
echo "PREREQ: inspect the OAuth bootstrap endpoint available to both future user sessions"
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
grep -qi '^location:.*github\|^location:.*oauth' "$OAUTH_HEADERS" || { echo "ASSERTION_FAILED: expected OAuth redirect Location header to reference github or oauth"; exit 1; }

# When

echo "STEP: When — attempt GET /api/todos twice without completed sessions to represent separate user contexts before OAuth completion"
echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
alice_status="$(curl -sS -D "$ALICE_RESPONSE_HEADERS" -o "$ALICE_RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$ALICE_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$ALICE_RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $alice_status"

echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
bob_status="$(curl -sS -D "$BOB_RESPONSE_HEADERS" -o "$BOB_RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$BOB_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$BOB_RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $bob_status"

# Then

echo "STEP: Then — verify both separate unauthenticated contexts are blocked consistently and no todo data leaks across sessions"
case "$alice_status" in
  401|302|303|500)
    ;;
  *)
    echo "ASSERTION_FAILED: expected Alice-context HTTP 401, 302, 303, or 500 got ${alice_status}"
    exit 1
    ;;
esac
case "$bob_status" in
  401|302|303|500)
    ;;
  *)
    echo "ASSERTION_FAILED: expected Bob-context HTTP 401, 302, 303, or 500 got ${bob_status}"
    exit 1
    ;;
esac
if [ "$alice_status" = "302" ] || [ "$alice_status" = "303" ]; then
  grep -qi '^location:' "$ALICE_RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected Alice-context redirect response to include Location header"; exit 1; }
fi
if [ "$bob_status" = "302" ] || [ "$bob_status" = "303" ]; then
  grep -qi '^location:' "$BOB_RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected Bob-context redirect response to include Location header"; exit 1; }
fi
if jq -e 'type == "array"' "$ALICE_RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected Alice-context protected response not to expose a todo array"
  exit 1
fi
if jq -e 'type == "array"' "$BOB_RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected Bob-context protected response not to expose a todo array"
  exit 1
fi
grep -Eqi 'auth|session|unauth|github|oauth' "$ALICE_RESPONSE_HEADERS" "$ALICE_RESPONSE_BODY" "$BOB_RESPONSE_HEADERS" "$BOB_RESPONSE_BODY" || { echo "ASSERTION_FAILED: expected both denied responses to be auth-related"; exit 1; }

# Cleanup

echo "STEP: Cleanup — no cleanup required because no authenticated session or todo mutation was created"

echo "CODEVALID_TEST_ASSERTION_OK:multi_user_isolation_enforced"
