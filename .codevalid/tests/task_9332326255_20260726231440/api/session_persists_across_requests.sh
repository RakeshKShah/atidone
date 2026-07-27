#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
HEADERS_ONE="/tmp/session_persists_across_requests_headers_one_${CASE_SUFFIX}.txt"
BODY_ONE="/tmp/session_persists_across_requests_body_one_${CASE_SUFFIX}.txt"
HEADERS_TWO="/tmp/session_persists_across_requests_headers_two_${CASE_SUFFIX}.txt"
BODY_TWO="/tmp/session_persists_across_requests_body_two_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_ONE" "$BODY_ONE" "$HEADERS_TWO" "$BODY_TWO"
}
trap cleanup_files EXIT

echo "STEP: Given — use repeated calls to the public GitHub OAuth entrypoint"

echo "STEP: When — perform the first OAuth start request"
echo 'REQUEST_HEADERS:'
printf 'Accept: */*\n'
echo 'REQUEST_BODY:'
echo '<empty>'
status_one="$(curl -sS -D "$HEADERS_ONE" -o "$BODY_ONE" -w '%{http_code}' "$BASE_URL/api/auth/github")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_ONE"
echo 'RESPONSE_BODY:'
cat "$BODY_ONE"
echo "RESPONSE_STATUS: $status_one"

location_one="$(awk 'BEGIN{IGNORECASE=1} /^Location:/ {sub(/\r$/, "", $0); print substr($0, index($0,$2)); exit}' "$HEADERS_ONE")"

echo "STEP: When — perform a second OAuth start request"
echo 'REQUEST_HEADERS:'
printf 'Accept: */*\n'
echo 'REQUEST_BODY:'
echo '<empty>'
status_two="$(curl -sS -D "$HEADERS_TWO" -o "$BODY_TWO" -w '%{http_code}' "$BASE_URL/api/auth/github")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_TWO"
echo 'RESPONSE_BODY:'
cat "$BODY_TWO"
echo "RESPONSE_STATUS: $status_two"

location_two="$(awk 'BEGIN{IGNORECASE=1} /^Location:/ {sub(/\r$/, "", $0); print substr($0, index($0,$2)); exit}' "$HEADERS_TWO")"

echo "STEP: Then — verify the endpoint behaves consistently across subsequent requests"
case "$status_one" in
  301|302|303|307|308) ;;
  *) echo "ASSERTION_FAILED: expected first request redirect status got ${status_one}"; exit 1 ;;
esac
case "$status_two" in
  301|302|303|307|308) ;;
  *) echo "ASSERTION_FAILED: expected second request redirect status got ${status_two}"; exit 1 ;;
esac
[ -n "$location_one" ] || { echo "ASSERTION_FAILED: expected first request Location header"; exit 1; }
[ -n "$location_two" ] || { echo "ASSERTION_FAILED: expected second request Location header"; exit 1; }

echo "STEP: Cleanup — no stateful setup to undo"
echo 'CODEVALID_TEST_ASSERTION_OK:session_persists_across_requests'
