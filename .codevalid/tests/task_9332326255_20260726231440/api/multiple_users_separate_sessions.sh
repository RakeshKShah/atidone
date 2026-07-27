#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
HEADERS_FILE_ONE="/tmp/multiple_users_separate_sessions_headers_one_${CASE_SUFFIX}.txt"
BODY_FILE_ONE="/tmp/multiple_users_separate_sessions_body_one_${CASE_SUFFIX}.txt"
HEADERS_FILE_TWO="/tmp/multiple_users_separate_sessions_headers_two_${CASE_SUFFIX}.txt"
BODY_FILE_TWO="/tmp/multiple_users_separate_sessions_body_two_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE_ONE" "$BODY_FILE_ONE" "$HEADERS_FILE_TWO" "$BODY_FILE_TWO"
}
trap cleanup_files EXIT

echo "STEP: Given — use two independent unauthenticated requests as separate client sessions"

echo "STEP: When — initiate GitHub OAuth flow from session one"
echo 'REQUEST_HEADERS:'
printf 'Accept: */*\n'
echo 'REQUEST_BODY:'
echo '<empty>'
status_one="$(curl -sS -D "$HEADERS_FILE_ONE" -o "$BODY_FILE_ONE" -w '%{http_code}' "$BASE_URL/api/auth/github")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE_ONE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE_ONE"
echo "RESPONSE_STATUS: $status_one"

location_one="$(awk 'BEGIN{IGNORECASE=1} /^Location:/ {sub(/\r$/, "", $0); print substr($0, index($0,$2)); exit}' "$HEADERS_FILE_ONE")"

echo "STEP: When — initiate GitHub OAuth flow from session two"
echo 'REQUEST_HEADERS:'
printf 'Accept: */*\n'
echo 'REQUEST_BODY:'
echo '<empty>'
status_two="$(curl -sS -D "$HEADERS_FILE_TWO" -o "$BODY_FILE_TWO" -w '%{http_code}' "$BASE_URL/api/auth/github")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE_TWO"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE_TWO"
echo "RESPONSE_STATUS: $status_two"

location_two="$(awk 'BEGIN{IGNORECASE=1} /^Location:/ {sub(/\r$/, "", $0); print substr($0, index($0,$2)); exit}' "$HEADERS_FILE_TWO")"

echo "STEP: Then — verify both independent requests start redirect-based auth flows"
case "$status_one" in
  301|302|303|307|308) ;;
  *) echo "ASSERTION_FAILED: expected redirect status for first session got ${status_one}"; exit 1 ;;
esac
case "$status_two" in
  301|302|303|307|308) ;;
  *) echo "ASSERTION_FAILED: expected redirect status for second session got ${status_two}"; exit 1 ;;
esac
[ -n "$location_one" ] || { echo "ASSERTION_FAILED: first session missing Location header"; exit 1; }
[ -n "$location_two" ] || { echo "ASSERTION_FAILED: second session missing Location header"; exit 1; }
case "$location_one" in
  *github*|*login*|*/todos*) ;;
  *) echo "ASSERTION_FAILED: unexpected first session redirect location ${location_one}"; exit 1 ;;
esac
case "$location_two" in
  *github*|*login*|*/todos*) ;;
  *) echo "ASSERTION_FAILED: unexpected second session redirect location ${location_two}"; exit 1 ;;
esac

echo "STEP: Cleanup — no stateful setup to undo"
echo 'CODEVALID_TEST_ASSERTION_OK:multiple_users_separate_sessions'
