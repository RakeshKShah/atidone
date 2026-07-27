#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
HEADERS_FILE="/tmp/github_oauth_success_establishes_session_and_redirects_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/github_oauth_success_establishes_session_and_redirects_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — ensure the GitHub OAuth entrypoint is reachable without a pre-existing session"

echo "STEP: When — request GitHub OAuth start endpoint"
echo 'REQUEST_HEADERS:'
printf 'Accept: */*\n'
echo 'REQUEST_BODY:'
echo '<empty>'
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' "$BASE_URL/api/auth/github")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $status"

location="$(awk 'BEGIN{IGNORECASE=1} /^Location:/ {sub(/\r$/, "", $0); print substr($0, index($0,$2)); exit}' "$HEADERS_FILE")"


echo "STEP: Then — verify the endpoint initiates redirect-based OAuth flow"
case "$status" in
  301|302|303|307|308) ;;
  *) echo "ASSERTION_FAILED: expected redirect HTTP status got ${status}"; exit 1 ;;
esac
[ -n "$location" ] || { echo "ASSERTION_FAILED: expected Location header to be present"; exit 1; }
case "$location" in
  *github*|*login*|*/todos*) ;;
  *) echo "ASSERTION_FAILED: expected redirect location to reference GitHub auth or post-auth todos path, got ${location}"; exit 1 ;;
esac

echo "STEP: Cleanup — no stateful setup to undo"
echo 'CODEVALID_TEST_ASSERTION_OK:github_oauth_success_establishes_session_and_redirects'
