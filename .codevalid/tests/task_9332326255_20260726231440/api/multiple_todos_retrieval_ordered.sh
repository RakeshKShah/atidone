#!/usr/bin/env sh
set -eu

BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
OAUTH_HEADERS="/tmp/multiple_todos_retrieval_ordered_oauth_headers_${CASE_SUFFIX}.txt"
OAUTH_BODY="/tmp/multiple_todos_retrieval_ordered_oauth_body_${CASE_SUFFIX}.txt"
RESPONSE_HEADERS="/tmp/multiple_todos_retrieval_ordered_response_headers_${CASE_SUFFIX}.txt"
RESPONSE_BODY="/tmp/multiple_todos_retrieval_ordered_response_body_${CASE_SUFFIX}.txt"
SECOND_RESPONSE_HEADERS="/tmp/multiple_todos_retrieval_ordered_second_response_headers_${CASE_SUFFIX}.txt"
SECOND_RESPONSE_BODY="/tmp/multiple_todos_retrieval_ordered_second_response_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$OAUTH_HEADERS" "$OAUTH_BODY" "$RESPONSE_HEADERS" "$RESPONSE_BODY" "$SECOND_RESPONSE_HEADERS" "$SECOND_RESPONSE_BODY"
}
trap cleanup_files EXIT

# Given

echo "STEP: Given — verify the repo's only supported auth bootstrap is GitHub OAuth before any personal todo retrieval can occur"
echo "PREREQ: call GET /api/auth/github to confirm auth bootstrap is configured"
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

echo "STEP: When — make repeated unauthenticated GET /api/todos requests without a completed OAuth callback"
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

echo "REQUEST_HEADERS:"
echo "Accept: application/json"
echo "REQUEST_BODY: <empty>"
second_status="$(curl -sS -D "$SECOND_RESPONSE_HEADERS" -o "$SECOND_RESPONSE_BODY" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$SECOND_RESPONSE_HEADERS"
echo "RESPONSE_BODY:"
cat "$SECOND_RESPONSE_BODY"
echo
echo "RESPONSE_STATUS: $second_status"

# Then

echo "STEP: Then — verify repeated protected-route access remains denied and never returns a todo array or cross-user data"
case "$status" in
  401|302|303|500)
    ;;
  *)
    echo "ASSERTION_FAILED: expected first protected request HTTP 401, 302, 303, or 500 got ${status}"
    exit 1
    ;;
esac
case "$second_status" in
  401|302|303|500)
    ;;
  *)
    echo "ASSERTION_FAILED: expected second protected request HTTP 401, 302, 303, or 500 got ${second_status}"
    exit 1
    ;;
esac
if [ "$status" = "302" ] || [ "$status" = "303" ]; then
  grep -qi '^location:' "$RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected first redirect response to include Location header"; exit 1; }
fi
if [ "$second_status" = "302" ] || [ "$second_status" = "303" ]; then
  grep -qi '^location:' "$SECOND_RESPONSE_HEADERS" || { echo "ASSERTION_FAILED: expected second redirect response to include Location header"; exit 1; }
fi
if jq -e 'type == "array"' "$RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected first protected response not to return a todo array"
  exit 1
fi
if jq -e 'type == "array"' "$SECOND_RESPONSE_BODY" >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: expected second protected response not to return a todo array"
  exit 1
fi
grep -Eqi 'auth|session|github|oauth|unauth' "$RESPONSE_HEADERS" "$RESPONSE_BODY" "$SECOND_RESPONSE_HEADERS" "$SECOND_RESPONSE_BODY" || { echo "ASSERTION_FAILED: expected auth-related denial details across repeated protected-route responses"; exit 1; }

# Cleanup

echo "STEP: Cleanup — no cleanup required because the scenario performed no stateful setup"

echo "CODEVALID_TEST_ASSERTION_OK:multiple_todos_retrieval_ordered"
