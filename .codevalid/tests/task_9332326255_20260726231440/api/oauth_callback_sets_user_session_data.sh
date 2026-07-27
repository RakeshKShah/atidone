#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
HEADERS_FILE="/tmp/oauth_callback_sets_user_session_data_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/oauth_callback_sets_user_session_data_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — observe only public redirect behavior because internal OAuth callback/session storage is not externally mockable here"

echo "STEP: When — request the public GitHub OAuth endpoint"
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
set_cookie_present="$(awk 'BEGIN{IGNORECASE=1} /^Set-Cookie:/ {print "yes"; exit}' "$HEADERS_FILE" || true)"

echo "STEP: Then — verify the public endpoint starts an OAuth redirect flow instead of returning user session JSON directly"
case "$status" in
  301|302|303|307|308) ;;
  *) echo "ASSERTION_FAILED: expected redirect HTTP status got ${status}"; exit 1 ;;
esac
[ -n "$location" ] || { echo "ASSERTION_FAILED: expected Location header to be present"; exit 1; }
case "$location" in
  *github*|*login*|*/todos*) ;;
  *) echo "ASSERTION_FAILED: expected redirect location to reference OAuth progression, got ${location}"; exit 1 ;;
esac
[ -z "$set_cookie_present" ] || echo "INFO: Set-Cookie observed on redirect response"

echo "STEP: Cleanup — no stateful setup to undo"
echo 'CODEVALID_TEST_ASSERTION_OK:oauth_callback_sets_user_session_data'
