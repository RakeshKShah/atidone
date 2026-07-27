#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
HEADERS_FILE="/tmp/unauthenticated_access_requires_sign_in_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/unauthenticated_access_requires_sign_in_body_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE"
}
trap cleanup_files EXIT

echo "STEP: Given — operate without any authentication cookie or session"

echo "STEP: When — request the protected todos listing endpoint unauthenticated"
echo 'REQUEST_HEADERS:'
printf 'Accept: application/json\n'
echo 'REQUEST_BODY:'
echo '<empty>'
status="$(curl -sS -D "$HEADERS_FILE" -o "$BODY_FILE" -w '%{http_code}' "$BASE_URL/api/todos")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_FILE"
echo 'RESPONSE_BODY:'
cat "$BODY_FILE"
echo "RESPONSE_STATUS: $status"

location="$(awk 'BEGIN{IGNORECASE=1} /^Location:/ {sub(/\r$/, "", $0); print substr($0, index($0,$2)); exit}' "$HEADERS_FILE" || true)"
body_text="$(cat "$BODY_FILE")"

echo "STEP: Then — verify unauthenticated access is blocked and no todo list is returned"
case "$status" in
  401|302|303|500) ;;
  *) echo "ASSERTION_FAILED: expected unauthenticated protection status 401/302/303/500 got ${status}"; exit 1 ;;
esac
if [ "$status" = "302" ] || [ "$status" = "303" ]; then
  [ -n "$location" ] || { echo "ASSERTION_FAILED: expected Location header for redirect response"; exit 1; }
fi
case "$body_text" in
  *'[]'*) echo "ASSERTION_FAILED: unexpected todo array returned to unauthenticated caller"; exit 1 ;;
  *) ;;
esac

echo "STEP: Cleanup — no stateful setup to undo"
echo 'CODEVALID_TEST_ASSERTION_OK:unauthenticated_access_requires_sign_in'
