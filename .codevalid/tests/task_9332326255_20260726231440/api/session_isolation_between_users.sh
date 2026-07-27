#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
COOKIE_JAR_A="/tmp/session_isolation_between_users_a_cookie_${CASE_SUFFIX}.txt"
COOKIE_JAR_B="/tmp/session_isolation_between_users_b_cookie_${CASE_SUFFIX}.txt"
HEADERS_A="/tmp/session_isolation_between_users_a_headers_${CASE_SUFFIX}.txt"
BODY_A="/tmp/session_isolation_between_users_a_body_${CASE_SUFFIX}.txt"
HEADERS_B="/tmp/session_isolation_between_users_b_headers_${CASE_SUFFIX}.txt"
BODY_B="/tmp/session_isolation_between_users_b_body_${CASE_SUFFIX}.txt"
HEADERS_PATCH="/tmp/session_isolation_between_users_patch_headers_${CASE_SUFFIX}.txt"
BODY_PATCH="/tmp/session_isolation_between_users_patch_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$COOKIE_JAR_A" "$COOKIE_JAR_B" "$HEADERS_A" "$BODY_A" "$HEADERS_B" "$BODY_B" "$HEADERS_PATCH" "$BODY_PATCH"
}
trap cleanup_files EXIT

echo "STEP: Given — require isolated authenticated session cookies for user A and user B"
USER_A_COOKIE="${USER_A_COOKIE:-}"
USER_B_COOKIE="${USER_B_COOKIE:-}"
USER_B_TODO_ID="${USER_B_TODO_ID:-todo-B-1}"
[ -n "$USER_A_COOKIE" ] || { echo "ASSERTION_FAILED: USER_A_COOKIE environment variable is required"; exit 1; }
[ -n "$USER_B_COOKIE" ] || { echo "ASSERTION_FAILED: USER_B_COOKIE environment variable is required"; exit 1; }
: > "$COOKIE_JAR_A"
: > "$COOKIE_JAR_B"
printf '%s\n' "$USER_A_COOKIE" > "$COOKIE_JAR_A"
printf '%s\n' "$USER_B_COOKIE" > "$COOKIE_JAR_B"
echo "PREREQ: wrote independent cookie jars for each user session"

echo "STEP: When — list todos as user A"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
status_a="$(curl -sS -D "$HEADERS_A" -o "$BODY_A" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR_A" -c "$COOKIE_JAR_A" "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_A"
echo "RESPONSE_BODY:"
cat "$BODY_A"
echo
echo "RESPONSE_STATUS: $status_a"
[ "$status_a" = "200" ] || { echo "ASSERTION_FAILED: expected user A list HTTP 200 got ${status_a}"; exit 1; }

echo "STEP: When — list todos as user B"
echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY:"
status_b="$(curl -sS -D "$HEADERS_B" -o "$BODY_B" -w '%{http_code}' -H 'Accept: application/json' -b "$COOKIE_JAR_B" -c "$COOKIE_JAR_B" "$BASE_URL/api/todos")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_B"
echo "RESPONSE_BODY:"
cat "$BODY_B"
echo
echo "RESPONSE_STATUS: $status_b"
[ "$status_b" = "200" ] || { echo "ASSERTION_FAILED: expected user B list HTTP 200 got ${status_b}"; exit 1; }

echo "STEP: When — attempt cross-user modification as user A against user B todo"
PATCH_BODY='{"completed":true}'
echo "REQUEST_HEADERS: Accept: application/json; Content-Type: application/json"
echo "REQUEST_BODY: $PATCH_BODY"
status_patch="$(curl -sS -X PATCH -D "$HEADERS_PATCH" -o "$BODY_PATCH" -w '%{http_code}' -H 'Accept: application/json' -H 'Content-Type: application/json' -b "$COOKIE_JAR_A" -c "$COOKIE_JAR_A" "$BASE_URL/api/todos/$USER_B_TODO_ID" --data "$PATCH_BODY")"
echo "RESPONSE_HEADERS:"
cat "$HEADERS_PATCH"
echo "RESPONSE_BODY:"
cat "$BODY_PATCH"
echo
echo "RESPONSE_STATUS: $status_patch"

echo "STEP: Then — verify each user sees only their own data and cross-user access is denied"
printf '%s' "$(cat "$BODY_A")" | grep -F 'todo-A-1' >/dev/null 2>&1 || {
  echo "ASSERTION_FAILED: expected user A response to include todo-A-1"
  exit 1
}
if printf '%s' "$(cat "$BODY_A")" | grep -F 'todo-B-1' >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: user A response unexpectedly exposed todo-B-1"
  exit 1
fi
printf '%s' "$(cat "$BODY_B")" | grep -F 'todo-B-1' >/dev/null 2>&1 || {
  echo "ASSERTION_FAILED: expected user B response to include todo-B-1"
  exit 1
}
if printf '%s' "$(cat "$BODY_B")" | grep -F 'todo-A-1' >/dev/null 2>&1; then
  echo "ASSERTION_FAILED: user B response unexpectedly exposed todo-A-1"
  exit 1
fi
case "$status_patch" in
  403|404) ;;
  *)
    echo "ASSERTION_FAILED: expected cross-user PATCH to be denied with 403 or 404 got ${status_patch}"
    exit 1
    ;;
esac

echo "STEP: Cleanup — remove temporary files only"
echo "CODEVALID_TEST_ASSERTION_OK:session_isolation_between_users"
