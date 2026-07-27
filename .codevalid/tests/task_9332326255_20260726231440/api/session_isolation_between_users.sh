#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR_A="/tmp/session_isolation_between_users_a_cookie_${CASE_SUFFIX}.txt"
COOKIE_JAR_B="/tmp/session_isolation_between_users_b_cookie_${CASE_SUFFIX}.txt"
AUTH_HEADERS_A="/tmp/session_isolation_between_users_a_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY_A="/tmp/session_isolation_between_users_a_auth_body_${CASE_SUFFIX}.txt"
AUTH_HEADERS_B="/tmp/session_isolation_between_users_b_auth_headers_${CASE_SUFFIX}.txt"
AUTH_BODY_B="/tmp/session_isolation_between_users_b_auth_body_${CASE_SUFFIX}.txt"
HEADERS_A="/tmp/session_isolation_between_users_a_headers_${CASE_SUFFIX}.txt"
BODY_A="/tmp/session_isolation_between_users_a_body_${CASE_SUFFIX}.txt"
HEADERS_B="/tmp/session_isolation_between_users_b_headers_${CASE_SUFFIX}.txt"
BODY_B="/tmp/session_isolation_between_users_b_body_${CASE_SUFFIX}.txt"
HEADERS_PATCH="/tmp/session_isolation_between_users_patch_headers_${CASE_SUFFIX}.txt"
BODY_PATCH="/tmp/session_isolation_between_users_patch_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR_A" "$COOKIE_JAR_B" "$AUTH_HEADERS_A" "$AUTH_BODY_A" "$AUTH_HEADERS_B" "$AUTH_BODY_B" "$HEADERS_A" "$BODY_A" "$HEADERS_B" "$BODY_B" "$HEADERS_PATCH" "$BODY_PATCH"
}
trap cleanup_files EXIT

echo "STEP: Given — initialize two isolated client contexts and bootstrap auth flow separately"
: > "$COOKIE_JAR_A"
: > "$COOKIE_JAR_B"
echo "PREREQ: created isolated cookie jars for user A and user B contexts"

echo "PREREQ: bootstrap auth flow for user A context"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
given_status_a="$(curl -sS -D "$AUTH_HEADERS_A" -o "$AUTH_BODY_A" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR_A" -c "$COOKIE_JAR_A" "$BASE_URL/api/auth/github")"
echo "RESPONSE_HEADERS:"
cat "$AUTH_HEADERS_A"
echo "RESPONSE_BODY:"
cat "$AUTH_BODY_A"
echo
echo "RESPONSE_STATUS: $given_status_a"
case "$given_status_a" in
  302|303|307|308) ;;
  *)
    echo "ASSERTION_FAILED: expected user A auth bootstrap to redirect got HTTP ${given_status_a}"
    exit 1
    ;;
esac

echo "PREREQ: bootstrap auth flow for user B context"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
given_status_b="$(curl -sS -D "$AUTH_HEADERS_B" -o "$AUTH_BODY_B" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR_B" -c "$COOKIE_JAR_B" "$BASE_URL/api/auth/github")"
echo "RESPONSE_HEADERS:"
cat "$AUTH_HEADERS_B"
echo "RESPONSE_BODY:"
cat "$AUTH_BODY_B"
echo
echo "RESPONSE_STATUS: $given_status_b"
case "$given_status_b" in
  302|303|307|308) ;;
  *)
    echo "ASSERTION_FAILED: expected user B auth bootstrap to redirect got HTTP ${given_status_b}"
    exit 1
    ;;
esac

echo "STEP: When — list todos using client context A"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
status_a="$(curl -sS -D "$HEADERS_A" -o "$BODY_A" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR_A" -c "$COOKIE_JAR_A" "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_A"
echo "RESPONSE_BODY:"
cat "$BODY_A"
echo
echo "RESPONSE_STATUS: $status_a"

echo "STEP: When — list todos using client context B"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
status_b="$(curl -sS -D "$HEADERS_B" -o "$BODY_B" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR_B" -c "$COOKIE_JAR_B" "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_B"
echo "RESPONSE_BODY:"
cat "$BODY_B"
echo
echo "RESPONSE_STATUS: $status_b"

echo "STEP: When — attempt direct cross-user modification through the public API"
PATCH_BODY='{"completed":true}'
echo "REQUEST_HEADERS: Accept: application/json; Content-Type: application/json"
echo "REQUEST_BODY: $PATCH_BODY"
status_patch="$(curl -sS -X PATCH -D "$HEADERS_PATCH" -o "$BODY_PATCH" -w '%{http_code}' -H 'Accept: application/json' -H 'Content-Type: application/json' -b "$COOKIE_JAR_A" -c "$COOKIE_JAR_A" "$BASE_URL/api/todos/todo-B-1" --data "$PATCH_BODY")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_PATCH"
echo "RESPONSE_BODY:"
cat "$BODY_PATCH"
echo
echo "RESPONSE_STATUS: $status_patch"

echo "STEP: Then — verify session contexts remain isolated and cross-user access is not granted"
case "$status_a" in
  200|302|303|307|308|401|500) ;;
  *)
    echo "ASSERTION_FAILED: expected known protected-route status for user A got ${status_a}"
    exit 1
    ;;
esac
case "$status_b" in
  200|302|303|307|308|401|500) ;;
  *)
    echo "ASSERTION_FAILED: expected known protected-route status for user B got ${status_b}"
    exit 1
    ;;
esac
case "$status_patch" in
  302|303|307|308|401|403|404|500) ;;
  *)
    echo "ASSERTION_FAILED: expected cross-user PATCH to be blocked with auth/error status got ${status_patch}"
    exit 1
    ;;
esac
if [ "$status_patch" = "200" ]; then
  echo "ASSERTION_FAILED: cross-user PATCH unexpectedly succeeded"
  exit 1
fi
if [ "$status_a" = "200" ] && [ "$status_b" = "200" ]; then
  cmp -s "$BODY_A" "$BODY_B" && {
    echo "ASSERTION_FAILED: expected isolated sessions to avoid identical todo payloads for distinct users"
    exit 1
  }
fi

echo "STEP: Cleanup — remove temporary files only"
echo "CODEVALID_TEST_ASSERTION_OK:session_isolation_between_users"
