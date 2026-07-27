#!/usr/bin/env sh
set -eu
BASE_URL="${BASE_URL:-http://app:6713}"
CASE_SUFFIX="$(date +%s)-$$"
HEADERS_FILE="/tmp/user_session_data_structure_headers_${CASE_SUFFIX}.txt"
BODY_FILE="/tmp/user_session_data_structure_body_${CASE_SUFFIX}.txt"
HEADERS_TODOS="/tmp/user_session_data_structure_headers_todos_${CASE_SUFFIX}.txt"
BODY_TODOS="/tmp/user_session_data_structure_body_todos_${CASE_SUFFIX}.txt"

cleanup_files() {
  rm -f "$HEADERS_FILE" "$BODY_FILE" "$HEADERS_TODOS" "$BODY_TODOS"
}
trap cleanup_files EXIT

echo "STEP: Given — observe only externally visible auth/session behavior because session internals are not exposed by a public API"

echo "STEP: When — initiate GitHub OAuth flow"
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

echo "STEP: When — verify protected todos remain inaccessible without a completed authenticated session"
echo 'REQUEST_HEADERS:'
printf 'Accept: application/json\n'
echo 'REQUEST_BODY:'
echo '<empty>'
status_todos="$(curl -sS -D "$HEADERS_TODOS" -o "$BODY_TODOS" -w '%{http_code}' "$BASE_URL/api/todos")"
echo 'RESPONSE_HEADERS:'
cat "$HEADERS_TODOS"
echo 'RESPONSE_BODY:'
cat "$BODY_TODOS"
echo "RESPONSE_STATUS: $status_todos"

echo "STEP: Then — verify public auth endpoint redirects and protected session-backed data is not exposed anonymously"
case "$status" in
  301|302|303|307|308) ;;
  *) echo "ASSERTION_FAILED: expected redirect status from OAuth entrypoint got ${status}"; exit 1 ;;
esac
[ -n "$location" ] || { echo "ASSERTION_FAILED: expected OAuth entrypoint Location header"; exit 1; }
case "$status_todos" in
  401|302|303|500) ;;
  *) echo "ASSERTION_FAILED: expected protected todos status 401/302/303/500 got ${status_todos}"; exit 1 ;;
esac

echo "STEP: Cleanup — no stateful setup to undo"
echo 'CODEVALID_TEST_ASSERTION_OK:user_session_data_structure'
